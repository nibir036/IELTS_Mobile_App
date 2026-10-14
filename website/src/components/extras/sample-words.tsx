'use client';

import { useEffect, useState } from 'react';
import type { VocabEntry } from '@/lib/extras/speaking-library';
import { kvSetToggle } from '@/lib/extras/kv-client';
import d from '../dialog.module.css';
import { Icon } from '../ui';
import { WordCard } from './word-card';
import r from './speaking.module.css';
import x from './extras.module.css';
import { Portal } from '@/components/portal';

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');
const MARK = /\[\[(.+?)\]\]/g;

function WordDialog({ e, onClose }: { e: VocabEntry; onClose: () => void }) {
  useEffect(() => {
    const onKey = (ev: KeyboardEvent) => ev.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby="word-title" onClick={onClose}>
      <div className={cx(d.sheet, r.sheetScroll)} onClick={(ev) => ev.stopPropagation()}>
        <WordCard e={e} headingId="word-title" />
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 12 }}>
          <button type="button" className={x.chip} onClick={onClose} autoFocus>
            Close
          </button>
        </div>
      </div>
    </div></Portal>
  );
}

/** Sample-answer text; `[[marks]]` are underlined and open the word sheet (MarkedText). */
export function MarkedText({ text, vocab }: { text: string; vocab: Record<string, VocabEntry> }) {
  const [open, setOpen] = useState<VocabEntry | null>(null);
  const parts: Array<string | { word: string }> = [];
  let last = 0;
  for (const m of text.matchAll(MARK)) {
    if ((m.index ?? 0) > last) parts.push(text.slice(last, m.index));
    parts.push({ word: m[1] ?? '' });
    last = (m.index ?? 0) + m[0].length;
  }
  if (last < text.length) parts.push(text.slice(last));
  return (
    <>
      <p className={r.marked}>
        {parts.map((p, i) => {
          if (typeof p === 'string') return <span key={i}>{p}</span>;
          const e = vocab[p.word.toLowerCase()];
          return e ? (
            <button key={i} type="button" className={r.mark} onClick={() => setOpen(e)} aria-haspopup="dialog">
              {p.word}
            </button>
          ) : (
            <span key={i} className={r.markPlain}>
              {p.word}
            </span>
          );
        })}
      </p>
      {open && <WordDialog e={open} onClose={() => setOpen(null)} />}
    </>
  );
}

/** Key vocabulary chips of a sample page. */
export function VocabChips({ keys, vocab }: { keys: string[]; vocab: Record<string, VocabEntry> }) {
  const [open, setOpen] = useState<VocabEntry | null>(null);
  return (
    <>
      <div className={r.vocab}>
        {keys.map((k) => (
          <button key={k} type="button" className={r.vocabChip} onClick={() => vocab[k] && setOpen(vocab[k])} aria-haspopup="dialog">
            {vocab[k]?.headword ?? k}
          </button>
        ))}
      </div>
      {open && <WordDialog e={open} onClose={() => setOpen(null)} />}
    </>
  );
}

/** Bookmark of a topic / cue card (kv speaking.savedCards / savedPart1 / savedPart3, shared with the app's vault). */
export function BookmarkButton({ kvKey, id, initial }: { kvKey: string; id: string; initial: boolean }) {
  const [on, setOn] = useState(initial);
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      className={cx(r.iconBtnBase, on && r.bookmarkOn)}
      aria-pressed={on}
      aria-label={on ? 'Remove bookmark' : 'Bookmark'}
      title={on ? 'Saved' : 'Save'}
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        const next = !on;
        setOn(next);
        const s = await kvSetToggle(kvKey, id, next);
        if (!s) setOn(!next);
        setBusy(false);
      }}
    >
      <Icon name="bookmark" size={20} filled={on} />
    </button>
  );
}
