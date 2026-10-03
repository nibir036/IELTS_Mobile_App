// Writing grading through Gemini (as on the website) or OpenRouter. The examiner prompt and rules are the
// website's (strict, calibrated, no inflation); the app additionally gets
// line-level issues for its Line Review screen and a strengths list.

import { env } from '../env';
import { HttpError } from './http';
import { geminiJson } from './gemini';
import { chatJson } from './openrouter';

/** One JSON grading call: Gemini (as on the website) or OpenRouter, per WRITING_PROVIDER. */
async function writingJson(opts: {
  label: string;
  system: string;
  user: string;
  schema: Record<string, unknown>;
  schemaName: string;
  maxTokens: number;
}): Promise<{ data: Record<string, unknown>; model: string }> {
  if (env.useGeminiForWriting) {
    return geminiJson({ label: opts.label, system: opts.system, user: opts.user, schema: opts.schema });
  }
  return chatJson({
    label: opts.label,
    model: env.openrouterWritingModel,
    schema: opts.schema,
    schemaName: opts.schemaName,
    maxTokens: opts.maxTokens,
    messages: [
      { role: 'system', content: opts.system },
      { role: 'user', content: opts.user },
    ],
  });
}

/** Languages the AI can explain in (answers and examples always stay English). */
export type FeedbackLang = 'en' | 'bn' | 'ne' | 'ar' | 'id';
export const FEEDBACK_LANGS: readonly FeedbackLang[] = ['en', 'bn', 'ne', 'ar', 'id'];

const LANG_NAME: Record<Exclude<FeedbackLang, 'en'>, string> = {
  bn: 'Bangla (বাংলা)',
  ne: 'Nepali (नेपाली)',
  ar: 'Modern Standard Arabic (العربية)',
  id: 'Indonesian (Bahasa Indonesia)',
};

/** System-prompt note for a non-English feedback language ('' for English). */
export function languageNote(lang: FeedbackLang | undefined): string {
  if (!lang || lang === 'en') return '';
  return (
    `Write every explanation, note, tip and feedback sentence in ${LANG_NAME[lang]}. Keep IELTS terms ` +
    '(band, Task Response, coherence, paraphrase …) in English where students would, and keep JSON keys, band ' +
    'numbers, quoted student text, corrected English sentences and model answers in English.'
  );
}

export const BANGLA_NOTE = languageNote('bn');

const SYSTEM_INSTRUCTION = `You are a certified senior IELTS Writing Examiner. You mark strictly and consistently against the official public IELTS Writing band descriptors. You are calibrated and NOT lenient — you do not inflate scores to be encouraging. A mediocre essay receives a mediocre band.

Mark on the four official criteria, each 0-9 in whole or half bands:
1. Task Achievement (Task 1) / Task Response (Task 2): For Task 1, does it accurately select, report and compare the KEY features shown in the visual, with a clear overview? For Task 2, does it fully address all parts of the task with a clear, developed, supported position?
2. Coherence & Cohesion: logical organisation, paragraphing, natural (non-mechanical) cohesion and referencing.
3. Lexical Resource: range, precision and natural control of vocabulary/collocation; spelling.
4. Grammatical Range & Accuracy: range of structures; frequency/impact of errors; punctuation.

CALIBRATION ANCHORS (apply honestly):
- Band 5: task addressed only partially; ideas underdeveloped; frequent errors causing some difficulty; limited/repetitive vocabulary.
- Band 6: task addressed but development uneven; generally organised; mix of accurate and faulty structures; adequate vocabulary with errors.
- Band 7: all parts addressed with a clear position/overview; well organised; good range with only occasional errors.
- Band 8: fully addressed; well developed; wide, natural, precise language with rare errors.
- Band 9: fully extended, near-flawless, fully natural control.

RULES:
- Penalise off-topic, memorised or template-heavy responses.
- Penalise responses under the word count (150 for Task 1, 250 for Task 2).
- For Task 1: judge factual ACCURACY against the chart data provided — penalise invented, missing or misreported data; reward a clear overview of the main trends/changes.
- If the response is empty, irrelevant, gibberish or not English prose, give bands at or below 3.0 and say so plainly.
- overallBand MUST equal the average of the four criterion scores, rounded to nearest 0.5.
- All five band numbers MUST be in 0.5 increments.
- Feedback must be specific to THIS response — reference actual words/sentences. No generic praise.
- "issues": up to 12 of the most important problems, each quoting an EXACT substring copied from the response (so it can be highlighted), with a corrected version, a type and a short reason.`;

