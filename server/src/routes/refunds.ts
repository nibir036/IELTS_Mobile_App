// Refund requests for website (bKash) passes.
//
// Student (signed in, IELTS website › Plans & billing):
//   GET    /v1/billing/payments                     their bKash payments, refund state, whether they can ask
//   POST   /v1/billing/refund-requests              {paymentID, reason}  (within 7 days of paying)
//
// Staff (header X-Admin-Token = ADMIN_TOKEN; the page /admin/refunds):
//   GET    /v1/admin/refund-requests?status=open|all
//   POST   /v1/admin/refund-requests/:id/approve    {amount, staff, note?}  sends the money back through bKash
//   POST   /v1/admin/refund-requests/:id/refuse     {note, staff}           the student sees the note
//   POST   /v1/admin/refund-requests/:id/check      {staff}  when bKash didn't answer an approval
//   GET    /admin/refunds                           the staff page
//
// An approval first moves the request to "processing", so two staff pressing
// Approve at once can't refund twice. If bKash doesn't answer, it stays
// "processing" until someone presses Check (bKash's own refund record decides).

import { prisma } from '../db';
import { requireAdmin } from '../lib/admin';
import { refundableLeft, refundBkashPayment, bkashRefunds, recordRefund, refundsOf, REFUND_WINDOW_DAYS, type PaidPayment } from '../lib/billing/refunds';
import { pick } from '../lib/billing/bkash';
import { passes } from '../lib/billing/passes';
import { badRequest, forbidden, rateLimit, required, Router, s } from '../lib/http';
import { requireUser } from '../lib/users';
import { page, sendHtml } from './web';

type Row = Record<string, unknown>;
const DAY = 86_400_000;

type PaymentRow = PaidPayment & { userId: string; passId: string | null; createdAt: Date; updatedAt: Date };
type RequestRow = {
  id: string;
  paymentId: string;
  userId: string;
  reason: string;
  status: string;
  amount: number | null;
  refundTrxId: string | null;
  decisionNote: string | null;
  decidedBy: string | null;
  decidedAt: Date | null;
  createdAt: Date;
};

/** When the student paid (set at completion; older payments: when they started paying). */
const paidAt = (p: PaymentRow) => {
  const t = typeof p.meta?.paidAt === 'string' ? new Date(p.meta.paidAt) : null;
  return t && !Number.isNaN(t.getTime()) ? t : p.createdAt;
};

const deadline = (p: PaymentRow) => new Date(paidAt(p).getTime() + REFUND_WINDOW_DAYS * DAY);

async function passNames(): Promise<Map<string, string>> {
  return new Map((await passes()).map((p) => [p.id, p.name]));
}

const showPhone = (phone: string) => (/^1\d{9}$/.test(phone) ? `0${phone}` : phone);

/** A short message in the student's notifications (app and website). */
async function notify(userId: string, title: string, body: string): Promise<void> {
  await prisma.notification
    .create({ data: { userId, type: 'billing', title, body, target: '/home/plans' } })
    .catch((e) => console.error('[refunds] notification failed', e));
}

/** The staff member's name, as typed on the admin page (kept on the decision). */
function staffName(body: Row): string {
  const name = s(body.staff, 60).trim();
  if (name.length < 2) throw badRequest('Type your name first (it is saved with the decision).', 'staff_required');
  return name;
}

function requestView(r: RequestRow) {
  return {
    id: r.id,
    status: r.status,
    reason: r.reason,
    requestedAt: r.createdAt.toISOString(),
    amount: r.amount,
    refundTrxID: r.refundTrxId,
    note: r.decisionNote,
    decidedBy: r.decidedBy,
    decidedAt: r.decidedAt?.toISOString() ?? null,
  };
}

