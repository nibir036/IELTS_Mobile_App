// nexted.app (study abroad) - the student-facing module that lives inside the
// IELTS app. One account, one login: every row here hangs off the same `users`
// table, so a counsellor on the web and the student on the phone read the same
// records.
//
// The mobile client only ever gets student actions: there are no staff
// endpoints here at all.

import { randomUUID } from 'node:crypto';
import type { Prisma } from '@prisma/client';
import { prisma } from '../db';
import { geminiJson } from '../lib/gemini';
import { badRequest, HttpError, int, notFound, obj, plainDashes, rateLimit, Router, s, type Ctx } from '../lib/http';
import {
  checkRestrictions,
  consumeAi,
  contactResponse,
  feeResponse,
  finishAnswer,
  fixedIntent,
  OFFICE,
  eligibility,
  readAiUsage,
  restrictionFacts,
  type RestrictionRule,
  type StudentScope,
} from '../lib/nexted';
import {
  aiCounsellor,
  aiCounsellorStream,
  aiCourses,
  aiScholarships,
  aiUsage,
  NextedAiUnreachable,
  nextedAiEnabled,
} from '../lib/nexted_ai';
import { appKey, contentTypeFor, deleteObjects, DOCUMENT_EXTS, putObject, signedUrl } from '../lib/r2';
import { requireUser } from '../lib/users';
import { archiveOnce } from '../lib/archive';

/** Documents: PDF, JPEG or PNG, up to 10 MB each. */
const MAX_DOC_BYTES = 10 * 1024 * 1024;

/** Which exam a transcript or certificate is for. */
const DOC_LEVELS = new Set(['ssc', 'hsc', 'bachelors', 'masters']);

/** Document types the student can upload. */
const DOC_KINDS = new Set(['passport', 'transcript', 'certificate', 'ielts', 'photo', 'other']);

/** The fixed steps an application moves through (staff move them on the web). */
export const STATUS_STEPS = [
  'Submitted',
  'Under Review',
  'Documents Requested',
  'Application Lodged with Institution',
  'Conditional Offer',
  'Unconditional Offer',
  'Deposit or Tuition Paid',
  'Admission Letter or CAS/CoE',
  'Visa Preparation',
  'Visa Lodged',
  'Visa Decision',
  'Enrolled',
];

const PROFILE_FIELDS = [
  'fullName',
  'email',
  'phone',
  'nationality',
  'highestLevel',
  'result',
  'ieltsBand',
  'preferredCountry',
  'preferredIntake',
  // What they want to study ("Nursing", "Data Science"). Without it every
  // search fell back to whatever the catalogue happened to hold.
  'subject',
  // The level they want to ENROL in (Bachelors, Masters, PhD ...) - not the
  // one they have finished. The AI searches at this level.
  'studyLevel',
  // Several UK rules close an intake by home district rather than by country,
  // so without this the counsellor can only answer "uncertain".
  'homeDistrict',
  // Any published research? "Yes" | "No" - asked for every level of study.
  'hasPublication',
] as const;

type ProfileRow = Record<(typeof PROFILE_FIELDS)[number], string>;

/** Where the IELTS band on the study-abroad profile came from. */
type BandSource = 'you' | 'mock' | 'target' | '';

/** "1734519208" → "01734519208"; anything else (demo ids) as stored. */
function phoneForProfile(phone: string): string {
  return /^1\d{9}$/.test(phone) ? `0${phone}` : phone;
}

/** 6.5 → "6.5", 7 → "7.0" (half-band steps). */
function bandText(b: number): string {
  return (Math.round(b * 2) / 2).toFixed(1);
}

/**
 * The IELTS band the IELTS side of the app already knows: the overall band of
 * the latest full mock test, else the target band the student set.
 */
async function ieltsBandFromApp(userId: string, profileJson: unknown): Promise<{ band: string; source: BandSource }> {
  const mock = await prisma.attempt.findFirst({
    where: { userId, skill: 'mock', kind: 'mock', band: { not: null } },
    orderBy: { createdAt: 'desc' },
    select: { band: true },
  });
  if (mock?.band != null && mock.band > 0) return { band: bandText(mock.band), source: 'mock' };
  const target = Number(((profileJson ?? {}) as Record<string, unknown>).targetBand);
  if (Number.isFinite(target) && target > 0) return { band: bandText(target), source: 'target' };
  return { band: '', source: '' };
}

/**
 * The study-abroad profile, with the fields both halves share taken from the
 * one place they live:
 *
 *  - full name and phone come from the account (`users`), always. The copy in
 *    nexted_profiles is only a mirror for the web platform, refreshed here
 *    whenever it has fallen behind.
 *  - the IELTS band is the one the student typed (source "you"); otherwise
 *    the IELTS side's latest mock band, else their target band. The automatic
 *    value is mirrored too, so the counsellor on the web sees the same number.
 */
