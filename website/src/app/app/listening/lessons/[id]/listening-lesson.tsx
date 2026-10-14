'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { bold } from '@/components/rich-text';
import { Icon, Nexi } from '@/components/ui';
import { tickPlanTasks } from '@/lib/client/plan';
import { LessonMenu, Toast, useToast } from '@/lib/lessons/lesson-menu';
import { newAttemptId, postAttempt, putState, type MenuEntry } from '@/lib/lessons/menu';
import s from '@/lib/lessons/lessons.module.css';
import { matches } from '@/lib/practice/marking';

const BASE = '/app/listening/lessons';

export interface GapRow {
  number: number;
  before: string;
  after: string;
  answer: string;
  accepted: string[];
}

export interface ListeningLessonView {
  id: string;
  title: string;
  body: string;
  audioUrl: string;
  duration: number;
  instruction: string;
  rows: GapRow[];
  number: number;
  count: number;
  next: { id: string; number: number } | null;
}

/** "0:52" (timeLabel, pad: false). */
const time = (sec: number) => {
  const t = Math.max(0, Math.floor(sec || 0));
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`;
};
const speedLabel = (v: number) => (v === 1 ? '1.0x' : `${v}x`);
const nextSpeed = (v: number) => (v < 1 ? 1 : v < 1.25 ? 1.25 : 0.75);

/** Bar heights for the waveform (WaveformBars, seed 3). */
const BARS = Array.from({ length: 36 }, (_, i) => 0.3 + 0.7 * Math.abs(Math.sin((i + 3) * 1.7) * Math.cos((i + 3) * 0.6)));

/** F6 · Listening Bite-size Lesson (listening_lesson_screen.dart): lesson note, audio clip, gap-fill. */
export function ListeningLesson({
  lesson,
  menu,
  currentDone,
  saved,
  note,
}: {
  lesson: ListeningLessonView;
  menu: MenuEntry[];
  currentDone: boolean;
  saved: { answers: Record<string, string>; current: number } | null;
  note: string;
}) {
  const router = useRouter();
  const rows = lesson.rows;
  const key = `listening.lesson.${lesson.id}`;
  const first = rows[0]?.number ?? 0;
  const [answers, setAnswers] = useState<Record<number, string>>(() => {
    const out: Record<number, string> = {};
    for (const [k, v] of Object.entries(saved?.answers ?? {})) if (Number.isFinite(Number(k))) out[Number(k)] = v;
    return out;
  });
  const [current, setCurrent] = useState(saved && rows.some((r) => r.number === saved.current) ? saved.current : first);
  const [checked, setChecked] = useState(false);
  const [correct, setCorrect] = useState(0);
  const [result, setResult] = useState<{ correct: number; total: number } | null>(null);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useToast();
  const openedAt = useRef(Date.now());
  const finished = useRef(false);
  const inputs = useRef<Record<number, HTMLInputElement | null>>({});
  const live = useRef({ answers, current, checked });
  live.current = { answers, current, checked };

  // Audio
  const audio = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [loading, setLoading] = useState(false);
  const [pos, setPos] = useState(0);
  const [dur, setDur] = useState(lesson.duration);
  const [speed, setSpeed] = useState(1);

  useEffect(() => {
    if (note === 'marked') setToast(`Marked as done · on to Lesson ${lesson.number}`);
    // The app starts the clip on open; browsers may need a tap first.
    audio.current?.play().catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (audio.current) audio.current.playbackRate = speed;
  }, [speed]);

  /** Unfinished answers → kv listening.lesson.<id> (null when none). */
  const persist = () => {
    const { answers: a, current: c, checked: done } = live.current;
    if (finished.current || done) return;
    const given: Record<string, string> = {};
    for (const [n, v] of Object.entries(a)) if (v.trim()) given[n] = v.trim();
    void putState(key, Object.keys(given).length ? { answers: given, current: c } : null);
  };

  // Save shortly after typing, and when leaving the page.
  const dirty = useRef(false);
  useEffect(() => {
    if (!dirty.current) return;
    const t = setTimeout(persist, 800);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [answers]);
  useEffect(() => {
    const onHide = () => {
      if (dirty.current) persist();
    };
    window.addEventListener('pagehide', onHide);
    return () => {
      window.removeEventListener('pagehide', onHide);
      onHide();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isCorrect = (r: GapRow) => matches(answers[r.number] ?? '', r.accepted.length ? r.accepted : r.answer);
  const score = () => rows.filter(isCorrect).length;

  const toggle = () => {
    const a = audio.current;
    if (!a) return;
    if (a.paused) {
      setLoading(a.readyState < 2);
      a.play().catch(() => setLoading(false));
    } else a.pause();
  };

  const replay = () => {
    const a = audio.current;
    if (!a) return;
    a.currentTime = 0;
    a.play().catch(() => {});
  };

  const advance = (n: number) => {
    const nums = rows.map((r) => r.number);
    const i = nums.indexOf(n);
    const next = i >= 0 && i < nums.length - 1 ? nums[i + 1] : 0;
    setCurrent(next);
    if (next) inputs.current[next]?.focus();
    else inputs.current[n]?.blur();
  };

  const check = () => {
    const k = score();
    setCorrect(k);
    setChecked(true);
    setCurrent(0);
    setToast(`${k} / ${rows.length} correct`);
  };

  const finish = async (marked = false) => {
    if (busy) return;
    setBusy(true);
    finished.current = true;
    const k = marked ? score() : correct;
    const secs = Math.round((Date.now() - openedAt.current) / 1000);
    const ok = await postAttempt({
      id: newAttemptId(),
      skill: 'listening',
      kind: 'lesson',
      title: `Lesson ${lesson.number} · ${lesson.title}`,
      refId: lesson.id,
      band: null,
      score: k,
      total: rows.length,
      durationSec: secs < 60 ? 60 : secs,
      createdAt: new Date().toISOString(),
      data: {
        lessonId: lesson.id,
        answers: Object.fromEntries(Object.entries(answers).map(([n, v]) => [n, v])),
        ...(marked ? { markedDone: true } : {}),
      },
    });
    if (!ok) {
      finished.current = false;
      setBusy(false);
      setToast('Couldn’t save the lesson. Check your connection and try again.');
      return;
    }
    await putState(key, null);
    void tickPlanTasks(lesson.id);
    audio.current?.pause();
    if (marked) {
      if (lesson.next) router.push(`${BASE}/${lesson.next.id}?note=marked`);
      else router.push(`${BASE}?note=last`);
      return;
    }
    setBusy(false);
    setResult({ correct: k, total: rows.length });
    router.refresh();
  };

  const restart = () => {
    void putState(key, null);
    dirty.current = false;
    finished.current = false;
    openedAt.current = Date.now();
    setAnswers({});
    setChecked(false);
    setCorrect(0);
    setResult(null);
    setCurrent(first);
    replay();
    setToast('Lesson restarted');
  };

  const header = (
    <div className={s.head}>
      <Link href={BASE} className={s.iconBtn} aria-label="Back to lessons">
        <Icon name="arrow_back" size={20} />
      </Link>
      <div className={s.headText}>
        <span className={s.overline}>
          Bite-size · Lesson {lesson.number} of {lesson.count}
        </span>
        <h1 className={s.h1}>{lesson.title}</h1>
      </div>
      <LessonMenu entries={menu} base={BASE} currentDone={currentDone || Boolean(result)} onRestart={restart} onMarkDone={() => void finish(true)} onLocked={setToast} />
    </div>
  );

  const progress = dur > 0 ? Math.min(1, pos / dur) : 0;

  return (
    <>
      {header}
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      <audio
        ref={audio}
        src={lesson.audioUrl || undefined}
        preload="auto"
        onPlay={() => setPlaying(true)}
        onPlaying={() => setLoading(false)}
        onPause={() => setPlaying(false)}
        onEnded={() => setPlaying(false)}
        onWaiting={() => setLoading(true)}
        onTimeUpdate={(e) => setPos(e.currentTarget.currentTime)}
        onLoadedMetadata={(e) => {
          if (Number.isFinite(e.currentTarget.duration)) setDur(e.currentTarget.duration);
          e.currentTarget.playbackRate = speed;
        }}
      />
      {result ? (
        <div className={`${s.card} ${s.complete}`}>
          <Nexi pose="listening" height={130} />
          <h2 className={s.completeTitle}>Lesson complete</h2>
          <p className={s.completeSub}>
            {result.correct} of {result.total} correct
          </p>
          <div className={s.actionsRow}>
            <button type="button" className={s.softBtn} onClick={restart}>
              <Icon name="refresh" size={18} /> Try again
            </button>
            {lesson.next ? (
              <Link href={`${BASE}/${lesson.next.id}`} className={s.primaryBtn}>
                Lesson {lesson.next.number} <Icon name="arrow_forward" size={18} />
              </Link>
            ) : (
              <Link href={BASE} className={s.primaryBtn}>
                All lessons
              </Link>
            )}
          </div>
        </div>
      ) : (
        <div className={s.split}>
          <div className={s.stack}>
            <div className={s.card}>
              <span className={s.lessonLabel}>
                <Icon name="school" size={16} /> Lesson
              </span>
              <p className={s.keyIdea}>{bold(lesson.body)}</p>
            </div>
            <div className={s.player}>
              <button type="button" className={s.playBtn} onClick={toggle} aria-label={playing ? 'Pause' : 'Play'} disabled={!lesson.audioUrl}>
                <Icon name={loading && playing ? 'progress_activity' : playing ? 'pause' : 'play_arrow'} size={26} filled />
              </button>
              <div className={s.playerMid}>
                <div
                  className={s.wave}
                  role="slider"
                  tabIndex={0}
                  aria-label="Seek"
                  aria-valuemin={0}
                  aria-valuemax={Math.round(dur)}
                  aria-valuenow={Math.round(pos)}
                  aria-valuetext={`${time(pos)} of ${time(dur)}`}
                  onClick={(e) => {
                    const a = audio.current;
                    if (!a || !dur) return;
                    const r = e.currentTarget.getBoundingClientRect();
                    a.currentTime = Math.max(0, Math.min(dur, ((e.clientX - r.left) / r.width) * dur));
                  }}
                  onKeyDown={(e) => {
                    const a = audio.current;
                    if (!a) return;
                    if (e.key === 'ArrowRight') a.currentTime = Math.min(dur, a.currentTime + 5);
                    else if (e.key === 'ArrowLeft') a.currentTime = Math.max(0, a.currentTime - 5);
                    else return;
                    e.preventDefault();
                  }}
                >
                  {BARS.map((h, i) => (
                    <span key={i} className={(i + 0.5) / BARS.length <= progress ? s.barOn : ''} style={{ height: `${Math.round(h * 100)}%` }} />
                  ))}
                </div>
                <div className={s.times}>
                  <b>{time(pos)}</b>
                  <span>{time(dur)}</span>
                </div>
              </div>
              <button type="button" className={s.speed} onClick={() => setSpeed(nextSpeed(speed))} aria-label={`Playback speed ${speedLabel(speed)}`}>
                {speedLabel(speed)}
              </button>
            </div>
          </div>

          <section className={s.card} aria-label="Exercise">
            <p className={s.muted} style={{ margin: 0 }}>
              {lesson.instruction}
            </p>
            <div className={s.gapList}>
              {rows.map((r) => {
                const value = answers[r.number] ?? '';
                const ok = checked && isCorrect(r);
                const state = checked ? (ok ? s.gapOk : s.gapBad) : current === r.number ? s.gapActive : value.trim() ? s.gapFilled : '';
                return (
                  <div key={r.number} className={s.gapLine}>
                    {r.before && <span>{r.before}</span>}
                    <span className={`${s.gapBox} ${state}`}>
                      <span className={s.gapNum}>{r.number}</span>
                      {checked ? (
                        <span className={s.gapValue}>
                          {value.trim() || '-'}
                          {ok ? <Icon name="check" size={16} /> : <Icon name="close" size={16} />}
                        </span>
                      ) : (
                        <input
                          ref={(el) => {
                            inputs.current[r.number] = el;
                          }}
                          className={s.gapInput}
                          value={value}
                          aria-label={`Answer ${r.number}`}
                          autoComplete="off"
                          autoCapitalize="off"
                          spellCheck={false}
                          onFocus={() => setCurrent(r.number)}
                          onChange={(e) => {
                            dirty.current = true;
                            const v = e.target.value;
                            setAnswers((a) => ({ ...a, [r.number]: v }));
                          }}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              e.preventDefault();
                              advance(r.number);
                            }
                          }}
                        />
                      )}
                    </span>
                    {r.after && <span>{r.after}</span>}
                    {checked && !ok && <span className={s.correction}>{r.answer}</span>}
                  </div>
                );
              })}
            </div>
            <div className={s.actionsRow}>
              <button type="button" className={s.softBtn} onClick={replay} disabled={!lesson.audioUrl}>
                <Icon name="replay" size={18} /> Replay
              </button>
              <button type="button" className={s.primaryBtn} style={{ flex: 2 }} disabled={busy} onClick={() => (checked ? void finish() : check())}>
                {busy ? 'Saving…' : checked ? 'Finish lesson' : 'Check answers'}
              </button>
            </div>
          </section>
        </div>
      )}
      <Toast msg={toast} />
    </>
  );
}
