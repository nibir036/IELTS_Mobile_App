// Personal study plan engine (Phase 1: rules only, no LLM).
//
// Inputs (set-up answers) + evidence (attempts, finished lessons) →
//   1. a skill profile: an estimated band per sub-skill tag,
//   2. an estimate: weeks to the target band, phases, checkpoint weeks,
//   3. days of tasks, each a catalog item (server/data/plan_catalog.json,
//      built by tool/build_plan_catalog.py) that opens an exact app screen.
//
// Pure functions only (no database), so it can be unit-tested: see
// scripts/plan-check.ts.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// ── types ───────────────────────────────────────────────────────────────────

export type Module = 'reading' | 'listening' | 'writing' | 'speaking';
export type CatalogModule = Module | 'grammar' | 'vocab' | 'mock';
export type Level = 'beginner' | 'amateur' | 'intermediate' | 'advanced';
export const MODULES: Module[] = ['listening', 'reading', 'writing', 'speaking'];
export const LEVELS: Level[] = ['beginner', 'amateur', 'intermediate', 'advanced'];

export interface CatalogItem {
  id: string;
  ref: string | null;
  module: CatalogModule;
  type: 'lesson' | 'practice' | 'test' | 'ai_task' | 'mock';
  level: number;
  minutes: number;
  after: string | null;
  order: number;
  trains: string[];
  testType: 'both' | 'academic' | 'gt';
  title: string;
  route: string;
  args: Record<string, unknown>;
  repeat?: boolean;
  topic?: string;
}

export interface Catalog {
  version: number;
  tags: string[];
  items: CatalogItem[];
}

export interface PlanInputs {
  modules: Module[];
  levels: Partial<Record<Module, Level>>;
  targetBand: number;
  examDate: string | null;
  testType: 'academic' | 'gt';
  /** Study weekdays, 1 = Monday … 7 = Sunday. */
  days: number[];
  minutesPerDay: number;
  /** 'HH:MM' local. */
  studyTime: string;
  /** A module or sub-skill tag the student worries about most. */
  worry: string | null;
  goal: string | null;
  interests: string[];
  previousScore: number | null;
  /** The student's local date when the plan was made ('YYYY-MM-DD'). */
  startDate: string;
  /** Minutes east of UTC (Bangladesh = 360), for "today" on the server. */
  tzOffsetMin: number;
}

export interface EvidenceAttempt {
  skill: string;
  kind: string;
  refId: string | null;
  band: number | null;
  score: number | null;
  total: number | null;
  data: Record<string, unknown> | null;
  createdAt: Date;
}

export interface Evidence {
  attempts: EvidenceAttempt[];
  /** Finished course lesson ids. */
  lessonsDone: string[];
}

export interface TagScore {
  band: number;
  /** How many results (not counting the starting guess) shaped it. */
  n: number;
}
export type Profile = Record<string, TagScore>;

export interface Phase {
  id: 'foundation' | 'build' | 'exam' | 'review';
  fromWeek: number;
  toWeek: number;
}

export interface Estimate {
  weeks: number;
  weeksMin: number;
  weeksMax: number;
  hoursNeeded: number;
  startBand: number;
  targetBand: number;
  realisticBand: number;
  onTrack: boolean;
  /** Why the plan can't reach the target: the exam date, or a year's study. */
  limit: 'exam' | 'year' | null;
  /** Band gain the plan can realistically bring (0.5 steps). */
  gainBy: number;
  weeksToExam: number | null;
  split: Partial<Record<Module, number>>;
  phases: Phase[];
  /** Weeks that end with a checkpoint (mock test or module tests). */
  checkpointWeeks: number[];
  focus: Module;
  focusTags: string[];
}

export interface PlannedTask {
  date: string;
  itemId: string;
  ref: string | null;
  title: string;
  skill: string;
  minutes: number;
  route: string;
  args: Record<string, unknown>;
  reason: string;
  checkpoint?: boolean;
}

/** What the generator needs to know about tasks already in the plan. */
export interface PlanState {
  /** Item ids already scheduled in this plan (any date). */
  scheduled: Set<string>;
  /** Refs finished outside the plan too (attempt refIds, lesson ids). */
  doneRefs: Set<string>;
}

// ── settings ────────────────────────────────────────────────────────────────

/**
 * Study hours a student with all four modules needs for half a band. A
 * planning setting for the teaching team to tune (PLAN_HOURS_PER_HALF_BAND).
 */
export const HOURS_PER_HALF_BAND = Number(process.env.PLAN_HOURS_PER_HALF_BAND) || 50;
export const MAX_WEEKS = 52;

const LEVEL_BAND: Record<Level, number> = { beginner: 4.0, amateur: 5.0, intermediate: 6.0, advanced: 7.0 };

