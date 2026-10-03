import type { Ctx } from './http';
import { forbidden, unauthorized } from './http';
import { verifyAccessToken } from './tokens';
import { prisma } from '../db';
import { env } from '../env';

/** Reads the Bearer token and sets ctx.userId (401 if missing/invalid). */
export function requireUser(ctx: Ctx): string {
  const h = ctx.req.headers.authorization || '';
  const m = /^Bearer\s+(.+)$/i.exec(h);
  if (!m) throw unauthorized('Please log in.', 'no_token');
  const claims = verifyAccessToken(m[1].trim());
  if (!claims) throw unauthorized('Your session has expired. Please log in again.', 'token_expired');
  ctx.userId = claims.sub;
  return claims.sub;
}

export type Skill = 'writing' | 'speaking';

/** Pro = an active subscription (or the demo account's Pro profile). */
export async function isPro(userId: string): Promise<boolean> {
  const now = new Date();
  const sub = await prisma.subscription.findFirst({
    where: {
      userId,
      status: 'active',
      OR: [{ renewsAt: null }, { renewsAt: { gt: now } }],
    },
    select: { id: true },
  });
  if (sub) return true;
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { isDemo: true, profile: true } });
  const plan = String(((user?.profile ?? {}) as Record<string, unknown>).plan ?? '').toLowerCase();
  return Boolean(user?.isDemo && plan === 'pro');
}

/** AI-graded tests used so far (writing tests / speaking sessions). */
export async function usedTests(userId: string, skill: Skill): Promise<number> {
  return prisma.attempt.count({
    where: { userId, skill, data: { path: ['aiGraded'], equals: true } },
  });
}

export async function usage(userId: string) {
  const pro = await isPro(userId);
  const [w, sp] = await Promise.all([usedTests(userId, 'writing'), usedTests(userId, 'speaking')]);
  return {
    plan: pro ? 'pro' : 'free',
    writing: { used: w, limit: pro ? null : env.freeWritingTests },
    speaking: { used: sp, limit: pro ? null : env.freeSpeakingTests },
  };
}

/** Throws 403 (code "quota_reached") when a free account has used its tests. */
export async function checkQuota(userId: string, skill: Skill): Promise<void> {
  if (await isPro(userId)) return;
  const limit = skill === 'writing' ? env.freeWritingTests : env.freeSpeakingTests;
  const used = await usedTests(userId, skill);
  if (used >= limit) {
    throw forbidden(
      `You've used your ${limit} free ${skill} evaluations. Upgrade to Pro for unlimited AI feedback.`,
      'quota_reached',
    );
  }
}

type UserRow = {
  id: string;
  name: string;
  phone: string;
  isDemo: boolean;
  profile: unknown;
  phoneVerifiedAt: Date | null;
  createdAt: Date;
};

/** What the app sees about the signed-in student. */
export function publicUser(u: UserRow) {
  return {
    id: u.id,
    name: u.name,
    phone: u.phone,
    isDemo: u.isDemo,
    profile: (u.profile ?? {}) as Record<string, unknown>,
    phoneVerified: Boolean(u.phoneVerifiedAt),
    createdAt: u.createdAt.toISOString(),
  };
}

export const userSelect = {
  id: true,
  name: true,
  phone: true,
  isDemo: true,
  profile: true,
  phoneVerifiedAt: true,
  createdAt: true,
} as const;
