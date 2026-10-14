import { rows, str, type Raw } from '../practice/marking';
import { getPack } from './packs';

/** Listening question bank: 32 sets (4 parts × 8 formats). */
export async function listeningBankSets(): Promise<Raw[]> {
  return rows((await getPack<Raw>('bank.listening')).sets);
}

/** Full listening tests and their part recordings (tests bank). */
export async function listeningTests(): Promise<{ tests: Raw[]; sets: Raw[] }> {
  const l = ((await getPack<Raw>('bank.tests')).listening ?? {}) as Raw;
  return { tests: rows(l.tests), sets: rows(l.sets) };
}

export async function listeningSet(id: string): Promise<Raw | null> {
  const bank = await listeningBankSets();
  return bank.find((s) => str(s.id) === id) ?? (await listeningTests()).sets.find((s) => str(s.id) === id) ?? null;
}

/** Reading: full tests (tests bank) and the question bank (passages + short practice tests). */
export async function readingContent(): Promise<{ fullTests: Raw[]; practiceTests: Raw[]; bankPassages: Raw[]; testPassages: Raw[]; lessons: Raw[] }> {
  const [bank, tests] = await Promise.all([getPack<Raw>('bank.reading'), getPack<Raw>('bank.tests')]);
  const r = (tests.reading ?? {}) as Raw;
  return {
    fullTests: rows(r.tests),
    testPassages: rows(r.passages),
    practiceTests: rows(bank.tests),
    bankPassages: rows(bank.passages),
    lessons: rows(bank.lessons),
  };
}

export async function readingPassage(id: string): Promise<Raw | null> {
  const c = await readingContent();
  return c.bankPassages.find((p) => str(p.id) === id) ?? c.testPassages.find((p) => str(p.id) === id) ?? null;
}
