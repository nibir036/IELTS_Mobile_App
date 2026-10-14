// Server-side loaders for the mock answer review and improvement plan.

import { rows, str, type Raw } from '../practice/marking';
import type { Attempt } from '../server/attempts';
import { attempt, attempts } from '../server/attempts';
import { mockData, type MockData } from '../server/mocks';
import { getPack } from '../server/packs';

/** A mock attempt by id (null when missing or not a mock). */
export async function mockAttempt(id: string): Promise<Attempt | null> {
  const a = await attempt(decodeURIComponent(id));
  return a && a.skill === 'mock' ? a : null;
}

export const mockIdOf = (a: Attempt) => str(a.data.mockId) || a.refId;

/** The composition of the attempt's mock plus its raw cue card (prompt, topic). */
export async function mockComposition(a: Attempt): Promise<{ mock: MockData | null; cue: Raw }> {
  const [mock, tests] = await Promise.all([mockData(mockIdOf(a)).catch(() => null), getPack<Raw>('bank.tests').catch(() => ({}) as Raw)]);
  const S = (tests.speaking ?? {}) as Raw;
  const cue = mock?.cue.id ? (rows(S.cueCards).find((c) => str(c.id) === mock.cue.id) ?? {}) : {};
  return { mock, cue };
}

/** Every mock attempt of the student, newest first. */
export async function mockAttempts(): Promise<Attempt[]> {
  try {
    const list = await attempts({ skill: 'mock', limit: 200 });
    return list.filter((x) => x.kind === 'mock' || !x.kind).sort((x, y) => y.createdAt.localeCompare(x.createdAt));
  } catch {
    return [];
  }
}

/** The mock section's UI copy (demo_data.json → mock). */
export async function mockCopy(): Promise<Raw> {
  try {
    return ((await getPack<Raw>('ui')).mock ?? {}) as Raw;
  } catch {
    return {};
  }
}
