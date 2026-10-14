// Mock answer review (lib/features/mock/mock_content.dart + mock_answers_parts.dart):
// a mock's Listening / Reading questions flattened and renumbered 1–40, each
// marked against the bank key, ready for the review page. Pure: no fetching.

import { listeningBand, matches, norm, passageQuestionCount, readingBand, rows, setQuestionCount, str, strs, type Raw } from '../practice/marking';
import { boldSegments, highlightSegments } from './format';

export type Mark = 'correct' | 'partial' | 'wrong' | 'blank' | 'unknown';

interface Opt {
  key: string;
  text: string;
}

export interface MockQuestion {
  number: number;
  span: number;
  kind: 'choice' | 'multi' | 'text';
  text: string;
  label: string;
  before: string;
  after: string;
  options: Opt[];
  answers: string[];
  accepted: string[];
  raw: Raw;
}

export interface MockGroup {
  type: string;
  title: string;
  instruction: string;
  heading: string;
  unitIndex: number;
  formTitle: string;
  shared: Opt[];
  questions: MockQuestion[];
}

/** Typed-answer group types (no lettered options). */
const TEXT_TYPES = new Set(['form', 'gap', 'notes', 'table', 'flowchart', 'diagram', 'short_answer', 'summary', 'sentence']);

function options(v: unknown): Opt[] {
  if (!Array.isArray(v)) return [];
  return v
    .filter((e) => e != null)
    .map((e) => (typeof e === 'object' ? { key: str((e as Raw).key), text: str((e as Raw).text) } : { key: str(e), text: '' }));
}

const answerList = (v: unknown): string[] => (Array.isArray(v) ? v.map(str) : v == null ? [] : [str(v)]);

/** Groups of one set / passage with numbers shifted by [offset] (mockGroupsOf). */
function groupsOf(unit: Raw, offset: number, unitIndex: number, heading: string): MockGroup[] {
  return rows(unit.groups).map((g) => {
    const type = str(g.type);
    const pick = Number(g.pick) > 1 ? Number(g.pick) : 1;
    const shared = type === 'heading' ? options(g.headings) : options(type === 'sentence_endings' ? g.endings : g.options);
    const questions: MockQuestion[] = rows(g.questions).map((q) => {
      const number = (Number(q.number) || 0) + offset;
      const answers = answerList(q.answer);
      const qOpts = options(q.options);
      const nums = Array.isArray(q.numbers) ? q.numbers.length : 0;
      const base = { number, text: str(q.text), label: str(q.label), before: str(q.before), after: str(q.after), raw: q, accepted: [] as string[] };
      if (type === 'multi' || pick > 1 || nums > 1) {
        return { ...base, span: Math.max(pick, nums, 1), kind: 'multi', options: qOpts, answers };
      }
      if (TEXT_TYPES.has(type) && !qOpts.length && !shared.length) {
        const acc = strs(q.accepted);
        return { ...base, span: 1, kind: 'text', options: [], answers, accepted: acc.length ? acc : answers };
      }
      return { ...base, span: 1, kind: 'choice', options: qOpts, answers };
    });
    return {
      type,
      title: str(g.title),
      instruction: str(g.instruction),
      heading,
      unitIndex,
      formTitle: str(g.formTitle),
      shared,
      questions,
    };
  });
}

/** Listening sets / reading passages with their question offsets. */
export function withOffsets(units: Raw[], listening: boolean): Array<[Raw, number]> {
  const out: Array<[Raw, number]> = [];
  let off = 0;
  for (const u of units) {
    out.push([u, off]);
    off += listening ? setQuestionCount(u) : passageQuestionCount(u);
  }
  return out;
}

export function listeningGroups(units: Array<[Raw, number]>): MockGroup[] {
  return units.flatMap(([set, off], i) => groupsOf(set, off, i, `Part ${Number(set.part) > 0 ? Number(set.part) : i + 1}`));
}

export function readingGroups(units: Array<[Raw, number]>): MockGroup[] {
  return units.flatMap(([p, off], i) => groupsOf(p, off, i, `Passage ${i + 1}`));
}

const range = (g: MockGroup) => {
  const first = g.questions[0]?.number ?? 0;
  const last = g.questions.length ? g.questions[g.questions.length - 1].number + g.questions[g.questions.length - 1].span - 1 : 0;
  return first === last ? `Question ${first}` : `Questions ${first}–${last}`;
};

const multiKeys = (v: string) =>
  v
    .split(',')
    .map((e) => e.trim())
    .filter(Boolean);

