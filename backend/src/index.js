// IELTS AI by nextED — API worker (Cloudflare Workers, plain ES modules).
//
// Keeps the OpenRouter key and the R2 bucket on the server. The Flutter app
// calls these endpoints; if the app has no API_BASE_URL configured it falls
// back to its built-in demo scorer, so the app still works offline.
//
// Endpoints (all JSON unless noted, all need `X-App-Key` when APP_KEY is set):
//   GET  /health
//   POST /v1/writing/evaluate      {task, prompt, text}
//   POST /v1/writing/rewrite       {task, prompt, text, targetBand}
//   POST /v1/speaking/transcribe   {audioBase64, format} | {key}
//   POST /v1/speaking/evaluate     {part, questions[], transcript, durationSec, cueCard?}
//   POST /v1/pronunciation/score   {word, audioBase64, format}
//   POST /v1/chat/partner          {history[{role, content}], topic?, questions[]?}
//   PUT  /v1/uploads?ext=wav       raw audio body  -> {key, url}
//   GET  /v1/uploads/<key>         streams the object from R2
//   POST /v1/otp/send              {phone}
//   POST /v1/otp/verify            {phone, code}

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// ── helpers ────────────────────────────────────────────────────────────────

function cors(env) {
  return {
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,X-App-Key',
    'Access-Control-Max-Age': '86400',
  };
}

function json(env, body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...cors(env) },
  });
}

function fail(env, status, message) {
  return json(env, { error: message }, status);
}

/** Round to the nearest IELTS half band, clamp 0–9. */
export function band(v) {
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return Math.min(9, Math.max(0, Math.round(n * 2) / 2));
}

/** IELTS overall rounding (.25 → .5, .75 → next whole). */
export function overall(values) {
  const xs = values.map(Number).filter(Number.isFinite);
  if (!xs.length) return null;
  const avg = xs.reduce((a, b) => a + b, 0) / xs.length;
  const floor = Math.floor(avg);
  const frac = avg - floor;
  if (frac < 0.25) return floor;
  if (frac < 0.75) return floor + 0.5;
  return floor + 1;
}