export const TAG_LABELS: Record<string, string> = {
  'writing.t1': 'Writing Task 1',
  'writing.t2': 'Writing Task 2',
  'writing.ta': 'answering the task fully',
  'writing.cc': 'coherence and linking',
  'writing.lr': 'vocabulary range',
  'writing.gra': 'grammar range and accuracy',
  'speaking.p1': 'Speaking Part 1',
  'speaking.p2': 'Speaking Part 2',
  'speaking.p3': 'Speaking Part 3',
  'speaking.fc': 'fluency',
  'speaking.lr': 'speaking vocabulary',
  'speaking.gra': 'spoken grammar',
  'speaking.pron': 'pronunciation',
  'reading.strategy': 'reading strategy',
  'listening.strategy': 'listening strategy',
  'listening.p1': 'Listening Part 1',
  'listening.p2': 'Listening Part 2',
  'listening.p3': 'Listening Part 3',
  'listening.p4': 'Listening Part 4',
  'reading.mcq': 'multiple choice (reading)',
  'reading.tfng': 'True / False / Not Given',
  'reading.ynng': 'Yes / No / Not Given',
  'reading.matching_info': 'matching information',
  'reading.headings': 'matching headings',
  'reading.matching_features': 'matching features',
  'reading.sentence_endings': 'sentence endings',
  'reading.sentence_completion': 'sentence completion',
  'reading.summary_completion': 'summary completion',
  'reading.note_completion': 'note completion',
  'reading.table_completion': 'table completion',
  'reading.flowchart_completion': 'flow-chart completion',
  'reading.diagram_label': 'diagram labelling',
  'reading.short_answer': 'short-answer questions',
  'listening.fn': 'form and note completion',
  'listening.mc': 'multiple choice (listening)',
  'listening.ma': 'matching (listening)',
  'listening.pm': 'plan and map labelling',
  'listening.sc': 'sentence completion (listening)',
  'listening.tc': 'table completion (listening)',
  'listening.sm': 'summary completion (listening)',
  'listening.sa': 'short answers (listening)',
};

const MODULE_LABEL: Record<CatalogModule, string> = {
  reading: 'Reading',
  listening: 'Listening',
  writing: 'Writing',
  speaking: 'Speaking',
  grammar: 'Grammar',
  vocab: 'Vocabulary',
  mock: 'Mock test',
};

// ── catalog ─────────────────────────────────────────────────────────────────

let _catalog: Catalog | null = null;

export function loadCatalog(): Catalog {
  if (_catalog) return _catalog;
  const path = join(__dirname, '..', '..', 'data', 'plan_catalog.json');
  _catalog = JSON.parse(readFileSync(path, 'utf8')) as Catalog;
  return _catalog;
}

/** Module a tag belongs to ('writing.cc' → writing). */
export function tagModule(tag: string): Module {
  return tag.split('.')[0] as Module;
}

// ── dates ───────────────────────────────────────────────────────────────────

export function parseDay(d: string): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(d);
  if (!m) throw new Error(`bad date ${d}`);
  return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
}
export const dayKey = (d: Date) => d.toISOString().slice(0, 10);
export const addDays = (d: string, n: number) => dayKey(new Date(parseDay(d).getTime() + n * 86400000));
export const daysBetween = (a: string, b: string) => Math.round((parseDay(b).getTime() - parseDay(a).getTime()) / 86400000);
/** 1 = Monday … 7 = Sunday. */
export const weekday = (d: string) => ((parseDay(d).getUTCDay() + 6) % 7) + 1;

/** The student's local calendar day now. */
export function localToday(tzOffsetMin: number, now = new Date()): string {
  return dayKey(new Date(now.getTime() + tzOffsetMin * 60000));
}

// ── input checks ────────────────────────────────────────────────────────────

/** Normalises set-up answers from the app; throws Error(message) when invalid. */
export function normaliseInputs(raw: Record<string, unknown>): PlanInputs {
  const modules = (Array.isArray(raw.modules) ? raw.modules : [])
    .map(String)
    .filter((m): m is Module => (MODULES as string[]).includes(m));
  const uniq = [...new Set(modules)];
  if (!uniq.length) throw new Error('Choose at least one module.');
  const levelsIn = (raw.levels && typeof raw.levels === 'object' ? raw.levels : {}) as Record<string, unknown>;
  const levels: Partial<Record<Module, Level>> = {};
  for (const m of uniq) {
    const l = String(levelsIn[m] ?? 'intermediate');
    levels[m] = (LEVELS as string[]).includes(l) ? (l as Level) : 'intermediate';
  }
  const target = Number(raw.targetBand);
  if (!Number.isFinite(target) || target < 4 || target > 9) throw new Error('Target band must be between 4.0 and 9.0.');
  const days = [...new Set((Array.isArray(raw.days) ? raw.days : []).map(Number))]
    .filter((d) => Number.isInteger(d) && d >= 1 && d <= 7)
    .sort();
  if (!days.length) throw new Error('Choose at least one study day.');
  const minutes = Math.round(Number(raw.minutesPerDay));
  if (!Number.isFinite(minutes) || minutes < 15 || minutes > 240) throw new Error('Minutes per day must be 15 to 240.');
  const startDate = String(raw.startDate ?? '');
  try {
    parseDay(startDate);
  } catch {
    throw new Error('startDate must be YYYY-MM-DD.');
  }
  let examDate: string | null = raw.examDate ? String(raw.examDate).slice(0, 10) : null;
  if (examDate) {
    try {
      parseDay(examDate);
      if (daysBetween(startDate, examDate) < 1) examDate = null;
    } catch {
      examDate = null;
    }
  }
  const time = /^([01]\d|2[0-3]):[0-5]\d$/.test(String(raw.studyTime ?? '')) ? String(raw.studyTime) : '20:00';
  const prev = Number(raw.previousScore);
  const tz = Math.round(Number(raw.tzOffsetMin));
  return {
    modules: MODULES.filter((m) => uniq.includes(m)),
    levels,
    targetBand: Math.round(target * 2) / 2,
    examDate,
    // The app has Academic content only for now; GT support stays in the engine.
    testType: 'academic',
    days,
    minutesPerDay: minutes,
    studyTime: time,
    worry: raw.worry ? String(raw.worry).slice(0, 40) : null,
    goal: raw.goal ? String(raw.goal).slice(0, 40) : null,
    interests: (Array.isArray(raw.interests) ? raw.interests : []).map((x) => String(x).slice(0, 40)).slice(0, 6),
    previousScore: Number.isFinite(prev) && prev >= 1 && prev <= 9 ? Math.round(prev * 2) / 2 : null,
    startDate,
    tzOffsetMin: Number.isFinite(tz) && Math.abs(tz) <= 14 * 60 ? tz : 360,
  };
}

