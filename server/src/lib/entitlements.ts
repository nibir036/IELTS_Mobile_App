// Free plan allowances (lifetime, per account) and the checks that enforce
// them. Pro accounts are never limited.
//
//   Writing   Task 1 practice ........ 1     Task 2 practice ........ 1
//             Writing Test (Tests tab) 1 test (both tasks of that one test)
//   Speaking  Part 1 ................. 1     Part 2 ................. 1
//             Part 3 ................. 1
//             Speaking Test (Tests tab) 1 test (its three parts)
//   Full Mock Test ................... 1 (its writing + its speaking)
//   Level test (onboarding) .......... 1 (its writing + its speaking)
//   Pronunciation trainer ............ 5 words scored
//   Band 8 rewrite ................... 1
//   Study plan: the first 3 study days, rules only (no AI notes, no
//   weekly re-planning), no quick check.
//
// Writing and speaking use is read from the AI-graded attempts, so a failed
// or "please re-record" speaking session (aiGraded: false) doesn't use the
// allowance. Pronunciation and rewrites leave no attempt: they are counted
// in usage_events.

import { prisma } from '../db';
import { HttpError } from './http';
import { isPro } from './users';

export const FREE = {
  writingTask1: 1,
  writingTask2: 1,
  writingTests: 1,
  speakingPart1: 1,
  speakingPart2: 1,
  speakingPart3: 1,
  speakingTests: 1,
  mocks: 1,
  diagnostics: 1,
  pronunciation: 5,
  rewrite: 1,
  planDays: 3,
} as const;

/** Error the app turns into the upgrade screen. */
export function upgradeRequired(message: string, feature: string): HttpError {
  return new HttpError(402, message, 'upgrade_required', { feature });
}

type Row = Record<string, unknown>;

/** "wt_12_t1" → "wt_12"; "st_03_cc" → "st_03"; anything else → null. */
export function fullTestOf(ref: unknown): string | null {
  const m = /^((?:wt|st)_\d+)(?:_|$)/.exec(String(ref ?? ''));
  return m ? m[1] : null;
}

/** What a writing request or attempt uses up. */
export interface WritingUse {
  bucket: 'task1' | 'task2' | 'test' | 'mock' | 'diagnostic';
  /** For 'test': the Writing Test id (wt_NN). */
  test?: string;
  /** Tasks of that test (1, 2). */
  tasks: number[];
}

/** Classifies a writing evaluation by its kind and prompt/test ids. */
export function writingUse(kind: string, refs: unknown[], tasks: number[]): WritingUse {
  if (kind.startsWith('mock_')) return { bucket: 'mock', tasks };
  if (kind.startsWith('diag_')) return { bucket: 'diagnostic', tasks };
  for (const r of refs) {
    const test = fullTestOf(r);
    if (test?.startsWith('wt_')) return { bucket: 'test', test, tasks };
  }
  if (kind === 'test') return { bucket: 'test', tasks };
  return { bucket: tasks.includes(1) && !tasks.includes(2) ? 'task1' : 'task2', tasks };
}

/** What a speaking session uses up. */
export interface SpeakingUse {
  bucket: 'practice' | 'test' | 'mock' | 'diagnostic';
  /** For 'test': the Speaking Test id (st_NN). */
  test?: string;
  /** Parts it covers (1, 2, 3). */
  parts: number[];
}

export function speakingUse(mode: string, refId: unknown, parts: number[]): SpeakingUse {
  const uniq = [...new Set(parts.filter((p) => p >= 1 && p <= 3))].sort();
  if (mode === 'mock') return { bucket: 'mock', parts: uniq };
  if (mode === 'diagnostic') return { bucket: 'diagnostic', parts: uniq };
  const test = fullTestOf(refId);
  if (test?.startsWith('st_')) return { bucket: 'test', test, parts: uniq };
  if (!uniq.length) {
    const m = /^part([123])$/.exec(mode);
    if (m) uniq.push(Number(m[1]));
  }
  return { bucket: 'practice', parts: uniq };
}

interface Used {
  writing: WritingUse[];
  speaking: SpeakingUse[];
  pronunciation: number;
  rewrite: number;
}

const tasksOf = (kind: string, data: Row): number[] => {
  if (data.task1 || data.task2) return [...(data.task1 ? [1] : []), ...(data.task2 ? [2] : [])];
  const m = /task([12])$/.exec(kind);
  return m ? [Number(m[1])] : [2];
};

