// Student progress: attempts, saved state (kv), notifications, study tasks,
// plus one /v1/sync call the app uses to pull everything changed since its
// last sync. Records use the same JSON shape as the app's local Store.

import { prisma } from '../db';
import { badRequest, forbidden, HttpError, int, notFound, obj, required, Router, s, type Ctx } from '../lib/http';
import { requireUser } from '../lib/users';

type Row = Record<string, unknown>;

const SKILLS = new Set(['listening', 'reading', 'writing', 'speaking', 'mock', 'vocab']);
const MAX_JSON_BYTES = 512 * 1024;

function jsonSize(v: unknown): number {
  return Buffer.byteLength(JSON.stringify(v ?? null));
}

function date(v: unknown, fallback: Date | null = null): Date | null {
  if (v == null || v === '') return fallback;
  const d = new Date(String(v));
  return Number.isNaN(d.getTime()) ? fallback : d;
}

/** 'YYYY-MM-DD' -> UTC midnight Date (study-task dates are calendar days). */
function day(v: unknown): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s(v, 20));
  if (!m) throw badRequest('date must be YYYY-MM-DD.');
  return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
}

const numOrNull = (v: unknown) => (v === null || v === undefined || v === '' ? null : Number.isFinite(Number(v)) ? Number(v) : null);

// ── mappers ─────────────────────────────────────────────────────────────────

export function attemptJson(a: {
  id: string;
  skill: string;
  kind: string;
  title: string | null;
  refId: string | null;
  band: number | null;
  score: number | null;
  total: number | null;
  durationSec: number | null;
  data: unknown;
  createdAt: Date;
}) {
  return {
    id: a.id,
    skill: a.skill,
    kind: a.kind,
    title: a.title ?? '',
    refId: a.refId ?? '',
    band: a.band,
    score: a.score,
    total: a.total,
    durationSec: a.durationSec ?? 0,
    createdAt: a.createdAt.toISOString(),
    data: (a.data ?? {}) as Row,
  };
}

function notificationJson(n: {
  id: string;
  type: string;
  skill: string | null;
  title: string;
  body: string | null;
  read: boolean;
  target: string | null;
  args: unknown;
  createdAt: Date;
}) {
  return {
    id: n.id,
    type: n.type,
    skill: n.skill ?? '',
    title: n.title,
    body: n.body ?? '',
    read: n.read,
    target: n.target ?? '',
    ...(n.args ? { args: n.args } : {}),
    createdAt: n.createdAt.toISOString(),
  };
}

function taskJson(t: {
  id: string;
  title: string;
  skill: string | null;
  kind: string | null;
  time: string | null;
  durationMin: number | null;
  done: boolean;
  target: string | null;
  date: Date;
}) {
  return {
    id: t.id,
    title: t.title,
    skill: t.skill ?? '',
    kind: t.kind ?? '',
    date: t.date.toISOString().slice(0, 10),
    time: t.time ?? '',
    durationMin: t.durationMin ?? 0,
    done: t.done,
    target: t.target ?? '',
  };
}

// ── attempts ────────────────────────────────────────────────────────────────

/**
 * Saves an attempt the app scored itself (reading, listening, vocab, lessons,
 * study sessions …). Upserts by the app's own id so offline results can be
 * re-sent safely. AI-graded writing/speaking attempts are created by their
 * own routes (with the app's id); a later save here only adds the app's extra
 * fields - the evaluation and band stay the server's.
 */
/** Keys of an AI-graded attempt that only the server writes. */
const SERVER_OWNED = ['evaluation', 'task1', 'task2', 'sessionId', 'status', 'message', 'noSpeech', 'recordings', 'segments'];

