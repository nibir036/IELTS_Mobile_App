// bKash Tokenized Checkout (website payments). With an agreement the student's
// wallet is saved for renewals: an agreement payment only asks for the bKash
// PIN, no OTP.
//
//   BKASH_BASE_URL   https://tokenized.sandbox.bka.sh/v1.2.0-beta  (live: https://tokenized.pay.bka.sh/v1.2.0-beta)
//   BKASH_APP_KEY / BKASH_APP_SECRET / BKASH_USERNAME / BKASH_PASSWORD
//
// Flow: create → the student opens bkashURL and approves → bKash redirects
// to callbackURL?paymentID=…&status=success|failure|cancel → execute.

import { env } from '../../env';
import { HttpError } from '../http';

type Json = Record<string, unknown>;

export function bkashConfigured(): boolean {
  return Boolean(env.bkashAppKey && env.bkashAppSecret && env.bkashUsername && env.bkashPassword);
}

let grant: { token: string; until: number } | null = null;

async function idToken(): Promise<string> {
  if (grant && Date.now() < grant.until) return grant.token;
  if (!bkashConfigured()) throw new HttpError(503, 'bKash payments are not set up on the server yet.', 'billing_not_configured');
  const res = await fetch(`${env.bkashBaseUrl}/tokenized/checkout/token/grant`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', username: env.bkashUsername, password: env.bkashPassword },
    body: JSON.stringify({ app_key: env.bkashAppKey, app_secret: env.bkashAppSecret }),
  });
  const data = (await res.json().catch(() => ({}))) as { id_token?: string; expires_in?: number; statusMessage?: string };
  if (!res.ok || !data.id_token) {
    console.error('[bkash] grant failed', res.status, data);
    throw new HttpError(502, 'Could not reach bKash right now. Please try again.', 'bkash_unavailable');
  }
  grant = { token: data.id_token, until: Date.now() + Math.max(60, (data.expires_in ?? 3600) - 300) * 1000 };
  return grant.token;
}

async function call(path: string, body: Json): Promise<Json> {
  const res = await fetch(`${env.bkashBaseUrl}/tokenized/checkout${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', Authorization: await idToken(), 'X-APP-Key': env.bkashAppKey },
    body: JSON.stringify(body),
  });
  const data = (await res.json().catch(() => ({}))) as Json;
  if (!res.ok) {
    console.error('[bkash]', path, res.status, data);
    throw new HttpError(502, 'bKash could not complete the request. Please try again.', 'bkash_failed');
  }
  return data;
}

/** bKash's own error ("statusCode" not "0000"), as a student-facing message. */
export function bkashError(data: Json): string | null {
  const code = String(data.statusCode ?? '');
  if (!code || code === '0000') return null;
  return String(data.statusMessage ?? data.errorMessage ?? 'The bKash payment did not go through.');
}

export interface Created {
  paymentID: string;
  bkashURL: string;
}

function created(data: Json): Created {
  const err = bkashError(data);
  if (err || !data.paymentID || !data.bkashURL) throw new HttpError(502, err ?? 'bKash did not start the payment.', 'bkash_failed');
  return { paymentID: String(data.paymentID), bkashURL: String(data.bkashURL) };
}

/** Step 1 of saving a wallet: the student approves an agreement. */
export async function createAgreement(payerReference: string, callbackURL: string): Promise<Created> {
  return created(await call('/create', { mode: '0000', payerReference, callbackURL, currency: 'BDT', intent: 'sale', amount: '0' }));
}

/** A payment: with a saved agreement (mode 0001, PIN only) or a one-off (0011). */
export async function createPayment(p: {
  amount: number;
  invoice: string;
  payerReference: string;
  callbackURL: string;
  agreementID?: string;
}): Promise<Created> {
  return created(
    await call('/create', {
      mode: p.agreementID ? '0001' : '0011',
      payerReference: p.payerReference,
      callbackURL: p.callbackURL,
      ...(p.agreementID ? { agreementID: p.agreementID } : {}),
      amount: p.amount.toFixed(2),
      currency: 'BDT',
      intent: 'sale',
      merchantInvoiceNumber: p.invoice,
    }),
  );
}

/** Completes an approved agreement or payment. */
export async function execute(paymentID: string): Promise<Json> {
  return call('/execute', { paymentID });
}

/** A payment's status (when execute timed out). */
export async function paymentStatus(paymentID: string): Promise<Json> {
  return call('/payment/status', { paymentID });
}

export async function cancelAgreement(agreementID: string): Promise<void> {
  try {
    await call('/agreement/cancel', { agreementID });
  } catch (e) {
    console.error('[bkash] agreement cancel failed', e);
  }
}

/** "01712345678" → "017•••••678". */
export function maskWallet(msisdn: string): string {
  const d = msisdn.replace(/\D/g, '').replace(/^880/, '0');
  return d.length >= 7 ? `${d.slice(0, 3)}•••••${d.slice(-3)}` : d;
}