export function registerRefundRoutes(r: Router): void {
  // ── student ────────────────────────────────────────────────────────────

  r.get('/v1/billing/payments', async (ctx) => {
    const userId = requireUser(ctx);
    const [rows, names] = await Promise.all([
      prisma.payment.findMany({
        where: { userId, provider: 'bkash', kind: 'payment', status: { in: ['completed', 'refunded'] } },
        orderBy: { createdAt: 'desc' },
        take: 30,
        include: { refundRequest: true },
      }) as Promise<Array<PaymentRow & { refundRequest: RequestRow | null }>>,
      passNames(),
    ]);
    const now = Date.now();
    return {
      refundWindowDays: REFUND_WINDOW_DAYS,
      payments: rows.map((p) => {
        const until = deadline(p);
        return {
          paymentID: p.providerRef,
          trxID: p.trxId,
          passId: p.passId,
          passName: (p.passId && names.get(p.passId)) || 'Pro pass',
          amount: p.amount ?? 0,
          paidAt: paidAt(p).toISOString(),
          status: p.status,
          refunded: refundsOf(p.meta).reduce((n, x) => n + x.amount, 0),
          refundRequest: p.refundRequest ? requestView(p.refundRequest) : null,
          refundDeadline: until.toISOString(),
          canRequestRefund: p.status === 'completed' && !p.refundRequest && now < until.getTime() && refundableLeft(p) > 0,
        };
      }),
    };
  });

  r.post('/v1/billing/refund-requests', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`refund-request:${userId}`, 10, 3600);
    const paymentID = required(ctx.body, 'paymentID', 200);
    const reason = s(ctx.body.reason, 600).trim();
    if (reason.length < 10) throw badRequest('Please tell us a little more about why (at least 10 characters).', 'reason_short');
    if (reason.length > 500) throw badRequest('Please keep the reason under 500 characters.', 'reason_long');
    const pay = (await prisma.payment.findUnique({ where: { providerRef: paymentID } })) as PaymentRow | null;
    if (!pay || pay.userId !== userId) throw forbidden('This payment is not on your account.', 'bad_payment');
    if (pay.provider !== 'bkash' || pay.kind !== 'payment') throw badRequest('Only passes bought on the website with bKash can be refunded here.', 'not_refundable');
    if (pay.status !== 'completed' || refundableLeft(pay) <= 0) throw badRequest('This payment has already been refunded.', 'not_refundable');
    if (Date.now() >= deadline(pay).getTime()) {
      throw badRequest(`Refunds can be requested within ${REFUND_WINDOW_DAYS} days of paying. This payment is older.`, 'too_late');
    }
    try {
      await prisma.refundRequest.create({ data: { paymentId: pay.id, userId, reason } });
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002') throw badRequest('You have already asked for a refund of this payment.', 'already_requested');
      throw e;
    }
    return { ok: true, message: 'Thanks. We will look at your request and reply within 2 working days.' };
  });

  // ── staff ──────────────────────────────────────────────────────────────

  r.get('/v1/admin/refund-requests', async (ctx) => {
    requireAdmin(ctx);
    const open = ctx.query.get('status') !== 'all';
    const [rows, names] = await Promise.all([
      prisma.refundRequest.findMany({
        where: open ? { status: { in: ['requested', 'processing'] } } : {},
        orderBy: { createdAt: open ? 'asc' : 'desc' },
        take: 200,
        include: { payment: true, user: { select: { name: true, phone: true } } },
      }) as Promise<Array<RequestRow & { payment: PaymentRow; user: { name: string; phone: string } }>>,
      passNames(),
    ]);
    return {
      requests: rows.map((q) => ({
        ...requestView(q),
        student: { name: q.user.name, phone: showPhone(q.user.phone) },
        payment: {
          paymentID: q.payment.providerRef,
          trxID: q.payment.trxId,
          passName: (q.payment.passId && names.get(q.payment.passId)) || q.payment.passId || 'Pro pass',
          amount: q.payment.amount ?? 0,
          paidAt: paidAt(q.payment).toISOString(),
          status: q.payment.status,
          refunded: refundsOf(q.payment.meta).reduce((n, x) => n + x.amount, 0),
          refundable: refundableLeft(q.payment),
        },
      })),
    };
  });

  r.post('/v1/admin/refund-requests/:id/approve', async (ctx) => {
    requireAdmin(ctx);
    const staff = staffName(ctx.body);
    const note = s(ctx.body.note, 300).trim();
    const amount = Number(ctx.body.amount);
    // Claim it first: only one approval can go to bKash.
    const claim = await prisma.refundRequest.updateMany({ where: { id: ctx.params.id, status: 'requested' }, data: { status: 'processing', decidedBy: staff } });
    if (claim.count !== 1) throw badRequest('This request is already being handled or was decided. Reload the page.', 'not_open');
    const q = (await prisma.refundRequest.findUnique({ where: { id: ctx.params.id }, include: { payment: true } })) as (RequestRow & { payment: PaymentRow }) | null;
    if (!q) throw badRequest('Unknown request.', 'bad_request');
    const back = (data: Row = {}) => prisma.refundRequest.update({ where: { id: q.id }, data: { status: 'requested', ...data } });

    let result;
    try {
      result = await refundBkashPayment(q.payment, (note || 'Refund approved').slice(0, 100), amount);
    } catch (e) {
      await back(); // nothing reached bKash (wrong amount, payment already refunded …)
      throw e;
    }
    if (!result.ok) {
      if (result.noResponse) {
        await prisma.refundRequest.update({ where: { id: q.id }, data: { decisionNote: 'bKash did not answer: press Check.' } });
        return { done: false, status: 'processing', message: result.message };
      }
      await back();
      return { done: false, status: 'requested', message: result.message };
    }
    await prisma.refundRequest.update({
      where: { id: q.id },
      data: { status: 'refunded', amount: result.amount, refundTrxId: result.refundTrxID, decisionNote: note || null, decidedBy: staff, decidedAt: new Date() },
    });
    await notify(q.userId, 'Refund sent', `BDT ${result.amount} was sent back to your bKash (refund ID ${result.refundTrxID}).`);
    return { done: true, status: 'refunded', amount: result.amount, refundTrxID: result.refundTrxID, fullyRefunded: result.fullyRefunded };
  });

  r.post('/v1/admin/refund-requests/:id/refuse', async (ctx) => {
    requireAdmin(ctx);
    const staff = staffName(ctx.body);
    const note = s(ctx.body.note, 300).trim();
    if (note.length < 5) throw badRequest('Say why it is refused (the student sees this).', 'note_required');
    const q = (await prisma.refundRequest.findUnique({ where: { id: ctx.params.id } })) as RequestRow | null;
    const done = await prisma.refundRequest.updateMany({
      where: { id: ctx.params.id, status: 'requested' },
      data: { status: 'refused', decisionNote: note, decidedBy: staff, decidedAt: new Date() },
    });
    if (!q || done.count !== 1) throw badRequest('This request is already being handled or was decided. Reload the page.', 'not_open');
    await notify(q.userId, 'Refund request declined', note);
    return { done: true, status: 'refused' };
  });

  // An approval bKash didn't answer: bKash's own refund record decides.
  r.post('/v1/admin/refund-requests/:id/check', async (ctx) => {
    requireAdmin(ctx);
    const staff = staffName(ctx.body);
    const q = (await prisma.refundRequest.findUnique({ where: { id: ctx.params.id }, include: { payment: true } })) as (RequestRow & { payment: PaymentRow }) | null;
    if (!q || q.status !== 'processing') throw badRequest('Only a request waiting for bKash can be checked. Reload the page.', 'not_processing');
    const st = await bkashRefunds(q.payment);
    const known = new Set(refundsOf(q.payment.meta).map((x) => x.refundTrxID));
    const list = Array.isArray(st.data.refundTransactions) ? (st.data.refundTransactions as Row[]) : [];
    const fresh = list.find(
      (x) => pick(x, 'refundTransactionStatus') === 'Completed' && !known.has(pick(x, 'refundTrxId', 'refundTrxID')),
    );
    if (fresh) {
      const refundTrxID = pick(fresh, 'refundTrxId', 'refundTrxID');
      const amount = Math.round(Number(pick(fresh, 'refundAmount')) || 0);
      await recordRefund(q.payment, refundTrxID, amount, 'Refund approved');
      await prisma.refundRequest.update({
        where: { id: q.id },
        data: { status: 'refunded', amount, refundTrxId: refundTrxID, decisionNote: null, decidedBy: staff, decidedAt: new Date() },
      });
      await notify(q.userId, 'Refund sent', `BDT ${amount} was sent back to your bKash (refund ID ${refundTrxID}).`);
      return { done: true, status: 'refunded', message: `bKash did send it: BDT ${amount}, refund ID ${refundTrxID}.` };
    }
    await prisma.refundRequest.update({ where: { id: q.id }, data: { status: 'requested', decisionNote: null } });
    return { done: false, status: 'requested', message: 'bKash has no record of this refund, so nothing was sent. You can approve it again.' };
  });

  r.get('/admin/refunds', async (ctx) => {
    sendHtml(ctx, 200, page('Refunds', ADMIN_BODY, ADMIN_SCRIPT).replace('<meta name="robots" content="index,follow">', '<meta name="robots" content="noindex">'));
  });
}