// ── skill profile ───────────────────────────────────────────────────────────

/** Correct-answer share → an approximate band (reading/listening style). */
export function accuracyBand(acc: number): number {
  const pts: [number, number][] = [
    [0, 3],
    [0.3, 4],
    [0.5, 5.5],
    [0.7, 6.5],
    [0.85, 7.5],
    [0.95, 8.5],
    [1, 9],
  ];
  const a = Math.min(1, Math.max(0, acc));
  for (let i = 1; i < pts.length; i++) {
    const [x1, y1] = pts[i];
    const [x0, y0] = pts[i - 1];
    if (a <= x1) return y0 + ((a - x0) / (x1 - x0)) * (y1 - y0);
  }
  return 9;
}

/** The band a student starts from in [module], before any results. */
export function priorBand(inputs: PlanInputs, module: Module): number {
  if (inputs.previousScore != null) return inputs.previousScore;
  const l = inputs.levels[module] ?? 'intermediate';
  const base = LEVEL_BAND[l];
  // Self-ratings above beginner are usually optimistic: start one step lower.
  return l === 'beginner' ? base : Math.max(4, base - 1);
}

const CRITERIA: Record<string, Record<string, string>> = {
  writing: { TA: 'writing.ta', TR: 'writing.ta', CC: 'writing.cc', LR: 'writing.lr', GRA: 'writing.gra' },
  speaking: { FC: 'speaking.fc', LR: 'speaking.lr', GRA: 'speaking.gra', P: 'speaking.pron', PR: 'speaking.pron' },
};

function criteriaOf(data: Record<string, unknown> | null): Record<string, unknown> {
  if (!data) return {};
  const c = data.criteria ?? (data.evaluation as Record<string, unknown> | undefined)?.criteria;
  return c && typeof c === 'object' ? (c as Record<string, unknown>) : {};
}

/** Result samples (tag, band) from one attempt. */
export function samplesOf(a: EvidenceAttempt, byRef: Map<string, CatalogItem>): [string, number][] {
  const out: [string, number][] = [];
  const ref = a.refId ?? '';
  const acc = a.total && a.total > 0 && a.score != null ? a.score / a.total : null;
  if (a.skill === 'reading' && acc != null) {
    const item = byRef.get(ref);
    for (const t of item?.trains ?? ['reading.strategy']) out.push([t, accuracyBand(acc)]);
  } else if (a.skill === 'listening' && acc != null) {
    const item = byRef.get(ref);
    for (const t of item?.trains ?? ['listening.strategy']) out.push([t, accuracyBand(acc)]);
  } else if (a.skill === 'writing') {
    if (a.kind === 'drill' && acc != null) {
      for (const t of byRef.get(ref)?.trains ?? ['writing.cc']) out.push([t, accuracyBand(acc)]);
    } else if (a.band != null) {
      out.push([a.kind === 'task1' ? 'writing.t1' : 'writing.t2', a.band]);
      for (const [k, v] of Object.entries(criteriaOf(a.data))) {
        const tag = CRITERIA.writing[k];
        if (tag && Number.isFinite(Number(v))) out.push([tag, Number(v)]);
      }
    }
  } else if (a.skill === 'speaking') {
    if (a.kind === 'pronunciation' && acc != null) {
      out.push(['speaking.pron', accuracyBand(acc)]);
    } else if (a.band != null) {
      const part = /part([123])/.exec(a.kind)?.[1];
      if (part) out.push([`speaking.p${part}`, a.band]);
      for (const [k, v] of Object.entries(criteriaOf(a.data))) {
        const tag = CRITERIA.speaking[k];
        if (tag && Number.isFinite(Number(v))) out.push([tag, Number(v)]);
      }
    }
  }
  return out.filter(([, b]) => Number.isFinite(b));
}

