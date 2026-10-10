import type { Ctx } from './http';
import { HttpError, unauthorized } from './http';
import { verifyAccessToken } from './tokens';
import { prisma } from '../db';

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

/** A password can't be reset or changed again for this long. */
export const PASSWORD_COOLDOWN_HOURS = 48;

/**
 * Throws 429 (code "password_change_too_soon", with retryAt) when the
 * password was set (registration, reset or change) less than 48 hours ago.
 */
export function assertPasswordChangeAllowed(u: { passwordChangedAt: Date | null; createdAt: Date }): void {
  const last = u.passwordChangedAt ?? u.createdAt;
  const retryAt = new Date(last.getTime() + PASSWORD_COOLDOWN_HOURS * 3600 * 1000);
  const left = retryAt.getTime() - Date.now();
  if (left <= 0) return;
  const hours = Math.max(1, Math.ceil(left / 3600000));
  throw new HttpError(
    429,
    `For your security, the password can only be changed once every ${PASSWORD_COOLDOWN_HOURS} hours. ` +
      `Try again in about ${hours} hour${hours === 1 ? '' : 's'}.`,
    'password_change_too_soon',
    { retryAt: retryAt.toISOString() },
  );
}
