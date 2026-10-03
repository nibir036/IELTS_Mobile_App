// Client for the speaking evaluation service (NextED_IELTS_Speaking,
// FastAPI): VAD -> Groq Whisper -> RunPod pronunciation (GOP) ->
// Groq LLM scoring passes -> band report. Same contract the website uses:
//
//   POST /sessions/submit      multipart: user_id, segments_meta (JSON), audio_<id> files
//   GET  /sessions/{id}        status + per-segment transcript / fluency / pronunciation
//   GET  /sessions/{id}/report band scores + evidence (once status = completed)
//
// Every call sends X-Internal-Api-Key (= the service's INTERNAL_API_KEY).

import { env } from '../env';
import { HttpError } from './http';
import { halfBand } from './writing';

export interface SegmentInput {
  /** Stable slug: p1_intro, p1_topic1, p2_main, p3_topic1 … */
  id: string;
  partNumber: 1 | 2 | 3;
  label: string;
  questionText: string;
  audio: Buffer;
  format: string; // wav | m4a | webm | mp3 | ogg
}

export interface SessionPart {
  id: string;
  segment_id: string;
  part_number: number;
  label: string;
  question_text: string;
  transcript: string | null;
  fluency_features: Record<string, unknown> | null;
  pronunciation: Record<string, unknown> | null;
  status: string;
  error_reason: string | null;
}

export interface SessionStatus {
  id: string;
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'needs_rerecording';
  error_message: string | null;
  parts: SessionPart[];
}

export interface SessionReport {
  scores: { fluency: number; lexical: number; grammar: number; pronunciation: number; overall: number };
  evidence: Record<string, unknown> & {
    fluency?: string;
    lexical?: string;
    grammar?: string;
    pronunciation?: string;
    per_part_feedback?: string[];
    generalSummary?: string;
    keyImprovements?: string[];
    detailedAnalysis?: {
      textAnalysis?: Record<string, unknown>;
      pronunciation?: Record<string, unknown>;
    };
  };
}

function config() {
  if (!env.speakingApiKey) {
    throw new HttpError(503, 'Speaking evaluation is not configured on the server (SPEAKING_API_KEY).', 'speaking_not_configured');
  }
  return { base: env.speakingApiBaseUrl, headers: { 'X-Internal-Api-Key': env.speakingApiKey } };
}

const MIME: Record<string, string> = {
  wav: 'audio/wav',
  m4a: 'audio/mp4',
  mp3: 'audio/mpeg',
  webm: 'audio/webm',
  ogg: 'audio/ogg',
  aac: 'audio/aac',
  flac: 'audio/flac',
};

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  const { base, headers } = config();
  let res: Response;
  try {
    res = await fetch(`${base}${path}`, {
      ...init,
      headers: { ...headers, ...(init?.headers as Record<string, string> | undefined) },
      signal: AbortSignal.timeout(120_000),
    });
  } catch (e) {
    console.error('[speaking] service unreachable', e);
    throw new HttpError(502, 'The speaking evaluator is not reachable right now. Please try again.', 'speaking_unreachable');
  }
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    console.error(`[speaking] ${path} -> ${res.status}: ${detail.slice(0, 500)}`);
    throw new HttpError(502, 'The speaking evaluator rejected the request. Please try again.', 'speaking_failed', {
      status: res.status,
    });
  }
  return (await res.json()) as T;
}

export async function submitSession(userId: string, segments: SegmentInput[]): Promise<{ sessionId: string }> {
  const form = new FormData();
  form.set('user_id', userId);
  form.set(
    'segments_meta',
    JSON.stringify(
      segments.map((sg) => ({ id: sg.id, part_number: sg.partNumber, label: sg.label, question_text: sg.questionText })),
    ),
  );
  for (const sg of segments) {
    const type = MIME[sg.format] || 'application/octet-stream';
    form.set(`audio_${sg.id}`, new Blob([new Uint8Array(sg.audio)], { type }), `${sg.id}.${sg.format}`);
  }
  const data = await call<{ id: string }>('/sessions/submit', { method: 'POST', body: form });
  return { sessionId: data.id };
}

export interface WordPhoneme {
  phoneme: string;
  score: number | null;
}

