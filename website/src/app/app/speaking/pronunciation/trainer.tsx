'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Card, HeroCard, Icon } from '@/components/ui';
import { blobToBase64, speak, useRecorder } from '@/components/use-recorder';
import { UpgradeDialog } from '@/components/upgrade-dialog';
import d from '@/components/dialog.module.css';
import type { PronSet } from '@/lib/server/pronunciation';
import t from './trainer.module.css';
import { Portal } from '@/components/portal';

const KEY = 'speaking.pronScores';
type Sound = { phoneme: string; score: number | null };
type Result = { tip: string; heard: string; phonemes: Sound[] };

const newId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

/** Peak level per slice of a recording (bar heights 4–36), or null when it can't be decoded. */
async function waveOf(blob: Blob, bars: number): Promise<number[] | null> {
  try {
    const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    const ctx = new AC();
    const buf = await ctx.decodeAudioData(await blob.arrayBuffer());
    void ctx.close();
    const data = buf.getChannelData(0);
    const per = Math.floor(data.length / bars);
    if (!per) return null;
    const peaks: number[] = [];
    for (let b = 0; b < bars; b++) {
      let peak = 0;
      for (let i = b * per; i < (b + 1) * per; i += 4) peak = Math.max(peak, Math.abs(data[i]));
      peaks.push(peak);
    }
    const top = Math.max(...peaks);
    return top <= 0 ? peaks.map(() => 2) : peaks.map((p) => 4 + (32 * p) / top);
  } catch {
    return null;
  }
}

function Wave({ heights, color, progress }: { heights: number[]; color: string; progress?: number | null }) {
  return (
    <div className={t.wave} aria-hidden>
      {heights.map((h, i) => (
        <i
          key={i}
          style={{
            height: Math.max(2, Math.min(36, h)),
            background: color,
            opacity: progress != null && i / heights.length > progress ? 0.35 : 1,
          }}
        />
      ))}
    </div>
  );
}