async function used(userId: string): Promise<Used> {
  const [attempts, events] = await Promise.all([
    prisma.attempt.findMany({
      where: { userId, skill: { in: ['writing', 'speaking'] }, data: { path: ['aiGraded'], equals: true } },
      select: { skill: true, kind: true, refId: true, data: true },
    }),
    prisma.usageEvent.groupBy({ by: ['feature'], where: { userId }, _count: { _all: true } }) as Promise<
      Array<{ feature: string; _count: { _all: number } }>
    >,
  ]);
  const out: Used = { writing: [], speaking: [], pronunciation: 0, rewrite: 0 };
  for (const a of attempts as Array<{ skill: string; kind: string; refId: string | null; data: unknown }>) {
    const data = (a.data ?? {}) as Row;
    if (a.skill === 'writing') {
      const t1 = (data.task1 ?? {}) as Row;
      out.writing.push(writingUse(a.kind, [a.refId, data.promptId, t1.promptId], tasksOf(a.kind, data)));
    } else {
      const segs = Array.isArray(data.segments) ? (data.segments as Row[]) : [];
      out.speaking.push(speakingUse(a.kind, a.refId, segs.map((x) => Number(x.part))));
    }
  }
  for (const e of events) {
    if (e.feature === 'pronunciation') out.pronunciation = e._count._all;
    if (e.feature === 'rewrite') out.rewrite = e._count._all;
  }
  return out;
}

const PLAN_MSG = 'Upgrade to Pro for unlimited AI feedback.';

/** Throws 402 upgrade_required when a free account can't take this writing evaluation. */
export async function checkWriting(userId: string, use: WritingUse): Promise<void> {
  if (await isPro(userId)) return;
  const u = (await used(userId)).writing;
  const of = (b: WritingUse['bucket']) => u.filter((x) => x.bucket === b);
  switch (use.bucket) {
    case 'task1':
      if (of('task1').length >= FREE.writingTask1) {
        throw upgradeRequired(`Your free Writing Task 1 practice is used. ${PLAN_MSG}`, 'writing_task1');
      }
      return;
    case 'task2':
      if (of('task2').length >= FREE.writingTask2) {
        throw upgradeRequired(`Your free Writing Task 2 practice is used. ${PLAN_MSG}`, 'writing_task2');
      }
      return;
    case 'test': {
      const tests = new Set(of('test').map((x) => x.test ?? '?'));
      const sameTest = use.test != null && tests.has(use.test);
      if (!sameTest && tests.size >= FREE.writingTests) {
        throw upgradeRequired(`Your free Writing Test is used. ${PLAN_MSG}`, 'writing_test');
      }
      if (sameTest) {
        const done = new Set(of('test').filter((x) => x.test === use.test).flatMap((x) => x.tasks));
        if (use.tasks.some((t) => done.has(t))) {
          throw upgradeRequired(`You've already done this task of your free Writing Test. ${PLAN_MSG}`, 'writing_test');
        }
      }
      return;
    }
    case 'mock':
      if (of('mock').length >= FREE.mocks) {
        throw upgradeRequired(`Your free Full Mock Test is used. ${PLAN_MSG}`, 'mock');
      }
      return;
    case 'diagnostic':
      if (of('diagnostic').length >= FREE.diagnostics) {
        throw upgradeRequired(`You've already taken the free level test. ${PLAN_MSG}`, 'diagnostic');
      }
      return;
  }
}

/** Throws 402 upgrade_required when a free account can't start this speaking session. */
export async function checkSpeaking(userId: string, use: SpeakingUse): Promise<void> {
  if (await isPro(userId)) return;
  const u = (await used(userId)).speaking;
  const of = (b: SpeakingUse['bucket']) => u.filter((x) => x.bucket === b);
  switch (use.bucket) {
    case 'practice': {
      const done = new Set(of('practice').flatMap((x) => x.parts));
      const again = use.parts.find((p) => done.has(p));
      if (again) {
        throw upgradeRequired(`Your free Speaking Part ${again} practice is used. ${PLAN_MSG}`, `speaking_part${again}`);
      }
      return;
    }
    case 'test': {
      const tests = new Set(of('test').map((x) => x.test ?? '?'));
      const sameTest = use.test != null && tests.has(use.test);
      if (!sameTest && tests.size >= FREE.speakingTests) {
        throw upgradeRequired(`Your free Speaking Test is used. ${PLAN_MSG}`, 'speaking_test');
      }
      if (sameTest) {
        const done = new Set(of('test').filter((x) => x.test === use.test).flatMap((x) => x.parts));
        if (use.parts.some((p) => done.has(p))) {
          throw upgradeRequired(`You've already done this part of your free Speaking Test. ${PLAN_MSG}`, 'speaking_test');
        }
      }
      return;
    }
    case 'mock':
      if (of('mock').length >= FREE.mocks) {
        throw upgradeRequired(`Your free Full Mock Test is used. ${PLAN_MSG}`, 'mock');
      }
      return;
    case 'diagnostic':
      if (of('diagnostic').length >= FREE.diagnostics) {
        throw upgradeRequired(`You've already taken the free level test. ${PLAN_MSG}`, 'diagnostic');
      }
      return;
  }
}

