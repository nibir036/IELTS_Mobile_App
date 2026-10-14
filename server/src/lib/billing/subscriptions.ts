// Pro passes on the account: buying one adds its days after any pass still
// running (an upgrade never loses days). isPro() (lib/users.ts) is true while
// any active pass covers now.

import { prisma } from '../../db';
import { env } from '../../env';
import { sendSms } from '../sms';
import { passById, passes, type Pass } from './passes';

const DAY = 86_400_000;

type Sub = {
  id: string;
  passId: string | null;
  provider: string | null;
  providerRef: string | null;
  startedAt: Date | null;
  renewsAt: Date | null;
  autoRenew: boolean;
  amount: number | null;
  renewalNoticeAt?: Date | null;
};

async function ensureProPlan(): Promise<void> {
  await prisma.plan.upsert({
    where: { id: 'pro' },
    create: { id: 'pro', name: 'Pro', priceMonthly: 0, priceYearly: 0, sortOrder: 1 },
    update: {},
  });
}

/** Passes still running or still to come, earliest first. */
async function liveRows(userId: string): Promise<Sub[]> {
  return (await prisma.subscription.findMany({
    where: { userId, status: 'active', renewsAt: { gt: new Date() } },
    orderBy: { startedAt: 'asc' },
  })) as Sub[];
}

/** Adds [pass] to the account, after any pass still running. */
export async function grantPass(p: {
  userId: string;
  pass: Pass;
  provider: 'bkash' | 'google_play';
  providerRef: string;
  amount: number;
  autoRenew: boolean;
}): Promise<{ startedAt: Date; endsAt: Date }> {
  await ensureProPlan();
  const rows = await liveRows(p.userId);
  const now = new Date();
  const lastEnd = rows.reduce((m, r) => (r.renewsAt && r.renewsAt > m ? r.renewsAt : m), now);
  const startedAt = lastEnd;
  const endsAt = new Date(startedAt.getTime() + p.pass.days * DAY);
  await prisma.subscription.create({
    data: {
      userId: p.userId,
      planId: 'pro',
      period: p.pass.id,
      status: 'active',
      startedAt,
      renewsAt: endsAt,
      provider: p.provider,
      providerRef: p.providerRef,
      passId: p.pass.id,
      amount: p.amount,
      currency: 'BDT',
      autoRenew: p.autoRenew,
    },
  });
  // Auto-renewal follows the newest website pass.
  if (p.provider === 'bkash') {
    await prisma.subscription.updateMany({
      where: { userId: p.userId, provider: 'bkash', status: 'active', NOT: { providerRef: p.providerRef } },
      data: { autoRenew: false },
    });
  }
  return { startedAt, endsAt };
}

export interface BillingSummary {
  currency: 'BDT';
  /** The pass covering now (null on Free). */
  current: null | {
    passId: string;
    name: string;
    days: number;
    /** First day of the unbroken run of passes covering now. */
    startedAt: string;
    /** When Pro ends (after any passes queued behind this one). */
    endsAt: string;
    /** google_play | bkash */
    paidWith: string;
    /** Website passes only. */
    autoRenew: boolean;
    queued: Array<{ passId: string; name: string; startsAt: string; endsAt: string }>;
  };
  paymentMethod: null | { provider: string; label: string };
  /** Highest pass the account holds (to offer an upgrade below it). */
  highestPassId: string | null;
  canUpgrade: boolean;
  /** Website: the pass ends soon and auto-renewal is on (confirm with the PIN). */
  renewalDue: boolean;
}