async function loadProfileFull(userId: string): Promise<{ profile: ProfileRow; ieltsBandSource: BandSource }> {
  const [row, user] = await Promise.all([
    prisma.nextedProfile.findUnique({ where: { userId } }),
    prisma.user.findUnique({ where: { id: userId }, select: { name: true, phone: true, profile: true } }),
  ]);
  const profile = (row
    ? Object.fromEntries(PROFILE_FIELDS.map((f) => [f, row[f] ?? '']))
    : Object.fromEntries(PROFILE_FIELDS.map((f) => [f, '']))) as ProfileRow;
  profile.fullName = user?.name ?? '';
  profile.phone = phoneForProfile(user?.phone ?? '');

  let ieltsBandSource: BandSource = 'you';
  if (!row || row.ieltsBandSource !== 'you' || !row.ieltsBand.trim()) {
    const auto = await ieltsBandFromApp(userId, user?.profile);
    profile.ieltsBand = auto.band;
    ieltsBandSource = auto.source;
  }

  // Keep the web platform's copy in step (only when something changed).
  if (
    row &&
    (row.fullName !== profile.fullName || row.phone !== profile.phone || row.ieltsBand !== profile.ieltsBand)
  ) {
    await prisma.nextedProfile
      .update({
        where: { userId },
        data: { fullName: profile.fullName, phone: profile.phone, ieltsBand: profile.ieltsBand },
      })
      .catch(() => undefined);
  }
  return { profile, ieltsBandSource };
}

async function loadProfile(userId: string): Promise<ProfileRow> {
  return (await loadProfileFull(userId)).profile;
}

/**
 * What the finders need before they can give an honest answer. Without these
 * a "match" is a guess, so the course and scholarship finders refuse and the
 * app sends the student to their profile instead. Same list as the app's
 * NextedProfileRules.required.
 */
const REQUIRED_FOR_AI: ReadonlyArray<readonly [keyof ProfileRow, string]> = [
  ['fullName', 'Full name'],
  ['nationality', 'Nationality'],
  ['highestLevel', 'Highest education'],
  ['result', 'Result / GPA'],
  ['ieltsBand', 'IELTS band'],
  ['studyLevel', 'Level you want to study'],
  ['subject', 'Subject you want to study'],
  ['preferredCountry', 'Preferred country'],
  ['hasPublication', 'Publications'],
];

/** True when every field the AI features need is filled in. */
function profileComplete(p: ProfileRow): boolean {
  return REQUIRED_FOR_AI.every(([key]) => String(p[key] ?? '').trim());
}

function requireCompleteProfile(p: ProfileRow): void {
  const missing = REQUIRED_FOR_AI.filter(([key]) => !String(p[key] ?? '').trim()).map(([, label]) => label);
  if (missing.length) {
    throw new HttpError(
      409,
      'Please complete your profile first, so we can match you properly.',
      'profile_incomplete',
      { missing },
    );
  }
}

function profileSummary(p: ProfileRow): string {
  return PROFILE_FIELDS.filter((f) => p[f]).map((f) => `${f}: ${p[f]}`).join('\n') || '(the profile is empty)';
}

/**
 * Words worth searching on. "ICT and business courses" → ict, business.
 *
 * Searching the student's whole sentence as one string is why typing "ict"
 * used to return nothing: `contains` wanted that exact run of characters in
 * one column, and a catalogue of a few dozen rows almost never has it.
 */
const SEARCH_STOP = new Set([
  'and', 'or', 'the', 'for', 'with', 'from', 'into', 'about',
  'course', 'courses', 'program', 'programme', 'programs', 'programmes',
  'degree', 'degrees', 'study', 'studies', 'studying', 'university', 'universities',
  'want', 'looking', 'show', 'find', 'need', 'please', 'any', 'all', 'some',
]);

