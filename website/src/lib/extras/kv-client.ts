// Browser helpers for the app's kv state (Store.kv / kvSet), through the
// same-origin API proxy. Read-merge-write so changes the app made meanwhile
// are kept.

export async function kvGet<T = unknown>(key: string): Promise<T | null> {
  try {
    const res = await fetch(`/api/v1/state?prefix=${encodeURIComponent(key)}`, { cache: 'no-store' });
    if (!res.ok) return null;
    const body = (await res.json()) as { state?: Record<string, unknown> };
    return (body.state?.[key] as T) ?? null;
  } catch {
    return null;
  }
}

export async function kvPut(key: string, value: unknown): Promise<boolean> {
  try {
    const res = await fetch(`/api/v1/state/${encodeURIComponent(key)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ value }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

/** Store.kvSet: a list of strings. */
export async function kvSetRead(key: string): Promise<Set<string>> {
  const v = await kvGet<unknown>(key);
  return new Set(Array.isArray(v) ? v.map((e) => String(e)) : []);
}

/** Store.kvSetToggle (or force [on]). Returns the saved set, or null on failure. */
export async function kvSetToggle(key: string, value: string, on?: boolean): Promise<Set<string> | null> {
  const s = await kvSetRead(key);
  const want = on ?? !s.has(value);
  if (want) s.add(value);
  else s.delete(value);
  return (await kvPut(key, [...s])) ? s : null;
}
