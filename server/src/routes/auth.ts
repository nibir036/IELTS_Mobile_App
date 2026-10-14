// Accounts: phone + password, phone verified by OTP (Alpha SMS), token
// sessions for the app (short access token + rotating refresh token).

import { prisma } from '../db';
import { env } from '../env';
import { hashPassword, verifyPassword } from '../lib/password';
import { badRequest, HttpError, rateLimit, required, Router, s, unauthorized, type Ctx } from '../lib/http';
import { createOtp, verifyOtp, verifyProof, type OtpPurpose } from '../lib/otp';
import { demoLoginId, isStrongPassword, isValidPhone, normalizePhone } from '../lib/phone';
import { sendSms } from '../lib/sms';
import { hashToken, newRefreshToken, signAccessToken } from '../lib/tokens';
import { assertPasswordChangeAllowed, publicUser, userSelect } from '../lib/users';
import { admitDevice, deviceOf, endOtherSessions, sessionEndedError } from '../lib/devices';

function purposeOf(v: unknown): OtpPurpose {
  const p = s(v) || 'signup';
  if (p !== 'signup' && p !== 'reset') throw badRequest('purpose must be "signup" or "reset".');
  return p;
}

function phoneOf(body: Record<string, unknown>): string {
  const raw = required(body, 'phone', 30);
  if (!isValidPhone(raw)) throw badRequest('Enter a valid Bangladeshi mobile number.', 'invalid_phone');
  return normalizePhone(raw);
}

/**
 * Creates a session on the calling device and returns the token pair + user.
 * The device must be allowed (at most 2 per account; a further one is
 * locked for 48 hours), and the account's other sessions end: one signed-in
 * screen at a time. [recover] = after an OTP-proved password reset.
 */
export async function issueSession(ctx: Ctx, userId: string, opts: { recover?: boolean } = {}) {
  // The shared demo account (testing / store review) has no device limits.
  const demo = (await prisma.user.findUnique({ where: { id: userId }, select: { isDemo: true } }))?.isDemo === true;
  const deviceId = demo ? null : await admitDevice(userId, deviceOf(ctx), ctx.ip, opts);
  const refreshToken = newRefreshToken();
  const session = await prisma.session.create({
    data: {
      userId,
      deviceId,
      tokenHash: hashToken(refreshToken),
      userAgent: s(ctx.req.headers['user-agent'], 300) || null,
      expiresAt: new Date(Date.now() + env.refreshTokenDays * 86400_000),
    },
    select: { id: true, expiresAt: true },
  });
  if (!demo) await endOtherSessions(userId, session.id, 'signed_in_elsewhere');
  const access = signAccessToken(userId, session.id);
  const user = await prisma.user.findUnique({ where: { id: userId }, select: userSelect });
  if (!user) throw unauthorized();
  return {
    user: publicUser(user),
    accessToken: access.token,
    accessTokenExpiresAt: access.expiresAt.toISOString(),
    refreshToken,
    refreshTokenExpiresAt: session.expiresAt.toISOString(),
  };
}

