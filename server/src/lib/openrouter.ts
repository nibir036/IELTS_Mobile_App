// OpenRouter chat completions (OpenAI-compatible). Replaces Gemini for
// writing grading. Models come from .env; free ones end in ":free".
//
// - OPENROUTER_MODEL_FALLBACKS is sent as OpenRouter's `models` list: when the
//   main model is rate-limited, down or refuses the request, the next is tried.
// - Not every free model supports strict JSON-schema output, so a 400/422
//   steps down the response format (strict schema -> JSON mode -> none) and
//   the reply is parsed leniently.

import { env } from '../env';
import { HttpError } from './http';

export type ChatContent =
  | string
  | Array<{ type: 'text'; text: string } | { type: 'image_url'; image_url: { url: string } }>;

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: ChatContent;
}

export interface ChatJsonOptions {
  model: string;
  messages: ChatMessage[];
  schema?: Record<string, unknown>;
  schemaName?: string;
  maxTokens?: number;
  temperature?: number;
  label?: string;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Strips code fences / think tags and parses the first JSON object. */
export function parseJsonLoose(text: string): Record<string, unknown> {
  let t = text.trim();
  t = t.replace(/<think>[\s\S]*?<\/think>/gi, '').replace(/<thinking>[\s\S]*?<\/thinking>/gi, '');
  t = t.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
  try {
    const v = JSON.parse(t);
    if (v && typeof v === 'object' && !Array.isArray(v)) return v as Record<string, unknown>;
  } catch {
    // fall through
  }
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start >= 0 && end > start) {
    const v = JSON.parse(t.slice(start, end + 1));
    if (v && typeof v === 'object') return v as Record<string, unknown>;
  }
  throw new Error('The AI reply was not valid JSON.');
}

export async function chatJson(opts: ChatJsonOptions): Promise<{ data: Record<string, unknown>; model: string }> {
  if (!env.openrouterApiKey) {
    throw new HttpError(503, 'AI grading is not configured on the server (OPENROUTER_API_KEY).', 'ai_not_configured');
  }
  const models = [opts.model, ...env.openrouterFallbacks.filter((m) => m !== opts.model)];
  const formats: Array<Record<string, unknown> | null> = [];
  if (opts.schema) {
    formats.push({
      type: 'json_schema',
      json_schema: { name: opts.schemaName || 'result', strict: true, schema: opts.schema },
    });
  }
  formats.push({ type: 'json_object' }, null);

  let fmtIndex = 0;
  let rateRetries = 0;
  const label = opts.label || 'chat';
  for (;;) {
    const fmt = formats[fmtIndex];
    const body: Record<string, unknown> = {
      model: opts.model,
      models,
      messages: opts.messages,
      temperature: opts.temperature ?? 0.2,
      max_tokens: opts.maxTokens ?? 2500,
      // Thinking models: keep reasoning short so max_tokens is left for the JSON.
      reasoning: { effort: env.openrouterReasoningEffort, exclude: true },
    };
    if (fmt) body.response_format = fmt;

    let res: Response;
    try {
      res = await fetch(`${env.openrouterBaseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${env.openrouterApiKey}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': env.appUrl,
          'X-Title': 'IELTS AI by nextED',
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(150_000),
      });
    } catch (e) {
      console.error(`[openrouter:${label}] network error`, e);
      throw new HttpError(502, 'Could not reach the AI grader. Please try again.', 'ai_unreachable');
    }

    if (res.status === 429 && rateRetries < 2) {
      rateRetries++;
      const after = Number(res.headers.get('retry-after'));
      await sleep(Number.isFinite(after) && after > 0 ? Math.min(after, 30) * 1000 + 500 : 6000);
      continue;
    }
    if ((res.status === 400 || res.status === 422) && fmtIndex < formats.length - 1) {
      console.warn(`[openrouter:${label}] ${res.status} with ${fmt ? fmt.type : 'no format'}; trying simpler format`);
      fmtIndex++;
      continue;
    }
    const text = await res.text();
    if (!res.ok) {
      console.error(`[openrouter:${label}] HTTP ${res.status}:`, text.slice(0, 800));
      throw new HttpError(
        res.status === 429 ? 429 : 502,
        res.status === 429
          ? 'The AI grader is busy right now. Please try again in a minute.'
          : 'AI grading failed. Please try again.',
        res.status === 429 ? 'ai_busy' : 'ai_failed',
      );
    }
    let payload: {
      model?: string;
      error?: { message?: string };
      choices?: Array<{ message?: { content?: string | null }; finish_reason?: string }>;
    };
    try {
      payload = JSON.parse(text);
    } catch {
      throw new HttpError(502, 'Unexpected reply from the AI grader.', 'ai_failed');
    }
    if (payload.error) {
      console.error(`[openrouter:${label}] error`, payload.error);
      throw new HttpError(502, 'AI grading failed. Please try again.', 'ai_failed');
    }
    const content = payload.choices?.[0]?.message?.content || '';
    if (!content.trim()) {
      if (fmtIndex < formats.length - 1) {
        fmtIndex++;
        continue;
      }
      throw new HttpError(502, 'The AI grader returned an empty reply. Please try again.', 'ai_failed');
    }
    try {
      return { data: parseJsonLoose(content), model: payload.model || opts.model };
    } catch {
      if (fmtIndex < formats.length - 1) {
        fmtIndex++;
        continue;
      }
      throw new HttpError(502, 'The AI grader returned an unreadable reply. Please try again.', 'ai_failed');
    }
  }
}
