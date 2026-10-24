// Public web pages served by the API, for Google Play and anyone without the app:
//
//   GET  /privacy          Privacy Policy   (same text as the app: access.legal)
//   GET  /terms            Terms of Use
//   GET  /delete-account   request account deletion without the app
//   POST /delete-account   {phone, password} -> the same deletion as the app
//
// Google Play needs the privacy link on the store listing and the
// delete-account link in the Data safety form. The legal text comes from the
// ui content pack (the repo's demo_data.json as a fallback), so editing
// assets/demo/parts/access.json changes the app and these pages together.

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { gunzipSync } from 'node:zlib';
import { prisma } from '../db';
import { eraseUser } from '../lib/archive';
import { HttpError, rateLimit, required, Router, type Ctx } from '../lib/http';
import { packBody } from '../lib/packs';
import { verifyPassword } from '../lib/password';
import { isValidPhone, normalizePhone } from '../lib/phone';

type Raw = Record<string, unknown>;

interface LegalDoc {
  title: string;
  intro: string;
  sections: { heading: string; body?: string[]; bullets?: string[] }[];
}

interface Legal {
  updated: string;
  contactEmail: string;
  draftNote: string;
  terms: LegalDoc;
  privacy: LegalDoc;
}

let cache: { version: string; legal: Legal } | null = null;

/** access.legal from the ui pack, or from the repo file. */
async function legal(): Promise<Legal | null> {
  try {
    const body = await packBody(prisma, 'ui');
    if (body) {
      if (cache?.version === body.info.version) return cache.legal;
      const ui = JSON.parse(gunzipSync(body.gz).toString('utf8')) as Raw;
      const l = ((ui.access ?? {}) as Raw).legal as Legal | undefined;
      if (l?.privacy) {
        cache = { version: body.info.version, legal: l };
        return l;
      }
    }
  } catch {
    // fall through to the file
  }
  const file = path.resolve(__dirname, '..', '..', '..', 'assets', 'demo', 'demo_data.json');
  if (!existsSync(file)) return null;
  const ui = JSON.parse(readFileSync(file, 'utf8')) as Raw;
  return (((ui.access ?? {}) as Raw).legal as Legal | undefined) ?? null;
}

const esc = (t: string) =>
  t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

/** Escaped text with web links and the contact email made clickable. */
const linked = (t: string) =>
  esc(t)
    .replace(/https:\/\/[^\s<]+[^\s<.,)]/g, (u) => `<a href="${u}">${u}</a>`)
    .replace(/[\w.+-]+@[\w-]+\.[\w.-]+\w/g, (m) => `<a href="mailto:${m}">${m}</a>`);

const longDate = (iso: string) => {
  const d = new Date(`${iso}T00:00:00Z`);
  return Number.isNaN(d.getTime())
    ? iso
    : d.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' });
};

const STYLE = `
:root{--bg:#FBF5F3;--card:#fff;--ink:#151515;--soft:#4a4450;--muted:#6B6270;--line:#F0E2DD;--peach:#FF9C82;--danger:#C2410C;--field:#fff}
@media (prefers-color-scheme:dark){:root{--bg:#0D0F1A;--card:#161927;--ink:#fff;--soft:#c9c6d3;--muted:#9a96a8;--line:#272b3d;--danger:#FF8A65;--field:#0f1220}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:720px;margin:0 auto;padding:28px 16px 64px}
.brand{font-weight:500;font-size:22px;letter-spacing:-.5px;margin-bottom:28px}
.brand b{font-weight:800}.brand i{display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--peach);margin-left:3px}
h1{font-size:30px;line-height:1.2;letter-spacing:-.6px;margin:0 0 6px}
h2{font-size:18px;margin:28px 0 6px}
p,li{color:var(--soft)}ul{padding-left:22px}
.muted{color:var(--muted);font-size:14px}
.card{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:20px;margin:18px 0}
.note{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:12px 14px;font-size:14px;color:var(--muted)}
a{color:inherit}
label{display:block;font-weight:600;font-size:14px;margin:14px 0 6px}
input[type=tel],input[type=password]{width:100%;font:inherit;padding:12px 14px;border-radius:14px;border:1px solid var(--line);background:var(--field);color:var(--ink)}
.check{display:flex;gap:10px;align-items:flex-start;font-weight:400;color:var(--soft)}
.check input{margin-top:5px}
button{margin-top:18px;width:100%;font:inherit;font-weight:600;padding:14px;border:0;border-radius:999px;background:var(--danger);color:#fff;cursor:pointer}
button:disabled{opacity:.55;cursor:default}
#msg{margin-top:14px;font-weight:500}#msg.err{color:var(--danger)}
footer{margin-top:40px;font-size:14px;color:var(--muted)}footer a{margin-right:14px}
`;

function page(title: string, body: string, script = ''): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} · nextED</title><meta name="robots" content="index,follow"><style>${STYLE}</style></head>
<body><main><div class="brand">next<b>ED</b><i></i></div>${body}
<footer><a href="/privacy">Privacy Policy</a><a href="/terms">Terms of Use</a><a href="/delete-account">Delete account</a></footer>
</main>${script ? `<script>${script}</script>` : ''}</body></html>`;
}

function sendHtml(ctx: Ctx, status: number, html: string): void {
  ctx.res.writeHead(status, {
    'Content-Type': 'text/html; charset=utf-8',
    'Content-Length': Buffer.byteLength(html),
    'Cache-Control': 'public, max-age=300',
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
  });
  ctx.res.end(html);
}

function legalPage(l: Legal, doc: LegalDoc): string {
  const sections = doc.sections
    .map(
      (s) =>
        `<h2>${esc(s.heading)}</h2>${(s.body ?? []).map((b) => `<p>${linked(b)}</p>`).join('')}${
          s.bullets?.length ? `<ul>${s.bullets.map((b) => `<li>${linked(b)}</li>`).join('')}</ul>` : ''
        }`,
    )
    .join('');
  return page(
    doc.title,
    `<h1>${esc(doc.title)}</h1><p class="muted">Last updated ${esc(longDate(l.updated))}</p>
