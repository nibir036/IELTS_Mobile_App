// Pro passes: the plan the student holds, Google Play purchases (app) and
// bKash Tokenized Checkout without agreement (website, see lib/billing/bkash.ts).
//
//   GET    /v1/billing                      plan, dates, payment method, upgrade
//   PATCH  /v1/billing                      {autoRenew}
//   DELETE /v1/billing/payment-method       forget a saved bKash wallet
//   POST   /v1/billing/google/verify        {productId, purchaseToken}
//   POST   /v1/billing/google/rtdn?token=   Play notifications (refunds)
//   POST   /v1/billing/bkash/start          {passId, callbackURL} → {bkashURL}
//   POST   /v1/billing/bkash/save-method    not available without agreement (400)
//   POST   /v1/billing/bkash/callback       {paymentID, status} → {done, trxID} | {done: false, message}
//
// Admin (X-Admin-Token header = ADMIN_TOKEN):
//   GET    /v1/billing/bkash/payments?limit=20      latest bKash payments
//   POST   /v1/billing/bkash/refund                 {paymentID, amount?, reason?}
//   POST   /v1/billing/bkash/refund-status          {paymentID}

import { createHash, timingSafeEqual } from 'node:crypto';
import { prisma } from '../db';
import { env } from '../env';
import { badRequest, forbidden, HttpError, int, rateLimit, required, Router, s, type Ctx } from '../lib/http';
import { requireUser } from '../lib/users';
import {
  BkashNoResponse,
  bkashConfigured,
  createPayment,
  executePayment,
  failureMessage,
  maskWallet,
  pick,
  queryPayment,
  refundPayment,
  refundStatus,
  type BkashResult,
} from '../lib/billing/bkash';
import { consumePurchase, getProductPurchase } from '../lib/billing/google';
import { passById, passByProduct } from '../lib/billing/passes';
import { billingSummary, grantPass, setAutoRenew } from '../lib/billing/subscriptions';

type Row = Record<string, unknown>;

/** What the app sends Google as obfuscatedAccountId: a hash of the user id. */
export function playAccountId(userId: string): string {
  return createHash('sha256').update(`ieltsai:${userId}`).digest('hex').slice(0, 64);
}

/** bKash returns the student to the website only. */
function callbackUrl(raw: unknown): string {
  const url = s(raw, 500);
  const allowed = [env.websiteUrl, ...(env.isProd ? [] : ['http://localhost:', 'http://127.0.0.1:'])];
  if (!url || !allowed.some((a) => url.startsWith(a))) throw badRequest('Invalid return address.', 'bad_callback');
  return url;
}

async function phoneOf(userId: string): Promise<string> {
  const u = (await prisma.user.findUnique({ where: { id: userId }, select: { phone: true } })) as { phone?: string } | null;
  return (u?.phone ?? '').replace(/\D/g, '').replace(/^880/, '0');
}

async function savedAgreement(userId: string): Promise<{ id: string; token: string } | null> {
  return (await prisma.paymentMethod.findFirst({
    where: { userId, provider: 'bkash', revokedAt: null },
    orderBy: { createdAt: 'desc' },
    select: { id: true, token: true },
  })) as { id: string; token: string } | null;
}

/** Saved wallets need bKash's "with agreement" product, which this merchant account doesn't have. */
const NO_SAVED_WALLET = 'Saving a bKash wallet for auto-renewal is not available yet. You can pay with bKash each time.';

/** Starts a one-off bKash payment for [passId] and logs it. */
async function startPayment(userId: string, passId: string, callbackURL: string): Promise<string> {
  const pass = await passById(passId);
  if (!pass) throw badRequest('Unknown pass.', 'bad_pass');
  const invoice = `IA${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).slice(2, 5).toUpperCase()}`;
  const created = await createPayment({ amount: pass.webPrice, invoice, payerReference: await phoneOf(userId), callbackURL });
  await prisma.payment.create({
    data: {
      userId,
      provider: 'bkash',
      providerRef: created.paymentID,
      kind: 'payment',
      passId: pass.id,
      amount: pass.webPrice,
      currency: 'BDT',
      status: 'initiated',
      meta: { invoice },
    },
  });
  return created.bkashURL;
}