/** Pronunciation trainer / rewrite: check before calling the AI. */
export async function checkCounted(userId: string, feature: 'pronunciation' | 'rewrite'): Promise<void> {
  if (await isPro(userId)) return;
  const u = await used(userId);
  if (feature === 'pronunciation' && u.pronunciation >= FREE.pronunciation) {
    throw upgradeRequired(`You've used your ${FREE.pronunciation} free pronunciation checks. ${PLAN_MSG}`, 'pronunciation');
  }
  if (feature === 'rewrite' && u.rewrite >= FREE.rewrite) {
    throw upgradeRequired(`Your free Band 8 rewrite is used. ${PLAN_MSG}`, 'rewrite');
  }
}

/** Records a successful pronunciation check / rewrite. */
export async function recordUse(userId: string, feature: 'pronunciation' | 'rewrite', ref?: string): Promise<void> {
  await prisma.usageEvent.create({ data: { userId, feature, ref: ref ? ref.slice(0, 120) : null } });
}

/** Pro-only features (study plan AI, quick check). */
export async function requirePro(userId: string, message: string, feature: string): Promise<void> {
  if (!(await isPro(userId))) throw upgradeRequired(message, feature);
}

/**
 * What the app shows and uses to lock buttons before the student starts:
 * {plan, free: {feature: {used, limit, left}}, writingTest, speakingTest}.
 * Pro: plan 'pro' and no limits.
 */
export async function entitlements(userId: string) {
  const pro = await isPro(userId);
  if (pro) return { plan: 'pro' as const, limits: null };
  const u = await used(userId);
  const w = (b: WritingUse['bucket']) => u.writing.filter((x) => x.bucket === b);
  const sp = (b: SpeakingUse['bucket']) => u.speaking.filter((x) => x.bucket === b);
  const practiceParts = new Set(sp('practice').flatMap((x) => x.parts));
  const item = (usedN: number, limit: number) => ({ used: usedN, limit, left: Math.max(0, limit - usedN) });
  const wTests = [...new Set(w('test').map((x) => x.test).filter(Boolean))] as string[];
  const sTests = [...new Set(sp('test').map((x) => x.test).filter(Boolean))] as string[];
  const mockUsed = Math.max(w('mock').length, sp('mock').length);
  return {
    plan: 'free' as const,
    limits: {
      writingTask1: item(w('task1').length, FREE.writingTask1),
      writingTask2: item(w('task2').length, FREE.writingTask2),
      writingTest: {
        ...item(wTests.length, FREE.writingTests),
        // The test already started (its other task is still free).
        test: wTests[0] ?? null,
        tasksDone: [...new Set(w('test').flatMap((x) => x.tasks))],
      },
      speakingPart1: item(practiceParts.has(1) ? 1 : 0, FREE.speakingPart1),
      speakingPart2: item(practiceParts.has(2) ? 1 : 0, FREE.speakingPart2),
      speakingPart3: item(practiceParts.has(3) ? 1 : 0, FREE.speakingPart3),
      speakingTest: {
        ...item(sTests.length, FREE.speakingTests),
        test: sTests[0] ?? null,
        partsDone: [...new Set(sp('test').flatMap((x) => x.parts))],
      },
      mock: {
        ...item(mockUsed, FREE.mocks),
        writingDone: w('mock').length > 0,
        speakingDone: sp('mock').length > 0,
      },
      diagnostic: item(Math.max(w('diagnostic').length, sp('diagnostic').length), FREE.diagnostics),
      pronunciation: item(u.pronunciation, FREE.pronunciation),
      rewrite: item(u.rewrite, FREE.rewrite),
      planDays: FREE.planDays,
      planAi: false,
      quickCheck: false,
    },
  };
}
