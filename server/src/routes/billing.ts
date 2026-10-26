// Pro passes: the plan the student holds, Google Play purchases (app) and
// bKash checkout with a saved wallet for renewals (website).
//
//   GET    /v1/billing                      plan, dates, payment method, upgrade
//   PATCH  /v1/billing                      {autoRenew}
//   DELETE /v1/billing/payment-method       forget the saved bKash wallet
//   POST   /v1/billing/google/verify        {productId, purchaseToken}
//   POST   /v1/billing/google/rtdn?token=   Play notifications (refunds)
//   POST   /v1/billing/bkash/start          {passId, autoRenew, callbackURL} → {bkashURL}
//   POST   /v1/billing/bkash/save-method    {callbackURL} → {bkashURL}
//   POST   /v1/billing/bkash/callback       {paymentID, status} → {done} | {next: bkashURL}

import { createHash, timingSafeEqual } from 'node:crypto';
import { prisma } from '../db';
import { env } from '../env';
import { badRequest, forbidden, HttpError, rateLimit, required, Router, s } from '../lib/http';
import { requireUser } from '../lib/users';
import { bkashConfigured, bkashError, cancelAgreement, createAgreement, createPayment, execute, maskWallet, paymentStatus } from '../lib/billing/bkash';
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

/** Starts a bKash payment for [passId] and logs it. */
async function startPayment(userId: string, passId: string, autoRenew: boolean, callbackURL: string, agreementID?: string) {
  const pass = await passById(passId);
  if (!pass) throw badRequest('Unknown pass.', 'bad_pass');
  const invoice = `IA${Date.now().toString(36).toUpperCase()}`;
  const created = await createPayment({ amount: pass.webPrice, invoice, payerReference: await phoneOf(userId), callbackURL, agreementID });
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
      meta: { autoRenew, invoice, agreement: Boolean(agreementID) },
    },
  });
  return created.bkashURL;
}

export function registerBillingRoutes(r: Router): void {
  r.get('/v1/billing', async (ctx) => {
    const userId = requireUser(ctx);
    return { ...(await billingSummary(userId)), playAccountId: playAccountId(userId), bkash: bkashConfigured() };
  });

  r.patch('/v1/billing', async (ctx) => {
    const userId = requireUser(ctx);
    if (typeof ctx.body.autoRenew === 'boolean') {
      if (ctx.body.autoRenew && !(await savedAgreement(userId))) {
        throw badRequest('Save a bKash wallet first to turn on auto-renewal.', 'no_payment_method');
      }
      await setAutoRenew(userId, ctx.body.autoRenew);
    }
    return billingSummary(userId);
  });

  r.delete('/v1/billing/payment-method', async (ctx) => {
    const userId = requireUser(ctx);
    const m = await savedAgreement(userId);
    if (m) {
      await cancelAgreement(m.token);
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
    const autoRenew = ctx.body.autoRenew !== false;
    const cb = callbackUrl(ctx.body.callbackURL);
    if (!(await passById(passId))) throw badRequest('Unknown pass.', 'bad_pass');
    const saved = await savedAgreement(userId);
    if (saved) return { bkashURL: await startPayment(userId, passId, autoRenew, cb, saved.token) };
    if (!autoRenew) return { bkashURL: await startPayment(userId, passId, false, cb) };
    // Auto-renewal on: save the wallet first (agreement), then pay with it.
    const created = await createAgreement(await phoneOf(userId), cb);
    await prisma.payment.create({
      data: { userId, provider: 'bkash', providerRef: created.paymentID, kind: 'agreement', passId, status: 'initiated', meta: { autoRenew: true, callbackURL: cb } },
    });
    return { bkashURL: created.bkashURL };
  });

  r.post('/v1/billing/bkash/save-method', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`bkash-start:${userId}`, 20, 3600);
    const cb = callbackUrl(ctx.body.callbackURL);
    const created = await createAgreement(await phoneOf(userId), cb);
    await prisma.payment.create({
      data: { userId, provider: 'bkash', providerRef: created.paymentID, kind: 'agreement', status: 'initiated', meta: { saveOnly: true } },
    });
    return { bkashURL: created.bkashURL };
  });

  r.post('/v1/billing/bkash/callback', async (ctx) => {
    const userId = requireUser(ctx);
    const paymentID = required(ctx.body, 'paymentID', 200);
    const status = s(ctx.body.status, 20).toLowerCase();
    const pay = (await prisma.payment.findUnique({ where: { providerRef: paymentID } })) as {
      id: string;
      userId: string;
      kind: string;
      passId: string | null;
      status: string;
      meta: Row | null;
    } | null;
    if (!pay || pay.userId !== userId) throw badRequest('Unknown payment.', 'bad_payment');
    const meta = pay.meta ?? {};
    if (pay.status === 'completed') return { done: true, billing: await billingSummary(userId) };
    if (status !== 'success') {
      await prisma.payment.update({ where: { id: pay.id }, data: { status: status === 'cancel' ? 'cancelled' : 'failed' } });
      return { done: false, message: status === 'cancel' ? 'You cancelled the bKash payment.' : 'The bKash payment did not go through.' };
    }

    let result: Row;
    try {
      result = await execute(paymentID);
    } catch (e) {
      // Execute may time out after bKash took the money: ask for the status.
      if (pay.kind !== 'agreement') result = await paymentStatus(paymentID);
      else throw e;
    }
    const err = bkashError(result);

    if (pay.kind === 'agreement') {
      if (err || !result.agreementID || String(result.agreementStatus ?? '') !== 'Completed') {
        await prisma.payment.update({ where: { id: pay.id }, data: { status: 'failed', meta: { ...meta, error: err } } });
        return { done: false, message: err ?? 'bKash could not save your wallet.' };
      }
      const agreementID = String(result.agreementID);
      await prisma.paymentMethod.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } });
      await prisma.paymentMethod.create({
        data: { userId, provider: 'bkash', token: agreementID, label: `bKash ${maskWallet(String(result.customerMsisdn ?? ''))}` },
      });
      await prisma.payment.update({ where: { id: pay.id }, data: { status: 'completed' } });
      if (meta.saveOnly) {
        await setAutoRenew(userId, true);
        return { done: true, billing: await billingSummary(userId) };
      }
      // Now the payment itself, with the saved wallet (PIN only).
      const next = await startPayment(userId, pay.passId ?? '', true, callbackUrl(meta.callbackURL), agreementID);
      return { done: false, next };
    }

    const trxID = String(result.trxID ?? '');
    if (err || String(result.transactionStatus ?? '') !== 'Completed' || !trxID) {
      await prisma.payment.update({ where: { id: pay.id }, data: { status: 'failed', meta: { ...meta, error: err } } });
      return { done: false, message: err ?? 'The bKash payment did not go through.' };
    }
    const pass = await passById(pay.passId ?? '');
    if (!pass) throw new HttpError(500, 'The pass for this payment no longer exists. Contact support.', 'bad_pass');
    // Claim the payment first, so a double callback can't grant twice.
    const claimed = await prisma.payment.updateMany({ where: { id: pay.id, status: 'initiated' }, data: { status: 'completed', trxId: trxID } });
    if (claimed.count === 1) {
      await grantPass({ userId, pass, provider: 'bkash', providerRef: paymentID, amount: Number(result.amount) || pass.webPrice, autoRenew: meta.autoRenew === true });
    }
    return { done: true, trxID, billing: await billingSummary(userId) };
  });
}
