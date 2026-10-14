// Essay helpers ported from the app (EssayAnalysis in writing_data.dart), so
// an essay scored on the website is stored exactly like one scored in the app.

export function wordCount(text: string): number {
  return (text.trim().match(/[A-Za-z0-9'’-]+/g) ?? []).length;
}

/** Sentences with offsets: [start, end, text]. */
export function sentences(text: string): Array<[number, number, string]> {
  const out: Array<[number, number, string]> = [];
  const re = /[^.!?\n]+[.!?]*/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text))) {
    const raw = m[0];
    const lead = raw.length - raw.trimStart().length;
    const body = raw.trim();
    if (!body) continue;
    const start = m.index + lead;
    out.push([start, start + body.length, body]);
  }
  return out;
}

/** First occurrence of [phrase] not overlapping [used] (exact, then any case). */
export function locate(text: string, phrase: string, used: Array<[number, number]>): [number, number] | null {
  if (!phrase || !text) return null;
  const free = (s: number, e: number) => !used.some(([a, b]) => s < b && e > a);
  const scan = (hay: string, needle: string): [number, number] | null => {
    let from = 0;
    while (from <= hay.length - needle.length) {
      const s = hay.indexOf(needle, from);
      if (s < 0) return null;
      const e = s + needle.length;
      if (free(s, e)) return [s, e];
      from = s + 1;
    }
    return null;
  };
  return scan(text, phrase) ?? scan(text.toLowerCase(), phrase.toLowerCase());
}

export interface Issue {
  id: string;
  type: 'grammar' | 'vocab';
  category: string;
  title: string;
  label: string;
  start: number;
  end: number;
  original: string;
  suggestion: string;
  note: string;
  sentenceIndex: number;
}

const AI_TITLES: Record<string, string> = {
  grammar: 'Grammar',
  vocabulary: 'Vocabulary',
  vocab: 'Vocabulary',
  cohesion: 'Cohesion',
  task: 'Task response',
  punctuation: 'Punctuation',
  style: 'Style',
};

/** AI issues {original, suggestion, type, note} → the app's line-review shape with offsets. */
export function aiIssues(text: string, raw: Array<Record<string, unknown>>): Issue[] {
  const used: Array<[number, number]> = [];
  const c: Omit<Issue, 'id' | 'sentenceIndex'>[] = [];
  for (const r of raw) {
    const orig = String(r.original ?? '').trim();
    if (!orig) continue;
    const hit = locate(text, orig, used);
    if (!hit) continue;
    used.push(hit);
    const category = String(r.type ?? '').toLowerCase().trim();
    const isVocab = category === 'vocabulary' || category === 'vocab' || category === 'style';
    c.push({
      type: isVocab ? 'vocab' : 'grammar',
      category,
      title: AI_TITLES[category] ?? (isVocab ? 'Vocabulary' : 'Grammar'),
      label: category || (isVocab ? 'vocabulary' : 'grammar'),
      start: hit[0],
      end: hit[1],
      original: text.slice(hit[0], hit[1]),
      suggestion: String(r.suggestion ?? ''),
      note: String(r.note ?? ''),
    });
  }
  // finalize: order, drop overlaps, cap 20, number them.
  c.sort((a, b) => a.start - b.start || b.end - a.end);
  const sents = sentences(text);
  const out: Issue[] = [];
  let cursor = -1;
  for (const i of c) {
    if (i.start < cursor) continue;
    let idx = 0;
    sents.forEach(([s], j) => {
      if (s <= i.start) idx = j;
    });
    out.push({ ...i, id: `i${out.length + 1}`, sentenceIndex: idx });
    cursor = i.end;
    if (out.length >= 20) break;
  }
  return out;
}

export function roundBand(b: number): number {
  return Math.round(b * 2) / 2;
}

export function formatBand(b: number | null | undefined): string {
  if (b == null || !Number.isFinite(b)) return '-';
  return b.toFixed(1);
}

// ── band comparison (writing_rewriter_screen.dart) ───────────────────────────