/**
 * The student's answer to [q]. A "choose TWO" answer is stored by the app as
 * "A,C" under its first number and by the website one letter per number.
 */
export function givenOf(q: MockQuestion, answers: Record<string, string> | null): string {
  if (!answers) return '';
  const first = str(answers[q.number]).trim();
  if (q.kind !== 'multi' || first.includes(',')) return first;
  const parts: string[] = [];
  for (let i = 0; i < q.span; i++) {
    const v = str(answers[q.number + i]).trim();
    if (v) parts.push(v);
  }
  return parts.join(',');
}

/** Marks for one question (0..span) (mockMarks). */
export function marksOf(q: MockQuestion, given: string): number {
  const v = given.trim();
  if (!v) return 0;
  if (q.kind === 'text') return matches(v, q.accepted) ? 1 : 0;
  if (q.kind === 'multi') {
    const key = new Set(q.answers.map((e) => e.toUpperCase()));
    const sel = new Set(multiKeys(v).map((e) => e.toUpperCase()));
    return Math.min(q.span, [...sel].filter((x) => key.has(x)).length);
  }
  return q.answers.some((a) => a.trim().toLowerCase() === v.toLowerCase()) ? 1 : 0;
}

function optionLabel(q: MockQuestion, g: MockGroup, key: string): string {
  const k = key.trim();
  const o = [...q.options, ...g.shared].find((x) => x.key.toLowerCase() === k.toLowerCase());
  return o ? (o.text ? `${o.key} · ${o.text}` : o.key) : k;
}

/** The question as read in the paper (form lines get their blank back). */
function questionText(q: MockQuestion): string {
  if (q.kind === 'text' && (q.label || !q.text)) {
    return [q.label ? `${q.label}:` : '', q.before, '______', q.after].filter(Boolean).join(' ');
  }
  return q.text;
}

function givenLabel(q: MockQuestion, g: MockGroup, value: string): string {
  const v = value.trim();
  if (!v) return '';
  if (q.kind === 'text') return v;
  if (q.kind === 'multi') return multiKeys(v).map((k) => optionLabel(q, g, k)).join('; ');
  return optionLabel(q, g, v);
}

function correctLabel(q: MockQuestion, g: MockGroup): string {
  if (!q.answers.length) return '–';
  if (q.kind === 'text') return str(q.raw.answerDisplay) || q.answers[0];
  if (q.kind === 'multi') return q.answers.map((k) => optionLabel(q, g, k)).join('; ');
  return optionLabel(q, g, q.answers[0]);
}

function alsoAccepted(q: MockQuestion): string {
  if (q.kind !== 'text' || !q.answers.length) return '';
  const seen = new Set([norm(q.answers[0])]);
  const out: string[] = [];
  for (const a of q.accepted) {
    const n = norm(a);
    if (!n || seen.has(n)) continue;
    seen.add(n);
    out.push(a);
  }
  return out.join(', ');
}

// ── View model (serializable, for the client page) ─────────────────────────

export type Seg = { text: string; hi?: boolean; bold?: boolean };

export interface ReviewDetails {
  label: string;
  explanation: Seg[];
  boxes: Array<{ title: string; lines: Array<{ head?: string; segs: Seg[] }> }>;
}

export interface ReviewRow {
  key: string;
  number: string;
  question: string;
  mark: Mark;
  given: string;
  correct: string;
  also: string;
  marks: string;
  details: ReviewDetails | null;
}

export interface ReviewGroup {
  heading: string;
  unitTitle: string;
  meta: string;
  title: string;
  rows: ReviewRow[];
}

export interface ObjectiveView {
  name: 'Listening' | 'Reading';
  recorded: boolean;
  total: number;
  correct: number | null;
  wrong: number;
  blank: number;
  band: number | null;
  groups: ReviewGroup[];
}

const clockOf = (sec: number) => `${Math.floor(Math.max(0, sec) / 60)}:${String(Math.round(Math.max(0, sec)) % 60).padStart(2, '0')}`;

function transcriptDetails(q: MockQuestion, unit: [Raw, number] | undefined): ReviewDetails | null {
  if (!unit) return null;
  const [set, offset] = unit;
  const numbers = Array.from({ length: q.span }, (_, i) => q.number + i);
  const lines: Array<{ head?: string; segs: Seg[] }> = [];
  for (const line of rows(set.transcript)) {
    const phrases = rows(line.answerTags)
      .filter((t) => numbers.includes((Number(t.question) || 0) + offset))
      .map((t) => str(t.after));
    if (phrases.length) {
      lines.push({ head: `${clockOf(Math.round(Number(line.start) || 0))}  ${str(line.speaker)}: `, segs: highlightSegments(str(line.text), phrases) });
    }
  }
  return lines.length ? { label: 'transcript', explanation: [], boxes: [{ title: 'Where you hear it', lines }] } : null;
}

