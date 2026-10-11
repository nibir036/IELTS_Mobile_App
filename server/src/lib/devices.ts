// Devices and the one-screen rule.
//
//   - An account can be used on at most MAX_DEVICES devices (phones /
//     browsers). Each app install sends a random id (X-Device-Id); it is not a
//     hardware id.
//   - A further device is refused and locked for DEVICE_LOCK_HOURS: no sign-in
//     on that device until the lock ends AND one of the account's devices has
//     been removed (Settings -> Your devices). Trying again while the account
//     is still full locks it again.
//   - Only one screen is signed in at a time: a new sign-in ends the other
//     sessions ("signed_in_elsewhere"); that device can take the account back.
//   - A device can be removed once every DEVICE_REMOVE_COOLDOWN_DAYS, so slots
//     can't be passed round friends.
//   - Recovery: a password reset (proved by an OTP to the account's phone)
//     on a new device replaces the least recently used one.

import { prisma } from '../db';
import { HttpError, s, type Ctx } from './http';

export const MAX_DEVICES = 2;
export const DEVICE_LOCK_HOURS = 48;
export const DEVICE_REMOVE_COOLDOWN_DAYS = 30;

export interface DeviceInfo {
  key: string;
  name: string;
  platform: string | null;
}

/** The calling device, from the X-Device-* headers (or the body). */
export function deviceOf(ctx: Ctx): DeviceInfo {
  const h = ctx.req.headers;
  const header = (k: string) => (Array.isArray(h[k]) ? (h[k] as string[])[0] : (h[k] as string | undefined));
  const key = s(header('x-device-id') ?? ctx.body.deviceId, 80).replace(/[^A-Za-z0-9_-]/g, '');
  const platform = s(header('x-device-platform') ?? ctx.body.devicePlatform, 20) || null;
  const name = s(header('x-device-name') ?? ctx.body.deviceName, 60) || (platform ? `${platform} device` : 'Unknown device');
  // Older app builds send no id: they share one "legacy" slot.
  return { key: key || 'legacy', name, platform };
}

const hoursLeft = (until: Date) => Math.max(1, Math.ceil((until.getTime() - Date.now()) / 3600_000));

type DeviceRow = { id: string; name: string; status: string; lockedUntil: Date | null; lastSeenAt: Date };

/**
 * Lets [device] use the account, registering it when there is room.
 * Throws 423 "device_locked" (with retryAt and the account's devices) when
 * the account is full or this device is locked. [recover] = OTP-proved
 * password reset: a full account drops its least recently used device.
 * Returns the device id.
 */
export async function admitDevice(
  userId: string,
  device: DeviceInfo,
  ip: string,
  opts: { recover?: boolean } = {},
): Promise<string> {
  const now = new Date();
  const mine = (await prisma.device.findFirst({ where: { userId, deviceKey: device.key } })) as
    | (DeviceRow & { lockCount: number })
    | null;
  const seen = { name: device.name, platform: device.platform, lastSeenAt: now, lastIp: ip || null };

  if (mine?.status === 'active') {
    await prisma.device.update({ where: { id: mine.id }, data: seen });
    return mine.id;
  }
  if (mine?.status === 'locked' && mine.lockedUntil && mine.lockedUntil > now && !opts.recover) {
    throw await lockedError(userId, mine.lockedUntil);
  }

  const active = (await prisma.device.findMany({
    where: { userId, status: 'active' },
    orderBy: { lastSeenAt: 'asc' },
  })) as DeviceRow[];

  if (active.length >= MAX_DEVICES) {
    if (opts.recover) {
      // Proved the phone number: the oldest device makes room.
      const oldest = active[0];
      await removeDevice(userId, oldest.id, 'device_removed');
    } else {
      // A further device: locked here for 48 hours.
      const lockedUntil = new Date(now.getTime() + DEVICE_LOCK_HOURS * 3600_000);
      if (mine) {
        await prisma.device.update({
          where: { id: mine.id },
          data: { ...seen, status: 'locked', lockedUntil, lockCount: { increment: 1 } },
        });
      } else {
        await prisma.device.create({
          data: { userId, deviceKey: device.key, ...seen, status: 'locked', lockedUntil, lockCount: 1 },
        });
      }
      console.warn(`[devices] user ${userId}: device limit reached, locked ${device.key.slice(0, 8)} until ${lockedUntil.toISOString()}`);
      throw await lockedError(userId, lockedUntil);
    }
  }

  if (mine) {
    await prisma.device.update({
      where: { id: mine.id },
      data: { ...seen, status: 'active', lockedUntil: null, removedAt: null },
    });
    return mine.id;
  }
  const row = await prisma.device.create({
    data: { userId, deviceKey: device.key, ...seen, status: 'active' },
    select: { id: true },
  });
  return row.id;
}

