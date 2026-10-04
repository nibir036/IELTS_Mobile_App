// AI features: writing grading + rewrite (Gemini, as on the website; OpenRouter
// fallback), speaking evaluation (speaking service: Groq Whisper + RunPod +
// Groq LLM), speaking-partner chat (OpenRouter).

import { randomBytes } from 'node:crypto';
import { prisma } from '../db';
import { env } from '../env';
import { badRequest, HttpError, int, notFound, obj, rateLimit, Router, s } from '../lib/http';
import { chatJson } from '../lib/openrouter';
import { appKey, contentTypeFor, putObject } from '../lib/r2';
import { getReport, getSession, mapEvaluation, phonemePercent, scoreWord, submitSession, type SegmentInput } from '../lib/speaking';
import { checkQuota, requireUser } from '../lib/users';
import { evaluateTask, FEEDBACK_LANGS, languageNote, type FeedbackLang, rewriteEssay, wordCount, writingTestBand, type TaskInput } from '../lib/writing';
import { attemptJson } from './progress';

type Row = Record<string, unknown>;

const newId = (prefix: string) => `${prefix}_${Date.now().toString(36)}${randomBytes(4).toString('hex')}`;

/**
 * The app may send its own id for the attempt so its local copy and the
 * server's share one record (sync then merges instead of duplicating).
 */
async function attemptIdFor(userId: string, raw: unknown, prefix: string): Promise<string> {
  const id = s(raw, 80);
  if (!id) return newId(prefix);
  if (!/^[A-Za-z0-9_\-]+$/.test(id)) throw badRequest('Invalid attempt id.');
  const existing = await prisma.attempt.findUnique({ where: { id }, select: { userId: true, data: true } });
  if (!existing) return id;
  if (existing.userId !== userId) throw new HttpError(409, 'This attempt id is already used.', 'id_taken');
  if ((existing.data as Row | null)?.aiGraded === true) throw new HttpError(409, 'This attempt was already evaluated.', 'already_evaluated');
  // An ungraded local copy synced first: it is replaced by the graded one.
  await prisma.attempt.delete({ where: { id } });
  return id;
}

/** Writing attempt kind: practice task, mock or diagnostic test. */
function writingKind(context: unknown, task: 1 | 2 | null): string {
  const c = s(context, 20);
  const prefix = c === 'mock' ? 'mock_' : c === 'diagnostic' ? 'diag_' : '';
  return task === null ? (prefix ? `${prefix}test` : 'test') : `${prefix}task${task}`;
}

const isLang = (v: unknown): v is FeedbackLang => FEEDBACK_LANGS.includes(v as FeedbackLang);

async function feedbackLanguage(userId: string, body: Row): Promise<FeedbackLang> {
  if (isLang(body.feedbackLanguage)) return body.feedbackLanguage;
  const pref = await prisma.userState.findUnique({
    where: { userId_key: { userId, key: 'feedbackLanguage' } },
    select: { value: true },
  });
  const v = pref?.value;
  return isLang(v) ? v : 'en';
}

/** Builds one task's input, preferring the server's copy of the prompt (+ chart). */
async function taskInput(raw: Row, fallbackTask: 1 | 2, language: FeedbackLang): Promise<TaskInput & { promptId: string }> {
  const text = s(raw.text ?? raw.essayText, 20000);
  if (wordCount(text) < 20) throw badRequest(`Your Task ${fallbackTask} answer is too short to evaluate.`, 'too_short');
  const promptId = s(raw.promptId, 80);
  let prompt = s(raw.prompt, 4000);
  let chart: unknown;
  let task: 1 | 2 = Number(raw.task) === 1 ? 1 : Number(raw.task) === 2 ? 2 : fallbackTask;
  if (promptId) {
    const p = await prisma.writingPrompt.findUnique({ where: { id: promptId } });
    if (p) {
      prompt = p.prompt;
      chart = p.chart ?? undefined;
      task = p.task === 1 ? 1 : 2;
    }
  }
  return { task, prompt, text, chart, language, promptId };
}

