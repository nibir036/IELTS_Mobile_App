import { NextResponse } from 'next/server';
import { api, type ApiError } from '@/lib/server/api';
import { errorResponse, withCookies } from '@/lib/server/respond';
import { sessionCookies, type AuthTokens } from '@/lib/session';

/** Phone + password → session cookies. Errors keep the API's code (device_locked …). */
export async function POST(req: Request) {
  const body = (await req.json().catch(() => ({}))) as { phone?: string; password?: string; keep?: boolean };
  const phone = String(body.phone ?? '').trim();
  const password = String(body.password ?? '');
  if (!phone || !password) {
    return NextResponse.json({ error: 'Enter your phone number and password.', code: 'missing' }, { status: 400 });
  }
  try {
    const r = await api<AuthTokens & { user: Record<string, unknown> }>('/v1/auth/login', {
      method: 'POST',
      body: { phone, password },
      auth: false,
    });
    return withCookies(NextResponse.json({ ok: true, user: r.user }), sessionCookies(r, body.keep !== false));
  } catch (e) {
    return errorResponse(e as ApiError);
  }
}
