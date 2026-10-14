// Marking for Listening and Reading, ported from the app (Scoring.norm /
// matches / listeningBand / readingBand in store.dart, listeningItems in
// listening/session.dart, ReadingRefs in reading/session.dart).

export type Raw = Record<string, unknown>;
export const str = (v: unknown) => (v == null ? '' : String(v));
export const rows = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);
export const strs = (v: unknown): string[] => (Array.isArray(v) ? v.map(str) : []);

export function norm(s: string): string {
  return s
    .toLowerCase()
    .replace(/[\s\-–—/]+/g, ' ')
    .trim()
    .replace(/^(the|a|an)\s+/, '')
    .replace(/[^a-z0-9 ]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function matches(given: string, accepted: unknown): boolean {
  const g = norm(given);
  if (!g) return false;
  const list = Array.isArray(accepted) ? accepted.map(str) : str(accepted).split('|');
  return list.some((a) => norm(a) === g);
}

function fromTable(raw: number, table: Array<[number, number]>): number {
  for (const [min, band] of table) if (raw >= min) return band;
  return raw > 0 ? 2 : 0;
}

export function listeningBand(correct: number, total = 40): number {
  const raw = total === 40 ? correct : Math.round((correct * 40) / Math.max(1, total));
  return fromTable(raw, [[39, 9], [37, 8.5], [35, 8], [32, 7.5], [30, 7], [26, 6.5], [23, 6], [18, 5.5], [16, 5], [13, 4.5], [11, 4], [8, 3.5], [6, 3], [4, 2.5]]);
}

export function readingBand(correct: number, total = 40): number {
  const raw = total === 40 ? correct : Math.round((correct * 40) / Math.max(1, total));
  return fromTable(raw, [[39, 9], [37, 8.5], [35, 8], [33, 7.5], [30, 7], [27, 6.5], [23, 6], [19, 5.5], [15, 5], [13, 4.5], [10, 4], [8, 3.5], [6, 3], [4, 2.5]]);
}

/** One answer box: a question (or one slot of a "choose TWO"). */
export interface Item {
  number: number;
  local: number;
  part: number;
  group: Raw;
  q: Raw;
  /** "Choose TWO": the item's numbers (all slots share them). */
  multi?: number[];
}

export const type = (it: Item) => str(it.group.type);

// ── Listening ───────────────────────────────────────────────────────────────

/** Questions in a set ("choose TWO" with pick 2 counts as 2). */
export function setQuestionCount(set: Raw): number {
  let n = 0;
  for (const g of rows(set.groups)) {
    const pick = Number(g.pick) || 0;
    n += rows(g.questions).length * (pick > 1 ? pick : 1);
  }
  return n;
}

export function listeningItems(set: Raw, offset: number, part: number): Item[] {
  const out: Item[] = [];
  for (const g of rows(set.groups)) {
    const pick = Number(g.pick) || 0;
    for (const q of rows(g.questions)) {
      const n = (Number(q.number) || 0) + offset;
      if (pick > 1) {
        const nums = Array.from({ length: pick }, (_, k) => n + k);
        for (const m of nums) out.push({ number: m, local: m - offset, part, group: g, q, multi: nums });
      } else {
        out.push({ number: n, local: n - offset, part, group: g, q });
      }
    }
  }
  return out;
}

const letters = (v: unknown): string[] =>
  Array.isArray(v) ? v.map((e) => str(e).trim().toUpperCase()).filter(Boolean) : str(v).split(/[,|/ ]/).map((e) => e.trim().toUpperCase()).filter(Boolean);

/** Correct numbers of a listening answer sheet. */
export function markListening(items: Item[], answers: Record<number, string>): number[] {
  const out: number[] = [];
  const doneMulti = new Set<string>();
  for (const it of items) {
    const t = type(it);
    if (it.multi) {
      const key = it.multi.join(',');
      if (doneMulti.has(key)) continue;
      doneMulti.add(key);
      const right = new Set(letters(it.q.answer));
      const used = new Set<string>();
      for (const n of it.multi) {
        const v = (answers[n] ?? '').trim().toUpperCase();
        if (v && right.has(v) && !used.has(v)) {
          used.add(v);
          out.push(n);
        }
      }
      continue;
    }
    const given = (answers[it.number] ?? '').trim();
    if (!given) continue;
    if (t === 'mcq' || t === 'matching' || t === 'map') {
      if (given.toUpperCase() === str(it.q.answer).trim().toUpperCase()) out.push(it.number);
    } else if (matches(given, it.q.accepted ?? it.q.answer)) {
      out.push(it.number);
    }
  }
  return out.sort((a, b) => a - b);
}

// ── Reading ─────────────────────────────────────────────────────────────────

export function passageQuestionCount(p: Raw): number {
  let n = 0;
  for (const g of rows(p.groups)) {
    for (const q of rows(g.questions)) {
      const nums = q.numbers;
      n += Array.isArray(nums) && nums.length > 1 ? nums.length : 1;
    }
  }
  return n;
}

export function readingItems(passages: Array<[Raw, number]>): Item[] {
  const out: Item[] = [];
  passages.forEach(([p, offset], part) => {
    for (const g of rows(p.groups)) {
      for (const q of rows(g.questions)) {
        const nums = q.numbers;
        if (Array.isArray(nums) && nums.length > 1) {
          const all = nums.map((x) => Number(x) + offset);
          for (const m of all) out.push({ number: m, local: m - offset, part, group: g, q, multi: all });
        } else {
          const n = Number(q.number) || 0;
          out.push({ number: n + offset, local: n, part, group: g, q });
        }
      }
    }
  });
  return out.sort((a, b) => a.number - b.number);
}

const TYPED = new Set(['gap', 'notes', 'table', 'flowchart', 'diagram', 'short_answer', 'summary']);

/** Lettered {key, text} options of a reading group (endings, features, word boxes). */
export function optionObjects(g: Raw): Raw[] {
  return str(g.type) === 'sentence_endings' ? rows(g.endings) : rows(g.options);
}

export function readingTyped(it: Item): boolean {
  return TYPED.has(type(it)) && optionObjects(it.group).length === 0;
}

export function readingCorrect(it: Item, given: string): boolean {
  const v = given.trim();
  if (!v) return false;
  const accepted = it.q.accepted ?? it.q.answer;
  if (readingTyped(it)) return matches(v, accepted);
  const list = Array.isArray(accepted) ? accepted.map(str) : [str(accepted)];
  return list.some((a) => a.trim().toLowerCase() === v.toLowerCase());
}

export function markReading(items: Item[], answers: Record<number, string>): number[] {
  return items.filter((it) => readingCorrect(it, answers[it.number] ?? '')).map((it) => it.number);
}

/** The correct answer as shown on the answer key. */
export function correctLabel(it: Item): string {
  if (it.multi) {
    const a = it.q.answer;
    return Array.isArray(a) ? a.map(str).join(' and ') : str(a);
  }
  return str(it.q.answerDisplay) || str(it.q.answer);
}
