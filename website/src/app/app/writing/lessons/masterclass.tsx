'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { Icon } from '@/components/ui';
import d from '@/components/dialog.module.css';
import s from './masterclass.module.css';
import { Portal } from '@/components/portal';

export interface McLesson {
  id: string;
  label: string;
  minutes: number;
  title: string;
  lessonLabel: string;
  formula: string[];
  keyPoints: string[];
}

const DONE = 'writing.lessons.done';
const POS = 'writing.lessons.pos';
const mmss = (n: number) => `${Math.floor(n / 60)}:${String(n % 60).padStart(2, '0')}`;

async function putState(key: string, value: unknown) {
  await fetch(`/api/v1/state/${encodeURIComponent(key)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ value }),
    keepalive: true,
  }).catch(() => null);
}

/** Lesson player: the formula builds up step by step while the lesson plays; finished lessons unlock the next. */
export function Masterclass({ lessons, initialDone, initialPos }: { lessons: McLesson[]; initialDone: string[]; initialPos: Record<string, number> }) {
  const [done, setDone] = useState(new Set(initialDone));
  const pos = useRef<Record<string, number>>({ ...initialPos });
  const firstOpen = () => {
    const i = lessons.findIndex((l) => !initialDone.includes(l.id));
    return i < 0 ? Math.max(0, lessons.length - 1) : i;
  };
  const [index, setIndex] = useState(firstOpen);
  const lesson = lessons[index];
  const duration = Math.max(1, (lesson?.minutes ?? 1) * 60);
  const [elapsed, setElapsed] = useState(() => {
    const v = lesson ? Number(initialPos[lesson.id]) || 0 : 0;
    return v >= duration ? 0 : v;
  });
  const [playing, setPlaying] = useState(false);
  const [menu, setMenu] = useState(false);
  const [toast, setToast] = useState('');

  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(''), 2400);
    return () => clearTimeout(id);
  }, [toast]);

  const savePos = (id: string, secs: number) => {
    pos.current = { ...pos.current, [id]: secs };
    void putState(POS, pos.current);
  };

  // The lesson clock.
  useEffect(() => {
    if (!playing || !lesson) return;
    const t = setInterval(() => setElapsed((e) => Math.min(duration, e + 1)), 1000);
    return () => clearInterval(t);
  }, [playing, lesson, duration]);

  // Played to the end: the lesson is done.
  useEffect(() => {
    if (!playing || !lesson || elapsed < duration) return;
    setPlaying(false);
    if (!done.has(lesson.id)) {
      const next = new Set(done);
      next.add(lesson.id);
      setDone(next);
      void putState(DONE, [...next]);
      setToast('Lesson complete');
    }
    savePos(lesson.id, duration);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [elapsed, duration, playing]);

  // Keep the place when leaving the page.
  useEffect(() => {
    const save = () => lesson && savePos(lesson.id, elapsed);
    window.addEventListener('pagehide', save);
    return () => window.removeEventListener('pagehide', save);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lesson?.id, elapsed]);

  if (!lesson) {
    return (
      <div className={s.wrap}>
        <Link href="/app/writing" className={s.box} aria-label="Back to Writing">
          <Icon name="arrow_back" size={20} />
        </Link>
        <p className={s.muted}>No lessons available yet.</p>
      </div>
    );
  }

  const status = (i: number) => (i === index ? 'current' : done.has(lessons[i].id) ? 'done' : i === 0 || done.has(lessons[i - 1].id) ? 'open' : 'locked');

  const toggle = () => {
    if (playing) {
      setPlaying(false);
      savePos(lesson.id, elapsed);
    } else {
      if (elapsed >= duration) setElapsed(0);
      setPlaying(true);
    }
  };

  const open = (i: number) => {
    if (i === index) return toggle();
    if (status(i) === 'locked') return setToast('Finish the previous lesson first');
    if (playing) savePos(lesson.id, elapsed);
    const l = lessons[i];
    const dur = Math.max(1, l.minutes * 60);
    const v = Number(pos.current[l.id]) || 0;
    setIndex(i);
    setElapsed(v >= dur ? 0 : v);
    setPlaying(true);
    setMenu(false);
  };

  const progress = elapsed / duration;
  const active = lesson.formula.length ? Math.min(lesson.formula.length - 1, Math.floor(progress * lesson.formula.length)) : 0;
  const learned = lessons.filter((l) => done.has(l.id)).length;

  return (
    <div className={s.wrap}>
      <div className={s.head}>
        <Link href="/app/writing" className={s.box} aria-label="Back to Writing">
          <Icon name="arrow_back" size={20} />
        </Link>
        <button type="button" className={s.box} onClick={() => setMenu(true)} aria-label="Lesson menu" title="Lesson menu">
          <Icon name="grid_view" size={22} />
        </button>
      </div>
      <h1 className={s.title}>{lesson.title}</h1>

      <section className={s.player} aria-label="Lesson player">
        <div className={s.playerTop}>
          <span className={s.muted}>{lesson.lessonLabel}</span>
          <button type="button" className={s.play} onClick={toggle} aria-label={playing ? 'Pause' : 'Play'}>
            <Icon name={playing ? 'pause' : 'play_arrow'} size={24} />
          </button>
        </div>
        <div className={s.formula}>
          {lesson.formula.map((f, i) => (
            <span key={f} style={{ display: 'contents' }}>
              {i > 0 && <Icon name="arrow_forward" size={16} color="var(--text-muted)" />}
              <span className={`${s.step} ${i === active ? s.stepOn : i < active ? s.stepPast : ''}`}>{f}</span>
            </span>
          ))}
        </div>
        <div className={s.times}>
          <span>{mmss(elapsed)}</span>
          <span>{mmss(duration)}</span>
        </div>
        <div className={s.bar}>
          <span style={{ width: `${progress * 100}%` }} />
        </div>
      </section>

      <div className={s.pills}>
        {lessons.map((l, i) => {
          const st = status(i);
          return (
            <button key={l.id} type="button" className={`${s.pill} ${s[st]}`} onClick={() => open(i)} aria-label={`${l.title} (${st})`}>
              {st === 'current' ? (
                <>
                  <b className={s.pillTitle}>{l.label || l.title}</b>
                  <small>
                    {mmss(elapsed)}/{mmss(duration)}
                  </small>
                </>
              ) : (
                <>
                  <span className={s.pillMin}>
                    {l.minutes}
                    <small> min</small>
                  </span>
                  <small>{l.label}</small>
                  {st === 'done' && (
                    <span className={s.tick}>
                      <Icon name="check" size={13} />
                    </span>
                  )}
                  {st === 'locked' && <Icon name="lock" size={14} className={s.lock} />}
                </>
              )}
            </button>
          );
        })}
      </div>

      <section className={s.points}>
        <span className={s.muted}>Key points</span>
        {lesson.keyPoints.map((p, i) => (
          <div key={p} className={s.point}>
            <b>{String(i + 1).padStart(2, '0')}</b>
            <span>{p}</span>
          </div>
        ))}
      </section>

      <div className={s.dock}>
        <span className={s.count}>
          {learned}
          <small>/{lessons.length}</small>
        </span>
        <span className={s.muted} style={{ flex: 1 }}>
          lessons learned
        </span>
        <Link href="/app/writing/sentence-builder" className={s.exercise}>
          Try exercise <Icon name="arrow_forward" size={18} />
        </Link>
      </div>

      {menu && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label="Masterclass lessons" onClick={() => setMenu(false)}>
          <div className={d.sheet} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', alignItems: 'baseline', marginBottom: 6 }}>
              <h2 className={d.title} style={{ flex: 1 }}>
                Masterclass lessons
              </h2>
              <span className={s.muted}>
                {learned} of {lessons.length} done
              </span>
            </div>
            <div className={s.menu}>
              {lessons.map((l, i) => {
                const st = status(i);
                return (
                  <button key={l.id} type="button" className={s.menuRow} onClick={() => (st === 'locked' ? setToast('Finish the previous lesson first') : open(i))}>
                    <span className={`${s.menuIcon} ${st === 'current' ? s.menuIconOn : ''}`}>
                      <Icon name={st === 'done' ? 'check' : st === 'current' ? 'play_arrow' : st === 'locked' ? 'lock' : 'play_circle'} size={18} />
                    </span>
                    <span style={{ flex: 1, minWidth: 0 }}>
                      <b style={{ color: st === 'locked' ? 'var(--text-muted)' : undefined }}>
                        {i + 1}. {l.title}
                      </b>
                      <small>{[l.label, `${l.minutes} min`].filter(Boolean).join(' · ')}</small>
                    </span>
                    <span className={`${s.tag} ${s['tag_' + st]}`}>{st === 'done' ? 'Done' : st === 'current' ? 'Current' : st === 'locked' ? 'Locked' : 'Up next'}</span>
                  </button>
                );
              })}
            </div>
          </div>
        </div></Portal>
      )}
      {toast && (
        <div className={s.toast} role="status">
          {toast}
        </div>
      )}
    </div>
  );
}