async function saveAttempt(userId: string, body: Row) {
  const id = required(body, 'id', 80);
  if (!/^[A-Za-z0-9_\-]+$/.test(id)) throw badRequest('Invalid attempt id.');
  const skill = required(body, 'skill', 20);
  if (!SKILLS.has(skill)) throw badRequest(`Unknown skill "${skill}".`);
  const data = { ...obj(body.data) };
  delete data.aiGraded; // only the server marks AI-graded attempts
  if (jsonSize(data) > MAX_JSON_BYTES) throw new HttpError(413, 'Attempt data is too large.', 'too_large');

  const existing = await prisma.attempt.findUnique({ where: { id }, select: { userId: true, data: true, band: true } });
  if (existing && existing.userId !== userId) throw forbidden('This attempt id belongs to another account.');
  const serverData = existing ? ((existing.data as Row | null) ?? {}) : {};
  const aiGraded = serverData.aiGraded === true;

  const fields = {
    skill,
    kind: required(body, 'kind', 40),
    title: s(body.title, 300) || null,
    refId: s(body.refId, 120) || null,
    band: numOrNull(body.band),
    score: numOrNull(body.score) === null ? null : Math.trunc(Number(body.score)),
    total: numOrNull(body.total) === null ? null : Math.trunc(Number(body.total)),
    durationSec: int(body.durationSec, 0, 0, 86400),
    data,
  };
  if (aiGraded) {
    // The app keeps its own copy of an AI-graded attempt (same id). Its extra
    // fields are merged in, but the server's evaluation and band always win.
    const merged: Row = { ...serverData, ...data, aiGraded: true };
    for (const k of SERVER_OWNED) if (k in serverData) merged[k] = serverData[k];
    fields.data = merged;
    fields.band = existing!.band;
  }
  const createdAt = date(body.createdAt, new Date()) as Date;
  const row = await prisma.attempt.upsert({
    where: { id },
    create: { id, userId, createdAt, ...fields },
    update: aiGraded ? { ...fields, skill: undefined } : fields,
  });
  return attemptJson(row);
}

// ── state (kv) ──────────────────────────────────────────────────────────────

function stateKey(k: string): string {
  if (!k || k.length > 200 || !/^[A-Za-z0-9_.:\-]+$/.test(k)) throw badRequest(`Invalid state key "${k}".`);
  return k;
}

async function putState(userId: string, key: string, value: unknown) {
  if (value === null || value === undefined) {
    await prisma.userState.deleteMany({ where: { userId, key } });
    return;
  }
  if (jsonSize(value) > MAX_JSON_BYTES) throw new HttpError(413, `State "${key}" is too large.`, 'too_large');
  await prisma.userState.upsert({
    where: { userId_key: { userId, key } },
    create: { userId, key, value: value as object },
    update: { value: value as object },
  });
}

// ── routes ──────────────────────────────────────────────────────────────────

function sinceParam(ctx: Ctx): Date | null {
  return date(ctx.query.get('since'));
}

