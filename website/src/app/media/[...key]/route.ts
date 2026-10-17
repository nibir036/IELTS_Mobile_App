// /media/<key>: listening audio and test / lesson images (R2), streamed
// through the website so the storage link never reaches the browser.
//
// Served only to a signed-in student's page that is playing or showing the
// file (an <audio> / <img> on this site). Opening the link in a tab, a
// "Save link as…" download, another site embedding it, or a script without
// the session cookie gets 403. Range requests pass through, so seeking works.
//
// No website can make media fully uncopyable (screen / audio recording,
// developer tools); this stops the easy routes.

import { cookies, headers } from 'next/headers';
import { NextResponse } from 'next/server';
import { env } from '@/lib/server/env';
import { COOKIE } from '@/lib/session';

const PASS = ['content-type', 'content-length', 'content-range', 'accept-ranges', 'last-modified', 'etag'];
// What an <audio>, <video> or <img> on the page asks for. A typed URL or a
// download is 'document' / 'empty'.
const EMBED = new Set(['audio', 'video', 'image', 'track']);

function deny(): NextResponse {
  return new NextResponse('Not available.', { status: 403, headers: { 'Cache-Control': 'no-store' } });
}

export async function GET(req: Request, ctx: { params: Promise<{ key: string[] }> }) {
  const { key } = await ctx.params;
  if (!key.length || key.some((k) => k === '..' || k === '' || k.includes('/'))) {
    return NextResponse.json({ error: 'Not found.' }, { status: 404 });
  }

  // Signed in on this site.
  const jar = await cookies();
  if (!jar.get(COOKIE.access)?.value && !jar.get(COOKIE.refresh)?.value) return deny();

  // Requested by this site's own page, as media (browsers set these headers;
  // pages cannot fake them).
  const h = await headers();
  const site = h.get('sec-fetch-site');
  const dest = h.get('sec-fetch-dest');
  if (site && site !== 'same-origin') return deny();
  if (dest && !EMBED.has(dest)) return deny();
  if (!site && !dest) {
    // Very old browsers send neither: fall back to the Referer.
    const ref = h.get('referer') ?? '';
    let ok = false;
    try {
      ok = new URL(ref).host === new URL(req.url).host;
    } catch {}
    if (!ok) return deny();
  }

  // The API answers with a redirect to a short-lived signed R2 link: follow
  // it here, server-side.
  let upstream: Response;
  try {
    const hop = await fetch(`${env.apiBaseUrl}/v1/media/${key.map(encodeURIComponent).join('/')}`, {
      redirect: 'manual',
      cache: 'no-store',
    });
    const signed = hop.headers.get('location');
    if (hop.status === 404 || !signed) return NextResponse.json({ error: 'Not found.' }, { status: 404 });
    const range = h.get('range');
    upstream = await fetch(signed, { headers: range ? { Range: range } : {}, cache: 'no-store' });
  } catch {
    return NextResponse.json({ error: 'Media unavailable.' }, { status: 502 });
  }
  if (!upstream.ok && upstream.status !== 206) {
    return NextResponse.json({ error: 'Not found.' }, { status: upstream.status === 416 ? 416 : 404 });
  }

  const out = new Headers();
  for (const name of PASS) {
    const v = upstream.headers.get(name);
    if (v) out.set(name, v);
  }
  out.set('Cache-Control', 'private, no-store');
  out.set('Content-Disposition', 'inline');
  out.set('X-Content-Type-Options', 'nosniff');
  out.set('Cross-Origin-Resource-Policy', 'same-origin');
  return new Response(upstream.body, { status: upstream.status, headers: out });
}
