'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { ConfirmDialog } from '../upgrade-dialog';
import { Card, Icon } from '../ui';
import x from './extras.module.css';
import r from './speaking.module.css';

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');
const clock = (s: number) => `${Math.floor(Math.max(0, s) / 60)}:${String(Math.floor(Math.max(0, s)) % 60).padStart(2, '0')}`;

export interface RecordingRow {
  id: string;
  part: string;
  group: string;
  title: string;
  meta: string;
  seconds: number;
  clips: Array<{ key: string; sec: number }>;
}

async function linkFor(key: string): Promise<string | null> {
  const res = await fetch(`/api/v1/uploads/${key.split('/').map(encodeURIComponent).join('/')}`).catch(() => null);
  const data = res && res.ok ? ((await res.json().catch(() => null)) as { url?: string } | null) : null;
  return data?.url ?? null;
}

/** D10 · My recordings list: filters, sort, play every answer of a session in order, seek, delete. */
export function RecordingsList({ items: initial, filters, groups }: { items: RecordingRow[]; filters: Array<{ id: string; label: string }>; groups: string[] }) {
  const [items, setItems] = useState(initial);
  const [filter, setFilter] = useState('all');
  const [oldest, setOldest] = useState(false);
  const [active, setActive] = useState(initial[0]?.id ?? '');
  const [playing, setPlaying] = useState(false);
  const [loading, setLoading] = useState(false);
  const [pos, setPos] = useState(0);
  const [confirm, setConfirm] = useState<RecordingRow | null>(null);
  const [msg, setMsg] = useState('');
  const audio = useRef<HTMLAudioElement | null>(null);
  const cur = useRef<{ id: string; index: number; urls: Array<string | null> } | null>(null);
  const itemsRef = useRef(items);
  itemsRef.current = items;

  useEffect(() => {
    const el = new Audio();
    audio.current = el;
    const tick = () => {
      const c = cur.current;
      const row = c && itemsRef.current.find((i) => i.id === c.id);
      if (!c || !row) return;
      const before = row.clips.slice(0, c.index).reduce((s, k) => s + k.sec, 0);
      setPos(before + (el.currentTime || 0));
    };
    const ended = () => {
      const c = cur.current;
      const row = c && itemsRef.current.find((i) => i.id === c.id);
      if (c && row && c.index + 1 < row.clips.length) void playClip(row, c.index + 1, 0);
      else {
        setPlaying(false);
        setPos(0);
        if (c) c.index = 0;
      }
    };
    el.addEventListener('timeupdate', tick);
    el.addEventListener('ended', ended);
    el.addEventListener('pause', () => setPlaying(!el.paused));
    el.addEventListener('play', () => setPlaying(true));
    return () => {
      el.pause();
      el.removeEventListener('timeupdate', tick);
      el.removeEventListener('ended', ended);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function flash(m: string) {
    setMsg(m);
    setTimeout(() => setMsg(''), 2600);
  }

  async function playClip(row: RecordingRow, index: number, offset: number) {
    const el = audio.current;
    if (!el) return;
    let c = cur.current;
    if (!c || c.id !== row.id) {
      c = { id: row.id, index: 0, urls: row.clips.map(() => null) };
      cur.current = c;
    }
    c.index = index;
    if (!c.urls[index]) {
      setLoading(true);
      c.urls[index] = await linkFor(row.clips[index].key);
      setLoading(false);
    }
    const url = c.urls[index];
    if (!url) {
      setPlaying(false);
      flash('This recording is no longer available');
      return;
    }
    if (el.src !== url) el.src = url;
    el.currentTime = offset;
    await el.play().catch(() => setPlaying(false));
  }

  function toggle(row: RecordingRow) {
    const el = audio.current;
    if (!el) return;
    if (!row.clips.length) {
      flash('This answer has no recording saved online');
      return;
    }
    if (active !== row.id || cur.current?.id !== row.id) {
      el.pause();
      setActive(row.id);
      setPos(0);
      void playClip(row, 0, 0);
      return;
    }
    if (el.paused) void (el.src ? el.play().catch(() => undefined) : playClip(row, 0, 0));
    else el.pause();
  }

  function seek(row: RecordingRow, fraction: number) {
    if (!row.clips.length) return;
    const total = row.clips.reduce((s, k) => s + k.sec, 0) || row.seconds;
    let t = fraction * total;
    let i = 0;
    while (i < row.clips.length - 1 && t > row.clips[i].sec) t -= row.clips[i++].sec;
    setActive(row.id);
    void playClip(row, i, Math.max(0, t));
  }

  async function remove(row: RecordingRow) {
    setConfirm(null);
    const res = await fetch(`/api/v1/attempts/${encodeURIComponent(row.id)}`, { method: 'DELETE' }).catch(() => null);
    if (!res?.ok) {
      flash('Couldn’t delete that recording. Please try again.');
      return;
    }
    if (cur.current?.id === row.id) {
      audio.current?.pause();
      cur.current = null;
      setPos(0);
    }
    setItems((l) => l.filter((i) => i.id !== row.id));
    flash('Recording deleted');
  }

  const visible = items.filter((i) => filter === 'all' || i.part === filter);
  const ordered = oldest ? [...visible].reverse() : visible;
  const groupOrder = oldest ? [...groups].reverse() : groups;
  const totalSec = items.reduce((s, i) => s + i.seconds, 0);

  return (
    <>
      <div className={x.top}>
        <Link href="/app/speaking" className={x.iconBtn} aria-label="Back to Speaking">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={x.topText}>
          <h1 className={x.topTitle}>My Recordings</h1>
          <span className={x.topSub}>{items.length ? `${items.length} recording${items.length === 1 ? '' : 's'} · ${Math.round(totalSec / 60)} min` : 'No recordings yet'}</span>
        </div>
        <button
          type="button"
          className={x.iconBtn}
          aria-label={oldest ? 'Sort newest first' : 'Sort oldest first'}
          title={oldest ? 'Oldest first' : 'Newest first'}
          onClick={() => {
            setOldest((o) => !o);
            flash(oldest ? 'Newest first' : 'Oldest first');
          }}
        >
          <Icon name="sort" size={22} />
        </button>
      </div>

      {items.length === 0 ? (
        <Card>
          <div className={x.empty}>
            <Icon name="mic" size={34} color="var(--text-muted)" />
            <h2 className={x.emptyTitle}>No recordings yet</h2>
            <p className={x.emptyText}>Your speaking answers are saved here so you can replay them.</p>
            <Link href="/app/speaking" className={r.darkBtn}>
              Start speaking practice
            </Link>
          </div>
        </Card>
      ) : (
        <div className={x.chips} role="group" aria-label="Filter recordings">
          {filters.map((f) => (
            <button key={f.id} type="button" className={cx(x.chip, filter === f.id && x.chipOn)} aria-pressed={filter === f.id} onClick={() => setFilter(f.id)}>
              {f.label}
            </button>
          ))}
        </div>
      )}

      {items.length > 0 && ordered.length === 0 && <p className={x.muted} style={{ textAlign: 'center', padding: '24px 0' }}>No recordings here yet.</p>}

      {groupOrder.map((g) => {
        const list = ordered.filter((i) => i.group === g);
        if (!list.length) return null;
        return (
          <Card key={g} padding="6px 16px 4px" radius={28}>
            <p className={x.small} style={{ padding: '6px 0' }}>
              {g}
            </p>
            {list.map((row) => {
              const isActive = row.id === active;
              const isCur = cur.current?.id === row.id;
              const total = row.clips.reduce((s, k) => s + k.sec, 0) || row.seconds || 1;
              const progress = isCur ? Math.min(1, pos / total) : 0;
              return (
                <div key={row.id} className={r.recRow}>
                  <button
                    type="button"
                    className={cx(r.play, isActive && r.playOn)}
                    aria-label={isCur && playing ? `Pause ${row.title}` : `Play ${row.title}`}
                    onClick={() => toggle(row)}
                    disabled={!row.clips.length}
                    title={row.clips.length ? undefined : 'No recording saved online'}
                  >
                    <Icon name={isCur && loading ? 'hourglass_empty' : isCur && playing ? 'pause' : 'play_arrow'} size={20} filled />
                  </button>
                  <div className={r.recText}>
                    <Link href={`/app/speaking/result/${encodeURIComponent(row.id)}`} className={r.recTitle}>
                      {row.title}
                    </Link>
                    <span className={r.recMeta}>{row.meta}</span>
                    {isActive && row.clips.length > 0 && (
                      <input
                        type="range"
                        className={r.seek}
                        min={0}
                        max={1000}
                        value={Math.round(progress * 1000)}
                        aria-label={`Position in ${row.title}`}
                        onChange={(e) => seek(row, Number(e.target.value) / 1000)}
                        style={{ ['--p' as string]: `${progress * 100}%` }}
                      />
                    )}
                  </div>
                  <span className={r.recTime}>{isCur && pos > 0 ? clock(pos) : clock(row.seconds)}</span>
                  <button type="button" className={r.del} aria-label={`Delete ${row.title}`} title="Delete recording" onClick={() => setConfirm(row)}>
                    <Icon name="delete" size={18} />
                  </button>
                </div>
              );
            })}
          </Card>
        );
      })}

      {confirm && (
        <ConfirmDialog
          title="Delete this recording?"
          message={`“${confirm.title}” and its band report will be removed from your account on every device.`}
          confirm="Delete"
          cancel="Keep it"
          onConfirm={() => remove(confirm)}
          onCancel={() => setConfirm(null)}
        />
      )}
      {msg && (
        <div className={x.toast} role="status" aria-live="polite">
          {msg}
        </div>
      )}
    </>
  );
}