/**
 * Estimated band per sub-skill tag: the starting guess (weight 1.5) blended
 * with results, newer results counting more (half weight after 30 days).
 */
/**
 * Quick-check results (set-up, optional): one estimated band per section,
 * applied to every sub-skill it stands for, so the whole module moves.
 *   qc_reading / qc_listening -> all reading / listening tags
 *   qc_grammar -> writing.gra, speaking.gra · qc_vocab -> writing.lr, speaking.lr
 *   qc_writing -> the paragraph's criteria (TA/CC/LR/GRA) + writing.t2
 */
export function quickCheckSamples(a: EvidenceAttempt, tags: string[]): [string, number][] {
  const band = a.band;
  const ref = a.refId ?? '';
  const out: [string, number][] = [];
  if (ref === 'qc_writing') {
    for (const [k, v] of Object.entries(criteriaOf(a.data))) {
      const tag = CRITERIA.writing[k];
      if (tag && Number.isFinite(Number(v))) out.push([tag, Number(v)]);
    }
    if (band != null) out.push(['writing.t2', band]);
    return out;
  }
  if (band == null || !Number.isFinite(band)) return out;
  if (ref === 'qc_reading' || ref === 'qc_listening') {
    const m = ref.slice(3);
    for (const t of tags) if (t.startsWith(`${m}.`)) out.push([t, band]);
  } else if (ref === 'qc_grammar') {
    out.push(['writing.gra', band], ['speaking.gra', band]);
  } else if (ref === 'qc_vocab') {
    out.push(['writing.lr', band], ['speaking.lr', band]);
  }
  return out;
}

export function buildProfile(inputs: PlanInputs, ev: Evidence, catalog: Catalog, now = new Date()): Profile {
  const byRef = new Map<string, CatalogItem>();
  for (const it of catalog.items) if (it.ref) byRef.set(it.ref, it);
  const acc: Record<string, { sum: number; w: number; n: number }> = {};
  for (const tag of catalog.tags) {
    const prior = priorBand(inputs, tagModule(tag));
    acc[tag] = { sum: prior * 1.5, w: 1.5, n: 0 };
  }
  for (const a of ev.attempts) {
    const ageDays = Math.max(0, (now.getTime() - a.createdAt.getTime()) / 86400000);
    const qc = a.kind === 'quickcheck';
    const w = (a.skill === 'mock' ? 3 : qc ? 2 : 1) * Math.pow(0.5, ageDays / 30);
    for (const [tag, band] of qc ? quickCheckSamples(a, catalog.tags) : samplesOf(a, byRef)) {
      const slot = acc[tag];
      if (!slot) continue;
      slot.sum += band * w;
      slot.w += w;
      slot.n += 1;
    }
  }
  const out: Profile = {};
  for (const [tag, v] of Object.entries(acc)) out[tag] = { band: Math.round((v.sum / v.w) * 10) / 10, n: v.n };
  return out;
}

export function moduleBand(profile: Profile, module: Module): number {
  const tags = Object.keys(profile).filter((t) => tagModule(t) === module);
  if (!tags.length) return 5;
  return tags.reduce((s, t) => s + profile[t].band, 0) / tags.length;
}

/** 0 (no need) … ~1.5 (far below target) per tag; the worry gets a boost. */
export function needs(profile: Profile, inputs: PlanInputs): Record<string, number> {
  const out: Record<string, number> = {};
  for (const [tag, s] of Object.entries(profile)) {
    let n = Math.min(1.5, Math.max(0, (inputs.targetBand - s.band) / 2)) + 0.05;
    if (inputs.worry && (tag === inputs.worry || tag.startsWith(`${inputs.worry}.`))) n *= 1.3;
    out[tag] = n;
  }
  return out;
}

// ── estimate ────────────────────────────────────────────────────────────────

const roundHalf = (b: number) => Math.round(b * 2) / 2;

