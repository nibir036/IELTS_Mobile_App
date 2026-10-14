'use client';

import { useState } from 'react';
import { Icon } from './ui';

const KEY = 'resources.savedWords';

/** Bookmark a word into the Vocab Vault (the app's kv `resources.savedWords`). */
export function SaveWord({ id, saved: initial }: { id: string; saved: boolean }) {
  const [saved, setSaved] = useState(initial);
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      aria-pressed={saved}
      aria-label={saved ? 'Remove from saved words' : 'Save word'}
      title={saved ? 'Saved' : 'Save'}
      disabled={busy}
      onClick={async (e) => {
        e.preventDefault();
        setBusy(true);
        // Read the latest list first: the app may have changed it.
        const res = await fetch(`/api/v1/state?prefix=${encodeURIComponent(KEY)}`).catch(() => null);
        const cur = res && res.ok ? (((await res.json()) as { state?: Record<string, unknown> }).state?.[KEY] as string[] | undefined) ?? [] : [];
        const next = saved ? cur.filter((x) => x !== id) : [...new Set([...cur, id])];
        const put = await fetch(`/api/v1/state/${encodeURIComponent(KEY)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ value: next }),
        }).catch(() => null);
        if (put?.ok) setSaved(!saved);
        setBusy(false);
      }}
      style={{
        border: 0,
        background: saved ? 'var(--accent-soft)' : 'transparent',
        color: saved ? 'var(--text)' : 'var(--text-muted)',
        width: 36,
        height: 36,
        borderRadius: 10,
        cursor: 'pointer',
        flex: 'none',
      }}
    >
      <Icon name="bookmark" size={20} filled={saved} />
    </button>
  );
}
