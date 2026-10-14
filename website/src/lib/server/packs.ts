// Content packs: the same JSON the app downloads (question banks, guides,
// courses, translations, UI text), so every web screen reads exactly the
// data its app screen reads. See ../../../../server/src/lib/packs.ts.

import { accessToken, ApiError, baseHeaders } from './api';
import { env } from './env';

export interface PackInfo {
  key: string;
  version: string;
  public: boolean;
  bytes: number;
  gzBytes: number;
}

type Json = Record<string, unknown>;

let manifest: { at: number; packs: PackInfo[] } | null = null;
const MANIFEST_TTL = 60_000;
/** Parsed packs by key, for the version they were fetched at. */
const cache = new Map<string, { version: string; data: Json }>();

async function packList(): Promise<PackInfo[]> {
  if (manifest && Date.now() - manifest.at < MANIFEST_TTL) return manifest.packs;
  const res = await fetch(`${env.apiBaseUrl}/v1/content/packs`, { headers: await baseHeaders(), cache: 'no-store' });
  if (!res.ok) throw new ApiError('Content is not available right now.', res.status, 'packs_unavailable');
  const body = (await res.json()) as { packs?: PackInfo[] };
  manifest = { at: Date.now(), packs: body.packs ?? [] };
  return manifest.packs;
}

/**
 * One pack's JSON. Non-public packs need a signed-in visitor (their token is
 * sent); the parsed result is shared by everyone until the version changes.
 */
export async function getPack<T = Json>(key: string): Promise<T> {
  const info = (await packList()).find((p) => p.key === key);
  if (!info) throw new ApiError(`No content pack "${key}".`, 404, 'not_found');
  const hit = cache.get(key);
  if (hit && hit.version === info.version) return hit.data as T;
  const token = info.public ? null : await accessToken();
  const res = await fetch(`${env.apiBaseUrl}/v1/content/packs/${encodeURIComponent(key)}?v=${info.version}`, {
    headers: { ...(await baseHeaders()), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    cache: 'no-store',
  });
  if (!res.ok) {
    let code = '';
    try {
      code = String(((await res.json()) as Json).code ?? '');
    } catch {}
    throw new ApiError('This content needs you to be signed in.', res.status, code || 'pack_failed');
  }
  const data = (await res.json()) as Json;
  cache.set(key, { version: info.version, data });
  return data as T;
}

/** The UI text pack (public): the same copy the app shows. */
export function uiPack() {
  return getPack<Json>('ui');
}
