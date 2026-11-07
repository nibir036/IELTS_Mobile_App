// Admin calls (refunds, payments): the X-Admin-Token header must equal
// ADMIN_TOKEN (24+ characters). The admin pages (/admin/banners,
// /admin/refunds) ask for the token and send it with each call.

import { timingSafeEqual } from 'node:crypto';
import { env } from '../env';
import { HttpError, rateLimit, s, type Ctx } from './http';

export function requireAdmin(ctx: Ctx): void {
  const want = Buffer.from(env.adminToken);
  if (want.length < 24) throw new HttpError(503, 'Admin calls are off: ADMIN_TOKEN must be at least 24 characters.', 'admin_off');
  rateLimit(`admin:${ctx.ip}`, 600, 3600);
  const got = Buffer.from(s(ctx.req.headers['x-admin-token'], 300));
  if (got.length !== want.length || !timingSafeEqual(got, want)) throw new HttpError(401, 'Wrong admin token.', 'bad_admin_token');
}
