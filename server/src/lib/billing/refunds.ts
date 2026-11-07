// Sending money back for a website (bKash) payment, used by the refund
// requests (routes/refunds.ts, /admin/refunds) and the admin refund call
// (POST /v1/billing/bkash/refund). Uses the stored bKash token (bkash.ts).
//
// A full refund ends the pass the payment bought; a partial one keeps it.
// If bKash gives no answer, nothing is retried (that could refund twice):
// the caller gets bKash's refund status to check first.

import { prisma } from '../../db';
import { badRequest } from '../http';
import { BkashNoResponse, failureMessage, pick, refundPayment, refundStatus, type BkashResult } from './bkash';

type Row = Record<string, unknown>;

/** Students may ask for a refund this many days after paying. */
export const REFUND_WINDOW_DAYS = 7;

/** One refund already sent, as kept in the payment's meta. */
export type SentRefund = { refundTrxID: string; amount: number; reason: string; at: string };

/** The bKash payment being refunded (a row of `payments`). */
export interface PaidPayment {
  id: string;
  providerRef: string;
  provider: string;
  kind: string;
  amount: number | null;
  status: string;
  trxId: string | null;
  meta: Row | null;
}

export function refundsOf(meta: Row | null): SentRefund[] {
  return Array.isArray(meta?.refunds) ? (meta!.refunds as SentRefund[]) : [];
}

/** BDT that can still be sent back for [pay]. */
export function refundableLeft(pay: PaidPayment): number {
  return Math.max(0, (pay.amount ?? 0) - refundsOf(pay.meta).reduce((n, r) => n + r.amount, 0));
}

export type RefundOutcome =
  | { ok: true; refundTrxID: string; amount: number; fullyRefunded: boolean; completedTime: string | null }
  | { ok: false; noResponse: true; message: string; refundStatus: Row | null }
  | { ok: false; noResponse: false; message: string };

/**
 * Asks bKash to send [amount] (default: everything left) back for [pay].
 * Throws badRequest when the payment can't be refunded or the amount is wrong.
 */
export async function refundBkashPayment(pay: PaidPayment, reason: string, amount?: number): Promise<RefundOutcome> {
  if (pay.provider !== 'bkash' || pay.kind !== 'payment') throw badRequest('Only website (bKash) payments can be refunded here.', 'not_refundable');
  if (pay.status !== 'completed' || !pay.trxId) throw badRequest(`Only completed payments can be refunded (this one is ${pay.status}).`, 'not_refundable');
  const left = refundableLeft(pay);
  const value = amount === undefined ? left : amount;
  if (!Number.isInteger(value) || value <= 0 || value > left) throw badRequest(`The refund must be a whole number of taka, more than 0 and at most ${left}.`, 'bad_amount');

  let result: BkashResult;
  try {
    result = await refundPayment({ paymentID: pay.providerRef, trxID: pay.trxId, amount: value, reason });
  } catch (e) {
    if (!(e instanceof BkashNoResponse)) throw e;
    const st = await refundStatus(pay.providerRef, pay.trxId).catch(() => null);
    return {
      ok: false,
      noResponse: true,
      message: 'bKash did not answer the refund. Check the refund status before trying again, so it is not sent twice.',
      refundStatus: st?.data ?? null,
    };
  }
  const refundTrxID = pick(result.data, 'refundTrxId', 'refundTrxID');
  if (!result.ok || pick(result.data, 'refundTransactionStatus', 'transactionStatus') !== 'Completed' || !refundTrxID) {
    return { ok: false, noResponse: false, message: failureMessage(result, 'bKash did not complete the refund.') };
  }

  const full = await recordRefund(pay, refundTrxID, value, reason);
  return { ok: true, refundTrxID, amount: value, fullyRefunded: full, completedTime: pick(result.data, 'completedTime') || null };
}

/**
 * Notes a refund bKash completed on the payment; a full one ends the pass it
 * bought. Returns true when nothing is left to refund.
 */
export async function recordRefund(pay: PaidPayment, refundTrxID: string, amount: number, reason: string): Promise<boolean> {
  const meta = pay.meta ?? {};
  const before = refundsOf(meta);
  if (before.some((r) => r.refundTrxID === refundTrxID)) return refundableLeft(pay) <= 0;
  const refunds = [...before, { refundTrxID, amount, reason, at: new Date().toISOString() }];
  const full = refunds.reduce((n, r) => n + r.amount, 0) >= (pay.amount ?? 0);
  await prisma.payment.update({ where: { id: pay.id }, data: { status: full ? 'refunded' : 'completed', meta: { ...meta, refunds } } });
  if (full) await prisma.subscription.updateMany({ where: { providerRef: pay.providerRef, provider: 'bkash' }, data: { status: 'refunded', autoRenew: false } });
  pay.meta = { ...meta, refunds };
  pay.status = full ? 'refunded' : 'completed';
  return full;
}

/** bKash's record of the refunds already made for [pay] (to check one that got no answer). */
export async function bkashRefunds(pay: PaidPayment): Promise<{ ok: boolean; data: Row }> {
  if (!pay.trxId) throw badRequest('This payment was never completed.', 'bad_payment');
  try {
    const r = await refundStatus(pay.providerRef, pay.trxId);
    return { ok: r.ok, data: r.data };
  } catch (e) {
    if (e instanceof BkashNoResponse) throw badRequest('bKash did not answer. Try again in a minute.', 'bkash_unavailable');
    throw e;
  }
}