export async function billingSummary(userId: string): Promise<BillingSummary> {
  const [rows, list, method] = await Promise.all([
    liveRows(userId),
    passes(),
    prisma.paymentMethod.findFirst({ where: { userId, revokedAt: null }, orderBy: { createdAt: 'desc' } }) as Promise<{
      provider: string;
      label: string;
    } | null>,
  ]);
  const top = list.length ? list[list.length - 1] : null;
  const rank = (id: string | null) => list.findIndex((p) => p.id === id);
  const now = Date.now();
  const current = rows.find((r) => r.startedAt && r.startedAt.getTime() <= now) ?? null;
  let summary: BillingSummary['current'] = null;
  if (current) {
    const pass = list.find((p) => p.id === current.passId);
    // The unbroken chain: from the running pass's start to the last end.
    const chainStart = current.startedAt!;
    const last = rows[rows.length - 1];
    summary = {
      passId: current.passId ?? '',
      name: pass?.name ?? 'Pro',
      days: pass?.days ?? 0,
      startedAt: chainStart.toISOString(),
      endsAt: (last.renewsAt ?? current.renewsAt!).toISOString(),
      paidWith: current.provider ?? '',
      autoRenew: last.provider === 'bkash' && last.autoRenew,
      queued: rows
        .filter((r) => r !== current)
        .map((r) => ({
          passId: r.passId ?? '',
          name: list.find((p) => p.id === r.passId)?.name ?? 'Pro',
          startsAt: r.startedAt!.toISOString(),
          endsAt: r.renewsAt!.toISOString(),
        })),
    };
  }
  const highest = rows.reduce<string | null>((best, r) => (rank(r.passId) > rank(best) ? r.passId : best), null);
  const last = rows[rows.length - 1];
  return {
    currency: 'BDT',
    current: summary,
    paymentMethod: method ? { provider: method.provider, label: method.label } : null,
    highestPassId: highest,
    canUpgrade: Boolean(top) && highest !== top!.id,
    renewalDue: Boolean(
      last && last.provider === 'bkash' && last.autoRenew && method && last.renewsAt && last.renewsAt.getTime() - now < env.renewalNoticeHours * 3_600_000,
    ),
  };
}

/** Turns auto-renewal of the newest website pass on or off. */
export async function setAutoRenew(userId: string, on: boolean): Promise<void> {
  const rows = (await liveRows(userId)).filter((r) => r.provider === 'bkash');
  const last = rows[rows.length - 1];
  if (!last) return;
  await prisma.subscription.update({ where: { id: last.id }, data: { autoRenew: on, renewalNoticeAt: null } });
}

/** The pass to renew: the newest website pass with auto-renewal on. */
export async function renewalPass(userId: string): Promise<Pass | null> {
  const rows = (await liveRows(userId)).filter((r) => r.provider === 'bkash');
  const last = rows[rows.length - 1];
  return last?.passId ? passById(last.passId) : null;
}

/**
 * Website passes about to end with auto-renewal on: ask the student (in the
 * app/website notifications and by SMS) to confirm the renewal with their
 * bKash PIN. Runs every hour; each pass is reminded once.
 */
export async function remindRenewals(): Promise<number> {
  const soon = new Date(Date.now() + env.renewalNoticeHours * 3_600_000);
  const due = (await prisma.subscription.findMany({
    where: { provider: 'bkash', status: 'active', autoRenew: true, renewalNoticeAt: null, renewsAt: { gt: new Date(), lte: soon } },
    select: { id: true, userId: true, renewsAt: true, passId: true },
  })) as Array<{ id: string; userId: string; renewsAt: Date; passId: string | null }>;
  let n = 0;
  for (const s of due) {
    // Only the newest pass, and only with a saved wallet.
    const later = await prisma.subscription.findFirst({
      where: { userId: s.userId, status: 'active', renewsAt: { gt: s.renewsAt } },
      select: { id: true },
    });
    const method = await prisma.paymentMethod.findFirst({ where: { userId: s.userId, revokedAt: null }, select: { id: true } });
    await prisma.subscription.update({ where: { id: s.id }, data: { renewalNoticeAt: new Date() } });
    if (later || !method) continue;
    const pass = s.passId ? await passById(s.passId) : null;
    const link = `${env.websiteUrl}/app/profile/billing?renew=1`;
    await prisma.notification.create({
      data: {
        userId: s.userId,
        type: 'billing',
        title: 'Your Pro pass ends soon',
        // Shown in the app too: no payment method or website named here (store rules).
        body: `Your ${pass?.name ?? 'Pro'} pass ends on ${s.renewsAt.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', timeZone: 'Asia/Dhaka' })}.`,
        target: '/home/plans',
      },
    });
    const user = (await prisma.user.findUnique({ where: { id: s.userId }, select: { phone: true } })) as { phone?: string } | null;
    if (user?.phone) {
      await sendSms(user.phone, `${env.smsBrand}: your Pro pass ends soon. Confirm the renewal with your bKash PIN: ${link}`).catch((e) =>
        console.error('[billing] renewal SMS failed', e),
      );
    }
    n++;
  }
  return n;
}