// ── the staff page ─────────────────────────────────────────────────────────

const ADMIN_BODY = `
<style>
main{max-width:980px}
input[type=text],input[type=number],input[type=password],input[type=search]{width:100%;font:inherit;padding:10px 12px;border-radius:12px;border:1px solid var(--line);background:var(--field);color:var(--ink)}
.btn{display:inline-block;width:auto;margin:0;padding:10px 16px;border-radius:999px;background:var(--ink);color:var(--bg);border:0;font:inherit;font-weight:600;cursor:pointer}
.btn.ghost{background:transparent;color:var(--ink);border:1px solid var(--line)}.btn.del{background:var(--danger);color:#fff}
.btn[disabled]{opacity:.5;cursor:default}
.row{display:flex;gap:10px;flex-wrap:wrap;align-items:end}.row>*{flex:1;min-width:140px}
.tabs{display:flex;gap:8px;margin:0 0 14px}
.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px 18px;margin:12px 0}
.facts div span{display:block;font-size:12px;color:var(--muted)}.facts div b{font-weight:600;word-break:break-all}
.mono{font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px}
.pill{display:inline-block;font-size:12px;font-weight:600;padding:2px 10px;border-radius:999px;border:1px solid var(--line)}
.requested{background:#fff4d6;border-color:#f3d48a}.processing{background:#e8eefe;border-color:#b9c8f7}.refunded{background:#16a34a;color:#fff;border-color:#16a34a}.refused{background:#f3e7e4}
.reason{margin:8px 0;padding:10px 12px;border-radius:12px;background:var(--bg);white-space:pre-wrap}
.head{display:flex;justify-content:space-between;gap:10px;align-items:start;flex-wrap:wrap}
.msg{margin:8px 0 0;font-weight:500}
</style>
<h1>Refunds</h1>
<p class="muted">Students ask on the IELTS website (Plans &amp; billing) within 7 days of paying with bKash. Approving sends the money straight back to their bKash wallet; a full refund also ends that pass. Refusing sends them your note.</p>
<div class="card" id="login">
<label for="tok">Admin token</label>
<input id="tok" type="password" autocomplete="off">
<button class="btn" id="go" style="margin-top:12px">Open</button>
<p id="lmsg" class="muted"></p>
</div>
<div id="app" hidden>
<div class="card row">
<div><label for="staff">Your name (saved with each decision)</label><input id="staff" type="text" maxlength="60" placeholder="e.g. Nibir"></div>
<div><label for="q">Find (name, phone, payment ID or transaction ID)</label><input id="q" type="search"></div>
</div>
<div class="tabs"><button class="btn" data-tab="open">Waiting</button><button class="btn ghost" data-tab="all">All</button></div>
<div id="list"></div>
</div>`;