const ISSUE_SCHEMA = {
  type: 'object',
  properties: {
    original: { type: 'string' },
    suggestion: { type: 'string' },
    type: { type: 'string', enum: ['grammar', 'vocabulary', 'cohesion', 'task', 'punctuation', 'spelling', 'style'] },
    note: { type: 'string' },
  },
  required: ['original', 'suggestion', 'type', 'note'],
  additionalProperties: false,
};

const RESPONSE_SCHEMA = {
  type: 'object',
  properties: {
    overallBand: { type: 'number' },
    taskResponseScore: { type: 'number' },
    coherenceScore: { type: 'number' },
    lexicalScore: { type: 'number' },
    grammarScore: { type: 'number' },
    taskResponseFeedback: { type: 'string' },
    coherenceFeedback: { type: 'string' },
    lexicalFeedback: { type: 'string' },
    grammarFeedback: { type: 'string' },
    generalSummary: { type: 'string' },
    strengths: { type: 'array', items: { type: 'string' } },
    keyImprovements: { type: 'array', items: { type: 'string' } },
    enhancedVersionSnippet: { type: 'string' },
    issues: { type: 'array', items: ISSUE_SCHEMA },
  },
  required: [
    'overallBand', 'taskResponseScore', 'coherenceScore', 'lexicalScore', 'grammarScore',
    'taskResponseFeedback', 'coherenceFeedback', 'lexicalFeedback', 'grammarFeedback',
    'generalSummary', 'strengths', 'keyImprovements', 'enhancedVersionSnippet', 'issues',
  ],
  additionalProperties: false,
};

const JSON_SHAPE = `Reply with ONLY a JSON object with exactly these keys:
{"overallBand": number, "taskResponseScore": number, "coherenceScore": number, "lexicalScore": number,
 "grammarScore": number, "taskResponseFeedback": string, "coherenceFeedback": string,
 "lexicalFeedback": string, "grammarFeedback": string, "generalSummary": string,
 "strengths": [string], "keyImprovements": [string], "enhancedVersionSnippet": string,
 "issues": [{"original": "exact substring of the response", "suggestion": string,
             "type": "grammar|vocabulary|cohesion|task|punctuation|spelling|style", "note": string}]}
No markdown, no text outside the JSON.`;

/** Nearest 0.5, clamped 0–9. */
export function halfBand(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.floor(Math.max(0, Math.min(9, n)) * 2 + 0.5) / 2;
}

