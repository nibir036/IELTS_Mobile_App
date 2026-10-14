// Speaking question bank for the library and sample answers (speaking/bank.dart):
// sample answers mark vocabulary as `[[word]]`; each mark's lower-case text is
// a key of the bank's `vocab`.

import { rows, str, strs, type Raw } from '../practice/marking';
import { getPack } from '../server/packs';

export interface VocabEntry {
  key: string;
  headword: string;
  pos: string;
  ipa: string;
  syllables: Array<{ text: string; stress: boolean }>;
  meaning: string;
  example: string;
  synonyms: string[];
  level: string;
}

export interface LibraryBank {
  meta: Raw;
  part1: Raw[];
  cards: Raw[];
  part3: Raw[];
  vocab: Raw;
  /** Part 3 topics of the full Speaking Tests (linked from their cue cards). */
  testPart3: Raw[];
}

export async function libraryBank(): Promise<LibraryBank> {
  const [b, t] = await Promise.all([getPack<Raw>('bank.speaking').catch(() => ({}) as Raw), getPack<Raw>('bank.tests').catch(() => ({}) as Raw)]);
  const ts = (t.speaking ?? {}) as Raw;
  return {
    meta: (b.meta ?? {}) as Raw,
    part1: rows(b.part1Topics),
    cards: rows(b.cueCards),
    part3: rows(b.part3Topics),
    vocab: (b.vocab && typeof b.vocab === 'object' ? b.vocab : {}) as Raw,
    testPart3: rows(ts.part3Topics),
  };
}

const MARK = /\[\[(.+?)\]\]/g;

export function plainSample(marked: string): string {
  return marked.replace(MARK, (_, w: string) => w);
}

/** Vocabulary keys marked in [marked], in order, no repeats. */
export function sampleVocabKeys(marked: string): string[] {
  const out: string[] = [];
  for (const m of marked.matchAll(MARK)) {
    const k = (m[1] ?? '').toLowerCase();
    if (k && !out.includes(k)) out.push(k);
  }
  return out;
}

export function sampleWordCount(marked: string): number {
  return (plainSample(marked).match(/[A-Za-z0-9'’-]+/g) ?? []).length;
}

export function vocabEntry(vocab: Raw, key: string): VocabEntry | null {
  const e = vocab[key.toLowerCase()];
  if (!e || typeof e !== 'object') return null;
  const r = e as Raw;
  return {
    key: key.toLowerCase(),
    headword: str(r.headword) || key,
    pos: str(r.pos),
    ipa: str(r.ipa),
    syllables: rows(r.syllables).map((s) => ({ text: str(s.text), stress: s.stress === true })),
    meaning: str(r.meaning),
    example: str(r.example),
    synonyms: strs(r.synonyms),
    level: str(r.level),
  };
}

/** One vocabulary key per headword, sorted by headword (library Words tab). */
export function wordKeys(vocab: Raw): string[] {
  const byHead = new Map<string, string>();
  for (const k of Object.keys(vocab)) {
    const head = str((vocab[k] as Raw | undefined)?.headword).toLowerCase() || k;
    if (!byHead.has(head)) byHead.set(head, k);
  }
  return [...byHead.keys()].sort().map((h) => byHead.get(h) as string);
}

export type SamplePart = 1 | 2 | 3;

/** The samples item by id, searching Part 1 topics, cue cards then Part 3 topics. */
export function findSample(bank: LibraryBank, id: string, part?: number): { part: SamplePart; item: Raw; list: Raw[] } | null {
  const lists: Array<[SamplePart, Raw[]]> = [
    [1, bank.part1],
    [2, bank.cards],
    [3, bank.part3],
  ];
  for (const [p, list] of lists) {
    if (part && part !== p) continue;
    const item = list.find((x) => str(x.id) === id);
    if (item) return { part: p, item, list };
  }
  if (!part || part === 3) {
    const t = bank.testPart3.find((x) => str(x.id) === id);
    if (t) return { part: 3, item: t, list: [t] };
  }
  return null;
}

export const samplesHref = (id: string) => `/app/speaking/samples/${encodeURIComponent(id)}`;

/** kv key of the bookmarks of a part (speaking/cue_card_vault_screen.dart). */
export const savedKey = (part: SamplePart) => (part === 1 ? 'speaking.savedPart1' : part === 3 ? 'speaking.savedPart3' : 'speaking.savedCards');
