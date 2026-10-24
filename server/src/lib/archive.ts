// A student's data as one JSON file in R2, and what happens on account
// deletion.
//
//   archiveOnce(userId, reason)   a snapshot, the first time a profile is
//                                 complete (IELTS onboarding, study-abroad
//                                 profile). Runs in the background.
//   eraseUser(userId)             account deletion: snapshot + files to the
//                                 archive, practice answers to the training
//                                 set (unlinked), then the account is deleted.
//
// Archives live at archive/users/<user id>/ in the bucket, are private
// (no route serves them) and are kept permanently. Each one is listed in
// the data_archives table, which is not tied to the user row, so the list
// survives the deletion.
//
// The privacy policy and the Play Store data-safety form must say this:
// what is kept after deletion (the archive, anonymised practice answers
// and speaking audio for training) and why.

import { randomUUID } from 'node:crypto';
import type { Prisma } from '@prisma/client';
import { prisma } from '../db';
import { env } from '../env';
import { HttpError } from './http';
import { appKey, copyObject, deleteObjects, putObject } from './r2';

export type ArchiveReason = 'ielts_profile_complete' | 'nexted_profile_complete' | 'account_deleted';

type Json = Record<string, unknown>;

const iso = (d: Date) => d.toISOString().replace(/[:.]/g, '-');

/** Everything the system holds about one student, in one object. */
export async function buildUserExport(userId: string): Promise<Json | null> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      sessions: true,
      devices: true,
      attempts: { include: { recordings: true }, orderBy: { createdAt: 'asc' } },
      recordings: true,
      notifications: true,
      tasks: true,
      plans: true,
      state: true,
      usageEvents: true,
      subscriptions: true,
      paymentMethods: true,
      payments: true,
      roomMessages: true,
      rooms: true,
      nextedProfile: true,
      nextedDocuments: true,
      nextedApplications: { include: { events: true } },
      nextedAiUsage: true,
      nextedChat: { orderBy: { createdAt: 'asc' } },
    },
  });
  if (!user) return null;

  // Secrets never leave the database, not even into a private archive.
  const { passwordHash: _password, sessions, paymentMethods, ...rest } = user;
  return {
    exportedAt: new Date().toISOString(),
    format: 'ielts-ai-user-export/1',
    ...rest,
    sessions: sessions.map(({ tokenHash: _token, ...s }) => s),
    // The bKash agreement id can charge the account: left out.
    paymentMethods: paymentMethods.map(({ token: _token, ...m }) => m),
  };
}

async function writeArchive(userId: string, reason: ArchiveReason, data: Json): Promise<string> {
  const body = Buffer.from(JSON.stringify(data, null, 2), 'utf8');
  const key = appKey(`archive/users/${userId}/${iso(new Date())}-${reason}.json`);
  await putObject(key, body, 'application/json');
  await prisma.dataArchive.create({ data: { userId, reason, r2Key: key, bytes: body.length } });
  return key;
}

/**
 * The snapshot for a completed profile, once per reason. Never throws and
 * never delays the request that triggered it.
 */
export function archiveOnce(userId: string, reason: Exclude<ArchiveReason, 'account_deleted'>): void {
  if (!env.r2Configured) return;
  void (async () => {
    const done = await prisma.dataArchive.findFirst({ where: { userId, reason }, select: { id: true } });
    if (done) return;
    const data = await buildUserExport(userId);
    if (data) await writeArchive(userId, reason, data);
  })().catch((e) => console.error(`[archive] ${reason} snapshot failed:`, e instanceof Error ? e.message : e));
}

// ── training set ─────────────────────────────────────────────────────────

// Keys dropped wherever they appear (compared lower-case, letters only).
const PII_KEY =
  /^(name|fullname|firstname|lastname|username|studentname|displayname|userid|deviceid|ip|dob|dateofbirth)$|phone|mobile|email|passport|address/;

/** A copy of [value] with the student's identifiers removed. */
function scrub(value: unknown, needles: RegExp | null): unknown {
  if (typeof value === 'string') return needles ? value.replace(needles, '[removed]') : value;
  if (Array.isArray(value)) return value.map((v) => scrub(v, needles));
  if (value && typeof value === 'object') {
    const out: Json = {};
    for (const [k, v] of Object.entries(value as Json)) {
      if (PII_KEY.test(k.toLowerCase().replace(/[^a-z]/g, ''))) continue;
      out[k] = scrub(v, needles);
    }
    return out;
  }
  return value;
}

