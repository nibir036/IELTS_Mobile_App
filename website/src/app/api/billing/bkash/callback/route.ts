// bKash sends the student back here after the wallet / PIN screens:
//   /api/billing/bkash/callback?paymentID=…&status=success|failure|cancel
// The API finishes the payment (or saves the wallet and starts the payment
// with it), and the student lands on Plans & billing with the result.

import { NextResponse } from 'next/server';
import { api, ApiError } from '@/lib/server/api';
import { env } from '@/lib/server/env';

type Result = { done?: boolean; next?: string; message?: string };

const BKASH_HOST = /(^|\.)bkash\.com$|(^|\.)bka\.sh$/i;

function back(params: Record<string, string>): NextResponse {
  const url = new URL(`${env.siteUrl}/app/profile/billing`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  return NextResponse.redirect(url, 303);
}

export async function GET(req: Request) {
  const q = new URL(req.url).searchParams;
  const paymentID = (q.get('paymentID') ?? q.get('paymentId') ?? '').slice(0, 200);
  const status = (q.get('status') ?? '').slice(0, 20);
  if (!paymentID) return back({ error: 'bKash did not return a payment. Please try again.' });
  try {
    const r = await api<Result>('/v1/billing/bkash/callback', { method: 'POST', body: { paymentID, status } });
    if (r.next) {
      // Wallet saved: on to the payment itself (PIN only).
      let host = '';
      try {
        host = new URL(r.next).hostname;
      } catch {}
      if (BKASH_HOST.test(host)) return NextResponse.redirect(r.next, 303);
      return back({ error: 'bKash returned an unexpected address. Please try again.' });
    }
    if (r.done) return back({ paid: '1' });
    return back({ error: r.message ?? 'The bKash payment did not go through.' });
  } catch (e) {
    return back({ error: e instanceof ApiError ? e.message : 'The bKash payment could not be confirmed. If money left your wallet, contact support.' });
  }
}