export function estimate(inputs: PlanInputs, profile: Profile): Estimate {
  const mods = inputs.modules;
  const bands = Object.fromEntries(mods.map((m) => [m, moduleBand(profile, m)])) as Record<Module, number>;
  const startBand = roundHalf(mods.reduce((s, m) => s + bands[m], 0) / mods.length);
  const gap = Math.max(0, inputs.targetBand - startBand);
  const halfBands = Math.ceil(gap / 0.5 - 1e-9);
  const moduleFactor = 0.5 + 0.5 * (mods.length / 4);
  const perHalf = HOURS_PER_HALF_BAND * moduleFactor;
  const hoursNeeded = Math.round(halfBands * perHalf);
  const weeklyHours = (inputs.days.length * inputs.minutesPerDay) / 60;
  let weeks = halfBands === 0 ? 4 : Math.max(2, Math.ceil(hoursNeeded / weeklyHours));
  const weeksToExam = inputs.examDate ? Math.max(0, Math.floor(daysBetween(inputs.startDate, inputs.examDate) / 7)) : null;
  let onTrack = true;
  let realisticBand = inputs.targetBand;
  let limit: 'exam' | 'year' | null = null;
  const cap = weeksToExam != null ? Math.min(weeksToExam, MAX_WEEKS) : MAX_WEEKS;
  if (weeks > cap) {
    onTrack = false;
    limit = weeksToExam != null && weeksToExam <= MAX_WEEKS ? 'exam' : 'year';
    weeks = Math.max(1, cap);
    const reachable = Math.floor((weeks * weeklyHours) / perHalf);
    realisticBand = Math.min(inputs.targetBand, startBand + reachable * 0.5);
  }
  const gainBy = Math.max(0, realisticBand - startBand);
  const weeksMin = onTrack ? Math.max(1, Math.round(weeks * 0.8)) : weeks;
  const weeksMax = onTrack ? Math.min(MAX_WEEKS, Math.round(weeks * 1.25)) : weeks;

  // Time split: more for modules further from the target, plus the worry.
  const need = needs(profile, inputs);
  const raw: Record<string, number> = {};
  for (const m of mods) {
    const tags = Object.keys(need).filter((t) => tagModule(t) === m);
    const avg = tags.reduce((s, t) => s + need[t], 0) / Math.max(1, tags.length);
    raw[m] = (0.6 + avg) * (inputs.worry && (inputs.worry === m || inputs.worry.startsWith(`${m}.`)) ? 1.25 : 1);
  }
  const total = Object.values(raw).reduce((s, v) => s + v, 0);
  const split = Object.fromEntries(mods.map((m) => [m, Math.round((raw[m] / total) * 100) / 100])) as Partial<
    Record<Module, number>
  >;
  // Ties (no results yet): writing and speaking first, they usually lag.
  const pref: Record<Module, number> = { writing: 0.003, speaking: 0.002, reading: 0.001, listening: 0 };
  const focus = [...mods].sort((a, b) => (raw[b] ?? 0) + pref[b] - ((raw[a] ?? 0) + pref[a]))[0];
  const focusTags = Object.keys(need)
    .filter((t) => mods.includes(tagModule(t)) && profile[t])
    .sort((a, b) => need[b] - need[a])
    .slice(0, 3);

  return {
    weeks,
    weeksMin,
    weeksMax,
    hoursNeeded,
    startBand,
    targetBand: inputs.targetBand,
    realisticBand,
    onTrack,
    limit,
    gainBy,
    weeksToExam,
    split,
    phases: phases(weeks),
    checkpointWeeks: checkpointWeeks(weeks),
    focus,
    focusTags,
  };
}

export function phases(weeks: number): Phase[] {
  if (weeks <= 1) return [{ id: 'exam', fromWeek: 1, toWeek: 1 }];
  if (weeks === 2) return [
    { id: 'build', fromWeek: 1, toWeek: 1 },
    { id: 'exam', fromWeek: 2, toWeek: 2 },
  ];
  if (weeks === 3) return [
    { id: 'foundation', fromWeek: 1, toWeek: 1 },
    { id: 'build', fromWeek: 2, toWeek: 2 },
    { id: 'exam', fromWeek: 3, toWeek: 3 },
  ];
  const review = 1;
  const foundation = Math.max(1, Math.round(weeks * 0.25));
  const exam = Math.max(1, Math.round(weeks * 0.25) - review);
  const build = Math.max(1, weeks - foundation - exam - review);
  const out: Phase[] = [];
  let w = 1;
  out.push({ id: 'foundation', fromWeek: w, toWeek: w + foundation - 1 });
  w += foundation;
  out.push({ id: 'build', fromWeek: w, toWeek: w + build - 1 });
  w += build;
  out.push({ id: 'exam', fromWeek: w, toWeek: Math.min(weeks - 1, w + exam - 1) });
  out.push({ id: 'review', fromWeek: weeks, toWeek: weeks });
  return out.filter((p) => p.fromWeek <= p.toWeek);
}

/** Every 3rd week (4th in long plans), and the week before the last. */
export function checkpointWeeks(weeks: number): number[] {
  const out: number[] = [];
  const every = weeks <= 12 ? 3 : 4;
  for (let w = every; w < weeks; w += every) out.push(w);
  if (weeks >= 4 && !out.includes(weeks - 1)) out.push(weeks - 1);
  return out.sort((a, b) => a - b);
}

export function phaseOf(est: Estimate, week: number): Phase['id'] {
  return est.phases.find((p) => week >= p.fromWeek && week <= p.toWeek)?.id ?? 'build';
}

// ── task generation ─────────────────────────────────────────────────────────

/** Deterministic 0…1 from a string (variety between students, stable on rebuild). */
function hash01(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return ((h >>> 0) % 10000) / 10000;
}

const desiredLevel = (band: number) => (band < 5 ? 1 : band < 6 ? 2 : band < 7 ? 3 : 4);

function skillOf(m: CatalogModule): string {
  if (m === 'grammar') return 'writing';
  return m;
}

function lessonPrefix(m: CatalogModule): string {
  return `${MODULE_LABEL[m]} course`;
}

