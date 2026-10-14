// Same-origin door to the API for the browser (client components): adds the
// signed-in user's token from the httpOnly cookie, so scripts never hold it.
//   fetch('/api/v1/attempts', {method: 'POST', body: …}) → API /v1/attempts

import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { baseHeaders } from '@/lib/server/api';
import { env } from '@/lib/server/env';
import { clearedSessionCookies, COOKIE, cookieBase, ENDED_CODES } from '@/lib/session';

type Ctx = { params: Promise<{ path: string[] }> };

async function forward(req: Request, ctx: Ctx): Promise<Response> {
  const { path } = await ctx.params;
  const joined = path.map(encodeURIComponent).join('/');
  // Sign-in goes through /api/auth/* (it sets the cookies).
  if (path[0] === 'auth') {
    return NextResponse.json({ error: 'Not found.', code: 'not_found' }, { status: 404 });
  }
  const token = (await cookies()).get(COOKIE.access)?.value;
  const url = new URL(req.url);
  const init: RequestInit = {
    method: req.method,
    headers: {
      ...(await baseHeaders()),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(req.headers.get('content-type') ? { 'Content-Type': req.headers.get('content-type')! } : {}),
    },
    body: req.method === 'GET' || req.method === 'HEAD' ? undefined : await req.arrayBuffer(),
    cache: 'no-store',
  };
  let res: Response;
  try {
    res = await fetch(`${env.apiBaseUrl}/v1/${joined}${url.search}`, init);
  } catch {
    return NextResponse.json({ error: 'Can’t reach the IELTS AI server. Please try again.', code: 'network' }, { status: 502 });
  }
  const out = new Headers();
  for (const h of ['content-type', 'cache-control', 'etag']) {
    const v = res.headers.get(h);
    if (v) out.set(h, v);
  }
  if (res.status === 401) {
    // The session is over (e.g. signed in on the app): forget it here too,
    // so the next page load goes to /login instead of a dead session.
    const text = await res.text();
    let code = '';
    try {
      code = String((JSON.parse(text) as { code?: unknown }).code ?? '');
    } catch {}
    const reply = new NextResponse(text, { status: 401, headers: out });
    if (ENDED_CODES.has(code)) {
      for (const c of clearedSessionCookies) reply.cookies.set(c.name, c.value, { ...cookieBase, maxAge: 0 });
    }
    return reply;
  }
  return new Response(res.body, { status: res.status, headers: out });
}

export const GET = forward;
export const POST = forward;
export const PUT = forward;
export const PATCH = forward;
export const DELETE = forward;
