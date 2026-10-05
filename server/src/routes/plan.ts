// Personal study plan (Phase 1, no AI): set-up answers + the student's own
// results -> an estimate, phases and daily tasks from the plan catalog.
//
// Tasks are ordinary StudyTask rows (kind 'plan') with deep-link args, so
// they reach the app through /v1/sync like any other task. The plan is filled
// about two weeks ahead and topped up whenever the app asks for the plan or
// syncs ("ensure"); missed tasks roll forward a little, then drop off.

import { randomBytes } from 'node:crypto';
import type { Prisma } from '@prisma/client';
import { prisma } from '../db';
import { env } from '../env';
import { badRequest, HttpError, notFound, obj, rateLimit, Router, s } from '../lib/http';
import {
  addDays,
  buildProfile,
  checkpointWeeks,
  daysBetween,
  dayKey,
  estimate,
  generateDays,
  loadCatalog,
  moduleBand,
  localToday,
  MODULES,
  normaliseInputs,
  parseDay,
  phaseLabel,
  phaseOf,
  phases,
  summary,
  TAG_LABELS,
  tagModule,
  weekday,
  type Catalog,
  type Estimate,
  type Evidence,
  type PlanInputs,
  type PlannedTask,
  type Profile,
} from '../lib/plan';
import { geminiJson } from '../lib/gemini';
import { aiWeek, planAiAllowed, rulesNote, type WeekContext, type WeekNote } from '../lib/plan_ai';
import { requireUser } from '../lib/users';

type Row = Record<string, unknown>;

/** Days filled ahead of today. */
const FILL_AHEAD = 13;
/** Missed tasks younger than this roll forward; older ones drop off. */
const ROLL_DAYS = 7;
/** A task that keeps rolling is dropped once it is this old. */
const ROLL_MAX_AGE_DAYS = 21;
const MAX_PAUSE_DAYS = 30;

const QC_WRITING_SYSTEM = `You are an experienced IELTS examiner. A student wrote ONE short paragraph (about 60 to 120 words) answering an opinion question, as a quick placement check, not a full Task 2 essay.
Estimate their level on the four IELTS writing criteria as half bands from 3.0 to 9.0:
TA (Task Response: answers the question, clear position, supported idea), CC (Coherence and Cohesion: logical order, linking), LR (Lexical Resource: range and accuracy of words), GRA (Grammatical Range and Accuracy).
Do not lower TA just because it is short; judge the paragraph for what it is. Be fair and consistent with real IELTS descriptors.
feedback: one short sentence in simple English on the most useful thing to improve. No em dashes.
Reply as JSON only.`;

const QC_WRITING_SCHEMA = {
  type: 'object',
  properties: {
    TA: { type: 'number' },
    CC: { type: 'number' },
    LR: { type: 'number' },
    GRA: { type: 'number' },
    feedback: { type: 'string' },
  },
  required: ['TA', 'CC', 'LR', 'GRA', 'feedback'],
};

let catalogCache: Catalog | null = null;
function catalog(): Catalog {
  return (catalogCache ??= loadCatalog());
}

const newTaskId = () => `pt_${Date.now().toString(36)}${randomBytes(5).toString('hex')}`;

// ── per-user lock (sync and the plan screen can ask at the same time) ──────

const locks = new Map<string, Promise<unknown>>();
async function withLock<T>(userId: string, fn: () => Promise<T>): Promise<T> {
  const prev = locks.get(userId) ?? Promise.resolve();
  const run = prev.catch(() => undefined).then(fn);
  locks.set(userId, run);
  try {
    return await run;
  } finally {
    if (locks.get(userId) === run) locks.delete(userId);
  }
}

// ── evidence ────────────────────────────────────────────────────────────────