/** Hold to record a word; the speaking service scores each sound (pronunciation_screen.dart). */
export function Trainer({ set, usedUp }: { set: PronSet; usedUp: boolean }) {
  const router = useRouter();
  const rec = useRecorder();
  const words = set.words;
  const bars = set.nativeWave.length || 18;
  const [index, setIndex] = useState(0);
  const [tries, setTries] = useState<Record<string, number[]>>(set.tries);
  const [ai, setAi] = useState<Record<string, Result>>({});
  const [audio, setAudio] = useState<Record<string, string>>({});
  const [waves, setWaves] = useState<Record<string, number[]>>({});
  const [live, setLive] = useState<number[]>([]);
  const [holding, setHolding] = useState(false);
  const [scoring, setScoring] = useState(false);
  const [playing, setPlaying] = useState<'native' | 'you' | null>(null);
  const [progress, setProgress] = useState(0);
  const [sheet, setSheet] = useState<null | 'list' | 'topics'>(null);
  const [upgrade, setUpgrade] = useState(false);
  const [toast, setToast] = useState('');
  const [finishing, setFinishing] = useState(false);
  const startedAt = useRef(Date.now());
  const holdStart = useRef(0);
  const held = useRef(false);
  const player = useRef<HTMLAudioElement | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);

  const w = words[index];

  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(''), 3000);
    return () => clearTimeout(id);
  }, [toast]);

  // Live level bars while recording.
  useEffect(() => {
    if (!rec.recording) return;
    setLive((l) => [...l, 4 + rec.level * 32].slice(-bars));
  }, [rec.level, rec.recording, bars]);

  useEffect(
    () => () => {
      if (timer.current) clearInterval(timer.current);
      player.current?.pause();
      window.speechSynthesis?.cancel();
      Object.values(audio).forEach((u) => URL.revokeObjectURL(u));
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  );

  if (!w) {
    return (
      <div className={t.wrap}>
        <p className={t.hint}>No words to practise right now.</p>
        <Link href="/app/speaking">Back to Speaking</Link>
      </div>
    );
  }

  const stopPlay = () => {
    if (timer.current) clearInterval(timer.current);
    player.current?.pause();
    window.speechSynthesis?.cancel();
    setPlaying(null);
    setProgress(0);
  };

  const play = (which: 'native' | 'you') => {
    if (playing === which) return stopPlay();
    stopPlay();
    setPlaying(which);
    if (which === 'native') {
      speak(w.word);
      // The browser voice has no progress: animate the bars for about a second.
      let p = 0;
      timer.current = setInterval(() => {
        p += 0.04;
        setProgress(Math.min(1, p));
        if (p >= 1) {
          if (timer.current) clearInterval(timer.current);
          setPlaying(null);
          setProgress(0);
        }
      }, 50);
      return;
    }
    const url = audio[w.id];
    if (!url) return setPlaying(null);
    const a = player.current ?? new Audio();
    player.current = a;
    a.src = url;
    a.ontimeupdate = () => setProgress(a.duration ? a.currentTime / a.duration : 0);
    a.onended = () => {
      setPlaying(null);
      setProgress(0);
    };
    void a.play().catch(() => setPlaying(null));
  };

  const startHold = async () => {
    if (scoring || holding) return;
    if (usedUp) return setUpgrade(true);
    stopPlay();
    held.current = true;
    setHolding(true);
    setLive([]);
    const ok = await rec.start();
    holdStart.current = Date.now();
    if (!ok) {
      held.current = false;
      setHolding(false);
      return;
    }
    // Released while the mic was starting.
    if (!held.current) void endHold();
  };

  const endHold = async () => {
    if (!held.current && !holdStart.current) return;
    held.current = false;
    setHolding(false);
    // Released before the mic started: startHold finishes the try.
    if (!holdStart.current) return;
    const ms = Date.now() - holdStart.current;
    holdStart.current = 0;
    const word = w;
    const clip = await rec.stop();
    if (!clip || ms < 250) {
      setToast(clip ? 'Hold the button while you say the word' : 'We couldn’t record that. Try again.');
      return;
    }
    const url = URL.createObjectURL(clip.blob);
    setAudio((a) => {
      if (a[word.id]) URL.revokeObjectURL(a[word.id]);
      return { ...a, [word.id]: url };
    });
    void waveOf(clip.blob, bars).then((wv) => wv && setWaves((x) => ({ ...x, [word.id]: wv })));
    setScoring(true);
    const res = await fetch('/api/v1/pronunciation/score', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ word: word.word, audioBase64: await blobToBase64(clip.blob), format: clip.format }),
    }).catch(() => null);
    const body = (await res?.json().catch(() => ({}))) as { score?: number; tip?: string; heard?: string; phonemes?: Sound[]; error?: string } | undefined;
    setScoring(false);
    if (res?.status === 402) return setUpgrade(true);
    if (!res?.ok || typeof body?.score !== 'number') {
      setToast(body?.error ?? 'We couldn’t score that word. Try again.');
      return;
    }
    const score = Math.min(1, Math.max(0, body.score / 100));
    setAi((x) => ({ ...x, [word.id]: { tip: body.tip ?? '', heard: body.heard ?? '', phonemes: body.phonemes ?? [] } }));
    const nextTries = { ...tries, [word.id]: [...(tries[word.id] ?? []), score] };
    setTries(nextTries);
    setToast('Attempt scored');
    // Keep the score with the account (merged with the app's).
    const cur = await fetch(`/api/v1/state?prefix=${encodeURIComponent(KEY)}`).catch(() => null);
    const all = cur?.ok ? ((((await cur.json()) as { state?: Record<string, unknown> }).state?.[KEY] as Record<string, number[]>) ?? {}) : {};
    void fetch(`/api/v1/state/${encodeURIComponent(KEY)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ value: { ...all, [word.id]: [...(Array.isArray(all[word.id]) ? all[word.id] : []), score] } }),
    }).catch(() => null);
  };

  const goTo = (i: number) => {
    stopPlay();
    setIndex(i);
    setSheet(null);
  };

  const finish = async () => {
    if (finishing) return;
    const list = words.map((x) => ({ word: x.word, score: tries[x.id]?.length ? tries[x.id][tries[x.id].length - 1] : 0 }));
    if (!list.some((x) => x.score > 0)) return setToast('Hold to record at least one word first');
    setFinishing(true);
    const good = list.filter((x) => x.score >= 0.75).length;
    const elapsed = Math.round((Date.now() - startedAt.current) / 1000);
    const res = await fetch('/api/v1/attempts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: newId(),
        skill: 'speaking',
        kind: 'pronunciation',
        title: set.title,
        refId: set.refId,
        score: good,
        total: words.length,
        durationSec: Math.max(60, elapsed),
        createdAt: new Date().toISOString(),
        data: { words: list, ...(set.topic ? { topic: set.topic } : {}) },
      }),
    }).catch(() => null);
    setFinishing(false);
    if (!res?.ok) return setToast('Couldn’t save your set. Check your connection.');
    setToast(`Word set complete · ${good} of ${words.length} clear`);
    setTimeout(() => router.push('/app/speaking'), 900);
  };

  const mine = tries[w.id] ?? [];
  const tried = mine.length > 0;
  const match = tried ? mine[mine.length - 1] : 0;
  const r = ai[w.id];
  const tip = !tried ? 'Hold the button, say the word, then release to compare.' : r?.tip || w.tip;
  const youWave = holding && live.length ? [...live, ...Array(Math.max(0, bars - live.length)).fill(2)] : waves[w.id] ?? Array(bars).fill(2);
  const soundClass = (sc: number | null) => (sc == null ? '' : sc >= 85 ? t.soundGood : sc >= 60 ? t.soundOk : t.soundBad);

  return (
    <div className={t.wrap}>
      <div className={t.head}>
        <Link href="/app/speaking" className={t.box} aria-label="Back to Speaking">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={t.headText}>
          <span className={t.count}>
            Word {index + 1} of {words.length}
          </span>
          {set.daily && (
            <button type="button" className={t.change} onClick={() => setSheet('topics')}>
              {set.topic ?? 'Today’s mix'} · Change
            </button>
          )}
        </div>
        <button type="button" className={t.box} onClick={() => setSheet('list')} aria-label="Word list" title="Word list">
          <Icon name="grid_view" size={22} />
        </button>
      </div>

      <div>
        <h1 className={t.word}>{w.word}</h1>
        <p className={t.ipa}>
          {w.ipa}
          {w.pos ? ` · ${w.pos}` : ''}
        </p>
      </div>

      <div className={t.chips}>
        {w.syllables.map((s, i) => (
          <span key={i} className={`${t.syl} ${s.state === 'stress' ? t.sylStress : ''}`}>
            {s.text}
          </span>
        ))}
      </div>
      {r?.phonemes.length ? (
        <div className={t.chips}>
          {r.phonemes.map((p, i) => (
            <span key={i} className={`${t.sound} ${soundClass(p.score)}`} title={p.score == null ? 'Not scored' : `${Math.round(p.score)}%`}>
              /{p.phoneme}/
            </span>
          ))}
        </div>
      ) : null}
      {r?.heard && <p className={t.heard}>We heard “{r.heard}”</p>}

      <HeroCard padding={16} radius={28}>
        <div className={t.player}>
          <button type="button" className={t.play} onClick={() => play('native')} aria-label="Play native audio" title="Play native audio">
            <Icon name={playing === 'native' ? 'pause' : 'play_arrow'} size={22} />
          </button>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span className={t.label}>Native speaker</span>
            <Wave heights={set.nativeWave} color="#fff" progress={playing === 'native' ? progress : null} />
          </div>
        </div>
      </HeroCard>

      <Card padding={16} radius={28}>
        <div className={t.player}>
          <button
            type="button"
            className={`${t.play} ${t.playMine}`}
            onClick={() => play('you')}
            disabled={!audio[w.id]}
            aria-label="Play your audio"
            title={audio[w.id] ? 'Play your audio' : 'Record first'}
          >
            <Icon name={playing === 'you' ? 'pause' : 'play_arrow'} size={22} />
          </button>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span className={`${t.label} ${t.labelLight}`}>You</span>
            <Wave heights={youWave} color="var(--text)" progress={playing === 'you' ? progress : null} />
          </div>
        </div>
      </Card>

      <Card padding="16px 18px" radius={28}>
        <div className={t.match}>
          <div className={t.ring} style={{ ['--v' as string]: `${match * 100}%` }}>
            {scoring ? '…' : tried ? `${Math.round(match * 100)}%` : '–'}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 16 }}>Sound match</div>
            <p className={t.tip} role="status">
              {tip}
            </p>
          </div>
        </div>
      </Card>

      {rec.error && <p className={t.hint} style={{ color: 'var(--danger)' }}>{rec.error}</p>}

      <div className={t.actions}>
        <button
          type="button"
          className={`${t.hold} ${holding ? t.holding : ''}`}
          disabled={scoring || !rec.supported}
          onPointerDown={(e) => {
            e.currentTarget.setPointerCapture?.(e.pointerId);
            void startHold();
          }}
          onPointerUp={() => void endHold()}
          onPointerCancel={() => void endHold()}
          onKeyDown={(e) => {
            if ((e.key === ' ' || e.key === 'Enter') && !e.repeat) {
              e.preventDefault();
              void startHold();
            }
          }}
          onKeyUp={(e) => {
            if (e.key === ' ' || e.key === 'Enter') void endHold();
          }}
          onContextMenu={(e) => e.preventDefault()}
        >
          <Icon name="mic" size={20} />
          {scoring ? 'Scoring…' : holding ? 'Recording… release to stop' : 'Hold to record'}
        </button>
        <button
          type="button"
          className={t.next}
          onClick={() => (index >= words.length - 1 ? void finish() : goTo(index + 1))}
          aria-label={index >= words.length - 1 ? 'Finish the set' : 'Next word'}
          title={index >= words.length - 1 ? 'Finish the set' : 'Next word'}
        >
          <Icon name={index >= words.length - 1 ? 'check' : 'arrow_forward'} size={22} />
        </button>
      </div>
      <p className={t.hint}>Tip: hold the space bar to record with the keyboard.</p>

      {sheet === 'list' && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label="Word list" onClick={() => setSheet(null)}>
          <div className={d.sheet} onClick={(e) => e.stopPropagation()}>
            <h2 className={d.title}>Word list</h2>
            <div className={t.scroll}>
              {words.map((x, i) => {
                const tr = tries[x.id] ?? [];
                return (
                  <button key={x.id} type="button" className={t.listRow} onClick={() => goTo(i)}>
                    <span className={t.listNum}>{i + 1}</span>
                    <span style={{ flex: 1 }}>
                      <b style={{ display: 'block', fontWeight: 500 }}>{x.word}</b>
                      <span style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{x.ipa}</span>
                    </span>
                    {tr.length ? (
                      <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{Math.round(tr[tr.length - 1] * 100)}%</span>
                    ) : i === index ? (
                      <Icon name="check_circle" size={20} color="var(--icon-accent)" filled />
                    ) : null}
                  </button>
                );
              })}
            </div>
          </div>
        </div></Portal>
      )}
      {sheet === 'topics' && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label="Choose words" onClick={() => setSheet(null)}>
          <div className={d.sheet} onClick={(e) => e.stopPropagation()}>
            <h2 className={d.title}>Choose words</h2>
            <p className={d.body}>10 words from the speaking word bank. A new set every day.</p>
            <div className={t.scroll}>
              {[{ label: null as string | null, count: 0 }, ...set.topics].map((x) => (
                <Link
                  key={x.label ?? 'mix'}
                  href={x.label ? `/app/speaking/pronunciation?topic=${encodeURIComponent(x.label)}` : '/app/speaking/pronunciation'}
                  className={t.listRow}
                  onClick={() => setSheet(null)}
                >
                  <span style={{ flex: 1 }}>
                    <b style={{ display: 'block', fontWeight: 500 }}>{x.label ?? 'Today’s mix'}</b>
                    <span style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>{x.label ? `${x.count} words in the bank` : 'All topics'}</span>
                  </span>
                  {x.label === set.topic && <Icon name="check_circle" size={20} color="var(--icon-accent)" filled />}
                </Link>
              ))}
            </div>
          </div>
        </div></Portal>
      )}
      {upgrade && <UpgradeDialog feature="pronunciation" onClose={() => setUpgrade(false)} />}
      {toast && (
        <div className={t.toast} role="status">
          {toast}
        </div>
      )}
    </div>
  );
}
