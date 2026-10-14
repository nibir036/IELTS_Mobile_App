// Study plan helpers shared by server pages and client components
// (lib/features/plan/plan_api.dart, plan_widgets.dart).

import { appHref } from '../home/routes';

export type Row = Record<string, unknown>;

export interface PlanTask {
  id: string;
  title: string;
  skill: string;
  kind: string;
  date: string;
  time?: string;
  durationMin: number;
  done: boolean;
  target: string;
  args?: Row;
  planId?: string;
  itemId?: string;
  ref?: string;
  reason?: string;
  checkpoint?: boolean;
}

export interface PlanInputs {
  modules: string[];
  levels: Record<string, string>;
  targetBand: number;
  testType?: string;
  examDate: string | null;
  days: number[];
  minutesPerDay: number;
  studyTime: string;
  previousScore?: number | null;
  worry?: string | null;
  startDate?: string;
  tzOffsetMin?: number;
}

export interface Plan {
  id: string;
  status: string;
  inputs: PlanInputs;
  estimate: Row & { targetBand?: number; weeks?: number };
  summary: string;
  pausedUntil: string | null;
  today: string;
  week: number;
  weeks: number;
  phase: { id: string; label: string };
  checkpointThisWeek: boolean;
  progress: { done: number; due: number; weekDone: number; weekTotal: number; minutesThisWeek: number };
  weekNote: { title: string; body: string; focus?: string[]; by?: string } | null;
  quickCheck: { done: boolean; at: string | null };
  access: { plan: 'free' | 'pro'; freeUntil: string | null; ended: boolean; ai: boolean; quickCheck: boolean };
  tasks: PlanTask[];
}

export const PLAN_MODULES = ['listening', 'reading', 'writing', 'speaking'] as const;

export const LEVEL_LABELS: Record<string, string> = {
  beginner: 'Beginner',
  amateur: 'Some basics',
  intermediate: 'Intermediate',
  advanced: 'Advanced',
};

export function moduleLabel(m: string): string {
  return { listening: 'Listening', reading: 'Reading', writing: 'Writing', speaking: 'Speaking' }[m] ?? m;
}

export function skillIcon(skill: string): string {
  switch (skill) {
    case 'listening':
      return 'headphones';
    case 'reading':
      return 'menu_book';
    case 'writing':
      return 'edit_note';
    case 'speaking':
      return 'mic';
    case 'mock':
      return 'fact_check';
    case 'vocab':
    case 'grammar':
      return 'school';
    default:
      return 'task_alt';
  }
}

const s = (v: unknown) => (v == null ? '' : String(v));
const enc = (v: unknown) => encodeURIComponent(s(v));

/** The web page for a plan task's app route + args (openPlanTask). */
export function taskHref(t: Pick<PlanTask, 'target' | 'args' | 'skill'>): string {
  const a = (t.args ?? {}) as Row;
  switch (t.target) {
    case '/reading/passage':
      return `/app/reading/do/${enc(a.passageId)}`;
    case '/reading/questions':
      return `/app/reading/do/${enc(a.testId)}`;
    case '/reading/bank/lesson':
      return `/app/reading/type/${enc(a.type)}`;
    case '/course/lesson':
      return `/app/courses/lesson/${enc(a.lesson)}`;
    case '/speaking/cue-card':
      return `/app/speaking/cue/${enc(a.cardId)}`;
    case '/speaking/part-1-3':
      return Number(a.part) === 3 ? `/app/speaking/session/3/${enc(a.part3TopicId ?? a.topicId)}` : `/app/speaking/session/1/${enc(a.topicId)}`;
    case '/speaking/pronunciation':
      return '/app/speaking/pronunciation';
    case '/writing/task1':
    case '/writing/task2':
      return `/app/writing/write/${enc(a.promptId)}`;
    case '/writing/sentence-builder':
      return a.set ? `/app/writing/sentence-builder?set=${enc(a.set)}` : '/app/writing/sentence-builder';
    case '/listening/player':
      return `/app/listening/set/${enc(a.setId)}`;
    case '/listening/answer-sheet':
      return `/app/listening/test/${enc(a.testId)}`;
    case '/mock/system-check':
      return `/app/mocks/${enc(a.mockId)}`;
    default: {
      // Any other app route (lessons, guides, resources …): the shared route map.
      const href = t.target ? appHref(t.target, a) : '';
      return href && href !== '/app' ? href : skillLanding(t.skill);
    }
  }
}

export function skillLanding(skill: string): string {
  switch (skill) {
    case 'listening':
      return '/app/listening';
    case 'reading':
      return '/app/reading';
    case 'writing':
      return '/app/writing';
    case 'speaking':
      return '/app/speaking';
    case 'mock':
      return '/app/mocks';
    default:
      return '/app/practice';
  }
}

const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MO = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "2026-10-14" → a Date at noon UTC (safe for day maths in any zone). */
export function parseDay(key: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(key);
  return m ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], 12)) : null;
}

export function dayKeyOf(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

export function addDays(key: string, n: number): string {
  const d = parseDay(key);
  if (!d) return key;
  d.setUTCDate(d.getUTCDate() + n);
  return dayKeyOf(d);
}

/** "Wed, 14 Oct". */
export function shortDay(key: string): string {
  const d = parseDay(key);
  return d ? `${WD[d.getUTCDay()]}, ${d.getUTCDate()} ${MO[d.getUTCMonth()]}` : key;
}

/** "Today", "Tomorrow", "Yesterday" or "Wed, 14 Oct" ([today] is the plan's own day key). */
export function planDayLabel(key: string, today: string): string {
  if (key === today) return 'Today';
  if (key === addDays(today, 1)) return 'Tomorrow';
  if (key === addDays(today, -1)) return 'Yesterday';
  return shortDay(key);
}

export const WEEKDAYS_SHORT = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

export function formatHalf(b: number | null | undefined): string {
  return typeof b === 'number' && Number.isFinite(b) ? b.toFixed(1) : '-';
}
