// Access tokens: short-lived HS256 JWTs (stateless, checked on every call).
// Refresh tokens: long random strings; only their SHA-256 hash is stored in
// the sessions table, and each refresh rotates to a new one.

import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { env } from '../env';

const b64url = (buf: Buffer | string) =>
  Buffer.from(buf).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

function fromB64url(s: string): Buffer {
  return Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

function hmac(data: string): string {
  return b64url(createHmac('sha256', env.authSecret).update(data).digest());
}

export interface AccessClaims {
  sub: string; // user id
  sid: string; // session id
  iat: number;
  exp: number;
}

export function signAccessToken(userId: string, sessionId: string): { token: string; expiresAt: Date } {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + env.accessTokenMinutes * 60;
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({ sub: userId, sid: sessionId, iat, exp }));
  const sig = hmac(`${header}.${payload}`);
  return { token: `${header}.${payload}.${sig}`, expiresAt: new Date(exp * 1000) };
}

/** Returns the claims, or null for a bad signature / expired token. */
export function verifyAccessToken(token: string): AccessClaims | null {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [header, payload, sig] = parts;
  const expected = hmac(`${header}.${payload}`);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  try {
    const claims = JSON.parse(fromB64url(payload).toString('utf8')) as AccessClaims;
    if (!claims.sub || !claims.exp || claims.exp * 1000 < Date.now()) return null;
    return claims;
  } catch {
    return null;
  }
}

export function newRefreshToken(): string {
  return b64url(randomBytes(32));
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