async function loadEvidence(userId: string): Promise<Evidence> {
  const since = new Date(Date.now() - 180 * 86400000);
  const [attempts, lessons, qc] = await Promise.all([
    prisma.attempt.findMany({
      where: { userId, createdAt: { gte: since } },
      select: { skill: true, kind: true, refId: true, band: true, score: true, total: true, data: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
      take: 1500,
    }),
    prisma.userState.findUnique({ where: { userId_key: { userId, key: 'lessons.done' } } }),
    prisma.userState.findUnique({ where: { userId_key: { userId, key: QUICK_CHECK_KEY } } }),
  ]);
  const done = lessons?.value && typeof lessons.value === 'object' && !Array.isArray(lessons.value) ? Object.keys(lessons.value) : [];
  return {
    attempts: [
      ...attempts.map((a) => ({ ...a, data: (a.data as Row | null) ?? null })),
      ...quickCheckAttempts(qc?.value),
    ],
    lessonsDone: done,
  };
}

/** Saved quick-check result (state key, synced like other kv state). */
const QUICK_CHECK_KEY = 'plan.quickcheck';

/**
 * The quick check is kept out of the attempt history (it is not a test the
 * student would look back on); for the profile it becomes one result per
 * section: {at, reading, listening, grammar, vocab: band, writing: {band, criteria}}.
 */
function quickCheckAttempts(v: unknown): Evidence['attempts'] {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return [];
  const q = v as Row;
  const at = new Date(String(q.at ?? ''));
  const createdAt = Number.isNaN(at.getTime()) ? new Date() : at;
  const band = (x: unknown) => (Number.isFinite(Number(x)) && Number(x) >= 1 && Number(x) <= 9 ? Number(x) : null);
  const out: Evidence['attempts'] = [];
  for (const k of ['reading', 'listening', 'grammar', 'vocab']) {
    const b = band(q[k]);
    if (b != null) out.push({ skill: 'quickcheck', kind: 'quickcheck', refId: `qc_${k}`, band: b, score: null, total: null, data: null, createdAt });
  }
  const w = q.writing && typeof q.writing === 'object' ? (q.writing as Row) : null;
  if (w && band(w.band) != null) {
    out.push({ skill: 'writing', kind: 'quickcheck', refId: 'qc_writing', band: band(w.band), score: null, total: null, data: { criteria: obj(w.criteria) }, createdAt });
  }
  return out;
}

function doneRefsOf(ev: Evidence): Set<string> {
  const out = new Set<string>(ev.lessonsDone);
  for (const a of ev.attempts) if (a.refId) out.add(a.refId);
  return out;
}

/** Focus tags are shown only when the student has results for them. */
function shownEstimate(est: Estimate, profile: Profile) {
  const tags = est.focusTags.filter((t) => (profile[t]?.n ?? 0) > 0);
  return {
    ...est,
    focusTags: tags,
    focusLabels: tags.map((t) => TAG_LABELS[t] ?? t),
    phases: est.phases.map((p) => ({ ...p, label: phaseLabel(p.id) })),
  };
}

/** Estimate for a plan that started [elapsedWeeks] ago and is re-planned today. */
function rebased(inputs: PlanInputs, profile: Profile, today: string): Estimate {
  const elapsed = Math.max(0, Math.floor(daysBetween(inputs.startDate, today) / 7));
  const fresh = estimate({ ...inputs, startDate: today }, profile);
  if (!elapsed) return fresh;
  const weeks = fresh.weeks + elapsed;
  return {
    ...fresh,
    weeks,
    weeksMin: fresh.weeksMin + elapsed,
    weeksMax: fresh.weeksMax + elapsed,
    weeksToExam: fresh.weeksToExam == null ? null : fresh.weeksToExam + elapsed,
    phases: phases(weeks),
    checkpointWeeks: checkpointWeeks(weeks).filter((w) => w > elapsed),
  };
}

const endDateOf = (inputs: PlanInputs, est: Estimate) => addDays(inputs.startDate, est.weeks * 7 - 1);

// ── mappers ─────────────────────────────────────────────────────────────────

type PlanRow = {
  id: string;
  status: string;
  inputs: unknown;
  estimate: unknown;
  startDate: Date;
  endDate: Date;
  filledUntil: Date | null;
  pausedUntil: Date | null;
  adaptedWeek: number;
  weekNote: unknown;
  userId: string;
  version: number;
  createdAt: Date;
  updatedAt: Date;
};

type TaskRow = {
  id: string;
  title: string;
  skill: string | null;
  kind: string | null;
  time: string | null;
  durationMin: number | null;
  done: boolean;
  target: string | null;
  args: unknown;
  planId: string | null;
  itemId: string | null;
  ref: string | null;
  reason: string | null;
  removedAt: Date | null;
  date: Date;
};

export function planTaskJson(t: TaskRow) {
  return {
    id: t.id,
    title: t.title,
    skill: t.skill ?? '',
    kind: t.kind ?? '',
    date: dayKey(t.date),
    time: t.time ?? '',
    durationMin: t.durationMin ?? 0,
    done: t.done,
    target: t.target ?? '',
    ...(t.args && typeof t.args === 'object' ? { args: t.args } : {}),
    ...(t.planId ? { planId: t.planId } : {}),
    ...(t.itemId ? { itemId: t.itemId } : {}),
    ...(t.ref ? { ref: t.ref } : {}),
    ...(t.reason ? { reason: t.reason } : {}),
    ...(t.removedAt ? { removed: true } : {}),
  };
}

async function planJson(plan: PlanRow, today: string) {
  const inputs = plan.inputs as unknown as PlanInputs;
  const est = plan.estimate as unknown as Estimate & { focusLabels?: string[] };
  const week = Math.max(1, Math.min(est.weeks, Math.floor(daysBetween(inputs.startDate, today) / 7) + 1));
  const weekStart = addDays(inputs.startDate, (week - 1) * 7);
  const weekEnd = addDays(weekStart, 6);
  const tasks = await prisma.studyTask.findMany({
    where: { planId: plan.id, removedAt: null, date: { gte: parseDay(addDays(today, -7)) } },
    orderBy: [{ date: 'asc' }, { createdAt: 'asc' }],
  });
  const qc = await prisma.userState.findUnique({ where: { userId_key: { userId: plan.userId, key: QUICK_CHECK_KEY } } });
  const dueWhere = { planId: plan.id, removedAt: null, date: { lte: parseDay(today) } };
  const [doneSoFar, dueSoFar] = await Promise.all([
    prisma.studyTask.count({ where: { ...dueWhere, done: true } }),
    prisma.studyTask.count({ where: dueWhere }),
  ]);
  const inWeek = tasks.filter((t) => {
    const d = dayKey(t.date);
    return d >= weekStart && d <= weekEnd;
  });
  return {
    id: plan.id,
    status: plan.status,
    version: plan.version,
    inputs,
    estimate: est,
    summary: summary(inputs, est),
    startDate: dayKey(plan.startDate),
    endDate: dayKey(plan.endDate),
    pausedUntil: plan.pausedUntil ? dayKey(plan.pausedUntil) : null,
    today,
    week,
    weeks: est.weeks,
    phase: { id: phaseOf(est, week), label: phaseLabel(phaseOf(est, week)) },
    checkpointThisWeek: est.checkpointWeeks.includes(week),
    progress: {
      done: doneSoFar,
      due: dueSoFar,
      weekDone: inWeek.filter((t) => t.done).length,
      weekTotal: inWeek.length,
      minutesThisWeek: inWeek.filter((t) => t.done).reduce((m, t) => m + (t.durationMin ?? 0), 0),
    },
    weekNote: (() => {
      const n = plan.weekNote as WeekNote | null;
      return n && n.week === week ? { title: n.title, body: n.body, focus: n.focus, by: n.by } : null;
    })(),
    quickCheck: { done: Boolean(qc), at: qc && typeof qc.value === 'object' ? (qc.value as Row).at ?? null : null },
    tasks: tasks.map(planTaskJson),
  };
}

// ── generation ──────────────────────────────────────────────────────────────

function taskRows(userId: string, planId: string, inputs: PlanInputs, planned: PlannedTask[]) {
  return planned.map((t) => ({
    id: newTaskId(),
    userId,
    planId,
    title: t.title,
    skill: t.skill,
    kind: t.checkpoint ? 'checkpoint' : 'plan',
    time: inputs.studyTime,
    durationMin: t.minutes,
    target: t.route,
    args: t.args as object,
    itemId: t.itemId,
    ref: t.ref,
    reason: t.reason.slice(0, 300),
    date: parseDay(t.date),
  }));
}

/** Tasks for [from]..[to] of [plan], written to the database. */
async function fill(userId: string, plan: PlanRow, from: string, to: string, ev: Evidence) {
  const inputs = plan.inputs as unknown as PlanInputs;
  const est = plan.estimate as unknown as Estimate;
  const existing = await prisma.studyTask.findMany({
    where: { planId: plan.id, removedAt: null },
    select: { itemId: true, skill: true, durationMin: true },
  });
  const used: Record<string, number> = {};
  for (const t of existing) {
    if (t.skill && (MODULES as string[]).includes(t.skill)) used[t.skill] = (used[t.skill] ?? 0) + (t.durationMin ?? 0);
  }
  const state = {
    scheduled: new Set<string>(existing.map((t) => t.itemId ?? '').filter(Boolean)),
    doneRefs: doneRefsOf(ev),
  };
  const profile = buildProfile(inputs, ev, catalog());
  const planned = generateDays(inputs, est, profile, catalog(), state, from, to, `${userId}:${plan.id}`, used);
  const rows = taskRows(userId, plan.id, inputs, planned);
  const prevFilled = plan.filledUntil;
  await prisma.$transaction(async (tx) => {
    // Only one writer fills a given range (guards against a second server).
    const { count } = await tx.studyPlan.updateMany({
      where: { id: plan.id, filledUntil: prevFilled },
      data: { filledUntil: parseDay(to) },
    });
    if (count && rows.length) await tx.studyTask.createMany({ data: rows });
  });
  plan.filledUntil = parseDay(to);
  return rows.length;
}

const removeTasks = (where: Prisma.StudyTaskWhereInput) =>
  prisma.studyTask.updateMany({ where: { ...where, removedAt: null }, data: { removedAt: new Date() } });

// ── weekly adapting ─────────────────────────────────────────────────────────

const planWeek = (inputs: PlanInputs, est: Estimate, today: string) =>
  Math.max(1, Math.min(est.weeks, Math.floor(daysBetween(inputs.startDate, today) / 7) + 1));

function weekBounds(inputs: PlanInputs, week: number): [Date, Date] {
  const start = addDays(inputs.startDate, (week - 1) * 7);
  return [parseDay(start), parseDay(addDays(start, 6))];
}

/** What the week's note is written from: only the student's own numbers. */
/**
 * Last week's tasks: planned (incl. ones missed and dropped, but not ones
 * re-planned away before their day) and done. Read before missed tasks roll on.
 */
async function lastWeekStats(plan: PlanRow, inputs: PlanInputs, week: number): Promise<NonNullable<WeekContext['lastWeek']>> {
  const [pf, pt] = weekBounds(inputs, week - 1);
  const prev = await prisma.studyTask.findMany({
    where: { planId: plan.id, date: { gte: pf, lte: pt } },
    select: { done: true, durationMin: true, removedAt: true, date: true },
  });
  const counted = prev.filter((t) => !t.removedAt || t.removedAt.getTime() >= t.date.getTime() + 86400000);
  return {
    planned: counted.length,
    done: counted.filter((t) => t.done).length,
    minutesDone: counted.filter((t) => t.done).reduce((m, t) => m + (t.durationMin ?? 0), 0),
  };
}

async function weekContext(
  plan: PlanRow,
  inputs: PlanInputs,
  est: Estimate,
  profile: Profile,
  week: number,
  today: string,
  last?: WeekContext['lastWeek'],
): Promise<WeekContext> {
  const [from, to] = weekBounds(inputs, week);
  const rows = await prisma.studyTask.findMany({
    where: { planId: plan.id, removedAt: null, date: { gte: from, lte: to } },
    orderBy: [{ date: 'asc' }, { createdAt: 'asc' }],
  });
  const lastWeek = last !== undefined ? last : week > 1 ? await lastWeekStats(plan, inputs, week) : null;
  const before = ((plan.weekNote as WeekNote | null)?.bands ?? {}) as Record<string, number>;
  const byId = new Map(catalog().items.map((i) => [i.id, i]));
  const weakest = Object.entries(profile)
    .filter(([t, v]) => v.n > 0 && inputs.modules.includes(tagModule(t)))
    .sort((a, b) => a[1].band - b[1].band)
    .slice(0, 3)
    .map(([t, v]) => ({ skill: TAG_LABELS[t] ?? t, band: v.band, results: v.n }));
  return {
    week,
    weeks: est.weeks,
    phase: phaseLabel(phaseOf(est, week)),
    targetBand: inputs.targetBand,
    examWeeksLeft: inputs.examDate ? Math.max(0, Math.floor(daysBetween(today, inputs.examDate) / 7)) : null,
    minutesPerDay: inputs.minutesPerDay,
    daysPerWeek: inputs.days.length,
    lastWeek,
    modules: inputs.modules.map((m) => ({
      module: m,
      bandNow: moduleBand(profile, m),
      bandBefore: Number.isFinite(Number(before[m])) ? Number(before[m]) : null,
      results: Object.entries(profile).filter(([t]) => tagModule(t) === m).reduce((n, [, v]) => n + v.n, 0),
    })),
    weakest,
    tasks: rows.map((t) => ({
      id: t.id,
      date: dayKey(t.date),
      title: t.title,
      skill: t.skill ?? '',
      minutes: t.durationMin ?? 0,
      practises: (byId.get(t.itemId ?? '')?.trains ?? []).slice(0, 3).map((x) => TAG_LABELS[x] ?? x),
      checkpoint: t.kind === 'checkpoint',
    })),
  };
}

/** Week notes being written by the AI right now (plan:week). */
const aiRunning = new Set<string>();

/** Writes the rules note at once, then lets the AI improve it in the background. */
async function writeWeekNote(
  userId: string,
  plan: PlanRow,
  inputs: PlanInputs,
  today: string,
  ev: Evidence,
  week: number,
  last?: WeekContext['lastWeek'],
) {
  const est = plan.estimate as unknown as Estimate;
  const profile = buildProfile(inputs, ev, catalog());
  const ctx = await weekContext(plan, inputs, est, profile, week, today, last);
  const note: WeekNote = {
    ...rulesNote(ctx),
    bands: Object.fromEntries(inputs.modules.map((m) => [m, Math.round(moduleBand(profile, m) * 10) / 10])),
    at: new Date().toISOString(),
  };
  await prisma.studyPlan.update({ where: { id: plan.id }, data: { adaptedWeek: week, weekNote: note as object } });
  plan.adaptedWeek = week;
  plan.weekNote = note;
  void improveWithAi(userId, plan.id, week, ctx, note);
}

async function improveWithAi(userId: string, planId: string, week: number, ctx: WeekContext, base: WeekNote) {
  const key = `${planId}:${week}`;
  if (aiRunning.has(key) || !ctx.tasks.length) return;
  aiRunning.add(key);
  try {
    if (!(await planAiAllowed(userId))) return;
    const r = await aiWeek(ctx);
    const cur = await prisma.studyPlan.findUnique({ where: { id: planId }, select: { adaptedWeek: true } });
    if (!cur || cur.adaptedWeek !== week) return; // re-planned meanwhile
    await prisma.studyPlan.update({ where: { id: planId }, data: { weekNote: { ...base, ...r.note } as object } });
    for (const [id, why] of r.reasons) {
      await prisma.studyTask.updateMany({ where: { id, planId, removedAt: null }, data: { reason: why } });
    }
  } catch (e) {
    console.warn('[plan-ai] week note kept from rules:', e instanceof Error ? e.message : e);
  } finally {
    aiRunning.delete(key);
  }
}

/**
 * Brings the active plan up to date: resume after a pause, finish at the end,
 * mark tasks done from results, roll missed tasks forward, fill ahead.
 * Returns the plan (or null when the student has none).
 */
export async function ensurePlan(userId: string): Promise<PlanRow | null> {
  return withLock(userId, async () => {
    const plan = await prisma.studyPlan.findFirst({
      where: { userId, status: { in: ['active', 'paused'] } },
      orderBy: { createdAt: 'desc' },
    });
    if (!plan) return null;
    const inputs = plan.inputs as unknown as PlanInputs;
    const today = localToday(inputs.tzOffsetMin);

    if (plan.status === 'paused') {
      if (plan.pausedUntil && dayKey(plan.pausedUntil) >= today) return plan;
      await prisma.studyPlan.update({ where: { id: plan.id }, data: { status: 'active', pausedUntil: null } });
      plan.status = 'active';
      plan.pausedUntil = null;
    }
    if (today > dayKey(plan.endDate)) {
      await prisma.studyPlan.update({ where: { id: plan.id }, data: { status: 'finished' } });
      plan.status = 'finished';
      return plan;
    }

    const ev = await loadEvidence(userId);

    // Results the student got anywhere in the app tick off matching tasks.
    const sinceStart = plan.createdAt;
    const recentRefs = new Set(
      ev.attempts.filter((a) => a.refId && a.createdAt >= sinceStart).map((a) => a.refId as string),
    );
    const lessonRefs = new Set(ev.lessonsDone);
    const open = await prisma.studyTask.findMany({
      where: { planId: plan.id, removedAt: null, done: false, ref: { not: null } },
      select: { id: true, ref: true, itemId: true },
    });
    const tick = open
      .filter((t) => t.itemId !== 'pron:daily' && (recentRefs.has(t.ref!) || (t.itemId?.startsWith('lesson:') && lessonRefs.has(t.ref!))))
      .map((t) => t.id);
    if (tick.length) await prisma.studyTask.updateMany({ where: { id: { in: tick } }, data: { done: true } });

    // A new plan week: re-plan the coming days from the latest results.
    const est = plan.estimate as unknown as Estimate;
    const week = planWeek(inputs, est, today);
    const newWeek = plan.adaptedWeek < week;
    const last = newWeek && week > 1 ? await lastWeekStats(plan, inputs, week) : null;
    if (newWeek && plan.adaptedWeek > 0) {
      await removeTasks({ planId: plan.id, done: false, date: { gte: parseDay(today) } });
      plan.filledUntil = parseDay(addDays(today, -1));
      await prisma.studyPlan.update({ where: { id: plan.id }, data: { filledUntil: plan.filledUntil } });
    }

    // Fill ahead.
    const filled = plan.filledUntil ? dayKey(plan.filledUntil) : addDays(today, -1);
    let from = addDays(filled, 1);
    if (from < today) from = today;
    if (from < inputs.startDate) from = inputs.startDate;
    let to = addDays(today, FILL_AHEAD);
    if (to > dayKey(plan.endDate)) to = dayKey(plan.endDate);
    if (from <= to) await fill(userId, plan, from, to, ev);

    // Roll missed tasks forward: at most one extra task per study day.
    const missed = await prisma.studyTask.findMany({
      where: { planId: plan.id, removedAt: null, done: false, date: { lt: parseDay(today) } },
      orderBy: { date: 'asc' },
    });
    if (missed.length) {
      const fresh = missed.filter(
        (t) =>
          daysBetween(dayKey(t.date), today) <= ROLL_DAYS &&
          Date.now() - t.createdAt.getTime() < ROLL_MAX_AGE_DAYS * 86400000 &&
          t.kind !== 'checkpoint',
      );
      const slots: string[] = [];
      const last = plan.filledUntil ? dayKey(plan.filledUntil) : today;
      for (let d = today; d <= last && slots.length < fresh.length; d = addDays(d, 1)) {
        if (inputs.days.includes(weekday(d))) slots.push(d);
      }
      // Most recent misses first: they are the most relevant.
      const keep = [...fresh].reverse().slice(0, slots.length);
      const keepIds = new Set(keep.map((t) => t.id));
      for (let i = 0; i < keep.length; i++) {
        await prisma.studyTask.update({ where: { id: keep[i].id }, data: { date: parseDay(slots[i]) } });
      }
      const drop = missed.filter((t) => !keepIds.has(t.id)).map((t) => t.id);
      if (drop.length) await removeTasks({ id: { in: drop } });
    }

    // The week's note (rules now, AI in the background).
    if (newWeek) await writeWeekNote(userId, plan, inputs, today, ev, week, last);

    // Purge long-removed rows (the app has had plenty of syncs to see them).
    await prisma.studyTask.deleteMany({
      where: { userId, removedAt: { lt: new Date(Date.now() - 30 * 86400000) } },
    });
    return plan;
  });
}

/** Re-plans from today: drops open tasks from today on and refills. */
async function replan(userId: string, plan: PlanRow, inputs: PlanInputs) {
  const today = localToday(inputs.tzOffsetMin);
  const ev = await loadEvidence(userId);
  const profile = buildProfile(inputs, ev, catalog());
  const est = shownEstimate(rebased(inputs, profile, today), profile);
  await removeTasks({ planId: plan.id, done: false, date: { gte: parseDay(today) } });
  await prisma.studyPlan.update({
    where: { id: plan.id },
    data: {
      inputs: inputs as object,
      estimate: est as object,
      endDate: parseDay(endDateOf(inputs, est)),
      filledUntil: parseDay(addDays(today, -1)),
      adaptedWeek: 0,
      version: { increment: 1 },
    },
  });
}

// ── routes ──────────────────────────────────────────────────────────────────

function inputsFrom(body: Row): PlanInputs {
  try {
    return normaliseInputs(obj(body.inputs ?? body));
  } catch (e) {
    throw badRequest(e instanceof Error ? e.message : 'Invalid plan settings.', 'bad_plan');
  }
}

/** A start date in the past becomes today (the app may send a stale one). */
function startFromToday(inputs: PlanInputs): PlanInputs {
  const today = localToday(inputs.tzOffsetMin);
  return inputs.startDate < today ? { ...inputs, startDate: today } : inputs;
}

export function registerPlanRoutes(r: Router): void {
  // Estimate + first week without saving anything.
  r.post('/v1/plan/preview', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`plan-preview:${userId}`, 10, 3600);
    const inputs = startFromToday(inputsFrom(ctx.body));
    const ev = await loadEvidence(userId);
    const profile = buildProfile(inputs, ev, catalog());
    const est = estimate(inputs, profile);
    const state = { scheduled: new Set<string>(), doneRefs: doneRefsOf(ev) };
    const week = generateDays(inputs, est, profile, catalog(), state, inputs.startDate, addDays(inputs.startDate, 6), `${userId}:preview`);
    return {
      inputs,
      estimate: shownEstimate(est, profile),
      summary: summary(inputs, est),
      endDate: endDateOf(inputs, est),
      week: week.map((t) => ({
        date: t.date,
        title: t.title,
        skill: t.skill,
        durationMin: t.minutes,
        reason: t.reason,
        ...(t.checkpoint ? { checkpoint: true } : {}),
      })),
    };
  });

  // Create the plan (replaces any current one) and its first two weeks.
  r.post('/v1/plan', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`plan-create:${userId}`, 10, 86400);
    const inputs = startFromToday(inputsFrom(ctx.body));
    const today = localToday(inputs.tzOffsetMin);
    const ev = await loadEvidence(userId);
    const profile = buildProfile(inputs, ev, catalog());
    const est = shownEstimate(estimate(inputs, profile), profile);
    await withLock(userId, async () => {
      const old = await prisma.studyPlan.findMany({
        where: { userId, status: { in: ['active', 'paused'] } },
        select: { id: true },
      });
      if (old.length) {
        const ids = old.map((p) => p.id);
        await prisma.studyPlan.updateMany({ where: { id: { in: ids } }, data: { status: 'replaced' } });
        await removeTasks({ planId: { in: ids }, done: false });
      }
      await prisma.studyPlan.create({
        data: {
          userId,
          inputs: inputs as object,
          estimate: est as object,
          startDate: parseDay(inputs.startDate),
          endDate: parseDay(endDateOf(inputs, est)),
        },
      });
    });
    const plan = await ensurePlan(userId);
    if (!plan) throw notFound('Plan not found.');
    return { plan: await planJson(plan, today) };
  });

  r.get('/v1/plan', async (ctx) => {
    const userId = requireUser(ctx);
    const plan = await ensurePlan(userId);
    if (!plan) return { plan: null };
    return { plan: await planJson(plan, localToday((plan.inputs as unknown as PlanInputs).tzOffsetMin)) };
  });

  // {action: 'pause', days} | {action: 'resume'} | {action: 'rebalance'}
  // | {action: 'update', days?, minutesPerDay?, studyTime?, targetBand?, examDate?}
  r.patch('/v1/plan', async (ctx) => {
    const userId = requireUser(ctx);
    const action = s(ctx.body.action, 20);
    const plan = await prisma.studyPlan.findFirst({
      where: { userId, status: { in: ['active', 'paused'] } },
      orderBy: { createdAt: 'desc' },
    });
    if (!plan) throw notFound('You have no study plan yet.');
    const inputs = plan.inputs as unknown as PlanInputs;
    const today = localToday(inputs.tzOffsetMin);

    await withLock(userId, async () => {
      if (action === 'pause') {
        const n = Math.round(Number(ctx.body.days));
        if (!Number.isFinite(n) || n < 1 || n > MAX_PAUSE_DAYS) throw badRequest(`Pause for 1 to ${MAX_PAUSE_DAYS} days.`);
        const until = addDays(today, n - 1);
        // The plan moves later by the pause, so phases pick up where they were.
        const shifted = { ...inputs, startDate: addDays(inputs.startDate, n) };
        await removeTasks({ planId: plan.id, done: false, date: { gte: parseDay(today) } });
        await prisma.studyPlan.update({
          where: { id: plan.id },
          data: {
            status: 'paused',
            pausedUntil: parseDay(until),
            inputs: shifted as object,
            startDate: parseDay(shifted.startDate),
            endDate: parseDay(addDays(dayKey(plan.endDate), n)),
            filledUntil: parseDay(until),
            version: { increment: 1 },
          },
        });
      } else if (action === 'resume') {
        if (plan.status !== 'paused') return;
        // Give back the days of the pause that were not used.
        const unused = plan.pausedUntil ? Math.max(0, daysBetween(today, dayKey(plan.pausedUntil)) + 1) : 0;
        const shifted = { ...inputs, startDate: addDays(inputs.startDate, -unused) };
        await prisma.studyPlan.update({
          where: { id: plan.id },
          data: {
            status: 'active',
            pausedUntil: null,
            inputs: shifted as object,
            startDate: parseDay(shifted.startDate),
            endDate: parseDay(addDays(dayKey(plan.endDate), -unused)),
            filledUntil: parseDay(addDays(today, -1)),
            version: { increment: 1 },
          },
        });
      } else if (action === 'rebalance') {
        rateLimit(`plan-rebalance:${userId}`, 5, 86400);
        await replan(userId, plan, inputs);
      } else if (action === 'update') {
        rateLimit(`plan-rebalance:${userId}`, 5, 86400);
        const b = ctx.body;
        let next: PlanInputs;
        try {
          next = normaliseInputs({
            ...inputs,
            ...(b.days !== undefined ? { days: b.days } : {}),
            ...(b.minutesPerDay !== undefined ? { minutesPerDay: b.minutesPerDay } : {}),
            ...(b.studyTime !== undefined ? { studyTime: b.studyTime } : {}),
            ...(b.targetBand !== undefined ? { targetBand: b.targetBand } : {}),
            ...(b.examDate !== undefined ? { examDate: b.examDate } : {}),
            ...(b.tzOffsetMin !== undefined ? { tzOffsetMin: b.tzOffsetMin } : {}),
          });
        } catch (e) {
          throw badRequest(e instanceof Error ? e.message : 'Invalid plan settings.', 'bad_plan');
        }
        // Keep the original start (normaliseInputs keeps it as given).
        await replan(userId, plan, next);
        if (next.studyTime !== inputs.studyTime) {
          await prisma.studyTask.updateMany({
            where: { planId: plan.id, removedAt: null, done: false, date: { gte: parseDay(today) } },
            data: { time: next.studyTime },
          });
        }
      } else {
        throw badRequest('action must be pause, resume, rebalance or update.');
      }
    });
    const fresh = await ensurePlan(userId);
    if (!fresh) return { plan: null };
    return { plan: await planJson(fresh, localToday((fresh.inputs as unknown as PlanInputs).tzOffsetMin)) };
  });

  // Quick check (optional, at set-up): saves the section bands the app worked
  // out and re-plans the active plan with them.
  // {reading?, listening?, grammar?, vocab?: band, writing?: {band, criteria}}
  r.post('/v1/plan/quick-check', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`plan-qc:${userId}`, 10, 86400);
    const b = ctx.body;
    const band = (x: unknown) => {
      const v = Number(x);
      return Number.isFinite(v) && v >= 1 && v <= 9 ? Math.round(v * 2) / 2 : undefined;
    };
    const value: Row = { at: new Date().toISOString() };
    for (const k of ['reading', 'listening', 'grammar', 'vocab']) {
      const v = band(b[k]);
      if (v !== undefined) value[k] = v;
    }
    const w = obj(b.writing);
    if (band(w.band) !== undefined) {
      const crit: Row = {};
      for (const [k, v] of Object.entries(obj(w.criteria))) {
        if (['TA', 'CC', 'LR', 'GRA'].includes(k) && band(v) !== undefined) crit[k] = band(v);
      }
      value.writing = { band: band(w.band), criteria: crit };
    }
    if (Object.keys(value).length < 2) throw badRequest('No quick-check results to save.');
    await prisma.userState.upsert({
      where: { userId_key: { userId, key: QUICK_CHECK_KEY } },
      create: { userId, key: QUICK_CHECK_KEY, value: value as object },
      update: { value: value as object },
    });
    const plan = await prisma.studyPlan.findFirst({
      where: { userId, status: { in: ['active', 'paused'] } },
      orderBy: { createdAt: 'desc' },
    });
    if (plan) await withLock(userId, () => replan(userId, plan, plan.inputs as unknown as PlanInputs));
    const fresh = plan ? await ensurePlan(userId) : null;
    return {
      quickCheck: value,
      plan: fresh ? await planJson(fresh, localToday((fresh.inputs as unknown as PlanInputs).tzOffsetMin)) : null,
    };
  });

  // Quick check, writing part: one short paragraph scored on the four
  // criteria (not counted as a writing test).
  r.post('/v1/plan/quick-check/writing', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`plan-qcw:${userId}`, 5, 86400);
    const question = s(ctx.body.question, 400);
    const text = s(ctx.body.text, 3000).trim();
    const words = text.split(/\s+/).filter(Boolean).length;
    if (words < 30) throw badRequest('Write at least 30 words.', 'too_short');
    const { data } = await geminiJson({
      label: 'plan-quickcheck-writing',
      model: env.geminiPlanModel || undefined,
      system: QC_WRITING_SYSTEM,
      user: JSON.stringify({ question, answer: text, words }),
      schema: QC_WRITING_SCHEMA,
    });
    const crit: Record<string, number> = {};
    for (const k of ['TA', 'CC', 'LR', 'GRA']) {
      const v = Number((data as Row)[k]);
      if (Number.isFinite(v)) crit[k] = Math.min(9, Math.max(1, Math.round(v * 2) / 2));
    }
    if (Object.keys(crit).length < 4) throw new HttpError(502, 'Could not score the paragraph. Please try again.', 'ai_failed');
    const avg = (crit.TA + crit.CC + crit.LR + crit.GRA) / 4;
    return {
      band: Math.round(avg * 2) / 2,
      criteria: crit,
      feedback: s((data as Row).feedback, 300),
    };
  });

  // Ends the plan. Finished tasks stay in the history; open ones go.
  r.delete('/v1/plan', async (ctx) => {
    const userId = requireUser(ctx);
    const plans = await prisma.studyPlan.findMany({
      where: { userId, status: { in: ['active', 'paused'] } },
      select: { id: true },
    });
    for (const p of plans) {
      await prisma.studyPlan.update({ where: { id: p.id }, data: { status: 'ended' } });
      await removeTasks({ planId: p.id, done: false });
    }
    return { ended: plans.length };
  });
}