/** Admin calls: X-Admin-Token must equal ADMIN_TOKEN (24+ characters). */
function requireAdmin(ctx: Ctx): void {
  const want = Buffer.from(env.adminToken);
  if (want.length < 24) throw new HttpError(503, 'Admin calls are off: ADMIN_TOKEN must be at least 24 characters.', 'admin_off');
  rateLimit(`admin:${ctx.ip}`, 600, 3600);
  const got = Buffer.from(s(ctx.req.headers['x-admin-token'], 300));
  if (got.length !== want.length || !timingSafeEqual(got, want)) throw new HttpError(401, 'Wrong admin token.', 'bad_admin_token');
}

type PayRow = {
  id: string;
  userId: string;
  kind: string;
  passId: string | null;
  amount: number | null;
  status: string;
  trxId: string | null;
  meta: Row | null;
  createdAt: Date;
};

type Refund = { refundTrxID: string; amount: number; reason: string; at: string };

function refundsOf(meta: Row | null): Refund[] {
  return Array.isArray(meta?.refunds) ? (meta!.refunds as Refund[]) : [];
}

/** The bKash fields worth keeping on the payment (no secrets). */
function bkashFields(r: BkashResult): Row {
  return {
    http: r.http,
    transactionStatus: pick(r.data, 'transactionStatus') || null,
    statusCode: pick(r.data, 'statusCode', 'errorCode', 'externalCode') || null,
    message: pick(r.data, 'errorMessageEn', 'errorMessage', 'statusMessage') || null,
  };
}