export function registerProgressRoutes(r: Router): void {
  // Everything that changed since ?since= (ISO time from the last sync's serverTime).
  r.get('/v1/sync', async (ctx) => {
    const userId = requireUser(ctx);
    const since = sinceParam(ctx);
    const changed = since ? { updatedAt: { gt: since } } : {};
    const serverTime = new Date().toISOString();
    const [attempts, notifications, tasks, state] = await Promise.all([
      prisma.attempt.findMany({ where: { userId, ...changed }, orderBy: { createdAt: 'desc' }, take: 2000 }),
      prisma.notification.findMany({ where: { userId, ...changed }, orderBy: { createdAt: 'desc' }, take: 200 }),
      prisma.studyTask.findMany({ where: { userId, ...changed }, orderBy: { date: 'asc' }, take: 1000 }),
      prisma.userState.findMany({ where: { userId, ...changed } }),
    ]);
    return {
      serverTime,
      full: !since,
      attempts: attempts.map(attemptJson),
      notifications: notifications.map(notificationJson),
      tasks: tasks.map(taskJson),
      state: Object.fromEntries(state.map((x) => [x.key, x.value])),
    };
  });

  // Upload local changes in one call: {attempts: [...], state: {key: value|null}, tasks: [...]}
  r.post('/v1/sync', async (ctx) => {
    const userId = requireUser(ctx);
    const attempts = Array.isArray(ctx.body.attempts) ? (ctx.body.attempts as Row[]).slice(0, 500) : [];
    const saved: string[] = [];
    const rejected: Array<{ id: string; error: string }> = [];
    for (const a of attempts) {
      try {
        saved.push((await saveAttempt(userId, obj(a))).id);
      } catch (e) {
        rejected.push({ id: s(obj(a).id, 80), error: e instanceof Error ? e.message : 'failed' });
      }
    }
    for (const [key, value] of Object.entries(obj(ctx.body.state))) {
      await putState(userId, stateKey(key), value);
    }
    const tasks = Array.isArray(ctx.body.tasks) ? (ctx.body.tasks as Row[]).slice(0, 500) : [];
    for (const t of tasks) await upsertTask(userId, obj(t));
    const notes = Array.isArray(ctx.body.notifications) ? (ctx.body.notifications as Row[]).slice(0, 200) : [];
    for (const n of notes) {
      try {
        await upsertNotification(userId, obj(n));
      } catch (e) {
        console.error('[sync] notification skipped', e instanceof Error ? e.message : e);
      }
    }
    return { serverTime: new Date().toISOString(), attempts: { saved, rejected } };
  });

  r.get('/v1/attempts', async (ctx) => {
    const userId = requireUser(ctx);
    const where: Row = { userId };
    const skill = s(ctx.query.get('skill'), 20);
    const kind = s(ctx.query.get('kind'), 40);
    const refId = s(ctx.query.get('refId'), 120);
    const before = date(ctx.query.get('before'));
    if (skill) where.skill = skill;
    if (kind) where.kind = kind;
    if (refId) where.refId = refId;
    if (before) where.createdAt = { lt: before };
    const rows = await prisma.attempt.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: int(ctx.query.get('limit'), 50, 1, 500),
    });
    return { items: rows.map(attemptJson) };
  });

  r.get('/v1/attempts/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const row = await prisma.attempt.findUnique({ where: { id: ctx.params.id } });
    if (!row || row.userId !== userId) throw notFound('Attempt not found.');
    return { item: attemptJson(row) };
  });

  r.post('/v1/attempts', async (ctx) => ({ item: await saveAttempt(requireUser(ctx), ctx.body) }));

  r.delete('/v1/attempts/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const { count } = await prisma.attempt.deleteMany({ where: { id: ctx.params.id, userId } });
    return { deleted: count > 0 };
  });

  // Saved state: saved words, bookmarks, highlights, drafts, in-progress tests …
  r.get('/v1/state', async (ctx) => {
    const userId = requireUser(ctx);
    const prefix = s(ctx.query.get('prefix'), 200);
    const rows = await prisma.userState.findMany({
      where: { userId, ...(prefix ? { key: { startsWith: prefix } } : {}) },
    });
    return { state: Object.fromEntries(rows.map((x) => [x.key, x.value])) };
  });

  // {values: {key: value | null}} - null deletes.
  r.put('/v1/state', async (ctx) => {
    const userId = requireUser(ctx);
    const values = obj(ctx.body.values);
    for (const [key, value] of Object.entries(values)) await putState(userId, stateKey(key), value);
    return { ok: true, count: Object.keys(values).length };
  });

  r.put('/v1/state/:key', async (ctx) => {
    const userId = requireUser(ctx);
    await putState(userId, stateKey(ctx.params.key), ctx.body.value);
    return { ok: true };
  });

  r.delete('/v1/state/:key', async (ctx) => {
    const userId = requireUser(ctx);
    await putState(userId, stateKey(ctx.params.key), null);
    return { ok: true };
  });

  r.get('/v1/notifications', async (ctx) => {
    const userId = requireUser(ctx);
    const rows = await prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: int(ctx.query.get('limit'), 50, 1, 200),
    });
    const unread = await prisma.notification.count({ where: { userId, read: false } });
    return { items: rows.map(notificationJson), unread };
  });

  r.post('/v1/notifications/read-all', async (ctx) => {
    const userId = requireUser(ctx);
    const { count } = await prisma.notification.updateMany({ where: { userId, read: false }, data: { read: true } });
    return { updated: count };
  });

  r.post('/v1/notifications/:id/read', async (ctx) => {
    const userId = requireUser(ctx);
    const { count } = await prisma.notification.updateMany({
      where: { id: ctx.params.id, userId },
      data: { read: true },
    });
    if (!count) throw notFound('Notification not found.');
    return { ok: true };
  });

  r.delete('/v1/notifications/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const { count } = await prisma.notification.deleteMany({ where: { id: ctx.params.id, userId } });
    return { deleted: count > 0 };
  });

  r.get('/v1/tasks', async (ctx) => {
    const userId = requireUser(ctx);
    const where: Row = { userId };
    const from = ctx.query.get('from');
    const to = ctx.query.get('to');
    if (from || to) where.date = { ...(from ? { gte: day(from) } : {}), ...(to ? { lte: day(to) } : {}) };
    const rows = await prisma.studyTask.findMany({ where, orderBy: [{ date: 'asc' }, { time: 'asc' }] });
    return { items: rows.map(taskJson) };
  });

  r.put('/v1/tasks/:id', async (ctx) => {
    const userId = requireUser(ctx);
    return { item: await upsertTask(userId, { ...ctx.body, id: ctx.params.id }) };
  });

  r.patch('/v1/tasks/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const task = await prisma.studyTask.findUnique({ where: { id: ctx.params.id } });
    if (!task || task.userId !== userId) throw notFound('Task not found.');
    const b = ctx.body;
    const updated = await prisma.studyTask.update({
      where: { id: task.id },
      data: {
        ...(b.title !== undefined ? { title: s(b.title, 200) || task.title } : {}),
        ...(b.done !== undefined ? { done: b.done === true } : {}),
        ...(b.time !== undefined ? { time: s(b.time, 5) || null } : {}),
        ...(b.date !== undefined ? { date: day(b.date) } : {}),
        ...(b.durationMin !== undefined ? { durationMin: int(b.durationMin, 0, 0, 1440) } : {}),
        ...(b.target !== undefined ? { target: s(b.target, 200) || null } : {}),
      },
    });
    return { item: taskJson(updated) };
  });

  r.delete('/v1/tasks/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const { count } = await prisma.studyTask.deleteMany({ where: { id: ctx.params.id, userId } });
    return { deleted: count > 0 };
  });
}

