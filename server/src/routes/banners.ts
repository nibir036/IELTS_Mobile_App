// Ad banners on the home pages: finished images uploaded from an admin page,
// shown in the app's banner carousel (lib/app/widgets/ad_carousel.dart).
//
// App (public):
//   GET    /v1/banners                    live banners for every place
//   GET    /v1/banners/:id/image          302 to the image in R2
// Admin (header X-Admin-Token = ADMIN_TOKEN):
//   GET    /v1/admin/banners              every banner, live or not
//   POST   /v1/admin/banners?place=&linkType=&link=&title=&sort=&startsAt=&endsAt=
//                                          body = the image (PNG, JPG or WebP, up to 3 MB)
//   PATCH  /v1/admin/banners/:id          {active, sort, place, title, linkType, link, startsAt, endsAt}
//   DELETE /v1/admin/banners/:id
//   GET    /admin/banners                 a simple admin page using the routes above
//
// Any website (ielts.nexted.app, nexted.app) can host its own admin page on
// these routes; the token is the only key, so keep it out of public code.

import { randomUUID, timingSafeEqual } from 'node:crypto';
import { prisma } from '../db';
import { env } from '../env';
import { badRequest, HttpError, notFound, rateLimit, Router, s, type Ctx } from '../lib/http';
import { appKey, contentTypeFor, deleteObjects, putObject, signedUrl } from '../lib/r2';
import { page, sendHtml } from './web';

const PLACES = new Set(['ielts', 'abroad', 'both']);
const LINK_TYPES = new Set(['none', 'screen', 'url']);
const IMAGE_EXTS: Record<string, string> = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp' };
const MAX_IMAGE_BYTES = 3 * 1024 * 1024;

