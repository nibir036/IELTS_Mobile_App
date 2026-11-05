// bKash Tokenized Checkout v2, without agreement (website payments).
//
//   BKASH_BASE_URL   https://tokenized.sandbox.bka.sh/v2  (live: https://tokenized.pay.bka.sh/v2)
//   BKASH_CHECKOUT_URL_APP_KEY / _APP_SECRET / _USER_NAME / _PASSWORD
//
// Flow (bKash's API review checklist):
//   0. Grant a token once and reuse it for its whole life (about 1 hour) for
//      every request and every student. It is kept in the database
//      (app_config "bkash.id_token") so restarts and several server copies
//      share one token, and a database lock makes sure only one grant runs.
//   create → the student approves on bkashURL → bKash returns them to the
//   website with ?paymentID=…&status=success|failure|cancel
//   1. failure / cancel → no execute; the student sees the failure message.
//   2. success → execute.
//   3. Paid only when execute says transactionStatus "Completed"; anything
//      else is a failure, shown with bKash's errorMessageEn.
//   4. Query payment only when execute gave no answer (timeout, network
//      error, empty body), never otherwise.
//   5. Refund (admin) uses the same stored token.

import { createHash } from 'node:crypto';
import { prisma } from '../../db';
import { env } from '../../env';
import { HttpError } from '../http';

type Json = Record<string, unknown>;

export function bkashConfigured(): boolean {
  return Boolean(env.bkashAppKey && env.bkashAppSecret && env.bkashUsername && env.bkashPassword);
}

/** bKash gave no answer: timeout, network error, or an empty / non-JSON body. */
export class BkashNoResponse extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BkashNoResponse';
  }
}

/** One answer from bKash. ok = HTTP 2xx and no bKash error code. */
export interface BkashResult {
  ok: boolean;
  http: number;
  data: Json;
}

/** The first non-empty field of [keys] (v2 is not consistent: paymentId / paymentID). */
export function pick(data: Json, ...keys: string[]): string {
  for (const k of keys) {
    const v = data[k];
    if (v !== undefined && v !== null && String(v) !== '') return String(v);
  }
  return '';
}

/** bKash's own error, as a student-facing message (errorMessageEn first); null when none. */
export function bkashError(data: Json): string | null {
  const code = pick(data, 'errorCode', 'externalCode');
  const status = pick(data, 'statusCode');
  const failed = (code !== '' && code !== '0000') || (status !== '' && status !== '0000');
  if (!failed) return null;
  return pick(data, 'errorMessageEn', 'errorMessage', 'statusMessage') || 'The bKash payment did not go through.';
}

/** The message to show for a failed result. */
export function failureMessage(r: BkashResult, fallback = 'The bKash payment did not go through.'): string {
  return bkashError(r.data) ?? (pick(r.data, 'errorMessageEn', 'errorMessage', 'statusMessage') || fallback);
}

// ── HTTP ─────────────────────────────────────────────────────────────────────

const SECRET = new Set(['app_key', 'app_secret', 'id_token', 'refresh_token', 'username', 'password', 'Authorization']);

/** For the logs: secrets hidden, wallet numbers cut to the last 3 digits. */
function safe(data: Json): Json {
  const out: Json = {};
  for (const [k, v] of Object.entries(data)) {
    if (SECRET.has(k)) out[k] = '***';
    else if (/msisdn|payerAccount|customer/i.test(k) && typeof v === 'string') out[k] = `•••${v.slice(-3)}`;
    else out[k] = v;
  }
  return out;
}

async function post(path: string, body: Json, headers: Record<string, string>): Promise<BkashResult> {
  const url = `${env.bkashBaseUrl}/tokenized-checkout/${path}`;
  let res: Response;
  let text: string;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', ...headers },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(env.bkashTimeoutMs),
    });
    text = await res.text();
  } catch (e) {
    console.error(`[bkash] ${path}: no response (${(e as Error).name}: ${(e as Error).message})`);
    throw new BkashNoResponse(`${path}: no response`);
  }
  let data: Json | null = null;
  try {
    const parsed = JSON.parse(text) as unknown;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) data = parsed as Json;
  } catch {
    data = null;
  }
  if (!data || Object.keys(data).length === 0) {
    console.error(`[bkash] ${path}: HTTP ${res.status} with an empty or unreadable body`);
    throw new BkashNoResponse(`${path}: empty response`);
  }
  const ok = res.ok && !bkashError(data);
  if (!ok) console.error(`[bkash] ${path}: HTTP ${res.status}`, safe(data));
  return { ok, http: res.status, data };
}

// ── Token (grant once, reuse for its life, stored in the database) ───────────

const TOKEN_KEY = 'bkash.id_token';
/** A forced re-grant (bKash said 401) is refused when the token is younger than this. */
const MIN_REGRANT_MS = 10 * 60_000;

type Stored = { idToken: string; expiresAt: number; grantedAt: number; account: string };

let cached: Stored | null = null;
let inflight: Promise<string> | null = null;

/** Which merchant account + server a token belongs to (switching sandbox → live drops it). */
function account(): string {
  return createHash('sha256').update(`${env.bkashBaseUrl}|${env.bkashAppKey}|${env.bkashUsername}`).digest('hex').slice(0, 16);
}

function usable(t: Stored | null | undefined): t is Stored {
  return Boolean(t && t.idToken && t.account === account() && Date.now() < t.expiresAt);
}