export function wordCount(text: string): number {
  return (text.match(/[A-Za-z0-9'’-]+/g) || []).length;
}

export interface TaskInput {
  task: 1 | 2;
  prompt: string;
  text: string;
  /** Task 1 chart data from the prompt (JSON), used instead of an image. */
  chart?: unknown;
  language?: FeedbackLang;
}

export interface WritingIssue {
  original: string;
  suggestion: string;
  type: string;
  note: string;
}

export interface TaskEvaluation {
  source: 'ai';
  model: string;
  task: 1 | 2;
  band: number;
  criteria: { TA: number; CC: number; LR: number; GRA: number };
  criteriaFeedback: { TA: string; CC: string; LR: string; GRA: string };
  words: number;
  summary: string;
  strengths: string[];
  feedback: string[];
  enhancedSnippet: string;
  issues: WritingIssue[];
}

const strList = (v: unknown, max: number) =>
  Array.isArray(v) ? v.map((x) => String(x ?? '').trim()).filter(Boolean).slice(0, max) : [];

export async function evaluateTask(input: TaskInput): Promise<TaskEvaluation> {
  const words = wordCount(input.text);
  const label = input.task === 1 ? 'Task 1' : 'Task 2';
  const chart =
    input.task === 1 && input.chart
      ? `\nCHART DATA (the visual this Task 1 describes — judge accuracy against it):\n${JSON.stringify(input.chart).slice(0, 6000)}\n`
      : '';
  const user = `IELTS Academic Writing ${label} — mark this candidate response.

TASK PROMPT:
"""
${input.prompt || 'IELTS Writing Task'}
"""
${chart}
CANDIDATE RESPONSE (${words} words):
"""
${input.text}
"""

Mark it now against the official band descriptors. Be strict and specific.`;

  const system = `${SYSTEM_INSTRUCTION}\n\n${JSON_SHAPE}${input.language && input.language !== 'en' ? `\n\n${languageNote(input.language)}` : ''}`;
  const { data: raw, model } = await writingJson({
    label: `writing-task${input.task}`,
    system,
    user,
    schema: RESPONSE_SCHEMA,
    schemaName: 'ielts_writing_evaluation',
    maxTokens: 4000,
  });

  const num = (k: string) => {
    const v = Number(raw[k]);
    if (raw[k] === undefined || raw[k] === null || !Number.isFinite(v)) {
      throw new HttpError(502, 'The AI grader returned an incomplete evaluation. Please try again.', 'ai_failed');
    }
    return halfBand(v);
  };
  const criteria = {
    TA: num('taskResponseScore'),
    CC: num('coherenceScore'),
    LR: num('lexicalScore'),
    GRA: num('grammarScore'),
  };
  const band = halfBand((criteria.TA + criteria.CC + criteria.LR + criteria.GRA) / 4);

  // Keep only issues that quote the essay exactly, so the app can highlight them.
  const issues: WritingIssue[] = [];
  if (Array.isArray(raw.issues)) {
    for (const it of raw.issues as Array<Record<string, unknown>>) {
      const original = String(it?.original ?? '').trim();
      if (!original || !input.text.includes(original)) continue;
      issues.push({
        original,
        suggestion: String(it.suggestion ?? '').trim(),
        type: String(it.type ?? 'grammar').trim() || 'grammar',
        note: String(it.note ?? '').trim(),
      });
      if (issues.length >= 12) break;
    }
  }

  return {
    source: 'ai',
    model,
    task: input.task,
    band,
    criteria,
    criteriaFeedback: {
      TA: String(raw.taskResponseFeedback ?? ''),
      CC: String(raw.coherenceFeedback ?? ''),
      LR: String(raw.lexicalFeedback ?? ''),
      GRA: String(raw.grammarFeedback ?? ''),
    },
    words,
    summary: String(raw.generalSummary ?? ''),
    strengths: strList(raw.strengths, 6),
    feedback: strList(raw.keyImprovements, 6),
    enhancedSnippet: String(raw.enhancedVersionSnippet ?? ''),
    issues,
  };
}

/** Real IELTS weighting: Task 2 counts double. */
export function writingTestBand(task1: number, task2: number): number {
  return halfBand((task1 + task2 * 2) / 3);
}

const REWRITE_SCHEMA = {
  type: 'object',
  properties: {
    text: { type: 'string' },
    changes: {
      type: 'array',
      items: {
        type: 'object',
        properties: { from: { type: 'string' }, to: { type: 'string' }, why: { type: 'string' } },
        required: ['from', 'to', 'why'],
        additionalProperties: false,
      },
    },
  },
  required: ['text', 'changes'],
  additionalProperties: false,
};

export async function rewriteEssay(input: TaskInput & { targetBand: number }) {
  const system =
    'You are a certified IELTS Academic examiner and writing coach. Reply with a single JSON object only: ' +
    '{"text": "full rewritten answer with \\n\\n between paragraphs", "changes": [{"from": "original phrase", ' +
    '"to": "new phrase", "why": "short reason"}]}' +
    (input.language && input.language !== 'en' ? `\n\n${languageNote(input.language)}` : '');
  const user =
    `Rewrite this IELTS Writing Task ${input.task} answer to Band ${input.targetBand} standard. Keep the student's ` +
    'ideas and position, fix errors, improve cohesion and vocabulary, keep a similar length. List up to 10 changes.\n\n' +
    `QUESTION:\n${input.prompt || '(not provided)'}\n\nANSWER:\n${input.text}`;
  const { data, model } = await writingJson({
    label: 'writing-rewrite',
    system,
    user,
    schema: REWRITE_SCHEMA,
    schemaName: 'ielts_writing_rewrite',
    maxTokens: 3500,
  });
  const text = String(data.text ?? '').trim();
  if (!text) throw new HttpError(502, 'The AI returned an empty rewrite. Please try again.', 'ai_failed');
  return {
    source: 'ai' as const,
    model,
    text,
    changes: Array.isArray(data.changes)
      ? (data.changes as Array<Record<string, unknown>>).slice(0, 10).map((c) => ({
          from: String(c?.from ?? ''),
          to: String(c?.to ?? ''),
          why: String(c?.why ?? ''),
        }))
      : [],
  };
}
