// Study plan, phase 2: the week's note and a personal "why" line per task,
// written by Gemini from the student's own numbers. The rules engine still
// chooses every task (reliable and testable); the AI only explains. Every
// reply is checked: unknown task ids are dropped, and a band the input does
// not contain makes that line fall back to the rules text.

import { env } from '../env';
import { geminiJson } from './gemini';
import { plainDashes } from './http';
import { isPro } from './users';

export interface WeekTask {
  id: string;
  date: string;
  title: string;
  skill: string;
  minutes: number;
  practises: string[];
  checkpoint: boolean;
}

export interface WeekContext {
  week: number;
  weeks: number;
  phase: string;
  targetBand: number;
  examWeeksLeft: number | null;
  minutesPerDay: number;
  daysPerWeek: number;
  /** null in week 1. */
  lastWeek: { planned: number; done: number; minutesDone: number } | null;
  /** Per module: about-band now, at the last note, and how many results it rests on. */
  modules: { module: string; bandNow: number; bandBefore: number | null; results: number }[];
  /** Weakest sub-skills that have real results (label + about-band). */
  weakest: { skill: string; band: number; results: number }[];
  tasks: WeekTask[];
}

export interface WeekNote {
  week: number;
  title: string;
  body: string;
  focus: string[];
  by: 'ai' | 'rules';
  /** Module bands when the note was written (next week compares against them). */
  bands: Record<string, number>;
  at: string;
}

const MODULE_NAME: Record<string, string> = {
  listening: 'Listening',
  reading: 'Reading',
  writing: 'Writing',
  speaking: 'Speaking',
};

const PHASE_LINE: Record<string, string> = {
  Foundations: 'This week builds your foundations: lessons first, then short practice.',
  'Build skills': 'This week turns your lessons into skills with more test-style practice.',
  'Exam practice': 'This week is about exam technique and timing.',
  'Final review': 'This week is a calm review before your exam.',
};

const fmt = (b: number) => (Math.round(b * 2) / 2).toFixed(1);

/** Whether this student gets the AI layer (PLAN_AI = all | pro | off). */
export async function planAiAllowed(userId: string): Promise<boolean> {
  if (!env.geminiApiKey || env.planAi === 'off') return false;
  if (env.planAi === 'pro') return isPro(userId);
  return true;
}

// ── rules note (always available, written instantly) ────────────────────────

export function rulesNote(ctx: WeekContext): Omit<WeekNote, 'bands' | 'at'> {
  const parts: string[] = [];
  if (ctx.lastWeek && ctx.lastWeek.planned > 0) {
    const { done, planned } = ctx.lastWeek;
    parts.push(
      done >= planned
        ? `You finished all ${planned} tasks last week.`
        : `You finished ${done} of ${planned} tasks last week.`,
    );
  }
  const up = ctx.modules.filter((m) => m.bandBefore != null && m.results > 0 && m.bandNow - (m.bandBefore ?? 0) >= 0.25);
  if (up.length) {
    parts.push(`${up.map((m) => MODULE_NAME[m.module]).join(' and ')} went up to about band ${fmt(up[0].bandNow)}.`);
  }
  const focus = ctx.weakest.slice(0, 2).map((w) => w.skill);
  const checkpoint = ctx.tasks.some((t) => t.checkpoint);
  if (checkpoint) parts.push('This is a checkpoint week: short section tests show how far you have come.');
  else if (focus.length) parts.push(`This week puts extra time on ${focus.join(focus.some((f) => f.includes(' and ')) ? ', and on ' : ' and ')}.`);
  else parts.push(PHASE_LINE[ctx.phase] ?? 'This week keeps your practice going.');
  return {
    week: ctx.week,
    title: checkpoint ? `Week ${ctx.week}: checkpoint week` : `Week ${ctx.week} of ${ctx.weeks}: ${ctx.phase}`,
    body: parts.join(' '),
    focus,
    by: 'rules',
  };
}

// ── AI note ─────────────────────────────────────────────────────────────────

const SYSTEM = `You are the study coach inside the "IELTS AI by nextED" app. You write short notes for ONE student's personal IELTS study plan.

Hard rules:
- Use ONLY the facts in the input JSON. Never invent scores, bands, dates, tasks, topics or reasons.
- Bands are estimates from practice in the app. Say "about band 6.0", never promise a band.
- If a module has results = 0, do not mention a level for it.
- The tasks are already chosen. Do not suggest other tasks, apps, books or websites.
- Simple, friendly English for learners at about B1-B2 level. Short sentences. Talk to the student as "you".
- No em dashes, no emojis, no hashtags. At most one exclamation mark in the whole reply.

Write:
- note.title: max 60 characters, names the week (for example "Week 3: more work on coherence").
- note.body: 2 or 3 sentences, max 300 characters. Say what changed since last week if lastWeek or bandBefore data exists, then what this week focuses on and why.
- note.focus: 1 to 3 short skill names, copied from "weakest" (or module names if weakest is empty).
- reasons: one item per task id in the input. "why" is ONE sentence, max 120 characters, saying why this task helps THIS student now (link it to their weaker skills, the week's focus or the phase). For checkpoint tasks, say it measures progress.`;

