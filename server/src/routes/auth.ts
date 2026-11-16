// Accounts: token sessions for the app (short access token + rotating
// refresh token), and two ways to sign up, chosen by country
// (lib/countries.ts):
//
//   Bangladesh  phone + password, phone verified by a code by SMS (Alpha SMS)
//   Gulf (GCC)  email + password, email verified by a code by email (Brevo)
//
// Every route below takes either {phone} or {email}; login also takes
// {login} (whatever the student typed: a number, an email or "Demo 1").

import { prisma } from '../db';
import { env } from '../env';
import { hashPassword, verifyPassword } from '../lib/password';
import { badRequest, HttpError, rateLimit, required, Router, s, unauthorized, type Ctx } from '../lib/http';
import { createOtp, verifyOtp, verifyProof, type OtpPurpose } from '../lib/otp';
import { demoLoginId, isStrongPassword, isValidPhone, normalizePhone } from '../lib/phone';
import { sendSms } from '../lib/sms';
import { COUNTRIES, countryOf } from '../lib/countries';
import { normalizeEmail, sendCodeEmail } from '../lib/email';
import { hashToken, newRefreshToken, signAccessToken } from '../lib/tokens';
import { assertPasswordChangeAllowed, publicUser, userSelect } from '../lib/users';
import { admitDevice, deviceOf, endOtherSessions, sessionEndedError } from '../lib/devices';

function purposeOf(v: unknown): OtpPurpose {
  const p = s(v) || 'signup';
  if (p !== 'signup' && p !== 'reset') throw badRequest('purpose must be "signup" or "reset".');
  return p;
}

/** Who a code / login is for: a Bangladeshi phone or an email address. */
type Who =
  | { kind: 'phone'; phone: string; key: string; label: string }
  | { kind: 'email'; email: string; key: string; label: string };

function phoneOf(raw: string): string {
  if (!isValidPhone(raw)) throw badRequest('Enter a valid Bangladeshi mobile number.', 'invalid_phone');
  return normalizePhone(raw);
}

function emailOf(raw: string): string {
  const email = normalizeEmail(raw);
  if (!email) throw badRequest('Enter a valid email address.', 'invalid_email');
  return email;
}

/**
 * {phone} or {email} from the body. A phone wins when both are sent (a
 * Bangladeshi sign-up may add an email for the profile). The OTP key of an
 * email is "email:<address>".
 */
function whoOf(body: Record<string, unknown>): Who {
  const rawPhone = s(body.phone, 30);
  const rawEmail = s(body.email, 200);
  if (!rawPhone && rawEmail) {
    const email = emailOf(rawEmail);
    return { kind: 'email', email, key: `email:${email}`, label: 'email' };
  }
  const phone = phoneOf(required(body, 'phone', 30));
  return { kind: 'phone', phone, key: phone, label: 'number' };
}

const whereOf = (who: Who) => (who.kind === 'email' ? { email: who.email } : { phone: who.phone });