export const LINKERS = [
  'however', 'moreover', 'furthermore', 'therefore', 'although', 'whereas',
  'in addition', 'on the other hand', 'for example', 'for instance',
  'consequently', 'nevertheless', 'in conclusion', 'overall', 'firstly',
  'secondly', 'finally', 'as a result', 'in contrast', 'to begin with',
  'meanwhile', 'admittedly',
];

const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const wordRe = (phrase: string) => new RegExp(`\\b${esc(phrase)}\\b`, 'gi');

export type Mark = { start: number; end: number; mark: 'cut' | 'new' };
export type Segment = { text: string; mark?: 'cut' | 'new' };

/** Issues whose offsets still point at their text, in order. */
export function validIssues(text: string, raw: unknown): Issue[] {
  const list = Array.isArray(raw) ? (raw as Issue[]) : [];
  return list
    .filter((i) => typeof i.start === 'number' && typeof i.end === 'number' && text.slice(i.start, i.end) === i.original)
    .sort((a, b) => a.start - b.start);
}

/** The essay with every suggestion applied, and marks on the replaced parts. */
export function applyFixes(text: string, issues: Issue[]): [string, Mark[]] {
  let out = '';
  const marks: Mark[] = [];
  let cursor = 0;
  for (const i of issues) {
    if (i.start < cursor) continue;
    out += text.slice(cursor, i.start);
    const ns = out.length;
    out += i.suggestion;
    marks.push({ start: ns, end: out.length, mark: 'new' });
    cursor = i.end;
  }
  out += text.slice(cursor);
  return [out, marks];
}

/** [text] split into paragraphs of plain / marked segments. */
export function paragraphs(text: string, marks: Mark[]): Segment[][] {
  const sorted = [...marks].sort((a, b) => a.start - b.start);
  const out: Segment[][] = [];
  const re = /[^\n]+/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text))) {
    if (!m[0].trim()) continue;
    const ps = m.index;
    const pe = ps + m[0].length;
    const segs: Segment[] = [];
    let cursor = ps;
    for (const k of sorted) {
      if (k.start < cursor || k.start < ps || k.end > pe || k.start >= k.end) continue;
      if (k.start > cursor) segs.push({ text: text.slice(cursor, k.start) });
      segs.push({ text: text.slice(k.start, k.end), mark: k.mark });
      cursor = k.end;
    }
    if (cursor < pe) segs.push({ text: text.slice(cursor, pe) });
    out.push(segs);
  }
  return out;
}

/** Every linking phrase in [text], non-overlapping. */
export function linkerMarks(text: string, mark: 'cut' | 'new'): Mark[] {
  const found: Mark[] = [];
  for (const l of LINKERS) for (const m of text.matchAll(wordRe(l))) found.push({ start: m.index ?? 0, end: (m.index ?? 0) + m[0].length, mark });
  found.sort((a, b) => a.start - b.start || b.end - a.end);
  const out: Mark[] = [];
  let cursor = -1;
  for (const f of found) {
    if (f.start < cursor) continue;
    out.push(f);
    cursor = f.end;
  }
  return out;
}

export function linkerCount(text: string): number {
  return LINKERS.reduce((n, l) => n + [...text.matchAll(wordRe(l))].length, 0);
}

export function complexCount(text: string): number {
  const re = /\b(which|who|whom|whose|because|although|though|while|whereas|when|if|since|unless|as a result)\b/i;
  return sentences(text).filter(([, , s]) => re.test(s)).length;
}

export function rareWordCount(text: string): number {
  return new Set((text.match(/[A-Za-z]{9,}/g) ?? []).map((w) => w.toLowerCase())).size;
}

/** The band the rewrite aims for: two bands up, Band 9 from Band 8 (WritingService.rewriteTarget). */
export function rewriteTarget(band: number | null, cached?: { text?: string; target?: number } | null): number {
  if (cached?.text?.trim()) return typeof cached.target === 'number' ? cached.target : 8;
  const b = band ?? 6;
  if (b >= 8) return 9;
  return Math.min(8, Math.floor(b) + 2);
}

export function rewriteLabel(target: number): string {
  return `Band ${formatBand(target).replace('.0', '')} version`;
}
