'use client';

import { blobToBase64, type Clip } from './use-recorder';
import { buildParagraphs, errorsOf } from '@/lib/speaking/transcript';

export interface SpeakingJob {
  kind: 'part1' | 'part2' | 'part3';
  title: string;
  refId: string;
  part: 1 | 2 | 3;
  /** One per answer, in order (null = not answered). */
  clips: Array<Clip | null>;
  questions: string[];
  expectedSec: number;
  durationSec: number;
  cueCard?: string;
  cardTitle: string;
}

export type SpeakingOutcome =
  | { ok: true; attemptId: string }
  | { ok: false; upgrade?: string; message: string };

const newId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function json(path: string, init?: RequestInit) {
  const res = await fetch(`/api/v1/${path}`, init);
  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  return { ok: res.ok, status: res.status, data };
}

const strings = (v: unknown): string[] =>
  Array.isArray(v)
    ? v
        .map((e) => (typeof e === 'string' ? e : e && typeof e === 'object' ? String((e as Record<string, unknown>).text ?? (e as Record<string, unknown>).tip ?? (e as Record<string, unknown>).note ?? '') : ''))
        .map((x) => x.trim())
        .filter(Boolean)
    : [];

/**
 * Same flow as the app (speaking_ai.dart processSpeaking): upload the
 * answers, wait for the speaking service's report, then store the app's own
 * copy of the attempt (same id) so it shows in the app too.
 */
export async function scoreSpeaking(job: SpeakingJob, onStage: (stage: string, progress: number) => void): Promise<SpeakingOutcome> {
  const answered = job.clips.map((c, i) => (c ? i : -1)).filter((i) => i >= 0);
  if (!answered.length) return { ok: false, message: 'Nothing was recorded. Please record your answer again.' };
  onStage('Uploading…', 0.05);
  const id = newId();
  const questionFor = (i: number) => (job.part === 2 && job.cueCard ? job.cueCard : job.questions[i] || job.cardTitle || job.title);
  const segments = await Promise.all(
    answered.map(async (i) => ({
      id: `q${i + 1}`,
      partNumber: job.part,
      label: `Part ${job.part} · Q${i + 1}`,
      questionText: questionFor(i),
      audioBase64: await blobToBase64(job.clips[i]!.blob),
      format: job.clips[i]!.format,
    })),
  );
  const sent = await submitSpeakingSession(
    { mode: job.kind, title: job.title, refId: job.refId, durationSec: job.durationSec, attemptId: id, segments },
    onStage,
  );
  if (!sent.ok) return { ok: false, upgrade: sent.upgrade, message: sent.message };
  const { evaluation: ev, recordings } = sent;
  onStage('Scoring…', 1);

  const keys = new Map(recordings.map((r) => [r.id, r.key]));
  const bySeg = new Map<string, string>(
    (Array.isArray(ev.segments) ? (ev.segments as Array<Record<string, unknown>>) : []).map((s) => [String(s.id), String(s.transcript ?? '').trim()]),
  );
  const texts = answered.map((i) => bySeg.get(`q${i + 1}`) ?? '').filter(Boolean);
  const errors = errorsOf(ev.errors);
  const paragraphs = buildParagraphs(texts, errors);
  let fillers = 0;
  let pauses = 0;
  let words = 0;
  for (const p of paragraphs) {
    for (const t of p.tokens) {
      if (t.type === 'filler') fillers++;
      if (t.type === 'pause') {
        pauses++;
        continue;
      }
      words += (t.text.match(/[A-Za-z']+/g) ?? []).length;
    }
  }
  const spokenSec = job.clips.reduce((a, c) => a + (c?.seconds ?? 0), 0);
  const band = typeof ev.band === 'number' ? ev.band : null;
  const crit = (ev.criteria ?? {}) as Record<string, unknown>;
  const cb = (k: string) => (typeof crit[k] === 'number' ? (crit[k] as number) : band ?? 0);
  await json('attempts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id,
      skill: 'speaking',
      kind: job.kind,
      title: job.title,
      refId: job.refId,
      band,
      durationSec: Math.max(60, job.durationSec),
      createdAt: new Date().toISOString(),
      data: {
        source: 'ai',
        spokenSec,
        expectedSec: job.expectedSec,
        questions: job.questions.map((q, i) => ({ q, spokenSec: job.clips[i]?.seconds ?? 0 })),
        criteria: { FC: cb('FC'), LR: cb('LR'), GRA: cb('GRA'), P: cb('P') },
        summary: String(ev.summary ?? ''),
        feedback: strings(ev.feedback),
        errors,
        ...(ev.criteriaFeedback ? { criteriaFeedback: ev.criteriaFeedback } : {}),
        ...(strings(ev.perPartFeedback).length ? { perPartFeedback: strings(ev.perPartFeedback) } : {}),
        ...(Array.isArray(ev.strengths) ? { aiStrengths: ev.strengths } : {}),
        ...(ev.fluency ? { fluencyReport: ev.fluency } : {}),
        ...(ev.pronunciation ? { pronunciationReport: ev.pronunciation } : {}),
        transcript: { text: texts.join('\n\n'), demo: false, paragraphs },
        stats: { fillers, pauses, wpm: Math.round((words * 60) / Math.max(1, spokenSec)) },
        audio: job.clips.map((c, i) => ({ path: '', key: keys.get(`q${i + 1}`) ?? null, durationSec: c?.seconds ?? 0 })).filter((x) => x.durationSec > 0),
      },
    }),
  });
  return { ok: true, attemptId: id };
}

export type SessionResult =
  | { ok: true; evaluation: Record<string, unknown>; recordings: Array<{ id: string; key: string }> }
  | { ok: false; upgrade?: string; message: string };

/** Uploads answers to the speaking service and waits for the report (usually 30–90 s). */
export async function submitSpeakingSession(body: Record<string, unknown>, onStage: (stage: string, progress: number) => void): Promise<SessionResult> {
  const start = await json('speaking/sessions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (start.status === 402) return { ok: false, upgrade: String(start.data.feature ?? `speaking_${String(body.mode)}`), message: '' };
  if (!start.ok) return { ok: false, message: String(start.data.error ?? 'We couldn’t upload your answers. Please try again.') };
  const id = String(start.data.attemptId ?? body.attemptId ?? '');
  const recordings = Array.isArray(start.data.recordings) ? (start.data.recordings as Array<{ id: string; key: string }>) : [];
  const began = Date.now();
  let misses = 0;
  while (Date.now() - began < 6 * 60_000) {
    const waited = (Date.now() - began) / 1000;
    onStage(waited < 15 ? 'Transcribing…' : 'Scoring…', 0.25 + 0.7 * (1 - 1 / (1 + waited / 45)));
    await sleep(3000);
    const r = await json(`speaking/sessions/${id}`).catch(() => null);
    if (!r || (!r.ok && r.status >= 500)) {
      if (++misses >= 5) return { ok: false, message: 'Can’t reach the server. Your answers are saved; check your history in a few minutes.' };
      continue;
    }
    misses = 0;
    const status = String(r.data.status ?? '');
    if (status === 'processing') continue;
    if (status === 'completed' && r.data.evaluation && typeof r.data.evaluation === 'object') {
      return { ok: true, evaluation: r.data.evaluation as Record<string, unknown>, recordings };
    }
    return { ok: false, message: String(r.data.message ?? 'Speaking evaluation failed. Please try again.') };
  }
  return { ok: false, message: 'The evaluation is taking longer than usual. It will appear in your history when it is ready.' };
}
