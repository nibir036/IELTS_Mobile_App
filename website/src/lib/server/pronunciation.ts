// Pronunciation trainer word sets (lib/features/speaking/bank.dart:
// pronunciationWordFor, pronunciationTopics, dailyPronunciationKeys), built
// from the speaking bank's vocabulary on the server so the page only gets
// the ten words it needs.

import { stateValue } from './attempts';
import { getPack, uiPack } from './packs';

type Raw = Record<string, unknown>;

export interface PronWord {
  id: string;
  word: string;
  ipa: string;
  pos: string;
  syllables: Array<{ text: string; state: 'stress' | 'normal' | 'error' }>;
  tip: string;
}

export const PRON_SCORES_KEY = 'speaking.pronScores';

const MARK = /\[\[(.+?)\]\]/g;
const s = (v: unknown) => (v == null ? '' : String(v));

function vocabOf(bank: Raw): Record<string, Raw> {
  const v = bank.vocab;
  return v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, Raw>) : {};
}

export function wordFor(vocab: Record<string, Raw>, key: string): PronWord | null {
  const e = vocab[key.toLowerCase()];
  if (!e) return null;
  const head = s(e.headword);
  const syl = Array.isArray(e.syllables) ? (e.syllables as Raw[]) : [];
  const stressed = syl
    .filter((x) => x.stress === true)
    .map((x) => s(x.text))
    .join('');
  return {
    id: `pv_${key.replace(/[^a-z0-9]+/g, '_')}`,
    word: head,
    ipa: s(e.ipa),
    pos: s(e.pos),
    syllables: syl.length
      ? syl.map((x) => ({ text: x.stress === true ? s(x.text).toUpperCase() : s(x.text), state: x.stress === true ? 'stress' : 'normal' }))
      : head.split(' ').map((w) => ({ text: w, state: 'normal' })),
    tip: stressed ? `Put the stress on “${stressed.toUpperCase()}”. ${s(e.meaning)}` : s(e.meaning),
  };
}

const topicCache = new WeakMap<object, Record<string, string[]>>();

/** Topic label → vocabulary keys marked in that topic's sample answers (10+ words). */
function topicsOf(bank: Raw): Record<string, string[]> {
  const hit = topicCache.get(bank);
  if (hit) return hit;
  const vocab = vocabOf(bank);
  const groups = new Map<string, Set<string>>();
  const collect = (o: unknown, into: Set<string>) => {
    if (typeof o === 'string') {
      for (const m of o.matchAll(MARK)) {
        const k = (m[1] ?? '').toLowerCase();
        if (k && vocab[k]) into.add(k);
      }
    } else if (Array.isArray(o)) o.forEach((v) => collect(v, into));
    else if (o && typeof o === 'object') Object.values(o).forEach((v) => collect(v, into));
  };
  for (const list of [bank.part1Topics, bank.cueCards, bank.part3Topics]) {
    for (const topic of Array.isArray(list) ? (list as Raw[]) : []) {
      const label = s(topic.categoryLabel);
      if (!label) continue;
      if (!groups.has(label)) groups.set(label, new Set());
      collect(topic, groups.get(label)!);
    }
  }
  const out = Object.fromEntries(
    [...groups.entries()]
      .filter(([, v]) => v.size >= 10)
      .sort((a, b) => b[1].size - a[1].size)
      .map(([k, v]) => [k, [...v].sort()]),
  );
  topicCache.set(bank, out);
  return out;
}

/** Small seeded generator (the same set all day, a new one tomorrow). */
function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function dailyKeys(bank: Raw, topic: string | null, count = 10): string[] {
  const pool = topic ? [...(topicsOf(bank)[topic] ?? [])] : Object.keys(vocabOf(bank)).sort();
  if (!pool.length) return [];
  const d = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Dhaka' }));
  let seed = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
  for (const c of topic ?? '') seed = (seed * 31 + c.charCodeAt(0)) & 0x7fffffff;
  const r = rng(seed);
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  const words = pool.filter((k) => !k.includes(' '));
  const phrases = pool.filter((k) => k.includes(' '));
  const nPhrases = Math.min(2, phrases.length);
  return [...words.slice(0, count - nPhrases), ...phrases.slice(0, count - Math.min(count - nPhrases, words.length))];
}

export interface PronSet {
  words: PronWord[];
  /** Today's mix / a topic (false for a fixed list of words). */
  daily: boolean;
  topic: string | null;
  title: string;
  refId: string;
  topics: Array<{ label: string; count: number }>;
  nativeWave: number[];
  tries: Record<string, number[]>;
}

/** The words to practise: given vocabulary keys, today's mix, or one topic. */
export async function pronunciationSet(q: { vocab?: string[]; title?: string; topic?: string | null }): Promise<PronSet> {
  const [bank, ui, tries] = await Promise.all([
    getPack<Raw>('bank.speaking'),
    uiPack().catch(() => ({}) as Raw),
    stateValue<Record<string, number[]>>(PRON_SCORES_KEY),
  ]);
  const vocab = vocabOf(bank);
  const topics = topicsOf(bank);
  const pron = ((ui.speaking ?? {}) as Raw).pronunciation as Raw | undefined;
  const nativeWave = Array.isArray(pron?.nativeWave) ? (pron!.nativeWave as number[]) : [4, 12, 8, 24, 32, 20, 8, 12, 6, 16, 10, 4, 12, 6, 2];
  const fixed = (q.vocab ?? []).map((k) => wordFor(vocab, k)).filter((w): w is PronWord => Boolean(w)).slice(0, 12);
  let words: PronWord[];
  let daily = false;
  let topic: string | null = null;
  let title: string;
  let refId: string;
  if (fixed.length) {
    words = fixed;
    title = `Pronunciation · ${q.title || 'Vocabulary'}`;
    refId = 'pron_vocab';
  } else {
    topic = q.topic && topics[q.topic] ? q.topic : null;
    words = dailyKeys(bank, topic)
      .map((k) => wordFor(vocab, k))
      .filter((w): w is PronWord => Boolean(w));
    daily = words.length > 0;
    if (!daily) {
      // No bank: the app's sample set.
      words = (Array.isArray(pron?.words) ? (pron!.words as Raw[]) : []).map((w) => ({
        id: s(w.id),
        word: s(w.word),
        ipa: s(w.ipa),
        pos: s(w.pos),
        syllables: (Array.isArray(w.syllables) ? (w.syllables as Raw[]) : []).map((x) => ({ text: s(x.text), state: s(x.state) === 'stress' ? 'stress' : 'normal' })),
        tip: s(w.tip),
      }));
    }
    title = daily ? `Pronunciation · ${topic ?? 'Today’s mix'}` : 'Pronunciation · Word set';
    refId = daily ? 'pron_daily' : 'pron_default';
  }
  const mine = tries && typeof tries === 'object' ? tries : {};
  return {
    words,
    daily,
    topic,
    title,
    refId,
    topics: Object.entries(topics).map(([label, keys]) => ({ label, count: keys.length })),
    nativeWave,
    tries: Object.fromEntries(words.map((w) => [w.id, Array.isArray(mine[w.id]) ? mine[w.id].filter((x) => typeof x === 'number') : []])),
  };
}