/** Codes are printed (and returned to the app) only while developing. */
function devCodeAllowed(who: Who): boolean {
  if (env.isProd) return false;
  return who.kind === 'email' ? env.emailProvider !== 'brevo' : env.smsProvider !== 'alpha';
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
  // Where students can sign up and how (the app's and the portal's first screen).
  r.get('/v1/auth/countries', async () => ({
    countries: COUNTRIES.map((c) => ({ code: c.code, name: c.name, dial: c.dial, channel: c.channel })),
  }));

  // Send a 6-digit code by SMS ({phone}) or by email ({email}).
  // purpose "signup" needs a new number / address, "reset" an existing one.
  r.post('/v1/auth/otp/send', async (ctx) => {
    const who = whoOf(ctx.body);
    const purpose = purposeOf(ctx.body.purpose);
    rateLimit(`otp-ip:${ctx.ip}`, 10, 3600);
    rateLimit(`otp-day:${who.key}`, 8, 86400);
    rateLimit('otp-global', 1500, 3600);
    const exists = await prisma.user.findUnique({
      where: whereOf(who),
      select: { id: true, passwordChangedAt: true, createdAt: true },
    });
    if (purpose === 'signup' && exists) {
      throw who.kind === 'email'
        ? new HttpError(409, 'An account with this email already exists. Log in instead.', 'email_taken')
        : new HttpError(409, 'An account with this number already exists. Log in instead.', 'phone_taken');
    }
    if (purpose === 'reset' && !exists) {
      throw new HttpError(404, `No account uses this ${who.label}.`, 'no_account');
    }
    // No code when the password was set less than 48 hours ago.
    if (purpose === 'reset' && exists) assertPasswordChangeAllowed(exists);
    const code = await createOtp(who.key, purpose);
    if (who.kind === 'email') {
      await sendCodeEmail(who.email, code, purpose);
    } else {
      await sendSms(who.phone, `Your ${env.smsBrand} verification code is ${code}. It expires in 5 minutes.`);
    }
    return {
      sent: true,
      channel: who.kind,
      expiresInSec: 300,
      resendAfterSec: 45,
      // Development only (SMS_PROVIDER / EMAIL_PROVIDER = console): the code,
      // so testing needs no phone or inbox.
      ...(devCodeAllowed(who) ? { devCode: code } : {}),
    };
  });

  r.post('/v1/auth/otp/verify', async (ctx) => {
    const who = whoOf(ctx.body);
    const purpose = purposeOf(ctx.body.purpose);
    const code = required(ctx.body, 'code', 10).replace(/\D/g, '');
    rateLimit(`otp-verify:${who.key}`, 20, 3600);
    const proof = await verifyOtp(who.key, code, purpose);
    return { verified: true, proof };
  });

  // Bangladesh: {phone, name, password, proof}. Gulf: {email, country, name,
  // password, proof}. The proof comes from /otp/verify (purpose "signup").
  r.post('/v1/auth/register', async (ctx) => {
    const who = whoOf(ctx.body);
    const name = required(ctx.body, 'name', 80);
    const password = required(ctx.body, 'password', 200);
    const proof = required(ctx.body, 'proof', 500);
    // Phone sign-up is Bangladesh; email sign-up is one of the Gulf countries.
    const country = countryOf(ctx.body.country ?? (who.kind === 'phone' ? 'BD' : ''));
    if (!country) throw badRequest('Choose your country.', 'invalid_country');
    if ((country.channel === 'email') !== (who.kind === 'email')) {
      throw badRequest(
        country.channel === 'email'
          ? `Students in ${country.name} sign up with their email address.`
          : `Students in ${country.name} sign up with their mobile number.`,
        'wrong_signup_method',
      );
    }
    if (!isStrongPassword(password)) {
      throw badRequest('Use 8+ characters with at least one number and one symbol.', 'weak_password');
    }
    if (!verifyProof(proof, who.key, 'signup')) {
      throw badRequest(
        who.kind === 'email'
          ? 'Email verification expired. Verify your email again.'
          : 'Phone verification expired. Verify your number again.',
        'otp_required',
      );
    }
    const exists = await prisma.user.findUnique({ where: whereOf(who), select: { id: true } });
    if (exists) {
      throw who.kind === 'email'
        ? new HttpError(409, 'An account with this email already exists.', 'email_taken')
        : new HttpError(409, 'An account with this number already exists.', 'phone_taken');
    }
    const now = new Date();
    let user: { id: string };
    if (who.kind === 'email') {
      user = await prisma.user.create({
        data: {
          name,
          email: who.email,
          emailVerifiedAt: now,
          country: country.code,
          passwordHash: hashPassword(password),
          passwordChangedAt: now,
          profile: { plan: 'Free', testType: 'Academic', email: who.email },
        },
        select: { id: true },
      });
    } else {
      // An email given at phone sign-up is kept on the profile (unverified).
      const extra = normalizeEmail(ctx.body.email);
      user = await prisma.user.create({
        data: {
          name,
          phone: who.phone,
          country: country.code,
          passwordHash: hashPassword(password),
          passwordChangedAt: now,
          phoneVerifiedAt: now,
          profile: { plan: 'Free', testType: 'Academic', ...(extra ? { email: extra } : {}) },
        },
        select: { id: true },
      });
      sendWelcomeSms(who.phone);
    }
    return issueSession(ctx, user.id);
  });

  // {login, password}: `login` is a Bangladeshi number, an email address or
  // "Demo 1" … "Demo 4" (the shared Pro demo accounts). The older {phone} and
  // {email} bodies still work.
  r.post('/v1/auth/login', async (ctx) => {
    const raw = s(ctx.body.login, 200) || s(ctx.body.email, 200) || s(ctx.body.phone, 30);
    if (!raw) throw badRequest('Enter your mobile number or email.', 'missing_login');
    const password = required(ctx.body, 'password', 200);
    const demoId = demoLoginId(raw);
    let where: { phone: string } | { email: string };
    let label: string;
    if (demoId) {
      where = { phone: demoId };
      label = 'demo';
    } else if (raw.includes('@')) {
      where = { email: emailOf(raw) };
      label = 'email';
    } else {
      where = { phone: phoneOf(raw) };
      label = 'number';
    }
    rateLimit(`login:${'email' in where ? where.email : where.phone}`, demoId ? 60 : 10, 900);
    const user = (await prisma.user.findUnique({ where, select: { id: true, passwordHash: true, isDemo: true } })) as {
      id: string;
      passwordHash: string;
      isDemo: boolean;
    } | null;
    if (!user || (demoId && !user.isDemo)) {
      throw new HttpError(
        404,
        demoId ? 'This demo account is not set up yet.' : `No account uses this ${label}. Sign up first.`,
        'no_account',
      );
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

  // Forgot password: verify the phone (or email) with purpose "reset", then set a new one.
  r.post('/v1/auth/reset-password', async (ctx) => {
    const who = whoOf(ctx.body);
    const password = required(ctx.body, 'password', 200);
    const proof = required(ctx.body, 'proof', 500);
    if (!isStrongPassword(password)) {
      throw badRequest('Use 8+ characters with at least one number and one symbol.', 'weak_password');
    }
    if (!verifyProof(proof, who.key, 'reset')) {
      throw badRequest(
        who.kind === 'email'
          ? 'Email verification expired. Verify your email again.'
          : 'Phone verification expired. Verify your number again.',
        'otp_required',
      );
    }
    const user = await prisma.user.findUnique({
      where: whereOf(who),
      select: { id: true, passwordChangedAt: true, createdAt: true },
    });
    if (!user) throw new HttpError(404, `No account uses this ${who.label}.`, 'no_account');
    assertPasswordChangeAllowed(user);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: hashPassword(password), passwordChangedAt: new Date() },
    });
    // Sign out every device, and stop sessions that were signed out earlier
    // ("signed in elsewhere") from taking the account back with "Use it here".
    await prisma.session.updateMany({
      where: { userId: user.id, revokedAt: null },
      data: { revokedAt: new Date(), revokeReason: 'password_reset' },
    });
    await prisma.session.updateMany({
      where: { userId: user.id, revokeReason: 'signed_in_elsewhere' },
      data: { revokeReason: 'password_reset' },
    });
    // The code proved the phone / email: a full account makes room for this device.
    return issueSession(ctx, user.id, { recover: true });
  });
}