interface BannerRow {
  id: string;
  place: string;
  title: string;
  r2Key: string;
  linkType: string;
  link: string;
  sort: number;
  active: boolean;
  startsAt: Date | null;
  endsAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const db = () => (prisma as unknown as { adBanner: any }).adBanner;

/** What the app and the admin page get for one banner. */
function view(b: BannerRow) {
  return {
    id: b.id,
    place: b.place,
    title: b.title,
    // Stable per version of the image, so phones can cache it.
    image: `/v1/banners/${b.id}/image?v=${b.updatedAt.getTime()}`,
    linkType: b.linkType,
    link: b.link,
    sort: b.sort,
    active: b.active,
    startsAt: b.startsAt?.toISOString() ?? null,
    endsAt: b.endsAt?.toISOString() ?? null,
  };
}

function requireAdmin(ctx: Ctx): void {
  const want = Buffer.from(env.adminToken);
  if (!want.length) throw new HttpError(503, 'The banner admin is not set up (ADMIN_TOKEN is empty).', 'admin_off');
  rateLimit(`admin:${ctx.ip}`, 600, 3600);
  const got = Buffer.from(s(ctx.req.headers['x-admin-token'], 300));
  if (got.length !== want.length || !timingSafeEqual(got, want)) {
    throw new HttpError(401, 'Wrong admin token.', 'bad_admin_token');
  }
}

function date(v: unknown, label: string): Date | null {
  const t = s(v, 40).trim();
  if (!t) return null;
  const d = new Date(t);
  if (Number.isNaN(d.getTime())) throw badRequest(`${label} is not a date.`);
  return d;
}

/** Checks and normalises the editable fields (only those given). */
function fields(src: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  if (src.place !== undefined) {
    const place = s(src.place, 10).toLowerCase();
    if (!PLACES.has(place)) throw badRequest('Place must be ielts, abroad or both.');
    out.place = place;
  }
  if (src.title !== undefined) out.title = s(src.title, 140).trim();
  if (src.sort !== undefined && s(src.sort, 10) !== '') {
    const n = Number(src.sort);
    if (!Number.isInteger(n)) throw badRequest('Order must be a whole number.');
    out.sort = n;
  }
  if (src.active !== undefined) out.active = src.active === true || src.active === 'true';
  if (src.startsAt !== undefined) out.startsAt = date(src.startsAt, 'Start');
  if (src.endsAt !== undefined) out.endsAt = date(src.endsAt, 'End');
  if (src.linkType !== undefined || src.link !== undefined) {
    const type = s(src.linkType ?? 'none', 10).toLowerCase() || 'none';
    const link = s(src.link, 500).trim();
    if (!LINK_TYPES.has(type)) throw badRequest('Link type must be none, screen or url.');
    if (type === 'screen' && !link.startsWith('/')) throw badRequest('A screen link starts with / (for example /home/plans).');
    if (type === 'url' && !/^https:\/\/\S+$/.test(link)) throw badRequest('A web link must start with https://');
    out.linkType = type;
    out.link = type === 'none' ? '' : link;
  }
  return out;
}

const live = (b: BannerRow, now: number) =>
  b.active && (!b.startsAt || b.startsAt.getTime() <= now) && (!b.endsAt || b.endsAt.getTime() > now);

export function registerBannerRoutes(r: Router): void {
  // ── app ────────────────────────────────────────────────────────────────
  r.get('/v1/banners', async (ctx) => {
    rateLimit(`banners:${ctx.ip}`, 600, 3600);
    const rows = (await db().findMany({ where: { active: true }, orderBy: [{ sort: 'asc' }, { createdAt: 'desc' }] })) as BannerRow[];
    const now = Date.now();
    ctx.res.setHeader('Cache-Control', 'public, max-age=60');
    return { banners: rows.filter((b) => live(b, now)).map(view) };
  });

  r.get('/v1/banners/:id/image', async (ctx) => {
    rateLimit(`banner-img:${ctx.ip}`, 2000, 3600);
    const b = (await db().findUnique({ where: { id: ctx.params.id } })) as BannerRow | null;
    if (!b) throw notFound('No such banner.');
    // Signed from the start of the hour for 2 h, like /v1/media: the same
    // link all hour, so it can be cached.
    const hour = 3600 * 1000;
    const start = new Date(Math.floor(Date.now() / hour) * hour);
    const url = await signedUrl(b.r2Key, 7200, start);
    const fresh = Math.max(60, Math.floor((start.getTime() + hour - Date.now()) / 1000));
    ctx.res.writeHead(302, { Location: url, 'Cache-Control': `public, max-age=${fresh}` });
    ctx.res.end();
    return undefined;
  });

  // ── admin ──────────────────────────────────────────────────────────────
  r.get('/v1/admin/banners', async (ctx) => {
    requireAdmin(ctx);
    const rows = (await db().findMany({ orderBy: [{ place: 'asc' }, { sort: 'asc' }, { createdAt: 'desc' }] })) as BannerRow[];
    const now = Date.now();
    return { banners: rows.map((b) => ({ ...view(b), live: live(b, now) })) };
  });

  r.post('/v1/admin/banners', async (ctx) => {
    requireAdmin(ctx);
    const type = String(ctx.req.headers['content-type'] || '').split(';')[0].trim().toLowerCase();
    const ext = IMAGE_EXTS[type];
    if (!ext) throw badRequest('Upload a PNG, JPG or WebP image.', 'bad_file_type');
    const bytes = ctx.raw;
    if (!bytes?.length) throw badRequest('Choose an image to upload.');
    if (bytes.length > MAX_IMAGE_BYTES) throw badRequest('The image is larger than 3 MB.', 'too_large');
    const q = Object.fromEntries(ctx.query.entries()) as Record<string, unknown>;
    const data = fields({ linkType: 'none', ...q, place: q.place ?? 'both' });
    const key = appKey(`banners/${randomUUID()}.${ext}`);
    await putObject(key, bytes, contentTypeFor(ext));
    const b = (await db().create({ data: { ...data, r2Key: key } })) as BannerRow;
    return { banner: view(b) };
  });

  r.patch('/v1/admin/banners/:id', async (ctx) => {
    requireAdmin(ctx);
    const found = (await db().findUnique({ where: { id: ctx.params.id } })) as BannerRow | null;
    if (!found) throw notFound('No such banner.');
    // A link type change needs its link checked together with it.
    const body = { ...ctx.body };
    if (body.link !== undefined && body.linkType === undefined) body.linkType = found.linkType;
    if (body.linkType !== undefined && body.link === undefined) body.link = found.link;
    const b = (await db().update({ where: { id: found.id }, data: fields(body) })) as BannerRow;
    return { banner: view(b) };
  });

  r.delete('/v1/admin/banners/:id', async (ctx) => {
    requireAdmin(ctx);
    const found = (await db().findUnique({ where: { id: ctx.params.id } })) as BannerRow | null;
    if (!found) throw notFound('No such banner.');
    await db().delete({ where: { id: found.id } });
    await deleteObjects([found.r2Key]).catch((e) => console.error('[banners] R2 delete failed', e));
    return { deleted: true };
  });

  r.get('/admin/banners', async (ctx) => {
    sendHtml(ctx, 200, page('Ad banners', ADMIN_BODY, ADMIN_SCRIPT).replace('<meta name="robots" content="index,follow">', '<meta name="robots" content="noindex">'));
  });
}

// ── the admin page ─────────────────────────────────────────────────────────

const SCREENS: [string, string][] = [
  ['/home', 'IELTS home'],
  ['/home/plans', 'Plans (Pro)'],
  ['/home/study-plan/setup', 'Build my study plan'],
  ['/mock/system-check', 'Start a mock test'],
  ['/nexted', 'Study abroad home'],
  ['/nexted/courses', 'Course matching'],
  ['/nexted/scholarships', 'Scholarships'],
  ['/nexted/counsellor', 'AI counsellor'],
  ['/nexted/profile', 'Study abroad profile'],
  ['/nexted/documents', 'Documents'],
];

const ADMIN_BODY = `
<style>
.row{display:flex;gap:12px;flex-wrap:wrap}.row>*{flex:1;min-width:150px}
select,input[type=text],input[type=number],input[type=datetime-local],input[type=password],input[type=file]{width:100%;font:inherit;padding:10px 12px;border-radius:12px;border:1px solid var(--line);background:var(--field);color:var(--ink)}
.btn{display:inline-block;width:auto;margin:0;padding:10px 16px;border-radius:999px;background:var(--ink);color:var(--bg);border:0;font:inherit;font-weight:600;cursor:pointer}
.btn.ghost{background:transparent;color:var(--ink);border:1px solid var(--line)}.btn.del{background:var(--danger);color:#fff}
.ban{display:grid;grid-template-columns:160px 1fr;gap:14px;align-items:start}
.ban img{width:160px;aspect-ratio:2/1;object-fit:cover;border-radius:14px;background:var(--line)}
.pill{display:inline-block;font-size:12px;font-weight:600;padding:2px 10px;border-radius:999px;border:1px solid var(--line);margin-right:6px}
.live{background:#16a34a;color:#fff;border-color:#16a34a}
@media(max-width:560px){.ban{grid-template-columns:1fr}.ban img{width:100%}}
</style>
<h1>Ad banners</h1>
<p class="muted">Banners show in the app's carousel on the IELTS and Study abroad home pages, in the order below, within a minute of a change. Use finished images at 1200 × 600 (2:1), keeping text and buttons away from the edges - phones crop the sides a little. PNG, JPG or WebP, up to 3 MB.</p>
<div class="card" id="login">
<label for="tok">Admin token</label>
<input id="tok" type="password" autocomplete="off">
<button class="btn" id="go" style="margin-top:12px">Open</button>
<p id="lmsg" class="muted"></p>
</div>
<div id="app" hidden>
<form class="card" id="up">
<h2 style="margin-top:0">Upload a banner</h2>
<label>Image</label><input type="file" name="file" accept="image/png,image/jpeg,image/webp" required>
<div class="row">
<div><label>Show on</label><select name="place"><option value="ielts">IELTS home</option><option value="abroad">Study abroad home</option><option value="both">Both</option></select></div>
<div><label>Order</label><input type="number" name="sort" value="0"></div>
</div>
<label>Alt text (read out by screen readers)</label><input type="text" name="title" maxlength="140" placeholder="Eid offer: Pro for less">
<div class="row">
<div><label>When tapped</label><select name="linkType"><option value="none">Nothing</option><option value="screen">Open an app screen</option><option value="url">Open a web page</option></select></div>
<div><label>Screen</label><select name="screen">${SCREENS.map(([v, n]) => `<option value="${v}">${n}</option>`).join('')}</select></div>
</div>
<label>Web page (https://…)</label><input type="text" name="url" placeholder="https://nexted.app/offer">
<div class="row">
<div><label>Starts (optional)</label><input type="datetime-local" name="startsAt"></div>
<div><label>Ends (optional)</label><input type="datetime-local" name="endsAt"></div>
</div>
<button class="btn" type="submit" style="margin-top:16px">Upload</button>
<p id="umsg"></p>
</form>
<div id="list"></div>
</div>`;

const ADMIN_SCRIPT = `
const $=s=>document.querySelector(s);let T='';
try{T=sessionStorage.getItem('bt')||''}catch(_){}
const api=async(m,p,body,type)=>{const h={'X-Admin-Token':T};if(type)h['Content-Type']=type;
const r=await fetch(p,{method:m,headers:h,body});const j=await r.json().catch(()=>({}));if(!r.ok)throw new Error(j.error||('Error '+r.status));return j};
const iso=v=>v?new Date(v).toISOString():'';
const names={ielts:'IELTS home',abroad:'Study abroad home',both:'Both homes'};
async function load(){const {banners}=await api('GET','/v1/admin/banners');
$('#list').innerHTML=banners.length?'':'<p class="muted">No banners yet - the app shows its built-in banner.</p>';
for(const b of banners){const d=document.createElement('div');d.className='card ban';
const when=[b.startsAt?'from '+new Date(b.startsAt).toLocaleString():'',b.endsAt?'until '+new Date(b.endsAt).toLocaleString():''].filter(Boolean).join(' ');
const link=b.linkType==='none'?'No link':(b.linkType==='screen'?'Screen '+b.link:b.link);
d.innerHTML='<img alt=""><div><div><span class="pill '+(b.live?'live':'')+'">'+(b.live?'Live':(b.active?'Scheduled':'Hidden'))+'</span><span class="pill">'+names[b.place]+'</span><span class="pill">Order '+b.sort+'</span></div>'+
'<p class="t"></p><p class="muted l"></p><div class="row" style="flex:none;gap:8px"><button class="btn ghost" data-a="toggle">'+(b.active?'Hide':'Show')+'</button><button class="btn ghost" data-a="up">Move up</button><button class="btn ghost" data-a="down">Move down</button><button class="btn del" data-a="del">Delete</button></div></div>';
d.querySelector('img').src=b.image;d.querySelector('.t').textContent=b.title||'(no alt text)';d.querySelector('.l').textContent=link+(when?' · '+when:'');
d.addEventListener('click',async e=>{const a=e.target.dataset&&e.target.dataset.a;if(!a)return;
try{if(a==='del'){if(!confirm('Delete this banner? It disappears from the app.'))return;await api('DELETE','/v1/admin/banners/'+b.id)}
else if(a==='toggle')await api('PATCH','/v1/admin/banners/'+b.id,JSON.stringify({active:!b.active}),'application/json');
else await api('PATCH','/v1/admin/banners/'+b.id,JSON.stringify({sort:b.sort+(a==='up'?-1:1)}),'application/json');
load()}catch(err){alert(err.message)}});
$('#list').appendChild(d)}}
async function open_(){try{await load();$('#login').hidden=true;$('#app').hidden=false;try{sessionStorage.setItem('bt',T)}catch(_){}}catch(e){$('#lmsg').textContent=e.message}}
$('#go').onclick=()=>{T=$('#tok').value.trim();open_()};
if(T)open_();
$('#up').addEventListener('submit',async e=>{e.preventDefault();const f=e.target,m=$('#umsg');m.textContent='Uploading…';
const file=f.file.files[0];if(!file){m.textContent='Choose an image.';return}
const lt=f.linkType.value,link=lt==='screen'?f.screen.value:(lt==='url'?f.url.value.trim():'');
const q=new URLSearchParams({place:f.place.value,sort:f.sort.value||'0',title:f.title.value,linkType:lt,link,startsAt:iso(f.startsAt.value),endsAt:iso(f.endsAt.value)});
try{await api('POST','/v1/admin/banners?'+q,file,file.type);m.textContent='Uploaded - live in the app within a minute.';f.reset();load()}catch(err){m.textContent=err.message}});
`;