/** The student's id, phone and name parts as one pattern (whole words). */
function identifiers(user: { id: string; phone: string; name: string }): RegExp | null {
  const esc = (t: string) => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const parts = [
    user.id,
    user.phone,
    `0${user.phone}`,
    `880${user.phone}`,
    ...user.name.split(/\s+/).filter((w) => w.length >= 3),
  ].filter(Boolean);
  if (!parts.length) return null;
  return new RegExp(`\\b(${parts.map(esc).join('|')})\\b`, 'gi');
}

const extOf = (key: string) => (key.match(/\.([a-z0-9]{2,5})$/i)?.[1] ?? 'wav').toLowerCase();

const monthOf = (d: Date) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1));

// ── account deletion ─────────────────────────────────────────────────────

/**
 * Archive, keep the practice answers for training, then delete the account.
 * Nothing is deleted unless the archive was written: if R2 fails, the
 * student is asked to try again.
 */
export async function eraseUser(userId: string): Promise<void> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      name: true,
      phone: true,
      profile: true,
      attempts: { include: { recordings: true } },
      recordings: { where: { attemptId: null } },
      nextedDocuments: { select: { id: true, r2Key: true } },
    },
  });
  if (!user) return;

  const storage = env.r2Configured;
  const toDelete: string[] = [];

  try {
    // 1. Files into the archive folder: study-abroad documents and the
    //    profile photo. (Speaking audio goes to the training set below.)
    const files: Json[] = [];
    if (storage) {
      const photo = typeof (user.profile as Json)?.photo === 'string' ? String((user.profile as Json).photo) : '';
      const sources = [
        ...user.nextedDocuments.map((d) => ({ what: `document:${d.id}`, key: d.r2Key })),
        ...(photo ? [{ what: 'profile_photo', key: photo }] : []),
      ];
      for (const f of sources) {
        const to = appKey(`archive/users/${userId}/files/${f.key.split('/').pop()}`);
        await copyObject(f.key, to);
        files.push({ what: f.what, from: f.key, archivedAs: to });
        toDelete.push(f.key);
      }
    }

    // 2. The JSON archive.
    const data = await buildUserExport(userId);
    if (data && storage) await writeArchive(userId, 'account_deleted', { ...data, archivedFiles: files });
    if (!storage) console.warn('[archive] R2 is not configured: account deleted without an archive');

    // 3. The training set: every practice answer, with nothing that points
    //    back to the student. Audio is copied under the sample's own id.
    const needles = identifiers(user);
    const samples: Prisma.TrainingSampleCreateManyInput[] = [];
    const addSample = async (
      base: Omit<Prisma.TrainingSampleCreateManyInput, 'id' | 'audio'>,
      recordings: { r2Key: string; format: string; durationMs: number }[],
    ) => {
      const id = randomUUID();
      const audio: Json[] = [];
      if (storage) {
        for (const [i, rec] of recordings.entries()) {
          const to = appKey(`training/speaking/${id}/${i + 1}.${extOf(rec.r2Key) || rec.format}`);
          await copyObject(rec.r2Key, to);
          audio.push({ key: to, format: rec.format, durationMs: rec.durationMs });
          toDelete.push(rec.r2Key);
        }
      }
      samples.push({ ...base, id, ...(audio.length ? { audio: audio as Prisma.InputJsonValue } : {}) });
    };

    for (const a of user.attempts) {
      await addSample(
        {
          skill: a.skill,
          kind: a.kind,
          title: a.title,
          refId: a.refId,
          band: a.band,
          score: a.score,
          total: a.total,
          durationSec: a.durationSec,
          data: a.data == null ? undefined : (scrub(a.data, needles) as Prisma.InputJsonValue),
          attemptedIn: monthOf(a.createdAt),
        },
        a.recordings,
      );
    }
    // Speaking audio saved without an attempt.
    for (const rec of user.recordings) {
      await addSample({ skill: 'speaking', kind: 'recording', attemptedIn: monthOf(rec.createdAt) }, [rec]);
    }

    // 4. Samples in, account out - together, or neither.
    await prisma.$transaction([
      prisma.trainingSample.createMany({ data: samples }),
      prisma.user.delete({ where: { id: userId } }), // cascades to all user rows
    ]);
  } catch (e) {
    if (e instanceof HttpError) throw e;
    console.error('[archive] account deletion stopped:', e instanceof Error ? e.message : e);
    throw new HttpError(503, 'We couldn’t delete your account just now. Please try again in a few minutes.', 'delete_failed');
  }

  // 5. The originals, now that their copies exist. A failure here leaves
  //    orphaned files, never a half-deleted account.
  await deleteObjects(toDelete).catch((e) => console.error('[archive] R2 cleanup failed', e));
}
