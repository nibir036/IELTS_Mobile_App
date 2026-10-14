'use client';

import { useState } from 'react';
import { SoftButton } from './ui';

/** Plays a stored recording: asks the API for a short-lived link first. */
export function RecordingPlayer({ storageKey, label }: { storageKey: string; label: string }) {
  const [url, setUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  if (url) {
    // eslint-disable-next-line jsx-a11y/media-has-caption
    return <audio src={url} controls autoPlay style={{ width: '100%' }} aria-label={label} />;
  }
  return (
    <SoftButton
      leading="play_arrow"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        const res = await fetch(`/api/v1/uploads/${storageKey.split('/').map(encodeURIComponent).join('/')}`).catch(() => null);
        const data = res && res.ok ? ((await res.json()) as { url?: string }) : null;
        setBusy(false);
        if (data?.url) setUrl(data.url);
        else setFailed(true);
      }}
    >
      {failed ? 'Recording unavailable' : busy ? 'Loading…' : label}
    </SoftButton>
  );
}
