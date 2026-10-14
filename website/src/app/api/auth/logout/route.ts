import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { api } from '@/lib/server/api';
import { withCookies } from '@/lib/server/respond';
import { clearedSessionCookies, COOKIE } from '@/lib/session';

export async function POST() {
  const refreshToken = (await cookies()).get(COOKIE.refresh)?.value;
  if (refreshToken) {
    try {
      await api('/v1/auth/logout', { method: 'POST', body: { refreshToken }, auth: false });
    } catch {
      // Signed out here either way.
    }
  }
  return withCookies(NextResponse.json({ ok: true }), clearedSessionCookies);
}
