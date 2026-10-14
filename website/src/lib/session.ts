// Cookie names and helpers shared by the middleware (edge) and the server.
// Tokens live only in httpOnly cookies: page scripts can never read them.

export const COOKIE = {
  access: 'ia_at',
  accessExp: 'ia_ax',
  refresh: 'ia_rt',
  keep: 'ia_keep',
  device: 'ia_dev',
} as const;

export interface AuthTokens {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt?: string;
}

export interface CookieWrite {
  name: string;
  value: string;
  maxAge?: number;
}

const secure = process.env.NODE_ENV === 'production';

export const cookieBase = {
  httpOnly: true,
  secure,
  sameSite: 'lax' as const,
  path: '/',
};

/** The cookies that hold a session. [keep] = "Keep me signed in". */
export function sessionCookies(t: AuthTokens, keep: boolean): CookieWrite[] {
  const now = Date.now();
  const accessMs = Math.max(60_000, Date.parse(t.accessTokenExpiresAt) - now);
  const refreshMs = t.refreshTokenExpiresAt ? Math.max(60_000, Date.parse(t.refreshTokenExpiresAt) - now) : 30 * 86400_000;
  const keepAge = keep ? Math.floor(refreshMs / 1000) : undefined; // no maxAge = ends with the browser
  return [
    { name: COOKIE.access, value: t.accessToken, maxAge: Math.floor(accessMs / 1000) },
    { name: COOKIE.accessExp, value: t.accessTokenExpiresAt, maxAge: Math.floor(accessMs / 1000) },
    { name: COOKIE.refresh, value: t.refreshToken, maxAge: keepAge },
    { name: COOKIE.keep, value: keep ? '1' : '0', maxAge: keepAge },
  ];
}

export const clearedSessionCookies: CookieWrite[] = [
  { name: COOKIE.access, value: '', maxAge: 0 },
  { name: COOKIE.accessExp, value: '', maxAge: 0 },
  { name: COOKIE.refresh, value: '', maxAge: 0 },
  { name: COOKIE.keep, value: '', maxAge: 0 },
];

/** A random id for this browser (the app does the same per install). */
export function newDeviceId(): string {
  const b = new Uint8Array(16);
  crypto.getRandomValues(b);
  return Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('');
}

export const DEVICE_COOKIE_AGE = 2 * 365 * 86400;

/** "Chrome", "Edge", … from the user agent (plain ASCII for the header). */
export function browserName(ua: string): string {
  if (/Edg\//.test(ua)) return 'Edge';
  if (/OPR\//.test(ua)) return 'Opera';
  if (/SamsungBrowser\//.test(ua)) return 'Samsung Internet';
  if (/Firefox\//.test(ua)) return 'Firefox';
  if (/Chrome\//.test(ua)) return 'Chrome';
  if (/Safari\//.test(ua)) return 'Safari';
  return 'browser';
}

function osName(ua: string): string {
  if (/Android/.test(ua)) return 'Android';
  if (/iPhone|iPad/.test(ua)) return 'iOS';
  if (/Windows/.test(ua)) return 'Windows';
  if (/Mac OS X/.test(ua)) return 'Mac';
  if (/Linux/.test(ua)) return 'Linux';
  return '';
}

/** X-Device-* headers for the API: "Web browser (Chrome on Windows)". */
export function deviceHeaders(deviceId: string, ua: string): Record<string, string> {
  const os = osName(ua);
  const name = `Web browser (${browserName(ua)}${os ? ` on ${os}` : ''})`.replace(/[^\x20-\x7E]/g, '');
  return deviceId
    ? { 'X-Device-Id': deviceId, 'X-Device-Name': name, 'X-Device-Platform': 'Web' }
    : { 'X-Device-Platform': 'Web' };
}

/** Codes the API uses when it has ended a session. */
export const ENDED_CODES = new Set(['signed_in_elsewhere', 'device_removed', 'session_ended']);