function readingDetails(q: MockQuestion, unit: [Raw, number] | undefined): ReviewDetails | null {
  const explanation = str(q.raw.explanation).trim();
  const letter = str(q.raw.evidenceParagraph).trim();
  const evidence = str(q.raw.evidence).trim();
  const paragraph = letter && unit ? str(rows(unit[0].paragraphs).find((p) => str(p.letter) === letter)?.text) : '';
  const boxes: ReviewDetails['boxes'] = [];
  if (paragraph) boxes.push({ title: `Evidence · Paragraph ${letter}`, lines: [{ segs: highlightSegments(paragraph, evidence ? [evidence] : []) }] });
  else if (evidence) boxes.push({ title: letter ? `Evidence · Paragraph ${letter}` : 'Evidence', lines: [{ segs: [{ text: `“${evidence}”` }] }] });
  if (!explanation && !boxes.length) return null;
  return { label: 'explanation', explanation: explanation ? boldSegments(explanation) : [], boxes };
}

/**
 * Listening or Reading of one mock for the review: groups with marked rows
 * and the score card numbers. [answers] null = not recorded on the attempt.
 */
export function objectiveView(
  listening: boolean,
  units: Array<[Raw, number]>,
  answers: Record<string, string> | null,
  data: Raw,
): ObjectiveView {
  const groups = listening ? listeningGroups(units) : readingGroups(units);
  const recorded = answers !== null;
  let total = 0;
  let correct = 0;
  let wrong = 0;
  let blank = 0;
  const out: ReviewGroup[] = [];
  for (const g of groups) {
    const reviewRows: ReviewRow[] = [];
    for (const q of g.questions) {
      const given = givenOf(q, answers);
      const m = recorded ? marksOf(q, given) : 0;
      const mark: Mark = !recorded ? 'unknown' : !given ? 'blank' : m >= q.span ? 'correct' : m > 0 ? 'partial' : 'wrong';
      total += q.span;
      correct += m;
      if (mark === 'wrong' || mark === 'partial') wrong += q.span - m;
      if (mark === 'blank') blank += q.span;
      const unit = units[g.unitIndex];
      reviewRows.push({
        key: `${listening ? 0 : 1}-${q.number}`,
        number: q.span > 1 ? `${q.number}–${q.number + q.span - 1}` : String(q.number),
        question: questionText(q),
        mark,
        given: givenLabel(q, g, given),
        correct: correctLabel(q, g),
        also: alsoAccepted(q),
        marks: `${m}/${q.span}`,
        details: listening ? transcriptDetails(q, unit) : readingDetails(q, unit),
      });
    }
    out.push({
      heading: g.heading,
      unitTitle: str(units[g.unitIndex]?.[0].title),
      meta: g.instruction ? `${range(g)} · ${g.instruction}` : range(g),
      title: g.type === 'form' && g.formTitle ? g.formTitle : g.title,
      rows: reviewRows,
    });
  }
  let shownCorrect: number | null = recorded ? correct : null;
  if (!recorded) {
    const stored = (data[listening ? 'listeningScore' : 'readingScore'] ?? {}) as Raw;
    if (typeof stored.correct === 'number') shownCorrect = stored.correct;
  }
  const sections = (data.sections ?? {}) as Raw;
  let b: number | null = typeof sections[listening ? 'listening' : 'reading'] === 'number' ? (sections[listening ? 'listening' : 'reading'] as number) : null;
  if (b === null && shownCorrect !== null && total > 0) b = listening ? listeningBand(shownCorrect, total) : readingBand(shownCorrect, total);
  return { name: listening ? 'Listening' : 'Reading', recorded, total, correct: shownCorrect, wrong, blank, band: b, groups: out };
}

/** Question number → answer of an attempt section, or null when not recorded. */
export function answersOf(data: Raw, key: 'listening' | 'reading'): Record<string, string> | null {
  const all = data.answers;
  if (!all || typeof all !== 'object') return null;
  const v = (all as Raw)[key];
  if (!v || typeof v !== 'object' || Array.isArray(v)) return null;
  const out: Record<string, string> = {};
  for (const [k, val] of Object.entries(v as Raw)) if (val != null && /^\d+$/.test(k)) out[k] = str(val);
  return out;
}