/** Pronunciation trainer: GOP for one recording of a known word/phrase. */
export async function scoreWord(text: string, audio: Buffer, format: string) {
  const form = new FormData();
  form.set('reference_text', text);
  form.set('audio', new Blob([new Uint8Array(audio)], { type: MIME[format] || 'application/octet-stream' }), `word.${format}`);
  return call<{ reference_text: string; heard: string; phonemes: WordPhoneme[]; utterance_avg: number | null }>(
    '/pronunciation/word',
    { method: 'POST', body: form },
  );
}

/**
 * GOP log-posterior → 0–100. The service's own bands: ≥ −0.5 native-like,
 * −0.5…−1.5 good, −1.5…−3 unclear, < −3 wrong.
 */
export function phonemePercent(score: number): number {
  const s = Math.min(0, score);
  const pct =
    s >= -0.5 ? 85 + ((s + 0.5) / 0.5) * 15
    : s >= -1.5 ? 60 + ((s + 1.5) / 1.0) * 25
    : s >= -3 ? 30 + ((s + 3) / 1.5) * 30
    : Math.max(0, 30 + (s + 3) * 10);
  return Math.round(pct);
}

export const getSession = (sessionId: string) => call<SessionStatus>(`/sessions/${encodeURIComponent(sessionId)}`);
export const getReport = (sessionId: string) =>
  call<SessionReport>(`/sessions/${encodeURIComponent(sessionId)}/report`);

type Rec = Record<string, unknown>;
const arr = (v: unknown): Rec[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Rec[]) : []);
const str = (v: unknown) => (v == null ? '' : String(v));

/** Maps the service's report + session onto what the app's speaking screens show. */
export function mapEvaluation(report: SessionReport, session: SessionStatus) {
  const criteria = {
    FC: halfBand(Number(report.scores.fluency)),
    LR: halfBand(Number(report.scores.lexical)),
    GRA: halfBand(Number(report.scores.grammar)),
    P: halfBand(Number(report.scores.pronunciation)),
  };
  const band = halfBand((criteria.FC + criteria.LR + criteria.GRA + criteria.P) / 4);
  const ev = report.evidence ?? {};
  const text = (ev.detailedAnalysis?.textAnalysis ?? {}) as Rec;
  const pron = (ev.detailedAnalysis?.pronunciation ?? {}) as Rec;
  const perPart = Array.isArray(ev.per_part_feedback) ? ev.per_part_feedback.map(str) : [];

  const errors = [
    ...arr(text.grammar_errors).map((e) => ({
      original: str(e.quote),
      suggestion: str(e.correction),
      type: 'grammar',
      note: str(e.issue),
    })),
    ...arr(text.vocabulary_issues).map((e) => ({
      original: str(e.quote),
      suggestion: '',
      type: 'vocabulary',
      note: str(e.issue),
    })),
  ].filter((e) => e.original);

  return {
    source: 'ai' as const,
    band,
    criteria,
    criteriaFeedback: {
      FC: str(ev.fluency),
      LR: str(ev.lexical),
      GRA: str(ev.grammar),
      P: str(ev.pronunciation),
    },
    summary: str(ev.generalSummary) || perPart.join(' ') || 'Evaluation completed.',
    feedback: Array.isArray(ev.keyImprovements) ? ev.keyImprovements.map(str).filter(Boolean) : [],
    perPartFeedback: perPart,
    errors,
    strengths: [
      ...arr(text.grammar_strengths).map((e) => ({ quote: str(e.quote), note: str(e.note), type: 'grammar' })),
      ...arr(text.vocabulary_strengths).map((e) => ({ quote: str(e.quote), note: str(e.note), type: 'vocabulary' })),
    ],
    fluency: {
      observations: arr(text.fluency_observations).map((e) => ({
        label: str(e.label),
        quote: str(e.quote),
        pattern: str(e.pattern),
      })),
      note: str(text.quantitative_note),
    },
    pronunciation: {
      issues: arr(pron.genuine_issues).map((e) => ({
        phoneme: str(e.phoneme),
        count: Number(e.total_occurrences_flagged) || 0,
        note: str(e.note),
      })),
      excluded: Array.isArray(pron.excluded_as_likely_artifacts) ? pron.excluded_as_likely_artifacts.map(str) : [],
      note: str(pron.overall_note),
    },
    segments: session.parts.map((p) => ({
      id: p.segment_id,
      part: p.part_number,
      label: p.label,
      question: p.question_text,
      transcript: p.transcript ?? '',
      fluency: p.fluency_features ?? {},
      status: p.status,
    })),
  };
}
