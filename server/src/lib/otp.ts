// Phone OTP (port of the website's lib/otp.ts onto the otp_codes table).
// Codes are never stored in plain text -- only an HMAC keyed by
// phone+purpose. A successful verify returns a short-lived signed "proof"
// that /auth/register or /auth/reset-password checks, so the app can't just
// claim a phone is verified.

import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { prisma } from '../db';
import { env } from '../env';
import { HttpError } from './http';

export type OtpPurpose = 'signup' | 'reset';

const CODE_LENGTH = 6;
const CODE_TTL_MS = 5 * 60 * 1000;
const RESEND_COOLDOWN_MS = 45 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;
const PROOF_TTL_MS = 15 * 60 * 1000;

function hmac(...parts: string[]): string {
  return createHmac('sha256', env.authSecret).update(parts.join('|')).digest('hex');
}

function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

const hashCode = (phone: string, purpose: string, code: string) => hmac('otp-code', phone, purpose, code);

/** Creates a code (enforcing the resend cooldown) and returns it in plain text. */
export async function createOtp(phone: string, purpose: OtpPurpose): Promise<string> {
  const recent = await prisma.otpCode.findFirst({
    where: { phone, purpose },
    orderBy: { createdAt: 'desc' },
  });
  if (recent && Date.now() - recent.createdAt.getTime() < RESEND_COOLDOWN_MS) {
    const wait = Math.ceil((RESEND_COOLDOWN_MS - (Date.now() - recent.createdAt.getTime())) / 1000);
    throw new HttpError(429, `Please wait ${wait}s before requesting another code.`, 'rate_limited', {
      retryAfterSec: wait,
    });
  }
  const code = randomInt(0, 10 ** CODE_LENGTH)
    .toString()
    .padStart(CODE_LENGTH, '0');
  await prisma.otpCode.create({
    data: {
      phone,
      purpose,
      codeHash: hashCode(phone, purpose, code),
      expiresAt: new Date(Date.now() + CODE_TTL_MS),
    },
  });
  return code;
}

/** Checks a code; on success consumes it and returns a signed proof. */
export async function verifyOtp(phone: string, code: string, purpose: OtpPurpose): Promise<string> {
  const otp = await prisma.otpCode.findFirst({
    where: { phone, purpose, consumedAt: null },
    orderBy: { createdAt: 'desc' },
  });
  if (!otp) throw new HttpError(400, 'No code was sent to this number. Request a new one.', 'otp_expired');
  if (otp.expiresAt.getTime() < Date.now()) {
    throw new HttpError(400, 'This code has expired. Request a new one.', 'otp_expired');
  }
  if (otp.attempts >= MAX_VERIFY_ATTEMPTS) {
    throw new HttpError(400, 'Too many incorrect attempts. Request a new code.', 'otp_too_many_attempts');
  }
  if (!safeEqual(hashCode(phone, purpose, code), otp.codeHash)) {
    await prisma.otpCode.update({ where: { id: otp.id }, data: { attempts: { increment: 1 } } });
    const left = MAX_VERIFY_ATTEMPTS - (otp.attempts + 1);
    throw new HttpError(
      400,
      left > 0 ? `Incorrect code. ${left} attempt(s) left.` : 'Incorrect code. Request a new one.',
      left > 0 ? 'otp_invalid' : 'otp_too_many_attempts',
    );
  }
  await prisma.otpCode.update({ where: { id: otp.id }, data: { consumedAt: new Date() } });
  return signProof(phone, purpose);
}

function signProof(phone: string, purpose: string): string {
  const expiresAt = Date.now() + PROOF_TTL_MS;
  const sig = hmac('otp-proof', phone, purpose, String(expiresAt));
  return Buffer.from(`${phone}|${purpose}|${expiresAt}|${sig}`).toString('base64url');
}

export function verifyProof(proof: string, phone: string, purpose: OtpPurpose): boolean {
  try {
    const [p, pur, exp, sig] = Buffer.from(proof, 'base64url').toString('utf8').split('|');
    if (!p || !pur || !exp || !sig || p !== phone || pur !== purpose) return false;
    if (Date.now() > Number(exp)) return false;
    return safeEqual(sig, hmac('otp-proof', p, pur, exp));
  } catch {
    return false;
  }
}