const ADMIN_SCRIPT = `
const $=s=>document.querySelector(s);let T='',TAB='open',ROWS=[];
try{T=sessionStorage.getItem('bt')||'';$('#staff').value=localStorage.getItem('staffName')||''}catch(_){}
const api=async(m,p,body)=>{const h={'X-Admin-Token':T};if(body)h['Content-Type']='application/json';
const r=await fetch(p,{method:m,headers:h,body:body?JSON.stringify(body):undefined});const j=await r.json().catch(()=>({}));if(!r.ok)throw new Error(j.error||('Error '+r.status));return j};
const when=v=>v?new Date(v).toLocaleString('en-GB',{timeZone:'Asia/Dhaka',day:'numeric',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit'}):'';
const tk=n=>'BDT '+Number(n||0).toLocaleString('en-US');
const el=(tag,cls,text)=>{const e=document.createElement(tag);if(cls)e.className=cls;if(text!=null)e.textContent=text;return e};
const fact=(label,value,mono)=>{const d=el('div');d.append(el('span','',label),el('b',mono?'mono':'',value||'—'));return d};
const STATUS={requested:'Waiting',processing:'Waiting for bKash',refunded:'Refunded',refused:'Refused'};
const staff=()=>{const n=$('#staff').value.trim();try{localStorage.setItem('staffName',n)}catch(_){}if(n.length<2){alert('Type your name first (top of the page).');$('#staff').focus();return ''}return n};
function card(q){const c=el('div','card');const head=el('div','head');const who=el('div');
who.append(el('b','',q.student.name),el('div','muted',q.student.phone));head.append(who,el('span','pill '+q.status,STATUS[q.status]||q.status));c.append(head);
const f=el('div','facts');f.append(fact('Paid',when(q.payment.paidAt)),fact('Requested',when(q.requestedAt)),fact('Pass',q.payment.passName),fact('Paid amount',tk(q.payment.amount)),
fact('Payment ID',q.payment.paymentID,true),fact('bKash transaction ID',q.payment.trxID,true));
if(q.payment.refunded)f.append(fact('Already refunded',tk(q.payment.refunded)));c.append(f);
c.append(el('div','reason',q.reason));
const msg=el('p','msg');
if(q.status==='requested'){const r=el('div','row');
const a=el('div');a.append(el('label','','Amount to send back (BDT)'));const amt=el('input');amt.type='number';amt.min='1';amt.max=String(q.payment.refundable);amt.step='1';amt.value=String(q.payment.refundable);a.append(amt);
const n=el('div');n.append(el('label','','Note (required to refuse; the student sees it)'));const note=el('input');note.type='text';note.maxLength=300;n.append(note);
const b=el('div');b.style.flex='none';const ok=el('button','btn','Approve & refund');const no=el('button','btn del','Refuse');b.append(ok,document.createTextNode(' '),no);
r.append(a,n,b);c.append(r);
ok.onclick=async()=>{const s=staff();if(!s)return;const v=Number(amt.value);
if(!Number.isInteger(v)||v<1||v>q.payment.refundable){msg.textContent='The amount must be a whole number from 1 to '+q.payment.refundable+'.';return}
if(!confirm('Send '+tk(v)+' back to '+q.student.name+' ('+q.student.phone+') through bKash? This cannot be undone.'))return;
ok.disabled=no.disabled=true;msg.textContent='Asking bKash…';
try{const j=await api('POST','/v1/admin/refund-requests/'+q.id+'/approve',{amount:v,note:note.value,staff:s});msg.textContent=j.done?'Refunded: '+tk(j.amount)+', refund ID '+j.refundTrxID:j.message;load()}
catch(e){msg.textContent=e.message;ok.disabled=no.disabled=false}};
no.onclick=async()=>{const s=staff();if(!s)return;if(note.value.trim().length<5){msg.textContent='Write a note saying why (the student sees it).';note.focus();return}
if(!confirm('Refuse this refund? The student gets your note.'))return;ok.disabled=no.disabled=true;
try{await api('POST','/v1/admin/refund-requests/'+q.id+'/refuse',{note:note.value,staff:s});load()}catch(e){msg.textContent=e.message;ok.disabled=no.disabled=false}};}
else if(q.status==='processing'){const chk=el('button','btn','Check with bKash');c.append(el('p','muted','bKash did not answer when this was approved'+(q.decidedBy?' by '+q.decidedBy:'')+'. Check before doing anything else, so the money is not sent twice.'),chk);
chk.onclick=async()=>{const s=staff();if(!s)return;chk.disabled=true;msg.textContent='Checking…';
try{const j=await api('POST','/v1/admin/refund-requests/'+q.id+'/check',{staff:s});alert(j.message);load()}catch(e){msg.textContent=e.message;chk.disabled=false}};}
else{const d=el('div','facts');if(q.status==='refunded'){d.append(fact('Sent back',tk(q.amount)),fact('Refund ID',q.refundTrxID,true))}
d.append(fact(q.status==='refunded'?'Approved by':'Refused by',(q.decidedBy||'')+(q.decidedAt?' · '+when(q.decidedAt):'')));if(q.note)d.append(fact('Note',q.note));c.append(d)}
c.append(msg);return c}
function draw(){const s=$('#q').value.trim().toLowerCase();const list=$('#list');list.textContent='';
const rows=ROWS.filter(q=>!s||[q.student.name,q.student.phone,q.payment.paymentID,q.payment.trxID].join(' ').toLowerCase().includes(s));
if(!rows.length){list.append(el('p','muted',TAB==='open'?'No refund requests waiting.':'No refund requests yet.'));return}
rows.forEach(q=>list.append(card(q)))}
async function load(){const j=await api('GET','/v1/admin/refund-requests?status='+TAB);ROWS=j.requests;draw()}
async function open_(){try{await load();$('#login').hidden=true;$('#app').hidden=false;try{sessionStorage.setItem('bt',T)}catch(_){}}catch(e){$('#lmsg').textContent=e.message}}
$('#go').onclick=()=>{T=$('#tok').value.trim();open_()};
$('#q').oninput=draw;
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{TAB=b.dataset.tab;document.querySelectorAll('[data-tab]').forEach(x=>x.className='btn'+(x===b?'':' ghost'));load().catch(e=>alert(e.message))});
if(T)open_();
`;
