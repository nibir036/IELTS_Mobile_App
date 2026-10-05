// The signed-in student: profile, password, plan usage, delete account.

import type { Prisma } from '@prisma/client';
import { prisma } from '../db';
import { badRequest, HttpError, obj, required, Router, s, unauthorized } from '../lib/http';
import { hashPassword, verifyPassword } from '../lib/password';
import { isStrongPassword } from '../lib/phone';
import { publicUser, requireUser, usage, userSelect } from '../lib/users';
import { deleteObjects } from '../lib/r2';

/** Profile keys the app may not set itself (billing / server-owned). */
const PROTECTED_PROFILE_KEYS = new Set(['plan', 'isDemo']);

export function registerMeRoutes(r: Router): void {
  r.get('/v1/me', async (ctx) => {
    const userId = requireUser(ctx);
    const user = await prisma.user.findUnique({ where: { id: userId }, select: userSelect });
    if (!user) throw unauthorized('This account no longer exists.', 'no_account');
    return { user: publicUser(user), usage: await usage(userId) };
  });

  // {name?, profile?: {...partial}} - profile keys are merged; null removes a key.
  r.patch('/v1/me', async (ctx) => {
    const userId = requireUser(ctx);
    const user = await prisma.user.findUnique({ where: { id: userId }, select: { profile: true } });
    if (!user) throw unauthorized('This account no longer exists.', 'no_account');
    const data: { name?: string; profile?: Prisma.InputJsonValue } = {};
    if (ctx.body.name !== undefined) {
      const name = s(ctx.body.name, 80);
      if (!name) throw badRequest('Name cannot be empty.');
      data.name = name;
    }
    const patch = obj(ctx.body.profile);
    if (Object.keys(patch).length) {
      const profile = { ...((user.profile ?? {}) as Record<string, unknown>) };
      for (const [k, v] of Object.entries(patch)) {
        if (PROTECTED_PROFILE_KEYS.has(k)) continue;
        if (v === null) delete profile[k];
        else profile[k] = v;
      }
      data.profile = profile as Prisma.InputJsonValue;
    }
    const updated = await prisma.user.update({ where: { id: userId }, data, select: userSelect });
    return { user: publicUser(updated) };
  });

  r.post('/v1/me/password', async (ctx) => {
    const userId = requireUser(ctx);
    const current = required(ctx.body, 'currentPassword', 200);
    const next = required(ctx.body, 'newPassword', 200);
    if (!isStrongPassword(next)) {
      throw badRequest('Use 8+ characters with at least one number and one symbol.', 'weak_password');
    }
    const user = await prisma.user.findUnique({ where: { id: userId }, select: { passwordHash: true } });
    if (!user) throw unauthorized('This account no longer exists.', 'no_account');
    if (!verifyPassword(current, user.passwordHash)) {
      throw new HttpError(400, 'Your current password is wrong.', 'wrong_password');
    }
    await prisma.user.update({ where: { id: userId }, data: { passwordHash: hashPassword(next) } });
    return { ok: true };
  });

  r.get('/v1/me/usage', async (ctx) => usage(requireUser(ctx)));

  // Permanently deletes the account and everything that belongs to it.
  r.delete('/v1/me', async (ctx) => {
    const userId = requireUser(ctx);
    const password = required(ctx.body, 'password', 200);
    const user = await prisma.user.findUnique({ where: { id: userId }, select: { passwordHash: true } });
    if (!user) return { deleted: true };
    if (!verifyPassword(password, user.passwordHash)) {
      throw new HttpError(400, 'Wrong password.', 'wrong_password');
    }
    const recordings = await prisma.recording.findMany({ where: { userId }, select: { r2Key: true } });
    await prisma.user.delete({ where: { id: userId } }); // cascades to all user rows
    await deleteObjects(recordings.map((x) => x.r2Key)).catch((e) => console.error('[me] R2 cleanup failed', e));
    return { deleted: true };
  });
}