export function registerBillingRoutes(r: Router): void {
  r.get('/v1/billing', async (ctx) => {
    const userId = requireUser(ctx);
    return { ...(await billingSummary(userId)), playAccountId: playAccountId(userId), bkash: bkashConfigured(), bkashSavedWallet: false };
  });

  r.patch('/v1/billing', async (ctx) => {
    const userId = requireUser(ctx);
    if (typeof ctx.body.autoRenew === 'boolean') {
      if (ctx.body.autoRenew && !(await savedAgreement(userId))) throw badRequest(NO_SAVED_WALLET, 'bkash_agreement_unavailable');
      await setAutoRenew(userId, ctx.body.autoRenew);
    }
    return billingSummary(userId);
  });

  r.delete('/v1/billing/payment-method', async (ctx) => {
    const userId = requireUser(ctx);
    const m = await savedAgreement(userId);
    if (m) {
      await prisma.paymentMethod.update({ where: { id: m.id }, data: { revokedAt: new Date() } });
      await setAutoRenew(userId, false);
    }
    return billingSummary(userId);
  });

  // ── Google Play (app) ─────────────────────────────────────────────────────

  r.post('/v1/billing/google/verify', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`play-verify:${userId}`, 30, 3600);
    const productId = required(ctx.body, 'productId', 100);
    const purchaseToken = required(ctx.body, 'purchaseToken', 4000);
    const pass = await passByProduct(productId);
    if (!pass) throw badRequest('Unknown product.', 'bad_product');

    const known = (await prisma.payment.findUnique({ where: { providerRef: purchaseToken } })) as { userId: string; status: string } | null;
    if (known && known.userId !== userId) throw forbidden('This purchase belongs to another account.', 'purchase_taken');
    // A refunded or cancelled purchase can't be verified again for a new pass.
    if (known && known.status !== 'completed' && known.status !== 'initiated' && known.status !== 'pending') {
      throw badRequest('This purchase was refunded or cancelled.', 'purchase_cancelled');
    }
    if (known?.status === 'completed') {
      await consumePurchase(productId, purchaseToken);
      return { status: 'completed', billing: await billingSummary(userId) };
    }

    const p = await getProductPurchase(productId, purchaseToken);
    if (!p) throw badRequest('Google Play does not recognise this purchase.', 'bad_purchase');
    if (p.purchaseState === 2) return { status: 'pending', billing: await billingSummary(userId) };
    if (p.purchaseState !== 0) throw badRequest('This purchase was cancelled.', 'purchase_cancelled');
    if (p.obfuscatedExternalAccountId && p.obfuscatedExternalAccountId !== playAccountId(userId)) {
      throw forbidden('This purchase was made from another account.', 'purchase_taken');
    }
    if (p.consumptionState === 1 && !known) throw badRequest('This purchase was already used.', 'purchase_used');

    // Claim the purchase atomically, so parallel calls with one token can't
    // grant two passes: only the call that creates (or flips) the row grants.
    const trxId = p.orderId ?? null;
    let claimed = false;
    try {
      await prisma.payment.create({
        data: {
          userId,
          provider: 'google_play',
          providerRef: purchaseToken,
          kind: 'purchase',
          passId: pass.id,
          amount: pass.appPrice,
          currency: 'BDT',
          status: 'completed',
          trxId,
          meta: { productId, regionCode: p.regionCode ?? null },
        },
      });
      claimed = true;
    } catch (e) {
      if ((e as { code?: string }).code !== 'P2002') throw e;
      // The row exists: flip it only if it is this user's and not yet used.
      const { count } = await prisma.payment.updateMany({
        where: { providerRef: purchaseToken, userId, status: { notIn: ['completed', 'refunded'] } },
        data: { status: 'completed', trxId },
      });
      claimed = count === 1;
    }
    if (!claimed) {
      // Another call already granted it (or it was refunded): nothing more to give.
      await consumePurchase(productId, purchaseToken).catch(() => undefined);
      return { status: 'completed', billing: await billingSummary(userId) };
    }
    await grantPass({ userId, pass, provider: 'google_play', providerRef: purchaseToken, amount: pass.appPrice, autoRenew: false });
    await consumePurchase(productId, purchaseToken);
    return { status: 'completed', billing: await billingSummary(userId) };
  });

  // Pub/Sub push: a refunded or charged-back Play purchase ends that pass.
  r.post('/v1/billing/google/rtdn', async (ctx) => {
    const got = Buffer.from(s(ctx.query.get('token'), 200));
    const want = Buffer.from(env.googlePlayRtdnToken);
    if (!want.length || got.length !== want.length || !timingSafeEqual(got, want)) throw forbidden('Bad token.', 'bad_token');
    const data = String(((ctx.body.message ?? {}) as Row).data ?? '');
    let msg: Row = {};
    try {
      msg = JSON.parse(Buffer.from(data, 'base64').toString('utf8')) as Row;
    } catch {
      return { ok: true };
    }
    const voided = (msg.voidedPurchaseNotification ?? null) as Row | null;
    const token = s(voided?.purchaseToken, 4000);
    if (token) {
      await prisma.payment.updateMany({ where: { providerRef: token }, data: { status: 'refunded' } });
      await prisma.subscription.updateMany({ where: { providerRef: token }, data: { status: 'refunded' } });
    }
    return { ok: true };
  });

  // ── bKash (website) ───────────────────────────────────────────────────────

  r.post('/v1/billing/bkash/start', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`bkash-start:${userId}`, 20, 3600);
    const passId = required(ctx.body, 'passId', 20);
    const cb = callbackUrl(ctx.body.callbackURL);
    return { bkashURL: await startPayment(userId, passId, cb) };
  });

  r.post('/v1/billing/bkash/save-method', async (ctx) => {
    requireUser(ctx);
    throw badRequest(NO_SAVED_WALLET, 'bkash_agreement_unavailable');
  });

  // The website forwards bKash's return here: ?paymentID=…&status=success|failure|cancel
  r.post('/v1/billing/bkash/callback', async (ctx) => {
    const userId = requireUser(ctx);
    const paymentID = required(ctx.body, 'paymentID', 200);
    const status = s(ctx.body.status, 20).toLowerCase();
    rateLimit(`bkash-callback:${userId}`, 60, 3600);
    const pay = (await prisma.payment.findUnique({ where: { providerRef: paymentID } })) as PayRow | null;
    if (!pay || pay.userId !== userId) throw badRequest('Unknown payment.', 'bad_payment');
    const meta = pay.meta ?? {};
    if (pay.status === 'completed') return { done: true, trxID: pay.trxId, billing: await billingSummary(userId) };
    if (pay.status === 'refunded') return { done: false, message: 'This bKash payment was refunded.' };
    if (pay.status !== 'initiated') return { done: false, message: String(meta.error ?? 'The bKash payment did not go through. Please try again.') };

    // 1. failure / cancel: never execute; the website shows the failure page.
    if (status !== 'success') {
      const cancelled = status === 'cancel';
      const message = cancelled ? 'You cancelled the bKash payment.' : 'The bKash payment failed. No money was taken. Please try again.';
      await prisma.payment.updateMany({
        where: { id: pay.id, status: 'initiated' },
        data: { status: cancelled ? 'cancelled' : 'failed', meta: { ...meta, callbackStatus: status || 'missing', error: message } },
      });
      return { done: false, message };
    }

    // 2. success: execute.
    let result: BkashResult;
    let via: 'execute' | 'query' = 'execute';
    try {
      result = await executePayment(paymentID);
    } catch (e) {
      if (!(e instanceof BkashNoResponse)) throw e;
      // 4. No answer from execute (timeout / empty): only now ask for the payment's status.
      via = 'query';
      try {
        result = await queryPayment(paymentID);
      } catch (e2) {
        if (!(e2 instanceof BkashNoResponse)) throw e2;
        await prisma.payment.update({ where: { id: pay.id }, data: { meta: { ...meta, unconfirmedAt: new Date().toISOString() } } });
        return {
          done: false,
          message: `bKash did not confirm the payment in time. If money left your wallet, contact support with payment ID ${paymentID} and we will add your pass.`,
        };
      }
    }

    // 3. Only transactionStatus "Completed" is a payment; anything else shows bKash's errorMessageEn.
    const trxID = pick(result.data, 'trxID', 'trxId');
    const completed = result.ok && pick(result.data, 'transactionStatus') === 'Completed' && Boolean(trxID);
    if (!completed) {
      const message = failureMessage(result, via === 'query' ? 'The bKash payment was not completed. Please try again.' : 'The bKash payment did not go through.');
      await prisma.payment.updateMany({
        where: { id: pay.id, status: 'initiated' },
        data: { status: 'failed', meta: { ...meta, via, bkash: bkashFields(result), error: message } },
      });
      return { done: false, message };
    }

    const pass = await passById(pay.passId ?? '');
    if (!pass) throw new HttpError(500, 'The pass for this payment no longer exists. Contact support.', 'bad_pass');
    const paid = Number(pick(result.data, 'amount')) || pay.amount || pass.webPrice;
    // Claim the payment first, so a double callback can't grant twice.
    const claimed = await prisma.payment.updateMany({
      where: { id: pay.id, status: 'initiated' },
      data: {
        status: 'completed',
        trxId: trxID,
        meta: { ...meta, via, bkash: bkashFields(result), wallet: maskWallet(pick(result.data, 'customerMsisdn', 'payerAccount')) || null },
      },
    });
    if (claimed.count === 1) {
      await grantPass({ userId, pass, provider: 'bkash', providerRef: paymentID, amount: paid, autoRenew: false });
    }
    return { done: true, trxID, billing: await billingSummary(userId) };
  });

  // ── bKash admin (UAT refund test, support) ───────────────────────────────

  r.get('/v1/billing/bkash/payments', async (ctx) => {
    requireAdmin(ctx);
    const rows = (await prisma.payment.findMany({
      where: { provider: 'bkash' },
      orderBy: { createdAt: 'desc' },
      take: int(ctx.query.get('limit') ?? undefined, 20, 1, 100),
    })) as Array<PayRow & { providerRef: string }>;
    return {
      payments: rows.map((p) => ({
        paymentID: p.providerRef,
        trxID: p.trxId,
        status: p.status,
        amount: p.amount,
        passId: p.passId,
        refunded: refundsOf(p.meta).reduce((n, x) => n + x.amount, 0),
        createdAt: p.createdAt.toISOString(),
      })),
    };
  });

  r.post('/v1/billing/bkash/refund', async (ctx) => {
    requireAdmin(ctx);
    const paymentID = required(ctx.body, 'paymentID', 200);
    const reason = s(ctx.body.reason, 200).trim() || 'Refund requested';
    const pay = (await prisma.payment.findUnique({ where: { providerRef: paymentID } })) as PayRow | null;
    if (!pay || pay.kind !== 'payment') throw badRequest('Unknown bKash payment.', 'bad_payment');
    if (pay.status !== 'completed' || !pay.trxId) throw badRequest(`Only completed payments can be refunded (this one is ${pay.status}).`, 'not_refundable');
    const meta = pay.meta ?? {};
    const done = refundsOf(meta);
    const left = (pay.amount ?? 0) - done.reduce((n, x) => n + x.amount, 0);
    const amount = ctx.body.amount === undefined || ctx.body.amount === null || ctx.body.amount === '' ? left : Number(ctx.body.amount);
    if (!Number.isFinite(amount) || amount <= 0 || amount > left) throw badRequest(`Refund amount must be more than 0 and at most ${left}.`, 'bad_amount');

    let result: BkashResult;
    try {
      result = await refundPayment({ paymentID, trxID: pay.trxId, amount, reason });
    } catch (e) {
      if (!(e instanceof BkashNoResponse)) throw e;
      // No answer: never retry blindly (it could refund twice). Show what bKash has.
      const st = await refundStatus(paymentID, pay.trxId).catch(() => null);
      return { done: false, message: 'bKash did not answer the refund. Check the refund status below before trying again.', refundStatus: st?.data ?? null };
    }
    const refundTrxID = pick(result.data, 'refundTrxId', 'refundTrxID');
    if (!result.ok || pick(result.data, 'refundTransactionStatus', 'transactionStatus') !== 'Completed' || !refundTrxID) {
      return { done: false, message: failureMessage(result, 'bKash did not complete the refund.'), bkash: bkashFields(result) };
    }

    const refunds = [...done, { refundTrxID, amount, reason, at: new Date().toISOString() }];
    const full = left - amount <= 0;
    await prisma.payment.update({ where: { id: pay.id }, data: { status: full ? 'refunded' : 'completed', meta: { ...meta, refunds } } });
    // A full refund ends the pass it bought.
    if (full) await prisma.subscription.updateMany({ where: { providerRef: paymentID, provider: 'bkash' }, data: { status: 'refunded', autoRenew: false } });
    return {
      done: true,
      paymentID,
      originalTrxID: pay.trxId,
      refundTrxID,
      refundAmount: amount,
      refundTransactionStatus: 'Completed',
      completedTime: pick(result.data, 'completedTime') || null,
      fullyRefunded: full,
    };
  });

  r.post('/v1/billing/bkash/refund-status', async (ctx) => {
    requireAdmin(ctx);
    const paymentID = required(ctx.body, 'paymentID', 200);
    const pay = (await prisma.payment.findUnique({ where: { providerRef: paymentID } })) as PayRow | null;
    if (!pay?.trxId) throw badRequest('Unknown or unpaid bKash payment.', 'bad_payment');
    let result: BkashResult;
    try {
      result = await refundStatus(paymentID, pay.trxId);
    } catch (e) {
      if (e instanceof BkashNoResponse) throw new HttpError(502, 'bKash did not answer. Try again in a minute.', 'bkash_unavailable');
      throw e;
    }
    return { ok: result.ok, recorded: refundsOf(pay.meta), bkash: result.data };
  });
}