async function grantToken(): Promise<Stored> {
  let r: BkashResult;
  try {
    r = await post('auth/grant-token', { app_key: env.bkashAppKey, app_secret: env.bkashAppSecret }, { username: env.bkashUsername, password: env.bkashPassword });
  } catch {
    throw new HttpError(502, 'Could not reach bKash right now. Please try again.', 'bkash_unavailable');
  }
  const token = pick(r.data, 'id_token');
  if (!r.ok || !token) throw new HttpError(502, 'Could not reach bKash right now. Please try again.', 'bkash_unavailable');
  const life = Number(r.data.expires_in) > 0 ? Number(r.data.expires_in) : 3600;
  const now = Date.now();
  // Reuse until 2 minutes before bKash's expiry (so a request never starts with a dying token).
  const t: Stored = { idToken: token, grantedAt: now, expiresAt: now + Math.max(60, life - 120) * 1000, account: account() };
  console.log(`[bkash] new token granted, reused until ${new Date(t.expiresAt).toISOString()}`);
  return t;
}

async function loadOrGrant(rejected: string | null): Promise<string> {
  return prisma.$transaction(
    async (tx) => {
      // One grant at a time across every server copy.
      await tx.$executeRawUnsafe(`SELECT pg_advisory_xact_lock(hashtext('nexted:bkash:grant'))`);
      const row = (await tx.appConfig.findUnique({ where: { key: TOKEN_KEY } })) as { value: unknown } | null;
      const saved = (row?.value ?? null) as Stored | null;
      if (usable(saved)) {
        // Someone else already replaced the rejected token, or it was not rejected at all.
        if (saved.idToken !== rejected) return (cached = saved).idToken;
        // bKash rejected a young token: don't spend one of the limited grants on it.
        if (Date.now() - saved.grantedAt < MIN_REGRANT_MS) return (cached = saved).idToken;
      }
      const t = await grantToken();
      const value = { idToken: t.idToken, expiresAt: t.expiresAt, grantedAt: t.grantedAt, account: t.account };
      await tx.appConfig.upsert({ where: { key: TOKEN_KEY }, create: { key: TOKEN_KEY, value }, update: { value } });
      cached = t;
      return t.idToken;
    },
    { maxWait: env.bkashTimeoutMs + 15_000, timeout: env.bkashTimeoutMs + 15_000 },
  );
}

/** The shared id_token; [rejected] = the token bKash just refused (401). */
async function idToken(rejected: string | null = null): Promise<string> {
  if (!bkashConfigured()) throw new HttpError(503, 'bKash payments are not set up on the server yet.', 'billing_not_configured');
  if (!rejected && usable(cached)) return cached.idToken;
  inflight ??= loadOrGrant(rejected).finally(() => {
    inflight = null;
  });
  return inflight;
}

/** An authorised call with the shared token; one retry with a new token on HTTP 401. */
async function call(path: string, body: Json): Promise<BkashResult> {
  const token = await idToken();
  const r = await post(path, body, { Authorization: token, 'X-App-Key': env.bkashAppKey });
  if (r.http !== 401) return r;
  const next = await idToken(token);
  if (next === token) return r;
  return post(path, body, { Authorization: next, 'X-App-Key': env.bkashAppKey });
}

// ── Payments ─────────────────────────────────────────────────────────────────

export interface Created {
  paymentID: string;
  bkashURL: string;
}

/** Create API: a one-off payment (mode 0011, without agreement). */
export async function createPayment(p: { amount: number; invoice: string; payerReference: string; callbackURL: string }): Promise<Created> {
  let r: BkashResult;
  try {
    r = await call('payment/create', {
      mode: '0011',
      payerReference: p.payerReference || p.invoice,
      callbackURL: p.callbackURL,
      amount: p.amount.toFixed(2),
      currency: 'BDT',
      intent: 'sale',
      merchantInvoiceNumber: p.invoice,
    });
  } catch (e) {
    if (e instanceof BkashNoResponse) throw new HttpError(502, 'Could not reach bKash right now. Please try again.', 'bkash_unavailable');
    throw e;
  }
  const paymentID = pick(r.data, 'paymentId', 'paymentID');
  const bkashURL = pick(r.data, 'bkashURL', 'bKashURL');
  if (!r.ok || !paymentID || !bkashURL) throw new HttpError(502, failureMessage(r, 'bKash did not start the payment. Please try again.'), 'bkash_failed');
  return { paymentID, bkashURL };
}

/** Execute API. Throws BkashNoResponse when bKash gives no answer (then, and only then, query). */
export function executePayment(paymentID: string): Promise<BkashResult> {
  return call('payment/execute', { paymentId: paymentID });
}

/** Query payment API: only as the fallback for an execute that got no answer. */
export function queryPayment(paymentID: string): Promise<BkashResult> {
  return call('query/payment', { paymentId: paymentID });
}

/** Refund API (full or partial), with the same stored token. */
export function refundPayment(p: { paymentID: string; trxID: string; amount: number; reason: string; sku?: string }): Promise<BkashResult> {
  return call('refund/payment/transaction', {
    paymentId: p.paymentID,
    trxId: p.trxID,
    refundAmount: p.amount.toFixed(2),
    sku: p.sku || 'pro-pass',
    reason: p.reason,
  });
}

/** Refunds already made for a payment (check this before retrying a refund that timed out). */
export function refundStatus(paymentID: string, trxID: string): Promise<BkashResult> {
  return call('refund/payment/status', { paymentId: paymentID, trxId: trxID });
}

/** "01712345678" → "017•••••678". */
export function maskWallet(msisdn: string): string {
  const d = msisdn.replace(/\D/g, '').replace(/^880/, '0');
  return d.length >= 7 ? `${d.slice(0, 3)}•••••${d.slice(-3)}` : d;
}
