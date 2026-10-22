// Client for the nextED AI service (the FastAPI project `nexted-ai`):
// AI Counsellor, Course Finding and Scholarship Finding.
//
// The phone never talks to that service. It calls this Node API as before
// (/v1/nexted/ai/*); when NEXTED_AI_URL is set, these routes vouch for the
// student, send their profile across and pass the answer back in the shape
// the app already reads. The service keeps its own daily allowance, so Node
// does not count a second time.
//
// If the service is not running (connection refused, wrong address) the
// routes fall back to the built-in Gemini versions, so the module keeps
// working while you develop. A slow or failing service is reported as an
// error instead - retrying it here would spend the student's allowance twice.

import { env } from '../env';
import { HttpError } from './http';

/** The service could not be reached at all (nothing listening). */
export class NextedAiUnreachable extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NextedAiUnreachable';
  }
}

export const nextedAiEnabled = (): boolean => Boolean(env.nextedAiUrl);

type Json = Record<string, unknown>;

async function call(
  method: 'GET' | 'POST',
  path: string,
  body?: unknown,
  timeoutMs: number = env.nextedAiTimeoutMs,
): Promise<Json> {
  const base = env.nextedAiUrl.replace(/\/+$/, '');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  let res: Response;
  try {
    res = await fetch(base + path, {
      method,
      headers: {
        Accept: 'application/json',
        ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
        ...(env.nextedAiToken ? { Authorization: `Bearer ${env.nextedAiToken}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (e) {
    if (controller.signal.aborted) {
      throw new HttpError(503, 'The counsellor is taking too long right now. Please try again in a moment.', 'ai_busy');
    }
    throw new NextedAiUnreachable(e instanceof Error ? e.message : String(e));
  } finally {
    clearTimeout(timer);
  }

  let data: Json = {};
  try {
    data = (await res.json()) as Json;
  } catch {
    data = {};
  }
  if (!res.ok) throw errorFrom(res.status, data);
  return data;
}

/** The service's error reply as the HttpError the app understands. */
function errorFrom(status: number, data: Json): HttpError {
  {
    // The service already speaks the app's error codes (ai_limit_reached,
    // ai_busy, missing_field ...): pass them straight through.
    const code = typeof data.code === 'string' ? data.code : 'ai_failed';
    const message =
      typeof data.message === 'string' && data.message
        ? data.message
        : 'The counsellor could not finish that. Please try again.';
    const extra: Json = {};
    if (data.usage) extra.usage = data.usage;
    if (status === 401) {
      // A token mismatch between the two .env files is a setup problem, not
      // the student's - never tell them to sign in again for it.
      console.error('[nexted-ai] rejected our token - check NEXTED_AI_TOKEN matches SERVICE_TOKEN');
      return new HttpError(503, 'The counsellor is not available right now.', 'ai_not_configured');
    }
    return new HttpError(status, message, code, extra);
  }
}

/** The Node profile row, in the field names the service reads. */
export function aiProfile(p: Record<string, string>): Json {
  return {
    name: p.fullName ?? '',
    phone: p.phone ?? '',
    nationality: p.nationality ?? '',
    homeDistrict: p.homeDistrict ?? '',
    highestLevel: p.highestLevel ?? '',
    result: p.result ?? '',
    ieltsBand: p.ieltsBand ?? '',
    preferredCountry: p.preferredCountry ?? '',
    subject: p.subject ?? '',
    studyLevel: p.studyLevel ?? '',
    intake: p.preferredIntake ?? '',
  };
}

/** A checked fact ({value, confirmed, note, sourceUrl}) as the plain text the app shows. */
function factText(v: unknown): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'object') {
    const value = (v as Json).value;
    return value === null || value === undefined ? '' : String(value);
  }
  return String(v);
}

function factNote(v: unknown): string {
  return v && typeof v === 'object' && typeof (v as Json).note === 'string' ? ((v as Json).note as string) : '';
}

const list = (v: unknown): Json[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Json[]) : []);

export async function aiUsage(studentId: string): Promise<Json> {
  const data = await call('GET', `/v1/ai/usage?studentId=${encodeURIComponent(studentId)}`);
  return { usage: data.usage ?? {} };
}

function counsellorRequest(studentId: string, profile: Record<string, string>, message: string, history: unknown[]): Json {
  return {
    studentId,
    profile: aiProfile(profile),
    message,
    history: list(history).map((h) => ({
      role: String(h.role ?? '') === 'student' ? 'student' : 'counsellor',
      content: String(h.content ?? '').slice(0, 2000),
    })),
  };
}

function counsellorBody(data: Json): Json {
  return {
    reply: data.reply ?? '',
    restricted: data.restricted ?? [],
    needsHomeDistrict: Boolean(data.needsHomeDistrict),
    usage: data.usage,
    disclaimer: data.disclaimer ?? '',
    ...(data.office ? { office: data.office } : {}),
  };
}

/**
 * The counsellor, streamed: calls [onToken] with each piece of the reply as
 * the model writes it, and resolves with the full body at the end.
 *
 * Errors before the first byte (limit reached, bad request, not reachable)
 * are thrown exactly like aiCounsellor's, so the caller can still answer
 * with plain JSON or fall back to the built-in AI.
 */
export async function aiCounsellorStream(
  studentId: string,
  profile: Record<string, string>,
  message: string,
  history: unknown[],
  onToken: (text: string) => void,
  abort?: AbortSignal,
): Promise<Json> {
  const base = env.nextedAiUrl.replace(/\/+$/, '');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), env.nextedAiTimeoutMs);
  abort?.addEventListener('abort', () => controller.abort());
  try {
    let res: Response;
    try {
      res = await fetch(base + '/v1/ai/counsellor/stream', {
        method: 'POST',
        headers: {
          Accept: 'text/event-stream',
          'Content-Type': 'application/json',
          ...(env.nextedAiToken ? { Authorization: `Bearer ${env.nextedAiToken}` } : {}),
        },
        body: JSON.stringify(counsellorRequest(studentId, profile, message, history)),
        signal: controller.signal,
      });
    } catch (e) {
      if (controller.signal.aborted) {
        throw new HttpError(503, 'The counsellor is taking too long right now. Please try again in a moment.', 'ai_busy');
      }
      throw new NextedAiUnreachable(e instanceof Error ? e.message : String(e));
    }
    if (res.status === 404) {
      // An older nexted-ai without the stream route.
      throw new NextedAiUnreachable('no stream route');
    }
    if (!res.ok || !res.body) {
      let data: Json = {};
      try {
        data = (await res.json()) as Json;
      } catch {
        data = {};
      }
      throw errorFrom(res.status, data);
    }

    // Server-Sent Events: frames separated by a blank line,
    // "event: <name>" and "data: <json>" lines inside.
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let done: Json | null = null;
    for (;;) {
      let chunk: ReadableStreamReadResult<Uint8Array>;
      try {
        chunk = await reader.read();
      } catch {
        if (controller.signal.aborted) {
          throw new HttpError(503, 'The counsellor is taking too long right now. Please try again in a moment.', 'ai_busy');
        }
        throw new HttpError(502, 'The counsellor stopped part way. Please try again.', 'ai_failed');
      }
      if (chunk.done) break;
      buffer += decoder.decode(chunk.value, { stream: true }).replace(/\r\n/g, '\n');
      let cut: number;
      while ((cut = buffer.indexOf('\n\n')) >= 0) {
        const frame = buffer.slice(0, cut);
        buffer = buffer.slice(cut + 2);
        let event = 'message';
        const lines: string[] = [];
        for (const line of frame.split('\n')) {
          if (line.startsWith('event:')) event = line.slice(6).trim();
          else if (line.startsWith('data:')) lines.push(line.slice(5).replace(/^ /, ''));
        }
        let data: Json = {};
        try {
          data = JSON.parse(lines.join('\n')) as Json;
        } catch {
          continue;
        }
        if (event === 'token' && typeof data.t === 'string') onToken(data.t);
        else if (event === 'done') done = counsellorBody(data);
        else if (event === 'error') throw errorFrom(typeof data.status === 'number' ? data.status : 500, data);
      }
    }
    if (!done) throw new HttpError(502, 'The counsellor stopped part way. Please try again.', 'ai_failed');
    return done;
  } finally {
    clearTimeout(timer);
  }
}

export async function aiCounsellor(
  studentId: string,
  profile: Record<string, string>,
  message: string,
  history: unknown[],
): Promise<Json> {
  const data = await call('POST', '/v1/ai/counsellor', counsellorRequest(studentId, profile, message, history));
  return counsellorBody(data);
}

export async function aiCourses(studentId: string, profile: Record<string, string>, query: string): Promise<Json> {
  const data = await call('POST', '/v1/ai/courses', { studentId, profile: aiProfile(profile), query });
  const courses = list(data.courses).map((c) => ({
    ...c,
    // The app shows these as plain text; the "please check" note travels alongside.
    tuition: factText(c.tuition),
    tuitionNote: factNote(c.tuition),
    minIelts: factText(c.minIelts),
    deadline: factText(c.deadline),
    deadlineNote: factNote(c.deadline),
  }));
  return {
    courses,
    // The AI service always has a catalogue (and reads the web when it is
    // thin), so an empty list means "nothing fits", never "nothing loaded".
    catalogueEmpty: false,
    searchNote: data.searchNote ?? '',
    researchNote: data.researchNote ?? '',
    needsHomeDistrict: Boolean(data.needsHomeDistrict),
    sources: data.sources ?? [],
    usage: data.usage,
    disclaimer: data.disclaimer ?? '',
  };
}

export async function aiScholarships(
  studentId: string,
  profile: Record<string, string>,
  query: string,
): Promise<Json> {
  const data = await call('POST', '/v1/ai/scholarships', { studentId, profile: aiProfile(profile), query });
  const scholarships = list(data.scholarships).map((x) => ({
    ...x,
    amount: factText(x.amount),
    amountNote: factNote(x.amount),
    deadline: factText(x.deadline),
    deadlineNote: factNote(x.deadline),
  }));
  return {
    scholarships,
    catalogueEmpty: false,
    searchNote: data.searchNote ?? '',
    researchNote: data.researchNote ?? '',
    gap: data.gap ?? null,
    sources: data.sources ?? [],
    usage: data.usage,
    disclaimer: data.disclaimer ?? '',
  };
}

/** Is the service up? (for /health) */
export async function aiHealth(): Promise<Json | null> {
  try {
    return await call('GET', '/health', undefined, 3000);
  } catch {
    return null;
  }
}