export function reasonFor(item: CatalogItem, need: Record<string, number>, profile: Profile, checkpoint = false): string {
  if (checkpoint) return item.type === 'mock'
    ? 'Checkpoint: a full mock test to measure your progress and update your plan.'
    : `Checkpoint: a ${MODULE_LABEL[item.module]} section test to measure your progress and update your plan.`;
  const top = [...item.trains].sort((a, b) => (need[b] ?? 0) - (need[a] ?? 0))[0];
  const label = top ? TAG_LABELS[top] ?? top : '';
  const s = top ? profile[top] : undefined;
  if (item.type === 'lesson') {
    return label ? `Next lesson in your ${lessonPrefix(item.module)}; it builds ${label}.` : `Next lesson in your ${lessonPrefix(item.module)}.`;
  }
  if (s && s.n > 0) return `Practises ${label}, one of your weaker areas so far (about band ${s.band.toFixed(1)}).`;
  return label ? `Practises ${label}.` : 'Keeps your practice going.';
}

interface DayContext {
  inputs: PlanInputs;
  est: Estimate;
  profile: Profile;
  need: Record<string, number>;
  catalog: Catalog;
  state: PlanState;
  userKey: string;
}

function usable(item: CatalogItem, ctx: DayContext): boolean {
  if (item.testType !== 'both' && item.testType !== ctx.inputs.testType) return false;
  if (!item.repeat) {
    if (ctx.state.scheduled.has(item.id)) return false;
    if (item.ref && ctx.state.doneRefs.has(item.ref)) return false;
  }
  return true;
}

/** Next course lesson of [module] whose prerequisite is done or scheduled. */
function nextLesson(module: CatalogModule, ctx: DayContext): CatalogItem | null {
  const lessons = ctx.catalog.items.filter((i) => i.module === module && i.type === 'lesson' && i.id.startsWith('lesson:'));
  lessons.sort((a, b) => a.order - b.order);
  for (const l of lessons) {
    if (!usable(l, ctx)) continue;
    if (l.after) {
      const prev = ctx.catalog.items.find((i) => i.id === l.after);
      const ok = !prev || ctx.state.scheduled.has(prev.id) || (prev.ref != null && ctx.state.doneRefs.has(prev.ref));
      if (!ok) continue;
    }
    return l;
  }
  return null;
}

function score(item: CatalogItem, ctx: DayContext, phase: Phase['id']): number {
  const tags = item.trains.length ? item.trains : [];
  const needSum = tags.reduce((s, t) => s + (ctx.need[t] ?? 0.2), 0) / Math.sqrt(Math.max(1, tags.length));
  const mod = (MODULES as string[]).includes(item.module) ? (item.module as Module) : 'writing';
  const want = Math.min(4, desiredLevel(moduleBand(ctx.profile, mod)) + (phase === 'exam' ? 1 : 0));
  const levelFit = 1 - 0.25 * Math.abs(item.level - want);
  let typeFit = 1;
  if (phase === 'foundation') typeFit = item.type === 'practice' ? 1.1 : item.type === 'ai_task' ? 0.8 : 1;
  if (phase === 'exam') typeFit = item.type === 'test' || item.type === 'ai_task' ? 1.3 : 0.9;
  let topicFit = 1;
  if (item.topic && ctx.inputs.interests.some((i) => item.topic!.toLowerCase().includes(i.toLowerCase()))) topicFit = 1.15;
  return needSum * levelFit * typeFit * topicFit + hash01(ctx.userKey + item.id) * 0.15;
}

function best(cands: CatalogItem[], ctx: DayContext, phase: Phase['id'], budget: number): CatalogItem | null {
  let top: CatalogItem | null = null;
  let topScore = -Infinity;
  for (const c of cands) {
    if (c.minutes > budget + 5 || !usable(c, ctx)) continue;
    const s = score(c, ctx, phase);
    if (s > topScore) {
      top = c;
      topScore = s;
    }
  }
  return top;
}

function practicePool(module: Module, ctx: DayContext, phase: Phase['id']): CatalogItem[] {
  return ctx.catalog.items.filter((i) => {
    if (i.module !== module) return false;
    if (i.type === 'lesson' || i.type === 'mock') return false;
    if (i.type === 'test' && phase === 'foundation') return false;
    return true;
  });
}

/** Support lessons (grammar, vocabulary) for writing and speaking students. */
function supportLesson(ctx: DayContext): CatalogItem | null {
  const mods = ctx.inputs.modules;
  if (!mods.includes('writing') && !mods.includes('speaking')) return null;
  const g = (ctx.need['writing.gra'] ?? 0) + (ctx.need['speaking.gra'] ?? 0);
  const v = (ctx.need['writing.lr'] ?? 0) + (ctx.need['speaking.lr'] ?? 0);
  const order: CatalogModule[] = g >= v ? ['grammar', 'vocab'] : ['vocab', 'grammar'];
  for (const m of order) {
    const l = nextLesson(m, ctx);
    if (l) return l;
  }
  return null;
}

