// Google Gemini (generateContent REST API) for writing grading — the same
// provider and model the website uses. Server-side only: the key never
// reaches the app.

import { env } from '../env';
import { HttpError } from './http';
import { parseJsonLoose } from './openrouter';

type Json = Record<string, unknown>;

/** JSON Schema (as used for OpenRouter) → Gemini responseSchema: upper-case
 *  types, no additionalProperties / enum (not all Gemini models accept them). */
export function toGeminiSchema(schema: unknown): unknown {
  if (Array.isArray(schema)) return schema.map(toGeminiSchema);
  if (!schema || typeof schema !== 'object') return schema;
  const out: Json = {};
  for (const [k, v] of Object.entries(schema as Json)) {
    if (k === 'additionalProperties' || k === 'enum') continue;
    if (k === 'type' && typeof v === 'string') out.type = v.toUpperCase();
    else if (k === 'properties' && v && typeof v === 'object') {
      out.properties = Object.fromEntries(Object.entries(v as Json).map(([p, s]) => [p, toGeminiSchema(s)]));
    } else if (k === 'items') out.items = toGeminiSchema(v);
    else out[k] = v;
  }
  return out;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export interface GeminiJsonOptions {
  system: string;
  user: string;
  schema?: Json;
  model?: string;
  label?: string;
}

/** One JSON reply from Gemini. Retries rate limits / overload twice and
 *  drops the response schema if the model rejects it. */
export async function geminiJson(opts: GeminiJsonOptions): Promise<{ data: Json; model: string }> {
  if (!env.geminiApiKey) {
    throw new HttpError(503, 'AI grading is not configured on the server (GEMINI_API_KEY).', 'ai_not_configured');
  }
  const model = opts.model || env.geminiWritingModel;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  let useSchema = Boolean(opts.schema);
  let retries = 0;
  for (;;) {
    const body: Json = {
      systemInstruction: { parts: [{ text: opts.system }] },
      contents: [{ role: 'user', parts: [{ text: opts.user }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        ...(useSchema ? { responseSchema: toGeminiSchema(opts.schema) } : {}),
      },
    };
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.geminiApiKey },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(120_000),
      });
    } catch (e) {
      console.error(`[gemini] ${opts.label ?? ''} request failed`, e);
      throw new HttpError(502, 'Could not reach the AI grader. Please try again.', 'ai_failed');
    }
    const text = await res.text();
    if ((res.status === 429 || res.status === 503 || res.status === 500) && retries < 2) {
      retries++;
      await sleep(retries * 4000);
      continue;
    }
    if (res.status === 400 && useSchema) {
      console.warn(`[gemini] ${opts.label ?? ''} schema rejected, retrying without it:`, text.slice(0, 300));
      useSchema = false;
      continue;
    }
    if (!res.ok) {
      console.error(`[gemini] ${opts.label ?? ''} HTTP ${res.status}:`, text.slice(0, 1000));
      throw new HttpError(
        res.status === 429 ? 503 : 502,
        res.status === 429 ? 'The AI grader is busy right now. Please try again in a minute.' : `AI grading failed (HTTP ${res.status}).`,
        res.status === 429 ? 'ai_busy' : 'ai_failed',
      );
    }
    let payload: { candidates?: Array<{ content?: { parts?: Array<{ text?: string; thought?: boolean }> } }> };
    try {
      payload = JSON.parse(text);
    } catch {
      throw new HttpError(502, 'Unexpected response from the AI grader.', 'ai_failed');
    }
    const reply = (payload.candidates?.[0]?.content?.parts ?? [])
      .filter((p) => !p.thought)
      .map((p) => p.text ?? '')
      .join('')
      .trim();
    if (!reply) throw new HttpError(502, 'The AI grader returned an empty reply. Please try again.', 'ai_failed');
    try {
      return { data: parseJsonLoose(reply), model };
    } catch {
      throw new HttpError(502, 'The AI grader returned an unreadable reply. Please try again.', 'ai_failed');
    }
  }
}