async function lockedError(userId: string, until: Date): Promise<HttpError> {
  const active = (await prisma.device.findMany({
    where: { userId, status: 'active' },
    orderBy: { lastSeenAt: 'desc' },
    select: { name: true },
  })) as Array<{ name: string }>;
  const names = active.map((d) => d.name);
  const h = hoursLeft(until);
  return new HttpError(
    423,
    `This account is already used on ${MAX_DEVICES} devices` +
      (names.length ? ` (${names.join(', ')})` : '') +
      `, so this device is locked for ${h} hour${h === 1 ? '' : 's'}. ` +
      'To use it after that, remove one of your devices in Settings → Your devices.',
    'device_locked',
    { retryAt: until.toISOString(), devices: names, maxDevices: MAX_DEVICES },
  );
}

// ── sessions ────────────────────────────────────────────────────────────────

/** Short cache of session checks so each request doesn't hit the database. */
const sessionCache = new Map<string, { ok: boolean; reason: string | null; at: number }>();
const SESSION_CACHE_MS = 10_000;

/** Ends the user's other sessions (one signed-in screen at a time). */
export async function endOtherSessions(userId: string, keepSessionId: string | null, reason: string) {
  const open = (await prisma.session.findMany({
    where: { userId, revokedAt: null },
    select: { id: true },
  })) as Array<{ id: string }>;
  const ids = open.map((x) => x.id).filter((id) => id !== keepSessionId);
  if (!ids.length) return;
  await prisma.session.updateMany({
    where: { id: { in: ids } },
    data: { revokedAt: new Date(), revokeReason: reason },
  });
  for (const id of ids) sessionCache.delete(id);
}

/** Marks a device removed and ends its sessions. */
export async function removeDevice(userId: string, deviceId: string, reason = 'device_removed') {
  const now = new Date();
  await prisma.device.update({
    where: { id: deviceId },
    data: { status: 'removed', removedAt: now, lockedUntil: null },
  });
  const open = (await prisma.session.findMany({
    where: { userId, deviceId, revokedAt: null },
    select: { id: true },
  })) as Array<{ id: string }>;
  if (open.length) {
    await prisma.session.updateMany({
      where: { id: { in: open.map((x) => x.id) } },
      data: { revokedAt: now, revokeReason: reason },
    });
    for (const x of open) sessionCache.delete(x.id);
  }
}

/** The 401 for an ended session, by why it ended. */
export function sessionEndedError(reason: string | null): HttpError {
  if (reason === 'signed_in_elsewhere') {
    return new HttpError(
      401,
      'Your account was opened on your other device, so you were signed out here.',
      'signed_in_elsewhere',
    );
  }
  if (reason === 'device_removed') {
    return new HttpError(401, 'This device was removed from your account. Log in again to use it.', 'device_removed');
  }
  return new HttpError(401, 'Your session has ended. Please log in again.', 'session_ended');
}

/**
 * Throws when the access token's session has ended (another device signed
 * in, the device was removed, logout). Cached for a few seconds.
 */
