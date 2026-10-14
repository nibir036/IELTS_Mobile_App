import { api } from './api';

export interface Attempt {
  id: string;
  skill: string;
  kind: string;
  title: string;
  refId: string;
  band: number | null;
  score: number | null;
  total: number | null;
  durationSec: number;
  createdAt: string;
  data: Record<string, unknown>;
}

export async function attempts(q: { skill?: string; kind?: string; refId?: string; limit?: number }): Promise<Attempt[]> {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(q)) if (v !== undefined && v !== '') p.set(k, String(v));
  return (await api<{ items: Attempt[] }>(`/v1/attempts?${p}`)).items;
}

export async function attempt(id: string): Promise<Attempt | null> {
  try {
    return (await api<{ item: Attempt }>(`/v1/attempts/${encodeURIComponent(id)}`)).item;
  } catch {
    return null;
  }
}

/** The app's kv state (drafts, saved words …), shared by app and web. */
export async function stateValue<T = unknown>(key: string): Promise<T | null> {
  try {
    const r = await api<{ state: Record<string, unknown> }>(`/v1/state?prefix=${encodeURIComponent(key)}`);
    return (r.state[key] as T) ?? null;
  } catch {
    return null;
  }
}
