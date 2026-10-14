// The Sentence Builder bank (pack bank.sentence): categories → sets of 10
// drills. Progress = the student's writing 'drill' attempts (refId = set id),
// exactly like the app (SentenceBank in writing_data.dart).

import type { Attempt } from './attempts';
import { getPack } from './packs';

type Raw = Record<string, unknown>;

export interface Drill {
  id: string;
  connector: string;
  function: string;
  sentences: string[];
  answer: string[];
  prefilled: number;
  bank: string[];
  hint: string;
  instruction?: string;
}
export interface SentenceSet {
  id: string;
  title: string;
  drills: Drill[];
}
export interface SentenceCategory {
  id: string;
  title: string;
  subtitle: string;
  icon: string;
  count: number;
  sets: SentenceSet[];
}
export interface SentenceBankData {
  instruction: string;
  total: number;
  categories: SentenceCategory[];
}

const s = (v: unknown) => (v == null ? '' : String(v));
const ss = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);
const rows = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);

export async function sentenceBank(): Promise<SentenceBankData> {
  const b = await getPack<Raw>('bank.sentence').catch(() => ({}) as Raw);
  return {
    instruction: s(b.instruction) || 'Join the two sentences into one',
    total: Number(b.total) || 0,
    categories: rows(b.categories).map((c) => ({
      id: s(c.id),
      title: s(c.title),
      subtitle: s(c.subtitle),
      icon: s(c.icon),
      count: Number(c.count) || 0,
      sets: rows(c.sets).map((x) => ({
        id: s(x.id),
        title: s(x.title),
        drills: rows(x.drills).map((d) => ({
          id: s(d.id),
          connector: s(d.connector),
          function: s(d.function),
          sentences: ss(d.sentences),
          answer: ss(d.answer),
          prefilled: Number(d.prefilled) || 0,
          bank: ss(d.bank),
          hint: s(d.hint),
          instruction: s(d.instruction) || undefined,
        })),
      })),
    })),
  };
}

export interface SetRef {
  category: SentenceCategory;
  set: SentenceSet;
  id: string;
  title: string;
}

const ref = (category: SentenceCategory, set: SentenceSet): SetRef => ({ category, set, id: set.id, title: `${category.title} · ${set.title}` });

export function findSet(bank: SentenceBankData, id: string): SetRef | null {
  for (const c of bank.categories) for (const x of c.sets) if (x.id === id) return ref(c, x);
  return null;
}

/** The set after [id]: the same category, then the next. */
export function nextSet(bank: SentenceBankData, id: string): SetRef | null {
  let found = false;
  for (const c of bank.categories)
    for (const x of c.sets) {
      if (found) return ref(c, x);
      if (x.id === id) found = true;
    }
  return null;
}

/** Best "right first time" score per set id. */
export function bestScores(drills: Attempt[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const a of drills) {
    const v = a.score ?? 0;
    if (v >= (out[a.refId] ?? -1)) out[a.refId] = v;
  }
  return out;
}

/** First unfinished set, starting after the latest one ([drills] newest first). */
export function resumeSet(bank: SentenceBankData, drills: Attempt[]): SetRef | null {
  const done = bestScores(drills);
  if (drills.length) {
    let r = findSet(bank, drills[0].refId) ? nextSet(bank, drills[0].refId) : null;
    while (r && done[r.id] !== undefined) r = nextSet(bank, r.id);
    if (r) return r;
  }
  for (const c of bank.categories) for (const x of c.sets) if (done[x.id] === undefined) return ref(c, x);
  return null;
}