function searchWords(query: string): string[] {
  return [
    ...new Set(
      query
        .toLowerCase()
        .split(/[^a-z0-9+#]+/)
        .map((w) => w.trim())
        .filter((w) => w.length >= 2 && !SEARCH_STOP.has(w)),
    ),
  ].slice(0, 6);
}

/** `contains` on each field, for one word. */
function wordClauses(word: string, fields: readonly string[]): Record<string, unknown>[] {
  return fields.map((f) => ({ [f]: { contains: word, mode: 'insensitive' as const } }));
}

/**
 * Runs the tiers in order and returns the first that finds anything, with a
 * note saying which one answered.
 *
 * The point is that a search never ends on an empty screen while the
 * catalogue has rows in it. A student who types "ICT" and sees nothing
 * concludes the app is broken; shown the closest matches and told plainly
 * that nothing matched the word, they have an answer they can act on.
 */
async function firstNonEmpty<T>(
  tiers: { note: string; run: () => Promise<T[]> }[],
): Promise<{ rows: T[]; note: string }> {
  for (const tier of tiers) {
    const rows = await tier.run();
    if (rows.length) return { rows, note: tier.note };
  }
  return { rows: [], note: '' };
}

/** The student's scope for the restriction rules. */
function scopeOf(p: ProfileRow, subject = ''): StudentScope {
  return {
    homeDistrict: p.homeDistrict,
    level: p.highestLevel,
    subject,
    intake: p.preferredIntake,
  };
}

/**
 * Every live restriction rule. There are a few dozen of them, so this is one
 * small query rather than a lookup per course.
 */
async function loadRestrictions(): Promise<RestrictionRule[]> {
  return prisma.nextedRestriction.findMany({ where: { active: true } });
}

/**
 * The settled restriction facts for this student, as short lines the AI is
 * handed rather than asked to recall.
 *
 * The decision is already made before the model sees anything: a rule that
 * closes a university for this student's district, level, subject or intake
 * arrives as CLOSED, and one we cannot resolve arrives as UNCERTAIN. The
 * model's only job is to say it in a sentence.
 */
function restrictionBlock(rules: RestrictionRule[], p: ProfileRow): string {
  const universities = [...new Set(rules.map((r) => r.university))];
  const lines = restrictionFacts(rules, universities, scopeOf(p));
  if (!lines.length) return '';
  return (
    '\n\nNextED partner restrictions that apply to THIS student (settled facts - do not ' +
    'contradict, soften or re-check them):\n' +
    lines.join('\n') +
    '\nCLOSED means you must not present it as available. Say it is not available through ' +
    'NextED for this intake and offer a counsellor. UNCERTAIN means say plainly that it ' +
    'depends on a detail we do not have yet. Never say a university rejects Bangladeshi ' +
    'students - this is NextED partner information, not a published university policy.'
  );
}

/**
 * The deterministic half of the check, run after the reply is written.
 *
 * A prompt is a request; this is the part that cannot be talked out of. Any
 * closed university the reply names is returned alongside it, so the app can
 * show the restriction next to the answer whatever the model chose to write.
 */
function flagClosed(reply: string, rules: RestrictionRule[], p: ProfileRow): string[] {
  const named: string[] = [];
  for (const u of new Set(rules.map((r) => r.university))) {
    if (!reply.toLowerCase().includes(u.toLowerCase().replace(/^the\s+/, ''))) continue;
    if (checkRestrictions(rules, u, scopeOf(p)).status === 'closed') named.push(u);
  }
  return named;
}

/** NXT-APP-0000123 */
async function nextReference(): Promise<string> {
  const count = await prisma.nextedApplication.count();
  for (let i = 1; i <= 5; i++) {
    const ref = `NXT-APP-${String(count + i).padStart(7, '0')}`;
    const taken = await prisma.nextedApplication.findUnique({ where: { reference: ref }, select: { id: true } });
    if (!taken) return ref;
  }
  return `NXT-APP-${randomUUID().slice(0, 7).toUpperCase()}`;
}

export function registerNextedRoutes(r: Router): void {
  // ── profile ───────────────────────────────────────────────────────────────

  // `ieltsBandSource`: "you" (typed here), "mock" (latest full mock test),
  // "target" (the target band) or "" (nothing yet). `accountFields` are shown
  // from the account: the name is edited here or in the IELTS profile (both
  // change the same account), the phone is the login number.
  r.get('/v1/nexted/profile', async (ctx) => {
    const userId = requireUser(ctx);
    // The study-abroad profile is complete for the first time: a copy of the
    // student's data goes to the archive, once (lib/archive.ts).
    if (profileComplete(await loadProfile(userId))) archiveOnce(userId, 'nexted_profile_complete');
    return { ...(await loadProfileFull(userId)), accountFields: ['fullName', 'phone'] };
  });

  r.patch('/v1/nexted/profile', async (ctx) => {
    const userId = requireUser(ctx);
    const patch: Partial<ProfileRow> & { ieltsBandSource?: string } = {};
    for (const f of PROFILE_FIELDS) {
      if (f === 'fullName' || f === 'phone') continue; // account fields, below
      if (ctx.body[f] !== undefined) patch[f] = s(ctx.body[f], 200);
    }
    if (patch.hasPublication !== undefined) {
      const v = patch.hasPublication.trim().toLowerCase();
      patch.hasPublication = v === 'yes' ? 'Yes' : v === 'no' ? 'No' : '';
    }

    // The name is the account's name: changing it here changes it in IELTS AI
    // too. The phone is the login number and is never changed from here.
    let name: string | undefined;
    if (ctx.body.fullName !== undefined) {
      name = s(ctx.body.fullName, 80);
      if (!name) throw badRequest('Name cannot be empty.');
    }

    // A band the student types wins over the automatic one. Sending the band
    // the app is already showing (unchanged) keeps it automatic; clearing the
    // field hands it back to the IELTS side.
    if (patch.ieltsBand !== undefined) {
      const current = await loadProfileFull(userId);
      const typed = patch.ieltsBand.trim();
      if (!typed) {
        patch.ieltsBandSource = '';
      } else if (current.ieltsBandSource !== 'you' && typed === current.profile.ieltsBand) {
        delete patch.ieltsBand;
      } else {
        patch.ieltsBandSource = 'you';
      }
    }

    if (!Object.keys(patch).length && name === undefined) throw badRequest('Nothing to update.');
    if (name !== undefined) await prisma.user.update({ where: { id: userId }, data: { name } });
    if (Object.keys(patch).length) {
      await prisma.nextedProfile.upsert({
        where: { userId },
        create: { userId, ...(await loadProfile(userId)), ...patch },
        update: patch,
      });
    }
    return { ...(await loadProfileFull(userId)), accountFields: ['fullName', 'phone'] };
  });

  // ── documents ─────────────────────────────────────────────────────────────

  r.get('/v1/nexted/documents', async (ctx) => {
    const userId = requireUser(ctx);
    const rows = await prisma.nextedDocument.findMany({
      where: { userId },
      orderBy: { uploadedAt: 'desc' },
      take: 200,
    });
    return {
      documents: await Promise.all(
        rows.map(async (d) => ({
          id: d.id,
          kind: d.kind,
          level: d.level,
          name: d.name,
          status: d.status,
          note: d.note,
          bytes: d.bytes,
          uploadedAt: d.uploadedAt.toISOString(),
          url: await signedUrl(d.r2Key).catch(() => null),
        })),
      ),
    };
  });

  /**
   * Upload one document: raw bytes with the file's Content-Type.
   *   POST /v1/nexted/documents?kind=passport&ext=jpg&name=Passport
   */
  const uploadDocument = async (ctx: Ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`nexted-doc:${userId}`, 60, 3600);
    const kind = (s(ctx.query.get('kind'), 20) || 'other').toLowerCase();
    if (!DOC_KINDS.has(kind)) throw badRequest('Unknown document type.');
    // A transcript or certificate says which one: SSC, HSC, Bachelor's, Master's.
    const level = (s(ctx.query.get('level'), 20) || '').toLowerCase();
    if (level && !DOC_LEVELS.has(level)) throw badRequest('Unknown level.');
    // (Optional here so older app builds can still upload; the app asks.)
    const ext = (s(ctx.query.get('ext'), 5) || 'jpg').toLowerCase();
    if (!DOCUMENT_EXTS.has(ext)) throw badRequest('Upload a PDF, JPG or PNG file.', 'bad_file_type');
    const bytes = ctx.raw && ctx.raw.length ? ctx.raw : Buffer.from(s(ctx.body.base64, 25_000_000), 'base64');
    if (!bytes.length) throw badRequest('Empty upload.');
    if (bytes.length > MAX_DOC_BYTES) throw badRequest('The file is larger than 10 MB.', 'too_large');

    // Straight into Cloudflare R2, in this student's own folder:
    // users/<user id>/documents/<kind>[-<level>]/<uuid>.<ext>
    const folder = level && (kind === 'transcript' || kind === 'certificate') ? `${kind}-${level}` : kind;
    const key = appKey(`users/${userId}/documents/${folder}/${randomUUID()}.${ext}`);
    await putObject(key, bytes, contentTypeFor(ext));
    const doc = await prisma.nextedDocument.create({
      data: {
        userId,
        kind,
        level: kind === 'transcript' || kind === 'certificate' ? level : '',
        name: s(ctx.query.get('name'), 120) || kind,
        r2Key: key,
        bytes: bytes.length,
        status: 'Pending',
      },
    });
    return {
      document: {
        id: doc.id,
        kind: doc.kind,
        level: doc.level,
        name: doc.name,
        status: doc.status,
        bytes: doc.bytes,
        uploadedAt: doc.uploadedAt.toISOString(),
        url: await signedUrl(key).catch(() => null),
      },
    };
  };
  r.post('/v1/nexted/documents', uploadDocument);
  r.put('/v1/nexted/documents', uploadDocument);

  r.delete('/v1/nexted/documents/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const doc = await prisma.nextedDocument.findUnique({ where: { id: ctx.params.id } });
    if (!doc || doc.userId !== userId) throw notFound('Document not found.');
    await prisma.nextedDocument.delete({ where: { id: doc.id } });
    await deleteObjects([doc.r2Key]).catch((e) => console.error('[nexted] R2 delete failed', e));
    return { deleted: true };
  });

  // ── applications ──────────────────────────────────────────────────────────

  r.get('/v1/nexted/applications', async (ctx) => {
    const userId = requireUser(ctx);
    const rows = await prisma.nextedApplication.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      take: int(ctx.query.get('limit'), 100, 1, 200),
    });
    return {
      applications: rows.map((a) => ({
        id: a.id,
        reference: a.reference,
        type: a.type,
        title: a.title,
        provider: a.provider,
        status: a.status,
        createdAt: a.createdAt.toISOString(),
        updatedAt: a.updatedAt.toISOString(),
      })),
    };
  });

  r.get('/v1/nexted/applications/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const a = await prisma.nextedApplication.findUnique({
      where: { id: ctx.params.id },
      include: { events: { orderBy: { at: 'asc' } } },
    });
    if (!a || a.userId !== userId) throw notFound('Application not found.');
    return {
      application: {
        id: a.id,
        reference: a.reference,
        type: a.type,
        title: a.title,
        provider: a.provider,
        status: a.status,
        createdAt: a.createdAt.toISOString(),
        updatedAt: a.updatedAt.toISOString(),
        history: a.events.map((e) => ({ status: e.status, note: e.note, at: e.at.toISOString() })),
      },
      steps: STATUS_STEPS,
    };
  });

  /**
   * Direct Apply. Creates the record and leaves it for NextED staff, who work
   * it manually on the web. The app never moves a status itself.
   */
  r.post('/v1/nexted/applications', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`nexted-apply:${userId}`, 30, 3600);
    const type = (s(ctx.body.type, 20) || 'course').toLowerCase();
    if (!['course', 'scholarship', 'university'].includes(type)) throw badRequest('Unknown application type.');
    const title = s(ctx.body.title, 200);
    if (!title) throw badRequest('title is required.', 'missing_field');

    const app = await prisma.nextedApplication.create({
      data: {
        userId,
        reference: await nextReference(),
        type,
        refId: s(ctx.body.refId, 80),
        title,
        provider: s(ctx.body.provider, 200),
        status: STATUS_STEPS[0],
        events: { create: { status: STATUS_STEPS[0], note: 'Sent from the app' } },
      },
    });

    // Staff see it on the web; this also gives the student their own trail.
    await prisma.notification
      .create({
        data: {
          userId,
          type: 'nexted_application',
          title: 'Application sent',
          body: `${title} · ${app.reference}. Your counsellor will pick it up.`,
          target: '/nexted/application',
          args: { id: app.id },
        },
      })
      .catch(() => undefined);

    return {
      application: {
        id: app.id,
        reference: app.reference,
        type: app.type,
        title: app.title,
        provider: app.provider,
        status: app.status,
        createdAt: app.createdAt.toISOString(),
      },
    };
  });

  // ── AI ────────────────────────────────────────────────────────────────────
  // With NEXTED_AI_URL set, the three features run on the nextED AI service
  // (FastAPI, the `nexted-ai` project) through lib/nexted_ai.ts, and that
  // service keeps the daily allowance. Without it - or while it isn't
  // running - the built-in Gemini versions below answer, and every call
  // counts against the cap kept in this process (lib/nexted.ts).

  /** Runs [viaService] when the AI service is configured; falls back only if it can't be reached. */
  async function viaAiService<T>(viaService: () => Promise<T>): Promise<T | undefined> {
    if (!nextedAiEnabled()) return undefined;
    try {
      return await viaService();
    } catch (e) {
      if (e instanceof NextedAiUnreachable) {
        console.warn(`[nexted-ai] not reachable (${e.message}) - using the built-in AI`);
        return undefined;
      }
      throw e;
    }
  }

  r.get('/v1/nexted/ai/usage', async (ctx) => {
    const userId = requireUser(ctx);
    const remote = await viaAiService(() => aiUsage(userId));
    return remote ?? { usage: await readAiUsage(userId) };
  });

  // ── the conversation, kept ────────────────────────────────────────────────
  // Every question and answer is saved, so the chat is still there after the
  // app restarts (and on the student's other devices). The history the model
  // sees still comes from the app, so nothing here changes the answers.

  const THREAD_LIMIT = 200;

  async function saveExchange(userId: string, message: string, answer: Record<string, unknown> | undefined) {
    const reply = s(answer?.reply ?? answer?.message, 20000);
    if (!reply) return;
    const meta: Record<string, unknown> = {};
    if (answer?.office && typeof answer.office === 'object') meta.office = answer.office;
    if (Array.isArray(answer?.restricted) && answer.restricted.length) meta.restricted = answer.restricted;
    if (Array.isArray(answer?.actions) && answer.actions.length) meta.actions = answer.actions;
    const now = Date.now();
    await prisma.nextedChatMessage
      .createMany({
        data: [
          { userId, role: 'student', content: message, createdAt: new Date(now) },
          {
            userId,
            role: 'counsellor',
            content: reply,
            meta: Object.keys(meta).length ? (meta as Prisma.InputJsonValue) : undefined,
            createdAt: new Date(now + 1),
          },
        ],
      })
      .catch((e) => console.warn('[nexted] chat not saved:', e instanceof Error ? e.message : e));
  }

  /** The saved conversation, oldest first (the latest THREAD_LIMIT messages). */
  r.get('/v1/nexted/ai/counsellor/thread', async (ctx) => {
    const userId = requireUser(ctx);
    const rows = await prisma.nextedChatMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: THREAD_LIMIT,
    });
    return {
      messages: rows.reverse().map((m) => ({
        id: m.id,
        role: m.role,
        content: m.content,
        meta: m.meta ?? {},
        createdAt: m.createdAt.toISOString(),
      })),
    };
  });

  /** Start the conversation again. The profile and documents are not touched. */
  r.delete('/v1/nexted/ai/counsellor/thread', async (ctx) => {
    const userId = requireUser(ctx);
    const { count } = await prisma.nextedChatMessage.deleteMany({ where: { userId } });
    return { cleared: count };
  });

  r.post('/v1/nexted/ai/counsellor', async (ctx) => {
    const userId = requireUser(ctx);
    const message = s(ctx.body.message, 4000);
    if (!message) throw badRequest('message is required.', 'missing_field');
    const history = Array.isArray(ctx.body.history) ? ctx.body.history.slice(-12) : [];
    const profile = await loadProfile(userId);

    const remote = await viaAiService(() => aiCounsellor(userId, profile, message, history));
    const answer = finishAnswer((remote ?? (await builtinCounsellor(userId, profile, message, history))) as Record<string, unknown>);
    await saveExchange(userId, message, answer as Record<string, unknown>);
    return answer;
  });

  /**
   * The counsellor, typed out as it is written (Server-Sent Events):
   *   event: token  data: {"t": "..."}      many
   *   event: done   data: {reply, usage ...} once, the same body as above
   *   event: error  data: {code, error}     instead of done, if it fails part way
   * An error before the first piece (limit reached, bad request) is a normal
   * JSON error reply, exactly like POST /v1/nexted/ai/counsellor.
   */
  r.post('/v1/nexted/ai/counsellor/stream', async (ctx) => {
    const userId = requireUser(ctx);
    const message = s(ctx.body.message, 4000);
    if (!message) throw badRequest('message is required.', 'missing_field');
    const history = Array.isArray(ctx.body.history) ? ctx.body.history.slice(-12) : [];
    const profile = await loadProfile(userId);
    const res = ctx.res;

    let open = false;
    const send = (event: string, data: unknown) => {
      if (!open) {
        res.writeHead(200, {
          'Content-Type': 'text/event-stream; charset=utf-8',
          'Cache-Control': 'no-cache, no-transform',
          Connection: 'keep-alive',
          'X-Accel-Buffering': 'no',
        });
        res.flushHeaders?.();
        open = true;
      }
      res.write(`event: ${event}\ndata: ${plainDashes(JSON.stringify(data))}\n\n`);
    };
    const gone = new AbortController();
    res.on('close', () => gone.abort());

    try {
      const body = await viaAiService(() =>
        aiCounsellorStream(userId, profile, message, history, (t) => send('token', { t }), gone.signal),
      );
      if (body) {
        const done = finishAnswer(body as Record<string, unknown>);
        await saveExchange(userId, message, done);
        send('done', done);
      } else {
        // Service off or not running: the built-in answer, typed out in
        // small pieces so the app behaves the same.
        const answer = finishAnswer(await builtinCounsellor(userId, profile, message, history));
        const words = String(answer.reply ?? '').split(/(?<= )/);
        for (let i = 0; i < words.length; i += 3) {
          if (gone.signal.aborted) break;
          send('token', { t: words.slice(i, i + 3).join('') });
          await new Promise((r) => setTimeout(r, 25));
        }
        await saveExchange(userId, message, answer);
        send('done', answer);
      }
    } catch (e) {
      if (!open) throw e; // nothing sent yet: a normal JSON error
      const err = e instanceof HttpError ? e : new HttpError(500, 'Something went wrong on the server.', 'server_error');
      send('error', { error: err.message, code: err.code ?? 'error', ...(err.extra ?? {}) });
    }
    if (open) res.end();
    return undefined;
  });

  async function builtinCounsellor(
    userId: string,
    profile: ProfileRow,
    message: string,
    history: unknown[],
  ): Promise<Record<string, unknown>> {
    const rules = await loadRestrictions();

    // "How do I reach a counsellor?" and "what does nextED cost?" are fixed
    // answers pointing at the office - never the model, and no AI credit.
    const fixed = fixedIntent(message);
    if (fixed) {
      return {
        reply: fixed === 'fee' ? feeResponse() : contactResponse(),
        office: OFFICE,
        restricted: [],
        needsHomeDistrict: !profile.homeDistrict,
        usage: await readAiUsage(userId),
      };
    }

    const usage = await consumeAi(userId);

    const transcript = history
      .map((h) => {
        const m = obj(h);
        return `${s(m.role, 20) === 'student' ? 'Student' : 'Counsellor'}: ${s(m.content, 2000)}`;
      })
      .join('\n');

    const { data } = await geminiJson({
      label: 'nexted-counsellor',
      system:
        'You are a NextED study-abroad counsellor talking to a student from Bangladesh in the NextED app. ' +
        'Be concrete and honest; never invent university names, fees, deadlines or visa rules you are not sure of - ' +
        'say a NextED counsellor will work it out with them instead. When you point the student to NextED, make it ' +
        'the clear next step, never an option: not "if you need help, a counsellor can confirm the details" or ' +
        '"feel free to request a counsellor", but "this is exactly what our counsellors at NextED do - come to NextED ' +
        'and we will <the specific work> with you". Formatting contract: use "#" and "##" headings, short paragraphs ' +
        'and plain "- " bullets. Never use emoji, numbered emoji lists or long walls of text. Keep it under 200 words.',
      user: `The student's profile:\n${profileSummary(profile)}${restrictionBlock(
        rules,
        profile,
      )}\n\nConversation so far:\n${transcript}\n\nStudent's new message:\n${message}`,
      schema: { type: 'object', properties: { reply: { type: 'string' } }, required: ['reply'] },
    });

    const reply = s(data.reply, 6000);
    // No office card on ordinary answers: the student gets the contact
    // details only when they ask for them (the fixed answers above).
    return {
      reply,
      // Closed universities the reply named, decided in code after the fact.
      // The app shows these next to the answer, so a model that forgot the
      // restriction cannot leave the student with a wrong impression.
      restricted: flagClosed(reply, rules, profile).map((u) => ({
        university: u,
        ...(({ message, detail }) => ({ message, detail }))(checkRestrictions(rules, u, scopeOf(profile))),
      })),
      // Empty home district is why some answers have to stay uncertain.
      needsHomeDistrict: !profile.homeDistrict,
      usage,
    };
  }

  // ── the latest finder results, kept ───────────────────────────────────────
  // A search that found something replaces the saved one; the screen opens
  // on it next time (on any device) until the student searches again.

  type SearchKind = 'courses' | 'scholarships';

  const saving =
    (kind: SearchKind, handler: (ctx: Ctx) => Promise<unknown>) =>
    async (ctx: Ctx) => {
      const out = (await handler(ctx)) as Record<string, unknown>;
      const list = out?.[kind];
      if (Array.isArray(list) && list.length) {
        const userId = requireUser(ctx);
        const query = s(ctx.body.query, 200);
        const { usage: _usage, ...result } = out;
        await prisma.nextedSavedSearch
          .upsert({
            where: { userId_kind: { userId, kind } },
            create: { userId, kind, query, result: result as Prisma.InputJsonValue },
            update: { query, result: result as Prisma.InputJsonValue },
          })
          .catch((e) => console.warn('[nexted] search not saved:', e instanceof Error ? e.message : e));
      }
      return out;
    };

  /** The saved results: {query, savedAt, ...the answer} or {} for none yet. */
  for (const kind of ['courses', 'scholarships'] as const) {
    r.get(`/v1/nexted/ai/${kind}/last`, async (ctx) => {
      const userId = requireUser(ctx);
      const row = await prisma.nextedSavedSearch.findUnique({ where: { userId_kind: { userId, kind } } });
      if (!row) return {};
      return { ...(row.result as Record<string, unknown>), query: row.query, savedAt: row.updatedAt.toISOString() };
    });
  }

  r.post('/v1/nexted/ai/courses', saving('courses', async (ctx) => {
    const userId = requireUser(ctx);
    const profile = await loadProfile(userId);
    requireCompleteProfile(profile);
    const query = s(ctx.body.query, 200);

    const remote = await viaAiService(() => aiCourses(userId, profile, query));
    if (remote) return remote;

    const rules = await loadRestrictions();

    const words = searchWords(query);
    const fields = ['title', 'subject', 'university', 'country', 'level'] as const;
    const inCountry = profile.preferredCountry
      ? { country: { contains: profile.preferredCountry, mode: 'insensitive' as const } }
      : {};
    // Any of the words, in any of the fields.
    const matchesWords = words.length ? { OR: words.flatMap((w) => wordClauses(w, fields)) } : {};

    // Narrowest first, then give up one constraint at a time rather than
    // handing back an empty screen.
    const { rows: candidates, note: searchNote } = await firstNonEmpty([
      {
        note: '',
        run: () =>
          prisma.nextedCourse.findMany({ where: { active: true, ...inCountry, ...matchesWords }, take: 40 }),
      },
      {
        note: words.length
          ? `Nothing in the catalogue matches “${query}” yet. These are the closest for your profile.`
          : '',
        run: () =>
          words.length && profile.preferredCountry
            ? prisma.nextedCourse.findMany({ where: { active: true, ...inCountry }, take: 40 })
            : Promise.resolve([]),
      },
      {
        note: words.length
          ? `Nothing matches “${query}”${
              profile.preferredCountry ? ` in ${profile.preferredCountry}` : ''
            } yet. Here is what the catalogue does have.`
          : profile.preferredCountry
            ? `No courses in ${profile.preferredCountry} yet. Here is what the catalogue does have.`
            : '',
        run: () => prisma.nextedCourse.findMany({ where: { active: true }, take: 40 }),
      },
    ]);

    if (!candidates.length) {
      return { courses: [], catalogueEmpty: true, usage: await readAiUsage(userId) };
    }

    const usage = await consumeAi(userId);

    const { data } = await geminiJson({
      label: 'nexted-courses',
      system:
        'You rank university courses for a study-abroad student. Use only the courses given to you - never invent ' +
        'a course, university, fee or intake. Score each one 0-100 for how well it fits the student, and explain ' +
        'in one or two short sentences. Return at most 12, best first.',
      user: `Student profile:\n${profileSummary(profile)}\n\n${query ? `They also asked for: ${query}\n\n` : ''}Courses (JSON):\n${JSON.stringify(
        candidates.map((c) => ({
          id: c.id,
          title: c.title,
          university: c.university,
          country: c.country,
          level: c.level,
          subject: c.subject,
          duration: c.duration,
          intake: c.intake,
          tuition: c.tuition,
          minIelts: c.minIelts,
        })),
      )}`,
      schema: {
        type: 'object',
        properties: {
          matches: {
            type: 'array',
            items: {
              type: 'object',
              properties: { id: { type: 'string' }, confidence: { type: 'number' }, why: { type: 'string' } },
              required: ['id', 'confidence'],
            },
          },
        },
        required: ['matches'],
      },
    });

    const byId = new Map(candidates.map((c) => [c.id, c]));
    const matches = Array.isArray(data.matches) ? data.matches : [];
    const courses = matches
      .map((m) => {
        const row = byId.get(s(obj(m).id, 60));
        if (!row) return null;
        const score = Number(obj(m).confidence);
        return {
          id: row.id,
          title: row.title,
          university: row.university,
          country: row.country,
          level: row.level,
          duration: row.duration,
          intake: row.intake,
          tuition: row.tuition,
          confidence: Number.isFinite(score) ? Math.min(100, Math.max(0, score)) : 0,
          why: s(obj(m).why, 500),
          // Decided in code from the rules table, not by the model above.
          restriction: checkRestrictions(rules, row.university, scopeOf(profile, row.subject)),
        };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null)
      // A closed course is pushed to the bottom, never removed: a student who
      // cannot find the university they had in mind assumes the list is
      // broken. Shown with the reason, it is an answer.
      .sort((a, b) => {
        const rank = (v: string) => (v === 'closed' ? 2 : v === 'check' ? 1 : 0);
        return rank(a.restriction.status) - rank(b.restriction.status) || b.confidence - a.confidence;
      });

    return { courses, searchNote, needsHomeDistrict: !profile.homeDistrict, usage };
  }));

  r.post('/v1/nexted/ai/scholarships', saving('scholarships', async (ctx) => {
    const userId = requireUser(ctx);
    const profile = await loadProfile(userId);
    requireCompleteProfile(profile);
    const query = s(ctx.body.query, 200);

    const remote = await viaAiService(() => aiScholarships(userId, profile, query));
    if (remote) return remote;

    const words = searchWords(query);
    const fields = ['title', 'provider', 'country', 'level'] as const;

    // Same rule as the course search: a word that matches nothing narrows the
    // list, it does not empty the screen.
    const { rows: candidates, note: searchNote } = await firstNonEmpty([
      {
        note: '',
        run: () =>
          prisma.nextedScholarship.findMany({
            where: {
              active: true,
              ...(words.length ? { OR: words.flatMap((w) => wordClauses(w, fields)) } : {}),
            },
            take: 30,
          }),
      },
      {
        note: words.length
          ? `No scholarship in the catalogue mentions “${query}” yet. These are the ones you could be eligible for.`
          : '',
        run: () =>
          words.length ? prisma.nextedScholarship.findMany({ where: { active: true }, take: 30 }) : Promise.resolve([]),
      },
    ]);

    if (!candidates.length) {
      return { scholarships: [], catalogueEmpty: true, usage: await readAiUsage(userId) };
    }

    // The verdict is decided here, by comparing the profile with each
    // scholarship's stored criteria. The AI only phrases the reasons.
    const judged = candidates.map((x) => ({
      row: x,
      ...eligibility(profile, {
        minIelts: x.minIelts,
        minGpa: x.minGpa,
        nationalities: x.nationalities,
        level: x.level,
        title: x.title,
      }),
    }));

    const usage = await consumeAi(userId);

    let phrased = new Map<string, string[]>();
    try {
      const { data } = await geminiJson({
        label: 'nexted-scholarships',
        system:
          'You explain scholarship eligibility to a student. The verdict and the facts are already decided and are ' +
          'correct - do not change them, do not add requirements, do not invent anything. Rewrite the facts for each ' +
          'scholarship as one or two short, plain sentences the student can act on.',
        user: JSON.stringify(
          judged.map((j) => ({ id: j.row.id, title: j.row.title, verdict: j.verdict, facts: j.facts })),
        ),
        schema: {
          type: 'object',
          properties: {
            items: {
              type: 'array',
              items: {
                type: 'object',
                properties: { id: { type: 'string' }, reasons: { type: 'array', items: { type: 'string' } } },
                required: ['id', 'reasons'],
              },
            },
          },
          required: ['items'],
        },
      });
      const items = Array.isArray(data.items) ? data.items : [];
      phrased = new Map(
        items.map((i) => {
          const m = obj(i);
          const reasons = Array.isArray(m.reasons) ? m.reasons.map((x) => s(x, 300)).filter(Boolean) : [];
          return [s(m.id, 60), reasons];
        }),
      );
    } catch (e) {
      // The rules already answered; a failed phrasing must not lose the verdict.
      console.error('[nexted] scholarship phrasing failed', e);
    }

    const order = { Eligible: 0, Borderline: 1, 'Not eligible': 2 } as const;
    const scholarships = judged
      .sort((a, b) => order[a.verdict] - order[b.verdict])
      .map((j) => ({
        id: j.row.id,
        title: j.row.title,
        provider: j.row.provider,
        country: j.row.country,
        amount: j.row.amount,
        deadline: j.row.deadline,
        verdict: j.verdict,
        reasons: phrased.get(j.row.id)?.length ? phrased.get(j.row.id) : j.facts,
      }));

    return { scholarships, searchNote, usage };
  }));
}
