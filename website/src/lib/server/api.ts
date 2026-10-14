// Calls to the IELTS AI API from the website's server (server components,
// route handlers). The browser never talks to the API directly and never
// sees a token: they are read here from httpOnly cookies.

import { cookies, headers } from 'next/headers';
import { COOKIE, deviceHeaders } from '../session';
import { env } from './env';

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public code: string,
    public data: Record<string, unknown> = {},
  ) {
    super(message);
  }
  get isUpgrade() {
    return this.code === 'upgrade_required';
  }
}

export interface ApiOptions {
  method?: string;
  body?: unknown;
  /** Send the signed-in user's access token (default true). */
  auth?: boolean;
  /** Override the token (route handlers that just signed in). */
  token?: string;
  /** Next.js fetch cache: seconds to keep a GET (default: not cached). */
  revalidate?: number;
}

/** Headers every API call carries: app key + this browser's device id. */
export async function baseHeaders(): Promise<Record<string, string>> {
  const jar = await cookies();
  const h = await headers();
  return {
    ...(env.appKey ? { 'X-App-Key': env.appKey } : {}),
    ...deviceHeaders(jar.get(COOKIE.device)?.value ?? '', h.get('user-agent') ?? ''),
  };
}

export async function accessToken(): Promise<string | null> {
  return (await cookies()).get(COOKIE.access)?.value ?? null;
}

/** True when this browser holds a session (it may still need a refresh). */
export async function hasSession(): Promise<boolean> {
  const jar = await cookies();
  return Boolean(jar.get(COOKIE.refresh)?.value || jar.get(COOKIE.access)?.value);
}

/** JSON call to the API. Throws [ApiError] with the server's message and code. */
export async function api<T = Record<string, unknown>>(path: string, opts: ApiOptions = {}): Promise<T> {
  const token = opts.token ?? (opts.auth === false ? null : await accessToken());
  const init: RequestInit & { next?: { revalidate: number } } = {
    method: opts.method ?? 'GET',
    headers: {
      ...(await baseHeaders()),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(opts.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
    },
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
    cache: opts.revalidate ? undefined : 'no-store',
    ...(opts.revalidate ? { next: { revalidate: opts.revalidate } } : {}),
  };
  let res: Response;
  try {
    res = await fetch(env.apiBaseUrl + path, init);
  } catch {
    throw new ApiError('Can’t reach the IELTS AI server. Please try again.', 0, 'network');
  }
  const text = await res.text();
  let data: Record<string, unknown> = {};
  try {
    data = text ? (JSON.parse(text) as Record<string, unknown>) : {};
  } catch {
    data = {};
  }
  if (!res.ok) {
    throw new ApiError(String(data.error ?? `Something went wrong (${res.status}).`), res.status, String(data.code ?? ''), data);
  }
  return data as T;
}