${l.draftNote ? `<p class="note">${esc(l.draftNote)}</p>` : ''}<p>${linked(doc.intro)}</p>${sections}`,
  );
}

const DELETE_SCRIPT = `
const f=document.getElementById('f'),m=document.getElementById('msg'),b=document.getElementById('go');
f.addEventListener('submit',async(e)=>{e.preventDefault();m.className='';m.textContent='';
if(!f.sure.checked){m.className='err';m.textContent='Tick the box to confirm.';return}
b.disabled=true;b.textContent='Deleting…';
try{const r=await fetch('/delete-account',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({phone:f.phone.value,password:f.password.value})});
const j=await r.json().catch(()=>({}));
if(r.ok){f.hidden=true;m.textContent='Your nextED account has been deleted. You can close this page.';return}
m.className='err';m.textContent=j.error||'Something went wrong. Please try again.';}
catch(_){m.className='err';m.textContent='Could not reach nextED. Check your connection and try again.';}
b.disabled=false;b.textContent='Delete my account';});
`;

function deletePage(email: string): string {
  const mail = esc(email);
  return page(
    'Delete your account',
    `<h1>Delete your nextED account</h1>
<p>This page is for the <b>nextED</b> app (IELTS practice and study abroad) by nextED, Bangladesh. You can delete your account here without the app, or in the app from <b>Profile › Delete account</b>.</p>
<div class="card">
<h2 style="margin-top:0">What happens</h2>
<ul>
<li>Your account is closed at once and you are signed out everywhere.</li>
<li>Your profile, study plan, progress, notifications, study-abroad profile, documents and counsellor chats are removed from the app.</li>
<li>Any Pro pass you have ends and is not refunded. Automatic bKash renewal stops.</li>
<li>We keep a private copy of your account data and documents in secure storage as a record. It is never shown in the app or used for marketing.</li>
<li>Your practice answers and speaking recordings are kept without your name, number or anything else that identifies you, to improve our IELTS scoring.</li>
</ul>
<p class="muted">More detail is in our <a href="/privacy">Privacy Policy</a>. This can't be undone.</p>
</div>
<form id="f" class="card" autocomplete="on">
<h2 style="margin-top:0">Delete my account</h2>
<label for="phone">Mobile number</label>
<input id="phone" name="phone" type="tel" inputmode="tel" placeholder="01XXXXXXXXX" autocomplete="tel" required>
<label for="password">Password</label>
<input id="password" name="password" type="password" autocomplete="current-password" required>
<label class="check"><input type="checkbox" name="sure"> I understand my account will be deleted and this can't be undone.</label>
<button id="go" type="submit">Delete my account</button>
</form>
<p id="msg" role="status" aria-live="polite"></p>
<p class="muted">Forgot your password? Reset it in the app with the code we text you, or email <a href="mailto:${mail}">${mail}</a> from any address with your registered mobile number and we will delete the account for you.</p>`,
    DELETE_SCRIPT,
  );
}

export function registerWebRoutes(r: Router): void {
  r.get('/privacy', async (ctx) => {
    const l = await legal();
    if (!l) throw new HttpError(503, 'The policy is not available right now.', 'legal_missing');
    sendHtml(ctx, 200, legalPage(l, l.privacy));
  });

  r.get('/terms', async (ctx) => {
    const l = await legal();
    if (!l) throw new HttpError(503, 'The terms are not available right now.', 'legal_missing');
    sendHtml(ctx, 200, legalPage(l, l.terms));
  });

  r.get('/delete-account', async (ctx) => {
    const l = await legal();
    sendHtml(ctx, 200, deletePage(l?.contactEmail || 'support@nexted.app'));
  });

  // The same deletion as DELETE /v1/me in the app, proved by number + password.
  r.post('/delete-account', async (ctx) => {
    rateLimit(`web-delete-ip:${ctx.ip}`, 20, 3600);
    const raw = required(ctx.body, 'phone', 30);
    const password = required(ctx.body, 'password', 200);
    if (!isValidPhone(raw)) throw new HttpError(400, 'Enter the Bangladeshi mobile number you signed up with.', 'invalid_phone');
    const phone = normalizePhone(raw);
    rateLimit(`web-delete:${phone}`, 5, 3600);
    const user = (await prisma.user.findUnique({ where: { phone }, select: { id: true, passwordHash: true, isDemo: true } })) as {
      id: string;
      passwordHash: string;
      isDemo: boolean;
    } | null;
    // One answer for an unknown number and a wrong password.
    if (!user || !verifyPassword(password, user.passwordHash)) {
      throw new HttpError(400, 'That number and password don’t match a nextED account.', 'wrong_login');
    }
    if (user.isDemo) throw new HttpError(403, 'Demo accounts can’t be deleted.', 'demo_account');
    await eraseUser(user.id);
    return { deleted: true };
  });
}