async function upsertTask(userId: string, b: Row) {
  const id = required(b, 'id', 80);
  if (!/^[A-Za-z0-9_\-]+$/.test(id)) throw badRequest('Invalid task id.');
  const existing = await prisma.studyTask.findUnique({ where: { id }, select: { userId: true } });
  if (existing && existing.userId !== userId) throw forbidden('This task id belongs to another account.');
  const fields = {
    title: required(b, 'title', 200),
    skill: s(b.skill, 20) || null,
    kind: s(b.kind, 40) || null,
    time: s(b.time, 5) || null,
    durationMin: int(b.durationMin, 0, 0, 1440),
    done: b.done === true,
    target: s(b.target, 200) || null,
    date: day(b.date),
  };
  const row = await prisma.studyTask.upsert({
    where: { id },
    create: { id, userId, ...fields },
    update: fields,
  });
  return taskJson(row);
}

/** Saves a notification the app created itself (welcome, score …) or its read flag. */
async function upsertNotification(userId: string, b: Row) {
  const id = required(b, 'id', 80);
  if (!/^[A-Za-z0-9_\-]+$/.test(id)) throw badRequest('Invalid notification id.');
  const existing = await prisma.notification.findUnique({ where: { id }, select: { userId: true } });
  if (existing && existing.userId !== userId) throw forbidden('This notification id belongs to another account.');
  const args = b.args && typeof b.args === 'object' ? (b.args as object) : undefined;
  const fields = {
    type: s(b.type, 40) || 'system',
    skill: s(b.skill, 20) || null,
    title: required(b, 'title', 300),
    body: s(b.body, 2000) || null,
    read: b.read === true,
    target: s(b.target, 200) || null,
    ...(args ? { args } : {}),
  };
  await prisma.notification.upsert({
    where: { id },
    create: { id, userId, createdAt: date(b.createdAt, new Date()) as Date, ...fields },
    update: fields,
  });
}
