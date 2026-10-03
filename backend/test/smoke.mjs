// Local smoke test: node backend/test/smoke.mjs  (mocks OpenRouter + R2)
import worker, { band, overall, parseJsonReply, partnerHistory } from '../src/index.js';

const store = new Map();
const BUCKET = {
  async put(k, body) { store.set(k, new Uint8Array(await new Response(body).arrayBuffer())); },
  async get(k) {
    const v = store.get(k);
    if (!v) return null;
    return { body: v, arrayBuffer: async () => v.buffer, writeHttpMetadata: (h) => h.set('Content-Type', 'audio/wav') };
  },
};
const env = { OPENROUTER_API_KEY: 'x', APP_KEY: 'k', WRITING_MODEL: 'm', SPEAKING_MODEL: 'm', AUDIO_MODEL: 'a', BUCKET };

let lastBody;
globalThis.fetch = async (url, init) => {
  lastBody = JSON.parse(init.body);
  const user = JSON.stringify(lastBody.messages[1].content);
  let reply;
  if (user.includes('PARTNER CHAT')) reply = { feedback: 'Clear opinion; add an example.', suggestion: 'crucial', question: 'Should governments fund this?' };
  else if (user.includes('Transcribe')) reply = { text: 'um I think that uh my friend helped me', fillers: 2, pauses: 0 };
  else if (user.includes('tried to say')) reply = { heard: 'environment', score: 83, tip: 'Stress the second syllable.' };
  else if (user.includes('Rewrite')) reply = { text: 'Better essay.', changes: [{ from: 'a', to: 'b', why: 'c' }] };
  else if (user.includes('Speaking')) reply = { criteria: { FC: 6.4, LR: 6.5, GRA: 6, P: 7 }, summary: 's', feedback: ['f'], errors: [{ original: 'um', suggestion: '', type: 'filler' }] };
  else reply = { criteria: { TA: 6.5, CC: 6, LR: 6.3, GRA: 5.5 }, summary: 's', strengths: ['x'], feedback: ['y'], issues: [{ original: 'very good things', suggestion: 'clear benefits', type: 'vocabulary', note: 'n' }] };
  return new Response(JSON.stringify({ choices: [{ message: { content: '```json\n' + JSON.stringify(reply) + '\n```' } }] }), { status: 200 });
};

const call = async (method, path, body, headers = { 'X-App-Key': 'k' }) => {
  const init = { method, headers: { 'Content-Type': 'application/json', ...headers } };
  if (body !== undefined) init.body = typeof body === 'string' || body instanceof Uint8Array ? body : JSON.stringify(body);
  const res = await worker.fetch(new Request('https://api.test' + path, init), env);
  const ct = res.headers.get('Content-Type') || '';
  return { status: res.status, body: ct.includes('json') ? await res.json() : await res.arrayBuffer() };
};

const assert = (c, m) => { if (!c) { console.error('FAIL', m); process.exitCode = 1; } else console.log('ok', m); };
const essay = Array(60).fill('Remote work has very good things for many people.').join(' ');

assert(band(6.3) === 6.5 && band(6.2) === 6 && overall([6.5, 6, 6.5, 5.5]) === 6 && overall([7, 7, 6.5, 6.5]) === 7, 'band math');
assert(parseJsonReply('xx {"a":1} yy').a === 1, 'json parse');
assert((await call('GET', '/health', undefined, {})).status === 200, 'health');
assert((await call('POST', '/v1/writing/evaluate', { text: essay }, {})).status === 401, 'auth');
let r = await call('POST', '/v1/writing/evaluate', { task: 2, prompt: 'p', text: essay });
assert(r.status === 200 && r.body.band === 6 && r.body.criteria.LR === 6.5 && r.body.issues.length === 1, 'writing evaluate ' + JSON.stringify(r.body));
r = await call('POST', '/v1/writing/evaluate', { text: 'too short' });
assert(r.status === 502, 'writing too short');
r = await call('POST', '/v1/writing/rewrite', { text: essay });
assert(r.body.text === 'Better essay.', 'rewrite');
r = await call('PUT', '/v1/uploads?ext=wav', new Uint8Array([82, 73, 70, 70]), { 'X-App-Key': 'k', 'Content-Type': 'audio/wav' });
assert(r.status === 200 && r.body.key.endsWith('.wav'), 'upload');
const key = r.body.key;
r = await call('GET', '/v1/uploads/' + key);
assert(r.status === 200 && r.body.byteLength === 4, 'download');
r = await call('POST', '/v1/speaking/transcribe', { key });
assert(r.body.text.startsWith('um') && r.body.fillers === 2 && lastBody.messages[1].content[1].input_audio.format === 'wav', 'transcribe via key');
r = await call('POST', '/v1/speaking/evaluate', { part: 2, transcript: 'um I think', durationSec: 95 });
assert(r.body.band === 6.5 && r.body.criteria.FC === 6.5, 'speaking evaluate ' + JSON.stringify(r.body));
r = await call('POST', '/v1/pronunciation/score', { word: 'environment', audioBase64: 'UklGRg==', format: 'wav' });
assert(r.body.score === 83, 'pronunciation');
r = await call('POST', '/v1/chat/partner', {
  topic: 'Environment',
  questions: ['Why do people litter?'],
  history: [{ role: 'partner', content: 'Why do people litter?' }, { role: 'student', content: 'Because bins are far away.' }, { role: 'x', content: '  ' }],
});
assert(r.status === 200 && r.body.source === 'ai' && r.body.question === 'Should governments fund this?' && r.body.suggestion === 'crucial'
  && JSON.stringify(lastBody.messages[1].content).includes('STUDENT: Because bins'), 'chat partner ' + JSON.stringify(r.body));
assert(partnerHistory([{ role: 'student', content: 'a' }, { content: '' }, null]).length === 1, 'partner history');
assert((await call('POST', '/v1/otp/verify', { code: '123456' })).body.valid === true, 'otp');
assert((await call('POST', '/v1/nope', {})).status === 404, '404');