export function registerAiRoutes(r: Router): void {
  /**
   * Writing evaluation.
   *   One task:  {task: 1|2, promptId?, prompt?, text, durationSec?, title?}
   *   Full test: {testId?, task1: {promptId?, prompt?, text}, task2: {…}, durationSec?}
   *   Both also take attemptId? (the app's own id) and context? (practice|mock|diagnostic).
   * Records an AI-graded attempt (counts toward the free-plan limit).
   */
  r.post('/v1/writing/evaluate', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`writing:${userId}`, 20, 3600);
    await checkQuota(userId, 'writing');
    const language = await feedbackLanguage(userId, ctx.body);
    const durationSec = int(ctx.body.durationSec, 0, 0, 86400);
    const attemptId = await attemptIdFor(userId, ctx.body.attemptId, 'att_w');

    if (ctx.body.task1 || ctx.body.task2) {
      const [i1, i2] = await Promise.all([
        taskInput(obj(ctx.body.task1), 1, language),
        taskInput(obj(ctx.body.task2), 2, language),
      ]);
      const [t1, t2] = await Promise.all([evaluateTask({ ...i1, task: 1 }), evaluateTask({ ...i2, task: 2 })]);
      const band = writingTestBand(t1.band, t2.band);
      const attempt = await prisma.attempt.create({
        data: {
          id: attemptId,
          userId,
          skill: 'writing',
          kind: writingKind(ctx.body.context, null),
          title: s(ctx.body.title, 200) || 'Writing test',
          refId: s(ctx.body.testId, 80) || null,
          band,
          durationSec,
          data: {
            aiGraded: true,
            task1: { promptId: i1.promptId, prompt: i1.prompt, text: i1.text, evaluation: t1 },
            task2: { promptId: i2.promptId, prompt: i2.prompt, text: i2.text, evaluation: t2 },
            weighting: 'Task 1 x1 + Task 2 x2 / 3',
          } as object,
        },
      });
      return { source: 'ai', band, task1: t1, task2: t2, attempt: attemptJson(attempt) };
    }

    const input = await taskInput(ctx.body, Number(ctx.body.task) === 1 ? 1 : 2, language);
    const evaluation = await evaluateTask(input);
    const attempt = await prisma.attempt.create({
      data: {
        id: attemptId,
        userId,
        skill: 'writing',
        kind: writingKind(ctx.body.context, input.task),
        title: s(ctx.body.title, 200) || `Writing Task ${input.task}`,
        refId: input.promptId || null,
        band: evaluation.band,
        durationSec,
        data: { aiGraded: true, promptId: input.promptId, prompt: input.prompt, text: input.text, evaluation } as object,
      },
    });
    return { ...evaluation, attempt: attemptJson(attempt) };
  });

  // Band-8 (or targetBand) rewrite of an essay. Not counted as a test.
  r.post('/v1/writing/rewrite', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`rewrite:${userId}`, 20, 3600);
    const language = await feedbackLanguage(userId, ctx.body);
    const input = await taskInput(ctx.body, Number(ctx.body.task) === 1 ? 1 : 2, language);
    const targetBand = Math.min(9, Math.max(6, Number(ctx.body.targetBand) || 8));
    return rewriteEssay({ ...input, targetBand });
  });

  /**
   * Speaking evaluation (the speaking service scores audio: transcript,
   * fluency timing, pronunciation, bands).
   * Body: {mode: part1|part2|part3|full|mock, attemptId?, title?, refId?, durationSec?,
   *        segments: [{id, partNumber, label, questionText, audioBase64, format}]}
   * Returns immediately with status "processing"; poll GET /v1/speaking/sessions/:attemptId.
   */
  r.post('/v1/speaking/sessions', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`speaking:${userId}`, 12, 3600);
    await checkQuota(userId, 'speaking');
    const raw = Array.isArray(ctx.body.segments) ? (ctx.body.segments as Row[]) : [];
    if (!raw.length || raw.length > 12) throw badRequest('Send 1–12 recorded segments.');
    const segments: SegmentInput[] = raw.map((sg, i) => {
      const id = s(sg.id, 40) || `seg${i + 1}`;
      if (!/^[a-z0-9_]+$/i.test(id)) throw badRequest(`Invalid segment id "${id}".`);
      const partNumber = Number(sg.partNumber);
      if (partNumber !== 1 && partNumber !== 2 && partNumber !== 3) throw badRequest('partNumber must be 1, 2 or 3.');
      const questionText = s(sg.questionText, 2000);
      if (!questionText) throw badRequest(`Segment "${id}" needs questionText.`);
      const b64 = s(sg.audioBase64, 60_000_000).replace(/^data:[^,]*,/, '');
      const audio = Buffer.from(b64, 'base64');
      if (audio.length < 1000) throw badRequest(`Segment "${id}" has no audio.`, 'no_audio');
      const format = (s(sg.format, 8) || 'wav').toLowerCase();
      return { id, partNumber, label: s(sg.label, 120) || id, questionText, audio, format };
    });
    const ids = new Set(segments.map((x) => x.id));
    if (ids.size !== segments.length) throw badRequest('Segment ids must be unique.');

    const attemptId = await attemptIdFor(userId, ctx.body.attemptId, 'att_s');
    const { sessionId } = await submitSession(userId, segments);

    // Keep the recordings for "My recordings" (best effort; the speaking
    // service keeps its own copy for scoring).
    const recordings: Array<{ id: string; key: string }> = [];
    if (env.r2Configured) {
      for (const sg of segments) {
        const key = appKey(`speaking/${userId}/${attemptId}/${sg.id}.${sg.format}`);
        try {
          await putObject(key, sg.audio, contentTypeFor(sg.format));
          recordings.push({ id: sg.id, key });
        } catch (e) {
          console.error('[speaking] R2 upload failed', e);
        }
      }
    }

    const attempt = await prisma.attempt.create({
      data: {
        id: attemptId,
        userId,
        skill: 'speaking',
        kind: s(ctx.body.mode, 20) || 'full',
        title: s(ctx.body.title, 200) || 'Speaking practice',
        refId: s(ctx.body.refId, 80) || null,
        band: null,
        durationSec: int(ctx.body.durationSec, 0, 0, 7200),
        data: {
          aiGraded: true,
          status: 'processing',
          sessionId,
          segments: segments.map((x) => ({ id: x.id, part: x.partNumber, label: x.label, question: x.questionText })),
          recordings,
        } as object,
      },
    });
    if (recordings.length) {
      await prisma.recording.createMany({
        data: recordings.map((rec) => ({
          userId,
          attemptId,
          r2Key: rec.key,
          format: rec.key.split('.').pop() || 'wav',
          durationMs: 0,
          bytes: segments.find((x) => x.id === rec.id)?.audio.length ?? null,
        })),
      });
    }
    return { attemptId: attempt.id, sessionId, status: 'processing', recordings };
  });

  r.get('/v1/speaking/sessions/:attemptId', async (ctx) => {
    const userId = requireUser(ctx);
    const attempt = await prisma.attempt.findUnique({ where: { id: ctx.params.attemptId } });
    if (!attempt || attempt.userId !== userId || attempt.skill !== 'speaking') throw notFound('Speaking session not found.');
    const data = (attempt.data ?? {}) as Row;
    const status = s(data.status);
    if (status !== 'processing') {
      return { attemptId: attempt.id, status, evaluation: data.evaluation ?? null, message: data.message ?? null, attempt: attemptJson(attempt) };
    }

    const sessionId = s(data.sessionId);
    const session = await getSession(sessionId);
    if (session.status === 'pending' || session.status === 'processing') {
      return { attemptId: attempt.id, status: 'processing' };
    }

    // The service marks a session "completed" with placeholder 6.5 bands when
    // its final scoring pass fails - treat that as a failure, not a result.
    const report = session.status === 'completed' ? await getReport(sessionId) : null;
    const placeholder = /^Automated scoring failed/i.test(String(report?.evidence?.generalSummary ?? ''));
    if (report && !placeholder) {
      const evaluation = mapEvaluation(report, session);
      // Single-part practice: the service is told Parts 2–3 (etc.) are
      // missing and says so in the summary - drop that sentence.
      if (attempt.kind !== 'full' && attempt.kind !== 'mock') {
        const kept = evaluation.summary
          .split(/(?<=[.!?])\s+/)
          .filter((x) => !/\b(not (been )?(recorded|submitted)|were not provided)\b/i.test(x));
        if (kept.length) evaluation.summary = kept.join(' ');
      }
      const updated = await prisma.attempt.update({
        where: { id: attempt.id },
        data: { band: evaluation.band, data: { ...data, status: 'completed', evaluation } as object },
      });
      await prisma.notification.create({
        data: {
          userId,
          type: 'ai',
          skill: 'speaking',
          title: 'Speaking evaluation ready',
          body: `${attempt.title ?? 'Speaking'} · Band ${evaluation.band.toFixed(1)}`,
          target: '/speaking/evaluation',
          args: { attemptId: attempt.id },
        },
      });
      return { attemptId: attempt.id, status: 'completed', evaluation, attempt: attemptJson(updated) };
    }

    // needs_rerecording or failed: doesn't count toward the free limit.
    const noSpeech = session.parts.filter((p) => p.status === 'no_speech_detected').map((p) => p.segment_id);
    const outcome = session.status === 'needs_rerecording' ? 'needs_rerecording' : 'failed';
    const message =
      outcome === 'needs_rerecording'
        ? session.error_message || 'Some answers had no detectable speech. Please re-record them and submit again.'
        : 'Speaking evaluation failed. Please try again.';
    if (placeholder) console.error(`[speaking] session ${sessionId}: scoring pass failed (placeholder bands)`);
    const updated = await prisma.attempt.update({
      where: { id: attempt.id },
      data: { data: { ...data, aiGraded: false, status: outcome, message, noSpeech } as object },
    });
    return { attemptId: attempt.id, status: outcome, message, noSpeech, attempt: attemptJson(updated) };
  });

  /**
   * Pronunciation trainer: {word, audioBase64, format?} →
   * {source, word, heard, score 0–100, tip, phonemes: [{phoneme, score 0–100}]}.
   * Goodness of Pronunciation from the speaking service, aligned against the
   * target word (not the transcript). Not counted toward the free limit.
   */
  r.post('/v1/pronunciation/score', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`pron:${userId}`, 120, 3600);
    const word = s(ctx.body.word, 200);
    if (!word) throw badRequest('word is required.');
    const audio = Buffer.from(s(ctx.body.audioBase64, 8_000_000).replace(/^data:[^,]*,/, ''), 'base64');
    if (audio.length < 1000) throw badRequest('The recording is empty.', 'no_audio');
    const format = (s(ctx.body.format, 8) || 'wav').toLowerCase();
    const r = await scoreWord(word, audio, format);
    const phonemes = r.phonemes
      .filter((p) => p.phoneme)
      .map((p) => ({ phoneme: p.phoneme, score: typeof p.score === 'number' ? phonemePercent(p.score) : null }));
    const scored = phonemes.filter((p): p is { phoneme: string; score: number } => p.score !== null);
    if (!scored.length) throw new HttpError(422, 'We couldn’t hear the word clearly. Try again a little louder.', 'no_speech');
    const score = Math.round(scored.reduce((a, p) => a + p.score, 0) / scored.length);
    const weak = [...scored].sort((a, b) => a.score - b.score).filter((p) => p.score < 60);
    const unique = [...new Set(weak.map((p) => p.phoneme))].slice(0, 2);
    const tip =
      score >= 85 && !unique.length ? 'Clear - every sound came through. Now say it inside a sentence.'
      : unique.length ? `Work on the ${unique.map((p) => `/${p}/`).join(' and ')} sound${unique.length > 1 ? 's' : ''} - listen to the native audio and copy the mouth shape.`
      : 'Good. Slow down slightly and make each sound distinct.';
    return { source: 'ai', word, heard: r.heard.trim(), score, tip, phonemes };
  });

  /**
   * AI speaking partner (community rooms / Part 3 practice).
   * {history: [{role: partner|student, content}], topic?, questions?[]}
   * -> {feedback, suggestion, question}
   */
  r.post('/v1/chat/partner', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`partner:${userId}`, 60, 3600);
    const language = await feedbackLanguage(userId, ctx.body);
    const history = (Array.isArray(ctx.body.history) ? (ctx.body.history as Row[]) : [])
      .filter((h) => s(h?.content))
      .slice(-12)
      .map((h) => `${h.role === 'student' ? 'STUDENT' : 'PARTNER'}: ${s(h.content, 1500)}`)
      .join('\n');
    const questions = (Array.isArray(ctx.body.questions) ? ctx.body.questions : []).map((q) => s(q, 300)).filter(Boolean).slice(0, 8);
    const topic = s(ctx.body.topic, 200);
    const system =
      'You are a friendly IELTS Academic Speaking partner who also gives examiner-style tips. Keep replies short and ' +
      'encouraging, use British spelling, never use em dashes (use a hyphen or comma), and reply with a single JSON object only: ' +
      '{"feedback": "...", "suggestion": "...", "question": "..."}' +
      (language !== 'en' ? `\n\n${languageNote(language)}` : '');
    const user =
      'PARTNER CHAT - IELTS Speaking Part 3 practice.\n' +
      (topic ? `TOPIC: ${topic}\n` : '') +
      (questions.length ? `QUESTION BANK (use or adapt):\n- ${questions.join('\n- ')}\n` : '') +
      `CONVERSATION SO FAR:\n${history || '(none yet)'}\n\n` +
      'If the student has answered, give feedback on their LAST answer only: one strength and one concrete improvement ' +
      '(development, linking words, vocabulary or grammar), max 2 sentences. Then ask ONE follow-up Part 3 question that ' +
      'builds on what they said. If they have not answered yet, leave feedback empty and ask an opening question.';
    const { data } = await chatJson({
      label: 'partner',
      model: env.openrouterChatModel,
      maxTokens: 700,
      temperature: 0.6,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
    });
    const question = s(data.question, 600) || questions[0] || '';
    if (!question) throw new HttpError(502, 'The AI partner did not reply. Please try again.', 'ai_failed');
    return { source: 'ai', feedback: s(data.feedback, 800), suggestion: s(data.suggestion, 300), question };
  });
}