export async function assertSessionOpen(sessionId: string): Promise<void> {
  const hit = sessionCache.get(sessionId);
  const now = Date.now();
  let entry = hit && now - hit.at < SESSION_CACHE_MS ? hit : null;
  if (!entry) {
    const row = (await prisma.session.findUnique({
      where: { id: sessionId },
      select: { revokedAt: true, revokeReason: true, expiresAt: true },
    })) as { revokedAt: Date | null; revokeReason: string | null; expiresAt: Date } | null;
    entry = {
      ok: Boolean(row && !row.revokedAt && row.expiresAt.getTime() > now),
      reason: row?.revokeReason ?? null,
      at: now,
    };
    sessionCache.set(sessionId, entry);
    if (sessionCache.size > 20_000) sessionCache.clear();
  }
  if (!entry.ok) throw sessionEndedError(entry.reason);
}

// ── listing / removing (Settings → Your devices) ────────────────────────────

export async function listDevices(userId: string, currentDeviceId: string | null) {
  const rows = (await prisma.device.findMany({
    where: { userId, status: { in: ['active', 'locked'] } },
    orderBy: { lastSeenAt: 'desc' },
  })) as Array<DeviceRow & { platform: string | null; firstSeenAt: Date }>;
  const lastRemoval = (await prisma.device.findFirst({
    where: { userId, removedAt: { not: null } },
    orderBy: { removedAt: 'desc' },
    select: { removedAt: true },
  })) as { removedAt: Date | null } | null;
  const nextRemovalAt = nextRemoval(lastRemoval?.removedAt ?? null);
  const now = new Date();
  return {
    maxDevices: MAX_DEVICES,
    lockHours: DEVICE_LOCK_HOURS,
    removeCooldownDays: DEVICE_REMOVE_COOLDOWN_DAYS,
    nextRemovalAt: nextRemovalAt && nextRemovalAt > now ? nextRemovalAt.toISOString() : null,
    devices: rows
      // An expired lock on a device that never got in is not worth showing.
      .filter((d) => d.status === 'active' || (d.lockedUntil && d.lockedUntil > now))
      .map((d) => ({
        id: d.id,
        name: d.name,
        platform: d.platform,
        status: d.status,
        current: d.id === currentDeviceId,
        lockedUntil: d.lockedUntil ? d.lockedUntil.toISOString() : null,
        firstSeenAt: d.firstSeenAt.toISOString(),
        lastSeenAt: d.lastSeenAt.toISOString(),
      })),
  };
}

function nextRemoval(last: Date | null): Date | null {
  return last ? new Date(last.getTime() + DEVICE_REMOVE_COOLDOWN_DAYS * 86400_000) : null;
}

/** Settings → remove a device (not the one in use; once per 30 days). */
export async function removeDeviceByUser(userId: string, deviceId: string, currentDeviceId: string | null) {
  const d = (await prisma.device.findFirst({ where: { id: deviceId, userId } })) as DeviceRow | null;
  if (!d || d.status === 'removed') throw new HttpError(404, 'Device not found.', 'not_found');
  if (d.id === currentDeviceId) {
    throw new HttpError(400, 'This is the device you are using. Log out instead.', 'current_device');
  }
  if (d.status === 'active') {
    const lastRemoval = (await prisma.device.findFirst({
      where: { userId, removedAt: { not: null } },
      orderBy: { removedAt: 'desc' },
      select: { removedAt: true },
    })) as { removedAt: Date | null } | null;
    const next = nextRemoval(lastRemoval?.removedAt ?? null);
    if (next && next > new Date()) {
      const days = Math.max(1, Math.ceil((next.getTime() - Date.now()) / 86400_000));
      throw new HttpError(
        429,
        `You can remove a device once every ${DEVICE_REMOVE_COOLDOWN_DAYS} days. ` +
          `Try again in ${days} day${days === 1 ? '' : 's'}.`,
        'device_remove_too_soon',
        { retryAt: next.toISOString() },
      );
    }
  }
  // A locked device never got in; its lock can't be lifted from here.
  if (d.status === 'locked') {
    throw new HttpError(400, 'This device is locked and was never added to your account.', 'device_locked_entry');
  }
  await removeDevice(userId, d.id, 'device_removed');
}