/** Extract the first JSON object from a model reply (handles ```json fences). */
export function parseJsonReply(text) {
  if (!text) throw new Error('Empty model reply');
  const cleaned = String(text).replace(/```(?:json)?/gi, '').trim();
  try {
    return JSON.parse(cleaned);
  } catch (_) {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) return JSON.parse(cleaned.slice(start, end + 1));
    throw new Error('Model did not return JSON');
  }
}

function wordCount(text) {
  return (String(text || '').match(/[A-Za-z']+/g) || []).length;
}

function strList(v, max = 12) {
  return Array.isArray(v) ? v.map((x) => String(x)).filter(Boolean).slice(0, max) : [];
}

function issueList(v, max = 20) {
  if (!Array.isArray(v)) return [];
  return v
    .filter((x) => x && typeof x === 'object' && x.original)
    .slice(0, max)
    .map((x) => ({
      original: String(x.original),
      suggestion: String(x.suggestion || ''),
      type: String(x.type || 'grammar'),
      note: String(x.note || ''),
    }));
}

const BANGLA_NOTE =
  'Write every explanation, note, tip and feedback sentence in Bangla (বাংলা). ' +
  'Keep JSON keys, band numbers, quoted student text, corrected English sentences ' +
  'and model answers in English.';

async function callModel(env, { model, system, user, maxTokens = 1800 }) {
  if (!env.OPENROUTER_API_KEY) throw new Error('OPENROUTER_API_KEY is not set');
  const res = await fetch(OPENROUTER_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': env.APP_URL || 'https://ieltsai.nexted.app',
      'X-Title': 'IELTS AI by nextED',
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      max_tokens: maxTokens,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: env.FEEDBACK_LANG === 'bn' ? `${system}\n\n${BANGLA_NOTE}` : system },
        { role: 'user', content: user },
      ],
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`OpenRouter ${res.status}: ${detail.slice(0, 300)}`);
  }
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content;
  const text = Array.isArray(content)
    ? content.map((p) => (typeof p === 'string' ? p : p?.text || '')).join('')
    : content;
  return parseJsonReply(text);
}

function audioPart(base64, format) {
  return { type: 'input_audio', input_audio: { data: base64, format: format || 'wav' } };
}

function toBase64(buf) {
  const bytes = new Uint8Array(buf);
  let s = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    s += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
  }
  return btoa(s);
}

async function readAudio(env, body) {
  if (body.audioBase64) return { base64: body.audioBase64, format: body.format || 'wav' };
  if (body.key) {
    if (!env.BUCKET) throw new Error('R2 bucket binding missing');
    const obj = await env.BUCKET.get(body.key);
    if (!obj) throw new Error('Recording not found');
    const ext = (body.key.split('.').pop() || 'wav').toLowerCase();
    return { base64: toBase64(await obj.arrayBuffer()), format: ext };
  }
  throw new Error('Send audioBase64 or key');
}

// ── prompts ────────────────────────────────────────────────────────────────

const EXAMINER =
  'You are a certified IELTS Academic examiner. Score strictly using the public IELTS band descriptors. ' +
  'Bands are 0–9 in steps of 0.5. Be specific and practical. Reply with a single JSON object only.';

function writingPrompt({ task, prompt, text }) {
  const t = Number(task) === 1 ? 1 : 2;
  const crit = t === 1 ? 'TA = Task Achievement' : 'TA = Task Response';
  return (
    `Evaluate this IELTS Academic Writing Task ${t} answer.\n` +
    `Criteria: ${crit}, CC = Coherence & Cohesion, LR = Lexical Resource, GRA = Grammatical Range & Accuracy.\n\n` +
    `QUESTION:\n${prompt || '(not provided)'}\n\nANSWER (${wordCount(text)} words):\n${text}\n\n` +
    'Return JSON: {"criteria":{"TA":n,"CC":n,"LR":n,"GRA":n},' +
    '"summary":"2 sentences","strengths":["..."],"feedback":["actionable tip", ...up to 6],' +
    '"issues":[{"original":"exact substring copied from the answer","suggestion":"corrected text","type":"grammar|vocabulary|cohesion|task|punctuation|style","note":"short why"}] (up to 12, most important first)}'
  );
}

function rewritePrompt({ task, prompt, text, targetBand }) {
  return (
    `Rewrite this IELTS Writing Task ${Number(task) === 1 ? 1 : 2} answer to Band ${targetBand || 8} standard. ` +
    'Keep the student\'s ideas and position, fix errors, improve cohesion and vocabulary, keep a similar length.\n\n' +
    `QUESTION:\n${prompt || '(not provided)'}\n\nANSWER:\n${text}\n\n` +
    'Return JSON: {"text":"full rewritten answer with \\n\\n between paragraphs",' +
    '"changes":[{"from":"original phrase","to":"new phrase","why":"short reason"}] (up to 10)}'
  );
}

function speakingPrompt({ part, questions, transcript, durationSec, cueCard }) {
  return (
    `Evaluate this IELTS Speaking Part ${part || 2} response from its transcript.\n` +
    'Criteria: FC = Fluency & Coherence, LR = Lexical Resource, GRA = Grammatical Range & Accuracy, ' +
    'P = Pronunciation (estimate cautiously from the transcript: hesitations, fillers, self-corrections).\n' +
    (cueCard ? `CUE CARD:\n${cueCard}\n` : '') +
    (Array.isArray(questions) && questions.length ? `QUESTIONS:\n- ${questions.join('\n- ')}\n` : '') +
    `SPEAKING TIME: ${Math.round(Number(durationSec) || 0)} seconds\n\nTRANSCRIPT:\n${transcript}\n\n` +
    'Return JSON: {"criteria":{"FC":n,"LR":n,"GRA":n,"P":n},"summary":"2 sentences",' +
    '"feedback":["actionable tip", ...up to 5],' +
    '"errors":[{"original":"exact words from transcript","suggestion":"better version","type":"grammar|vocabulary|filler|pronunciation","note":"short why"}] (up to 10)}'
  );
}

const PARTNER =
  'You are a friendly IELTS Academic Speaking partner who also gives examiner-style tips. ' +
  'Keep replies short and encouraging, use British spelling, and reply with a single JSON object only.';

/** Normalises the chat history sent by the app (last 12 turns, trimmed). */
export function partnerHistory(v) {
  if (!Array.isArray(v)) return [];
  return v
    .filter((x) => x && typeof x === 'object' && String(x.content || '').trim())
    .slice(-12)
    .map((x) => ({
      role: String(x.role) === 'student' ? 'student' : 'partner',
      content: String(x.content).trim().slice(0, 1500),
    }));
}

function partnerPrompt({ history, topic, questions }) {
  const lines = history.map((h) => `${h.role === 'student' ? 'STUDENT' : 'PARTNER'}: ${h.content}`).join('\n');
  return (
    'PARTNER CHAT — IELTS Speaking Part 3 practice.\n' +
    (topic ? `TOPIC: ${topic}\n` : '') +
    (Array.isArray(questions) && questions.length ? `QUESTION BANK (use or adapt):\n- ${questions.slice(0, 8).join('\n- ')}\n` : '') +
    `CONVERSATION SO FAR:\n${lines || '(none yet)'}\n\n` +
    'If the student has answered, give feedback on their LAST answer only: one strength and one concrete improvement ' +
    '(development, linking words, vocabulary or grammar), max 2 sentences. Then ask ONE follow-up Part 3 question ' +
    'that builds on what they said. If they have not answered yet, leave feedback empty and ask an opening question.\n' +
    'Return JSON: {"feedback":"...","suggestion":"a better word or phrase they could have used, or empty","question":"..."}'
  );
}

// ── handlers ───────────────────────────────────────────────────────────────

async function writingEvaluate(env, body) {
  const text = String(body.text || '');
  if (wordCount(text) < 20) throw new Error('Answer is too short to evaluate');
  const r = await callModel(env, { model: env.WRITING_MODEL, system: EXAMINER, user: writingPrompt(body) });
  const c = r.criteria || {};
  const criteria = { TA: band(c.TA), CC: band(c.CC), LR: band(c.LR), GRA: band(c.GRA) };
  return {
    source: 'ai',
    model: env.WRITING_MODEL,
    band: overall(Object.values(criteria)),
    criteria,
    words: wordCount(text),
    summary: String(r.summary || ''),
    strengths: strList(r.strengths, 6),
    feedback: strList(r.feedback, 6),
    issues: issueList(r.issues, 12),
  };
}

async function writingRewrite(env, body) {
  const r = await callModel(env, {
    model: env.WRITING_MODEL,
    system: EXAMINER,
    user: rewritePrompt(body),
    maxTokens: 2200,
  });
  return {
    source: 'ai',
    text: String(r.text || ''),
    changes: Array.isArray(r.changes)
      ? r.changes.slice(0, 10).map((c) => ({ from: String(c.from || ''), to: String(c.to || ''), why: String(c.why || '') }))
      : [],
  };
}

async function speakingTranscribe(env, body) {
  const audio = await readAudio(env, body);
  const r = await callModel(env, {
    model: env.AUDIO_MODEL,
    system:
      'You transcribe English learner speech verbatim for IELTS practice. Keep fillers (um, uh, er, like) ' +
      'and repetitions exactly as spoken; mark long pauses as "...". Reply with JSON only.',
    user: [
      { type: 'text', text: 'Transcribe this recording. Return JSON: {"text":"verbatim transcript","fillers":n,"pauses":n}' },
      audioPart(audio.base64, audio.format),
    ],
    maxTokens: 1500,
  });
  const text = String(r.text || '').trim();
  return {
    source: 'ai',
    text,
    words: wordCount(text),
    fillers: Number(r.fillers) || 0,
    pauses: Number(r.pauses) || 0,
  };
}

async function speakingEvaluate(env, body) {
  const transcript = String(body.transcript || '').trim();
  if (!transcript) throw new Error('Transcript is empty');
  const r = await callModel(env, { model: env.SPEAKING_MODEL, system: EXAMINER, user: speakingPrompt(body) });
  const c = r.criteria || {};
  const criteria = { FC: band(c.FC), LR: band(c.LR), GRA: band(c.GRA), P: band(c.P) };
  return {
    source: 'ai',
    model: env.SPEAKING_MODEL,
    band: overall(Object.values(criteria)),
    criteria,
    summary: String(r.summary || ''),
    feedback: strList(r.feedback, 5),
    errors: issueList(r.errors, 10),
  };
}

async function pronunciationScore(env, body) {
  const word = String(body.word || '').trim();
  if (!word) throw new Error('Missing word');
  const audio = await readAudio(env, body);
  const r = await callModel(env, {
    model: env.AUDIO_MODEL,
    system: 'You are a pronunciation coach for English learners. Reply with JSON only.',
    user: [
      {
        type: 'text',
        text:
          `The learner tried to say the word "${word}". Listen and rate how clearly and correctly it was pronounced ` +
          '(stress, vowels, final consonants). Return JSON: {"heard":"what you heard","score":0-100,"tip":"one short tip"}',
      },
      audioPart(audio.base64, audio.format),
    ],
    maxTokens: 300,
  });
  const score = Math.max(0, Math.min(100, Math.round(Number(r.score) || 0)));
  return { source: 'ai', word, heard: String(r.heard || ''), score, tip: String(r.tip || '') };
}

async function chatPartner(env, body) {
  const history = partnerHistory(body.history);
  const questions = strList(body.questions, 8);
  const r = await callModel(env, {
    model: env.SPEAKING_MODEL,
    system: PARTNER,
    user: partnerPrompt({ history, topic: body.topic ? String(body.topic) : '', questions }),
    maxTokens: 400,
  });
  const question = String(r.question || '').trim() || questions[0] || '';
  if (!question) throw new Error('Model did not return a question');
  return {
    source: 'ai',
    feedback: String(r.feedback || '').trim(),
    suggestion: String(r.suggestion || '').trim(),
    question,
  };
}

async function upload(env, request, url) {
  if (!env.BUCKET) throw new Error('R2 bucket binding missing');
  const ext = (url.searchParams.get('ext') || 'wav').replace(/[^a-z0-9]/gi, '').slice(0, 5) || 'wav';
  const day = new Date().toISOString().slice(0, 10);
  const key = `recordings/${day}/${crypto.randomUUID()}.${ext}`;
  const type = request.headers.get('Content-Type') || (ext === 'wav' ? 'audio/wav' : 'application/octet-stream');
  await env.BUCKET.put(key, request.body, { httpMetadata: { contentType: type } });
  return { key, url: `/v1/uploads/${key}` };
}

async function download(env, key) {
  if (!env.BUCKET) throw new Error('R2 bucket binding missing');
  const obj = await env.BUCKET.get(key);
  if (!obj) return fail(env, 404, 'Not found');
  const headers = new Headers(cors(env));
  obj.writeHttpMetadata(headers);
  headers.set('Cache-Control', 'private, max-age=3600');
  return new Response(obj.body, { headers });
}

function otpSend(env, body) {
  const phone = String(body.phone || '').replace(/\D/g, '');
  if (phone.length < 10) throw new Error('Invalid phone number');
  // No SMS provider yet: the demo code is accepted by /v1/otp/verify.
  return { sent: true, demo: !env.SMS_PROVIDER };
}

function otpVerify(env, body) {
  const code = String(body.code || '').trim();
  return { valid: code === String(env.DEMO_OTP || '123456') };
}

// ── router ─────────────────────────────────────────────────────────────────

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';

    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(env) });
    if (path === '/health') return json(env, { ok: true, service: 'ielts-ai-api' });

    if (env.APP_KEY && request.headers.get('X-App-Key') !== env.APP_KEY) {
      return fail(env, 401, 'Unauthorized');
    }

    try {
      if (request.method === 'GET' && path.startsWith('/v1/uploads/')) {
        return await download(env, decodeURIComponent(path.slice('/v1/uploads/'.length)));
      }
      if (request.method === 'PUT' && path === '/v1/uploads') {
        return json(env, await upload(env, request, url));
      }
      if (request.method !== 'POST') return fail(env, 405, 'Method not allowed');

      const body = await request.json().catch(() => ({}));
      // Optional: explanations in Bangla for students who prefer it.
      if (body && body.feedbackLanguage === 'bn') env = { ...env, FEEDBACK_LANG: 'bn' };
      switch (path) {
        case '/v1/writing/evaluate':
          return json(env, await writingEvaluate(env, body));
        case '/v1/writing/rewrite':
          return json(env, await writingRewrite(env, body));
        case '/v1/speaking/transcribe':
          return json(env, await speakingTranscribe(env, body));
        case '/v1/speaking/evaluate':
          return json(env, await speakingEvaluate(env, body));
        case '/v1/pronunciation/score':
          return json(env, await pronunciationScore(env, body));
        case '/v1/chat/partner':
          return json(env, await chatPartner(env, body));
        case '/v1/otp/send':
          return json(env, otpSend(env, body));
        case '/v1/otp/verify':
          return json(env, otpVerify(env, body));
        default:
          return fail(env, 404, 'Not found');
      }
    } catch (err) {
      return fail(env, 502, err instanceof Error ? err.message : String(err));
    }
  },
};