function toTask(item: CatalogItem, date: string, ctx: DayContext, checkpoint = false): PlannedTask {
  ctx.state.scheduled.add(item.id);
  const title = item.type === 'lesson' && item.id.startsWith('lesson:') ? `${lessonPrefix(item.module)} · ${item.title}` : item.title;
  return {
    date,
    itemId: item.id,
    ref: item.ref,
    title: title.slice(0, 200),
    skill: skillOf(item.module),
    minutes: item.minutes,
    route: item.route,
    args: item.args,
    reason: reasonFor(item, ctx.need, ctx.profile, checkpoint),
    ...(checkpoint ? { checkpoint: true } : {}),
  };
}

/** The section test for [m] in a checkpoint week (speaking: Part 2 + Part 3). */
function sectionTest(m: Module, ctx: DayContext): CatalogItem[] {
  const items = ctx.catalog.items;
  const pick = (pool: CatalogItem[]) => best(pool, ctx, 'exam', 60);
  switch (m) {
    case 'listening': {
      const t = pick(items.filter((i) => i.module === 'listening' && i.type === 'test'))
        ?? pick(items.filter((i) => i.module === 'listening' && i.type === 'practice' && !i.repeat));
      return t ? [t] : [];
    }
    case 'reading': {
      const t = pick(items.filter((i) => i.module === 'reading' && i.type === 'test'))
        ?? pick(items.filter((i) => i.module === 'reading' && i.type === 'practice'));
      return t ? [t] : [];
    }
    case 'writing': {
      const t = pick(items.filter((i) => i.id.startsWith('w2:')));
      return t ? [t] : [];
    }
    case 'speaking': {
      const out: CatalogItem[] = [];
      const p2 = pick(items.filter((i) => i.id.startsWith('sp2:')));
      if (p2) {
        out.push(p2);
        ctx.state.scheduled.add(p2.id);
      }
      const p3 = pick(items.filter((i) => i.id.startsWith('sp3:')));
      if (p3) out.push(p3);
      if (p2) ctx.state.scheduled.delete(p2.id);
      return out;
    }
  }
}

/**
 * Checkpoint week: one section test per module, each on its own study day at
 * the end of the week (the weakest module last, so its result is freshest).
 * Near the exam (the final checkpoint of a plan with an exam date and all four
 * modules) it is one full mock instead.
 */
function checkpointDays(week: number, ctx: DayContext): Map<string, CatalogItem[]> {
  const { inputs, est } = ctx;
  const weekStart = addDays(inputs.startDate, (week - 1) * 7);
  const studyDays: string[] = [];
  for (let k = 0; k < 7; k++) {
    const d = addDays(weekStart, k);
    if (inputs.days.includes(weekday(d))) studyDays.push(d);
  }
  const out = new Map<string, CatalogItem[]>();
  if (!studyDays.length) return out;
  const finalCheck = est.checkpointWeeks.length > 0 && week === est.checkpointWeeks[est.checkpointWeeks.length - 1];
  if (inputs.modules.length === 4 && inputs.examDate && finalCheck) {
    const mock = ctx.catalog.items.find((i) => i.type === 'mock' && usable(i, ctx));
    if (mock) {
      out.set(studyDays[studyDays.length - 1], [mock]);
      return out;
    }
  }
  const order = [...inputs.modules].sort((a, b) => moduleBand(ctx.profile, b) - moduleBand(ctx.profile, a));
  const days = studyDays.slice(-order.length);
  order.forEach((m, i) => {
    const d = days[i % days.length];
    out.set(d, [...(out.get(d) ?? []), ...sectionTest(m, ctx)]);
  });
  return out;
}

/** Module that is furthest behind its share of minutes so far. */
function pickModule(ctx: DayContext, used: Record<string, number>): Module {
  const total = Object.values(used).reduce((s, v) => s + v, 0) + 1;
  let pick = ctx.inputs.modules[0];
  let gapMax = -Infinity;
  for (const m of ctx.inputs.modules) {
    const share = ctx.est.split[m] ?? 0;
    const gap = share - (used[m] ?? 0) / total;
    if (gap > gapMax) {
      gapMax = gap;
      pick = m;
    }
  }
  return pick;
}

/**
 * Tasks for every study day from [from] to [to] (inclusive). [used] carries
 * minutes per module so the split stays balanced across calls.
 */
