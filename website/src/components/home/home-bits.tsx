'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Icon } from '@/components/ui';
import { speak } from '@/components/use-recorder';
import { patchMe } from './edit-profile';
import h from './home.module.css';

const SAVED = 'resources.savedWords';

/** Word of the day: listen + save to the vault (kv resources.savedWords). */
export function WordActions({ id, word, saved: initial }: { id: string; word: string; saved: boolean }) {
  const [saved, setSaved] = useState(initial);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const toggle = async () => {
    setBusy(true);
    // Read-merge-write: the app may have changed the list.
    const res = await fetch(`/api/v1/state?prefix=${encodeURIComponent(SAVED)}`).catch(() => null);
    const cur = res?.ok ? ((((await res.json()) as { state?: Record<string, unknown> }).state?.[SAVED] as unknown[]) ?? []).map(String) : null;
    if (cur) {
      const next = saved ? cur.filter((x) => x !== id) : [...new Set([...cur, id])];
      const put = await fetch(`/api/v1/state/${encodeURIComponent(SAVED)}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ value: next }),
      }).catch(() => null);
      if (put?.ok) {
        setMsg(saved ? 'Removed from your vault' : 'Saved to your vault');
        setSaved(!saved);
      }
    }
    setBusy(false);
  };
  return (
    <>
      <button type="button" className={h.squareBtn} onClick={() => speak(word)} aria-label={`Listen to “${word}”`} title="Listen">
        <Icon name="volume_up" size={18} />
      </button>
      <button type="button" className={h.squareBtn} onClick={toggle} disabled={busy} aria-pressed={saved} aria-label={saved ? 'Remove from your vault' : 'Save word'} title={saved ? 'Saved' : 'Save word'}>
        <Icon name="bookmark" size={18} filled={saved} />
      </button>
      <span className="visually-hidden" role="status">
        {msg}
      </span>
    </>
  );
}

/** Getting started › "Allow microphone access" (A8 on the web): asks the browser, then marks profile.micAllowed. */
export function MicStep({ title, current }: { title: string; current: boolean }) {
  const router = useRouter();
  const [error, setError] = useState('');
  return (
    <>
      <button
        type="button"
        className={`${h.step} ${current ? h.stepCurrent : ''}`}
        onClick={async () => {
          setError('');
          try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            stream.getTracks().forEach((t) => t.stop());
          } catch {
            setError('Microphone blocked. Allow it for this site in your browser settings.');
            return;
          }
          const err = await patchMe({ profile: { micAllowed: true } });
          if (err) setError(err);
          else router.refresh();
        }}
      >
        <span className={h.stepBox} />
        <span className={h.stepTitle}>{title}</span>
        {current && <Icon name="chevron_right" size={20} color="var(--icon-accent)" />}
      </button>
      {error && <p className={h.error}>{error}</p>}
    </>
  );
}
