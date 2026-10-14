'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Icon } from '@/components/ui';
import h from './home.module.css';

export interface NoteView {
  id: string;
  title: string;
  body: string;
  time: string;
  read: boolean;
  href: string;
  icon: string;
  tone: 'primary' | 'pink' | 'lavender' | 'neutral';
}

const TONES = { primary: h.tonePrimary, pink: h.tonePink, lavender: h.toneLavender, neutral: h.toneNeutral };

/** One notification: marks it read, then opens what it is about. */
export function NotificationRow({ n }: { n: NoteView }) {
  const router = useRouter();
  const [read, setRead] = useState(n.read);
  return (
    <button
      type="button"
      className={h.nRow}
      disabled={read && !n.href}
      onClick={async () => {
        if (!read) {
          setRead(true);
          await fetch(`/api/v1/notifications/${encodeURIComponent(n.id)}/read`, { method: 'POST' }).catch(() => null);
        }
        if (n.href) router.push(n.href);
        else router.refresh();
      }}
    >
      <span className={`${h.tint} ${TONES[n.tone]}`}>
        <Icon name={n.icon} size={20} />
      </span>
      <span className={h.rowText}>
        <span className={h.nTitle}>{n.title}</span>
        {n.body && <span className={h.nBody}>{n.body}</span>}
      </span>
      <span className={h.nMeta}>
        {n.time}
        {!read && <span className={h.unread} aria-label="Unread" />}
      </span>
    </button>
  );
}

export function MarkAllRead() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      className={h.linkBtn}
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        await fetch('/api/v1/notifications/read-all', { method: 'POST' }).catch(() => null);
        setBusy(false);
        router.refresh();
      }}
    >
      Mark all read
    </button>
  );
}