/** The welcome SMS (env WELCOME_SMS), in the background: sign-up never waits for or fails on it. */
function sendWelcomeSms(phone: string): void {
  try {
    const text = String(env.welcomeSms ?? '').trim();
    if (!text || text.toLowerCase() === 'off') return;
    const site = String(env.websiteUrl ?? '').replace(/^https?:\/\//, '');
    sendSms(phone, text.replace(/\{site\}/g, site)).catch((e) => console.error('[auth] welcome SMS failed', e));
  } catch (e) {
    console.error('[auth] welcome SMS failed', e);
  }
}

export function registerAuthRoutes(r: Router): void {
  // Send a 6-digit code. purpose "signup" needs a new number, "reset" an existing one.
  r.post('/v1/auth/otp/send', async (ctx) => {
    const phone = phoneOf(ctx.body);
    const purpose = purposeOf(ctx.body.purpose);
    rateLimit(`otp-ip:${ctx.ip}`, 10, 3600);
    const exists = await prisma.user.findUnique({ where: { phone }, select: { id: true } });
    if (purpose === 'signup' && exists) {
      throw new HttpError(409, 'An account with this number already exists. Log in instead.', 'phone_taken');
    }
    if (purpose === 'reset' && !exists) {
      throw new HttpError(404, 'No account uses this number.', 'no_account');
    }
    // No SMS when the password was set less than 48 hours ago.
    if (purpose === 'reset' && exists) {
      const u = await prisma.user.findUnique({ where: { phone }, select: { passwordChangedAt: true, createdAt: true } });
      if (u) assertPasswordChangeAllowed(u);
    }
    const code = await createOtp(phone, purpose);
    await sendSms(phone, `Your ${env.smsBrand} verification code is ${code}. It expires in 5 minutes.`);
    return {
      sent: true,
      expiresInSec: 300,
      resendAfterSec: 45,
      // Development only (SMS_PROVIDER=console): the code, so testing needs no phone.
      ...(env.smsProvider !== 'alpha' && !env.isProd ? { devCode: code } : {}),
    };
  });

  r.post('/v1/auth/otp/verify', async (ctx) => {
    const phone = phoneOf(ctx.body);
    const purpose = purposeOf(ctx.body.purpose);
    const code = required(ctx.body, 'code', 10).replace(/\D/g, '');
    rateLimit(`otp-verify:${phone}`, 20, 3600);
    const proof = await verifyOtp(phone, code, purpose);
    return { verified: true, proof };
  });

  r.post('/v1/auth/register', async (ctx) => {
    const phone = phoneOf(ctx.body);
    const name = required(ctx.body, 'name', 80);
    const password = required(ctx.body, 'password', 200);
    const proof = required(ctx.body, 'proof', 500);
    if (!isStrongPassword(password)) {
      throw badRequest('Use 8+ characters with at least one number and one symbol.', 'weak_password');
    }
    if (!verifyProof(proof, phone, 'signup')) {
      throw badRequest('Phone verification expired. Verify your number again.', 'otp_required');
    }
    const exists = await prisma.user.findUnique({ where: { phone }, select: { id: true } });
    if (exists) throw new HttpError(409, 'An account with this number already exists.', 'phone_taken');
    const profile = s(ctx.body.email, 200) ? { email: s(ctx.body.email, 200) } : {};
    const user = await prisma.user.create({
      data: {
        name,
        phone,
        passwordHash: hashPassword(password),
        passwordChangedAt: new Date(),
        phoneVerifiedAt: new Date(),
        profile: { plan: 'Free', testType: 'Academic', ...profile },
      },
      select: { id: true },
    });
    sendWelcomeSms(phone);
    return issueSession(ctx, user.id);
  });

  r.post('/v1/auth/login', async (ctx) => {
    // "Demo 1" … "Demo 4": the shared Pro demo accounts (no phone number).
    const demoId = demoLoginId(s(ctx.body.phone, 30));
    const phone = demoId ?? phoneOf(ctx.body);
    const password = required(ctx.body, 'password', 200);
    rateLimit(`login:${phone}`, demoId ? 60 : 10, 900);
    const user = (await prisma.user.findUnique({ where: { phone }, select: { id: true, passwordHash: true, isDemo: true } })) as {
      id: string;
      passwordHash: string;
      isDemo: boolean;
    } | null;
    if (!user || (demoId && !user.isDemo)) {
      throw new HttpError(404, demoId ? 'This demo account is not set up yet.' : 'No account uses this number. Sign up first.', 'no_account');
    }
    if (!verifyPassword(password, user.passwordHash)) {
      throw new HttpError(401, 'Wrong password.', 'wrong_password');
    }
    return issueSession(ctx, user.id);
  });

  // Swap a refresh token for a new pair (the old refresh token stops working).
  r.post('/v1/auth/refresh', async (ctx) => {
    const token = required(ctx.body, 'refreshToken', 200);
    const session = await prisma.session.findUnique({ where: { tokenHash: hashToken(token) } });
    if (!session || session.revokedAt || session.expiresAt.getTime() < Date.now()) {
      throw session?.revokedAt ? sessionEndedError(session.revokeReason) : unauthorized('Your session has ended. Please log in again.', 'session_ended');
    }
    const next = newRefreshToken();
    await prisma.session.update({
      where: { id: session.id },
      data: { tokenHash: hashToken(next), lastUsedAt: new Date() },
    });
    if (session.deviceId) {
      await prisma.device.updateMany({
        where: { id: session.deviceId },
        data: { lastSeenAt: new Date(), lastIp: ctx.ip || null },
      });
    }
    const access = signAccessToken(session.userId, session.id);
    const user = await prisma.user.findUnique({ where: { id: session.userId }, select: userSelect });
    if (!user) throw unauthorized();
    return {
      user: publicUser(user),
      accessToken: access.token,
      accessTokenExpiresAt: access.expiresAt.toISOString(),
      refreshToken: next,
      refreshTokenExpiresAt: session.expiresAt.toISOString(),
    };
  });

  r.post('/v1/auth/logout', async (ctx) => {
    const token = s(ctx.body.refreshToken, 200);
    if (token) {
      await prisma.session.updateMany({
        where: { tokenHash: hashToken(token), revokedAt: null },
        data: { revokedAt: new Date(), revokeReason: 'logout' },
      });
    }
    return { ok: true };
  });

  // "Use it here": a device that was signed out because the account was
  // opened on the other device takes it back (no password needed: it is
  // one of the account's registered devices). The other device is signed out.
  r.post('/v1/auth/takeover', async (ctx) => {
    const token = required(ctx.body, 'refreshToken', 200);
    rateLimit(`takeover:${ctx.ip}`, 30, 3600);
    const session = await prisma.session.findUnique({ where: { tokenHash: hashToken(token) } });
    if (
      !session ||
      session.revokeReason !== 'signed_in_elsewhere' ||
      session.expiresAt.getTime() < Date.now() ||
      !session.deviceId
    ) {
      throw unauthorized('Please log in again.', 'session_ended');
    }
    const device = await prisma.device.findFirst({ where: { id: session.deviceId, userId: session.userId } });
    if (!device || device.status !== 'active' || device.deviceKey !== deviceOf(ctx).key) {
      throw unauthorized('Please log in again.', 'session_ended');
    }
    // The old token can't be used twice.
    await prisma.session.update({ where: { id: session.id }, data: { revokeReason: 'taken_over' } });
    return issueSession(ctx, session.userId);
  });

  // Forgot password: verify the phone with purpose "reset", then set a new one.
  r.post('/v1/auth/reset-password', async (ctx) => {
    const phone = phoneOf(ctx.body);
    const password = required(ctx.body, 'password', 200);
    const proof = required(ctx.body, 'proof', 500);
    if (!isStrongPassword(password)) {
      throw badRequest('Use 8+ characters with at least one number and one symbol.', 'weak_password');
    }
    if (!verifyProof(proof, phone, 'reset')) {
      throw badRequest('Phone verification expired. Verify your number again.', 'otp_required');
    }
    const user = await prisma.user.findUnique({
      where: { phone },
      select: { id: true, passwordChangedAt: true, createdAt: true },
    });
    if (!user) throw new HttpError(404, 'No account uses this number.', 'no_account');
    assertPasswordChangeAllowed(user);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: hashPassword(password), passwordChangedAt: new Date() },
    });
    // Sign out every device.
    await prisma.session.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date(), revokeReason: 'password_reset' },
    });
    // The OTP proved the phone number: a full account makes room for this device.
    return issueSession(ctx, user.id, { recover: true });
  });
}
