// Runs before every page and /api request:
//  1. gives this browser a device id (like an app install) in a cookie;
//  2. keeps the session fresh: an access token about to expire is swapped
//     for a new pair with the refresh token, so pages always read a valid one;
//  3. sends visitors without a session from /app to /login, and signed-in
//     visitors from /login to /app.

import { NextResponse, type NextRequest } from 'next/server';
import {
  type AuthTokens,
  clearedSessionCookies,
  COOKIE,
  cookieBase,
  type CookieWrite,
  DEVICE_COOKIE_AGE,
  deviceHeaders,
  ENDED_CODES,
  newDeviceId,
  sessionCookies,
} from './lib/session';

const API = (process.env.API_BASE_URL || 'http://localhost:4000').replace(/\/+$/, '');
const APP_KEY = process.env.APP_KEY || '';

/** Refresh when the access token has less than this left. */
const REFRESH_MARGIN_MS = 60_000;

async function refresh(refreshToken: string, deviceId: string, ua: string) {
  try {
    const res = await fetch(`${API}/v1/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(APP_KEY ? { 'X-App-Key': APP_KEY } : {}),
        ...deviceHeaders(deviceId, ua),
      },
      body: JSON.stringify({ refreshToken }),
      cache: 'no-store',
    });
    const data = (await res.json().catch(() => ({}))) as Partial<AuthTokens> & { code?: string };
    if (res.ok && data.accessToken && data.refreshToken && data.accessTokenExpiresAt) {
      return { ok: true as const, tokens: data as AuthTokens };
    }
    // 401: the session is over (signed in elsewhere, removed, expired).
    if (res.status === 401) return { ok: false as const, ended: true, code: String(data.code ?? 'session_ended') };
    return { ok: false as const, ended: false, code: String(data.code ?? 'error') };
  } catch {
    // Server unreachable: keep the cookies, the page shows its own error.
    return { ok: false as const, ended: false, code: 'network' };
  }
}

function apply(res: NextResponse, writes: CookieWrite[]) {
  for (const c of writes) {
    res.cookies.set(c.name, c.value, { ...cookieBase, ...(c.maxAge !== undefined ? { maxAge: c.maxAge } : {}) });
  }
  return res;
}

export async function middleware(req: NextRequest) {
  const { pathname, search } = req.nextUrl;
  const ua = req.headers.get('user-agent') ?? '';
  const writes: CookieWrite[] = [];

  let deviceId = req.cookies.get(COOKIE.device)?.value ?? '';
  if (!/^[a-f0-9]{32}$/.test(deviceId)) {
    deviceId = newDeviceId();
    writes.push({ name: COOKIE.device, value: deviceId, maxAge: DEVICE_COOKIE_AGE });
  }

  let access = req.cookies.get(COOKIE.access)?.value ?? '';
  const exp = Date.parse(req.cookies.get(COOKIE.accessExp)?.value ?? '');
  const refreshToken = req.cookies.get(COOKIE.refresh)?.value ?? '';
  const keep = req.cookies.get(COOKIE.keep)?.value === '1';
  let ended: string | null = null;

  const isAuthRoute = pathname.startsWith('/api/auth/');
  // A page found the session over (signed in on another device, device
  // removed …) and sent the browser to /login?reason=…: drop the cookies
  // here. Server components can't, and with a still-valid access cookie
  // /login would bounce back to /app forever ("too many redirects").
  const endedReason = pathname === '/login' ? req.nextUrl.searchParams.get('reason') ?? '' : '';
  if (ENDED_CODES.has(endedReason) && (access || refreshToken)) {
    access = '';
    writes.push(...clearedSessionCookies);
    ended = endedReason;
  } else if (refreshToken && !isAuthRoute && (!access || !Number.isFinite(exp) || exp - Date.now() < REFRESH_MARGIN_MS)) {
    const r = await refresh(refreshToken, deviceId, ua);
    if (r.ok) {
      access = r.tokens.accessToken;
      writes.push(...sessionCookies(r.tokens, keep));
    } else if (r.ended) {
      access = '';
      writes.push(...clearedSessionCookies);
      ended = ENDED_CODES.has(r.code) ? r.code : 'session_ended';
    }
  }

  const signedIn = Boolean(access) && !ended;

  // Pages under /app need a session.
  if (pathname.startsWith('/app') && !signedIn) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.search = '';
    url.searchParams.set('next', pathname + search);
    if (ended) url.searchParams.set('reason', ended);
    return apply(NextResponse.redirect(url), writes);
  }
  if ((pathname === '/login' || pathname === '/signup') && signedIn) {
    const url = req.nextUrl.clone();
    url.pathname = '/app';
    url.search = '';
    return apply(NextResponse.redirect(url), writes);
  }

  // Let this request's server code see the new cookies too.
  const requestHeaders = new Headers(req.headers);
  if (writes.length) {
    const jar = new Map(req.cookies.getAll().map((c) => [c.name, c.value]));
    for (const w of writes) {
      if (w.maxAge === 0) jar.delete(w.name);
      else jar.set(w.name, w.value);
    }
    requestHeaders.set(
      'cookie',
      Array.from(jar, ([k, v]) => `${k}=${encodeURIComponent(v)}`).join('; '),
    );
  }
  return apply(NextResponse.next({ request: { headers: requestHeaders } }), writes);
}

export const config = {
  // Everything except static files and images.
  matcher: ['/((?!_next/static|_next/image|favicon.ico|mascot/|branding/|videos/|media/|robots.txt|sitemap.xml).*)'],
};