const SCHEMA = {
  type: 'object',
  properties: {
    note: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        body: { type: 'string' },
        focus: { type: 'array', items: { type: 'string' } },
      },
      required: ['title', 'body', 'focus'],
    },
    reasons: {
      type: 'array',
      items: {
        type: 'object',
        properties: { id: { type: 'string' }, why: { type: 'string' } },
        required: ['id', 'why'],
      },
    },
  },
  required: ['note', 'reasons'],
};

/** Every "band N" in [text] must be a band the input contains. */
function bandsGrounded(text: string, allowed: Set<string>): boolean {
  for (const m of text.matchAll(/band\s*(\d(?:\.\d)?)/gi)) {
    const v = Number(m[1]);
    if (!allowed.has(v.toFixed(1))) return false;
  }
  return true;
}

function clean(s: unknown, max: number): string {
  const t = plainDashes(String(s ?? ''))
    .replace(/\s+/g, ' ')
    .trim();
  if (t.length <= max) return t;
  const cut = t.slice(0, max);
  const end = Math.max(cut.lastIndexOf('. '), cut.lastIndexOf('.'));
  return end > max * 0.5 ? cut.slice(0, end + 1) : `${cut.slice(0, cut.lastIndexOf(' '))}.`;
}

export interface AiWeek {
  note: Omit<WeekNote, 'bands' | 'at'>;
  reasons: Map<string, string>;
}

/** The week's note and task reasons from Gemini; throws when the AI fails. */
export async function aiWeek(ctx: WeekContext): Promise<AiWeek> {
  const input = {
    week: ctx.week,
    weeks: ctx.weeks,
    phase: ctx.phase,
    targetBand: fmt(ctx.targetBand),
    examWeeksLeft: ctx.examWeeksLeft,
    studyTime: `${ctx.minutesPerDay} minutes a day, ${ctx.daysPerWeek} days a week`,
    lastWeek: ctx.lastWeek,
    modules: ctx.modules.map((m) => ({
      module: MODULE_NAME[m.module] ?? m.module,
      bandNow: m.results > 0 ? fmt(m.bandNow) : null,
      bandBefore: m.bandBefore != null && m.results > 0 ? fmt(m.bandBefore) : null,
      results: m.results,
    })),
    weakest: ctx.weakest.map((w) => ({ skill: w.skill, band: fmt(w.band), results: w.results })),
    tasks: ctx.tasks.map((t) => ({
      id: t.id,
      day: t.date,
      title: t.title,
      module: MODULE_NAME[t.skill] ?? t.skill,
      minutes: t.minutes,
      practises: t.practises,
      checkpoint: t.checkpoint,
    })),
  };
  const allowed = new Set<string>([fmt(ctx.targetBand)]);
  for (const m of input.modules) {
    if (m.bandNow) allowed.add(m.bandNow);
    if (m.bandBefore) allowed.add(m.bandBefore);
  }
  for (const w of input.weakest) allowed.add(w.band);

  const { data } = await geminiJson({
    label: 'plan-week',
    model: env.geminiPlanModel || undefined,
    system: SYSTEM,
    user: JSON.stringify(input),
    schema: SCHEMA,
  });

  const fallback = rulesNote(ctx);
  const n = (data.note ?? {}) as Record<string, unknown>;
  let title = clean(n.title, 60);
  let body = clean(n.body, 320);
  if (!title || !bandsGrounded(title, allowed)) title = fallback.title;
  if (!body || !bandsGrounded(body, allowed)) body = fallback.body;
  const focus = (Array.isArray(n.focus) ? n.focus : [])
    .map((f) => clean(f, 40))
    .filter(Boolean)
    .slice(0, 3);

  const ids = new Set(ctx.tasks.map((t) => t.id));
  const reasons = new Map<string, string>();
  for (const r of Array.isArray(data.reasons) ? data.reasons : []) {
    const id = String((r as Record<string, unknown>)?.id ?? '');
    const why = clean((r as Record<string, unknown>)?.why, 140);
    if (ids.has(id) && why && bandsGrounded(why, allowed)) reasons.set(id, why);
  }
  return {
    note: { week: ctx.week, title, body, focus: focus.length ? focus : fallback.focus, by: 'ai' },
    reasons,
  };
}
