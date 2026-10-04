// Tiny HTTP layer on Node's built-in http module: a router with :params,
// JSON bodies, typed errors and JSON replies. No framework needed for a
// mobile-only JSON API.

import type { IncomingMessage, ServerResponse } from 'node:http';
import { env } from '../env';

export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
    public code?: string,
    public extra?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export const badRequest = (message: string, code = 'bad_request') => new HttpError(400, message, code);
export const unauthorized = (message = 'Please log in again.', code = 'unauthorized') =>
  new HttpError(401, message, code);
export const forbidden = (message: string, code = 'forbidden') => new HttpError(403, message, code);
export const notFound = (message = 'Not found.') => new HttpError(404, message, 'not_found');

export interface Ctx {
  req: IncomingMessage;
  res: ServerResponse;
  method: string;
  path: string;
  query: URLSearchParams;
  params: Record<string, string>;
  /** Parsed JSON body ({} when empty or not JSON). */
  body: Record<string, unknown>;
  /** Raw body for non-JSON requests (file uploads). */
  raw?: Buffer;
  ip: string;
  /** Set by auth middleware for protected routes. */
  userId?: string;
}

export type Handler = (ctx: Ctx) => Promise<unknown> | unknown;

interface Route {
  method: string;
  parts: string[];
  handler: Handler;
}

export class Router {
  private routes: Route[] = [];

  add(method: string, pattern: string, handler: Handler): this {
    this.routes.push({ method, parts: pattern.split('/').filter(Boolean), handler });
    return this;
  }

  get(p: string, h: Handler) {
    return this.add('GET', p, h);
  }
  post(p: string, h: Handler) {
    return this.add('POST', p, h);
  }
  put(p: string, h: Handler) {
    return this.add('PUT', p, h);
  }
  patch(p: string, h: Handler) {
    return this.add('PATCH', p, h);
  }
  delete(p: string, h: Handler) {
    return this.add('DELETE', p, h);
  }

  /** Finds the route for a request; a trailing '*' param swallows the rest. */
  match(method: string, path: string): { handler: Handler; params: Record<string, string> } | 'method' | null {
    const segs = path.split('/').filter(Boolean).map((s) => decodeURIComponent(s));
    let methodMismatch = false;
    for (const r of this.routes) {
      const params: Record<string, string> = {};
      let ok = true;
      for (let i = 0; i < r.parts.length; i++) {
        const p = r.parts[i];
        if (p === '*') {
          params['*'] = segs.slice(i).join('/');
          if (!params['*']) ok = false;
          break;
        }
        const s = segs[i];
        if (s === undefined) {
          ok = false;
          break;
        }
        if (p.startsWith(':')) params[p.slice(1)] = s;
        else if (p !== s) {
          ok = false;
          break;
        }
        if (i === r.parts.length - 1 && segs.length !== r.parts.length) ok = false;
      }
      if (r.parts.length === 0 && segs.length !== 0) ok = false;
      if (!ok) continue;
      if (r.method !== method) {
        methodMismatch = true;
        continue;
      }
      return { handler: r.handler, params };
    }
    return methodMismatch ? 'method' : null;
  }
}

export async function readBody(req: IncomingMessage): Promise<Buffer> {
  const limit = env.maxBodyMb * 1024 * 1024;
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    const b = chunk as Buffer;
    size += b.length;
    if (size > limit) throw new HttpError(413, `Request is larger than ${env.maxBodyMb} MB.`, 'too_large');
    chunks.push(b);
  }
  return Buffer.concat(chunks);
}

/**
 * Replaces em dashes (U+2014) with a normal dash, spaced like the app
 * ("word - word"). Runs on every JSON response, so AI feedback (and anything
 * already stored) never reaches the app with em dashes. The dash is never
 * part of JSON syntax, so working on the serialised text is safe.
 */
export function plainDashes(text: string): string {
  if (!text.includes('\u2014')) return text;
  return text.replace(/[ \t]*\u2014[ \t]*/g, (m: string, offset: number) => {
    const b1 = text[offset - 1] ?? '';
    const b2 = text[offset - 2] ?? '';
    const end = offset + m.length;
    const a1 = text[end] ?? '';
    const a2 = text[end + 1] ?? '';
    const noLead = b1 === '' || (b1 === '"' && b2 !== '\\') || (b1 === 'n' && b2 === '\\') || '([{'.includes(b1);
    const noTrail = a1 === '' || (a1 === '\\' && a2 === 'n') || '")]},.;:'.includes(a1);
    return `${noLead ? '' : ' '}-${noTrail ? '' : ' '}`;
  });
}

export function sendJson(res: ServerResponse, status: number, body: unknown): void {
  if (res.headersSent) return;
  const data = plainDashes(JSON.stringify(body ?? {}));
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(data),
    'Cache-Control': 'no-store',
  });
  res.end(data);
}

// ── small input helpers ─────────────────────────────────────────────────────

export function s(v: unknown, max = 10000): string {
  return typeof v === 'string' ? v.trim().slice(0, max) : v == null ? '' : String(v).trim().slice(0, max);
}

export function required(body: Record<string, unknown>, key: string, max = 10000): string {
  const v = s(body[key], max);
  if (!v) throw badRequest(`${key} is required.`, 'missing_field');
  return v;
}

export function int(v: unknown, fallback: number, min = -Infinity, max = Infinity): number {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

export function obj(v: unknown): Record<string, unknown> {
  return v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

/** Simple fixed-window rate limit (per key, in memory). */
const buckets = new Map<string, { count: number; resetAt: number }>();
export function rateLimit(key: string, max: number, windowSec: number): void {
  const now = Date.now();
  const b = buckets.get(key);
  if (!b || b.resetAt <= now) {
    buckets.set(key, { count: 1, resetAt: now + windowSec * 1000 });
    if (buckets.size > 50000) {
      for (const [k, v] of buckets) if (v.resetAt <= now) buckets.delete(k);
    }
    return;
  }
  b.count++;
  if (b.count > max) {
    const wait = Math.ceil((b.resetAt - now) / 1000);
    throw new HttpError(429, `Too many attempts. Try again in ${wait}s.`, 'rate_limited', { retryAfterSec: wait });
  }
}