export function generateDays(
  inputs: PlanInputs,
  est: Estimate,
  profile: Profile,
  catalog: Catalog,
  state: PlanState,
  from: string,
  to: string,
  userKey: string,
  used: Record<string, number> = {},
): PlannedTask[] {
  const ctx: DayContext = { inputs, est, profile, need: needs(profile, inputs), catalog, state, userKey };
  const out: PlannedTask[] = [];
  const endDay = addDays(inputs.startDate, est.weeks * 7 - 1);
  const last = daysBetween(to, endDay) < 0 ? endDay : to;
  let pronThisWeek = 0;
  let weekSeen = -1;
  let cpWeek = -1;
  let cpDays = new Map<string, CatalogItem[]>();
  for (let d = from; daysBetween(d, last) >= 0; d = addDays(d, 1)) {
    const offset = daysBetween(inputs.startDate, d);
    if (offset < 0) continue;
    const week = Math.floor(offset / 7) + 1;
    if (week !== weekSeen) {
      weekSeen = week;
      pronThisWeek = 0;
    }
    if (!inputs.days.includes(weekday(d))) continue;
    const phase = phaseOf(est, week);

    // Checkpoint week: section tests on the last study days.
    if (est.checkpointWeeks.includes(week)) {
      if (cpWeek !== week) {
        cpWeek = week;
        cpDays = checkpointDays(week, ctx);
      }
      const cp = cpDays.get(d);
      if (cp && cp.length) {
        for (const item of cp) {
          out.push(toTask(item, d, ctx, true));
          if ((MODULES as string[]).includes(item.module)) used[item.module] = (used[item.module] ?? 0) + item.minutes;
        }
        continue;
      }
    }

    let budget = inputs.minutesPerDay;
    const dayTasks: PlannedTask[] = [];
    const mod = pickModule(ctx, used);
    const add = (item: CatalogItem | null) => {
      if (!item) return false;
      dayTasks.push(toTask(item, d, ctx));
      budget -= item.minutes;
      const m = (MODULES as string[]).includes(item.module) ? item.module : (item.module === 'grammar' || item.module === 'vocab') ? mod : mod;
      used[m] = (used[m] ?? 0) + item.minutes;
      return true;
    };

    // Slot 1: a course lesson early on, test-style practice later.
    if (phase === 'foundation' || (phase === 'build' && hash01(userKey + d) < 0.45)) {
      const l = nextLesson(mod, ctx);
      if (!(l && l.minutes <= budget + 5 && add(l))) add(best(practicePool(mod, ctx, phase), ctx, phase, budget));
    } else {
      add(best(practicePool(mod, ctx, phase), ctx, phase, budget));
    }

    // Slot 2: practice for the same module, or support grammar / vocabulary.
    if (budget >= 8) {
      const support = phase !== 'exam' && hash01(userKey + d + 's') < 0.35 ? supportLesson(ctx) : null;
      if (!(support && support.minutes <= budget + 5 && add(support))) {
        add(best(practicePool(mod, ctx, phase), ctx, phase, budget));
      }
    }

    // Pronunciation twice a week for speaking students who need it.
    if (budget >= 8 && inputs.modules.includes('speaking') && pronThisWeek < 2 && (ctx.need['speaking.pron'] ?? 0) > 0.2) {
      const pron = catalog.items.find((i) => i.id === 'pron:daily');
      if (pron && add(pron)) pronThisWeek++;
    }

    // Slot 3: fill what's left with another module's short practice.
    if (budget >= 10 && inputs.modules.length > 1) {
      const other = inputs.modules.filter((m) => m !== mod);
      const m2 = other[Math.floor(hash01(userKey + d + 'o') * other.length)];
      add(best(practicePool(m2, ctx, phase), ctx, phase, budget));
    }

    // Nothing fitted (very short budget): smallest practice of the module.
    if (!dayTasks.length) {
      const pool = practicePool(mod, ctx, phase).filter((i) => usable(i, ctx)).sort((a, b) => a.minutes - b.minutes);
      if (pool[0]) add(pool[0]);
    }
    out.push(...dayTasks);
  }
  return out;
}

// ── summary for the student ─────────────────────────────────────────────────

const PHASE_LABEL: Record<Phase['id'], string> = {
  foundation: 'Foundations',
  build: 'Build skills',
  exam: 'Exam practice',
  review: 'Final review',
};

export function phaseLabel(id: Phase['id']): string {
  return PHASE_LABEL[id];
}

export function summary(inputs: PlanInputs, est: Estimate): string {
  const days = inputs.days.length;
  const lines: string[] = [];
  if (est.onTrack) {
    lines.push(
      est.weeksMin === est.weeksMax
        ? `About ${est.weeks} weeks at ${inputs.minutesPerDay} minutes a day, ${days} days a week.`
        : `About ${est.weeksMin} to ${est.weeksMax} weeks at ${inputs.minutesPerDay} minutes a day, ${days} days a week.`,
    );
  } else {
    const gain = est.gainBy >= 0.5 ? `about +${est.gainBy.toFixed(1)} band is realistic by then` : 'the biggest gains will come from exam technique and steady practice';
    lines.push(
      est.limit === 'exam'
        ? `Your exam is in ${est.weeksToExam} week${est.weeksToExam === 1 ? '' : 's'}: tight for Band ${est.targetBand.toFixed(1)} at this pace, and ${gain}. More daily time or a later exam date would give you a better chance.`
        : `Band ${est.targetBand.toFixed(1)} needs more than a year at this pace. This ${est.weeks}-week plan gets you as far as possible; more daily time gets you there sooner.`,
    );
  }
  lines.push(`Most time goes to ${MODULE_LABEL[est.focus]}, where you have the most to gain.`);
  if (est.checkpointWeeks.length) lines.push('Checkpoint tests every few weeks keep the plan matched to your real level.');
  return lines.join(' ');
}
