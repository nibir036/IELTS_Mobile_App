// Sign-up and password reset steps, passed to the API:
//   otp-send   {phone, purpose: signup|reset}      → {resendAfterSec}
//   otp-verify {phone, purpose, code}              → {proof}
//   register   {name, phone, password, proof}      → session cookies
//   reset      {phone, password, proof}            → session cookies
import { NextResponse } from 'next/server';
import { api } from '@/lib/server/api';
import { errorResponse, withCookies } from '@/lib/server/respond';
import { sessionCookies, type AuthTokens } from '@/lib/session';

const PATHS: Record<string, string> = {
  'otp-send': '/v1/auth/otp/send',
  'otp-verify': '/v1/auth/otp/verify',
  register: '/v1/auth/register',
  reset: '/v1/auth/reset-password',
};
const SIGNS_IN = new Set(['register', 'reset']);

export async function POST(req: Request, ctx: { params: Promise<{ action: string }> }) {
  const { action } = await ctx.params;
  const path = PATHS[action];
  if (!path) return NextResponse.json({ error: 'Not found.', code: 'not_found' }, { status: 404 });
  const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
  try {
    const r = await api<Record<string, unknown>>(path, { method: 'POST', body, auth: false });
    if (SIGNS_IN.has(action)) {
      const t = r as unknown as AuthTokens;
      return withCookies(NextResponse.json({ ok: true, user: r.user }), sessionCookies(t, true));
    }
    // Never pass a development OTP on to the page in production.
    if (process.env.NODE_ENV === 'production') delete r.devCode;
    return NextResponse.json(r);
  } catch (e) {
    return errorResponse(e);
  }
}
