'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useRef, useState } from 'react';
import { LangSwitch } from '@/components/lang-switch';
import { bold } from '@/components/rich-text';
import { Icon, Nexi } from '@/components/ui';
import { tickPlanTasks } from '@/lib/client/plan';
import { LessonMenu, Toast, useToast } from '@/lib/lessons/lesson-menu';
import { newAttemptId, postAttempt, putState, type MenuEntry } from '@/lib/lessons/menu';
import s from '@/lib/lessons/lessons.module.css';

const PROGRESS_KEY = 'reading.lessonProgress';
const BASE = '/app/reading/lessons';

export interface ReadingExercise {
  id: string;
  seconds: number;
  quote: string;
  question: string;
  options: Array<{ key: string; text: string }>;
  answer: string;
}

export interface ReadingLessonView {
  id: string;
  /** English title (attempt titles stay English, like the app). */
  englishTitle: string;
  title: string;
  keyIdeaLabel: string;
  keyIdea: string;
  uses: Array<{ label: string; value: string }>;
  exercises: ReadingExercise[];
  number: number;
  count: number;
  next: { id: string; number: number } | null;
  lang: string;
  langs: string[];
  rtl: boolean;
}

/** "1:05" / "0:45" (shortClock). */
const clock = (sec: number) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;

/** E6 · Reading Lesson & Exercise (reading_lesson_screen.dart). */
export function ReadingLesson({
  lesson,
  menu,
  currentDone,
  resume,
  progressIsMine,
  note,
}: {
  lesson: ReadingLessonView;
  menu: MenuEntry[];
  currentDone: boolean;
  resume: { index: number; correct: number; elapsedSec: number } | null;
  /** The saved progress (kv) belongs to this lesson. */
  progressIsMine: boolean;
  note: string;
}) {
  const router = useRouter();
  const ex = lesson.exercises;
  const [index, setIndex] = useState(resume && resume.index < ex.length ? resume.index : 0);
  const [correct, setCorrect] = useState(resume?.correct ?? 0);
  const [selected, setSelected] = useState<string | null>(null);
  const [checked, setChecked] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(ex[index]?.seconds ?? 0);
  const [result, setResult] = useState<{ correct: number; total: number } | null>(null);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useToast();
  const elapsedBefore = useRef(resume?.elapsedSec ?? 0);
  const openedAt = useRef(Date.now());
  const ownsProgress = useRef(progressIsMine);
  const finished = useRef(false);
  const live = useRef({ index, checked, correct });
  live.current = { index, checked, correct };

  useEffect(() => {
    if (note === 'marked') setToast(`Marked as done · on to Lesson ${lesson.number}`);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const elapsed = () => elapsedBefore.current + Math.round((Date.now() - openedAt.current) / 1000);

  /** Remembers the next exercise to do (kv reading.lessonProgress). */
  const saveProgress = useCallback(
    (next: number, correctSoFar: number) => {
      if (next >= ex.length || finished.current) return;
      ownsProgress.current = true;
      void putState(PROGRESS_KEY, { lessonId: lesson.id, index: next, correct: correctSoFar, elapsedSec: elapsed() });
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [ex.length, lesson.id],
  );

  // Leaving mid-lesson keeps the place (like the app's dispose).
  useEffect(() => {
    const save = () => {
      const { index: i, checked: c, correct: k } = live.current;
      if (!finished.current && (i > 0 || c)) saveProgress(c ? i + 1 : i, k);
    };
    window.addEventListener('pagehide', save);
    return () => {
      window.removeEventListener('pagehide', save);
      save();
    };
  }, [saveProgress]);

  // Per-exercise countdown; time up = checked with no answer.
  useEffect(() => {
    if (checked || result) return;
    if (secondsLeft <= 0) {
      setChecked(true);
      saveProgress(index + 1, correct);
      return;
    }
    const t = setTimeout(() => setSecondsLeft((v) => Math.max(0, v - 1)), 1000);
    return () => clearTimeout(t);
  }, [secondsLeft, index, checked, result, correct, saveProgress]);

  const startExercise = (i: number) => {
    setIndex(i);
    setSelected(null);
    setChecked(false);
    setSecondsLeft(ex[i]?.seconds ?? 0);
  };

  const check = () => {
    if (selected == null || checked) return;
    const ok = selected === ex[index].answer;
    const k = correct + (ok ? 1 : 0);
    setCorrect(k);
    setChecked(true);
    saveProgress(index + 1, k);
  };

  const finish = async (marked = false) => {
    if (busy) return;
    setBusy(true);
    finished.current = true;
    const secs = elapsed();
    const ok = await postAttempt({
      id: newAttemptId(),
      skill: 'reading',
      kind: 'lesson',
      title: `Lesson ${lesson.number} · ${lesson.englishTitle}`,
      refId: lesson.id,
      band: null,
      score: correct,
      total: ex.length,
      durationSec: secs < 60 ? 60 : secs,
      createdAt: new Date().toISOString(),
      data: { lessonId: lesson.id, ...(marked ? { markedDone: true } : {}) },
    });
    if (!ok) {
      finished.current = false;
      setBusy(false);
      setToast('Couldn’t save the lesson. Check your connection and try again.');
      return;
    }
    if (ownsProgress.current) await putState(PROGRESS_KEY, null);
    void tickPlanTasks(lesson.id);
    if (marked) {
      if (lesson.next) router.push(`${BASE}/${lesson.next.id}?note=marked`);
      else router.push(`${BASE}?note=last`);
      return;
    }
    setBusy(false);
    setResult({ correct, total: ex.length });
    router.refresh();
  };

  const restart = () => {
    if (ownsProgress.current) void putState(PROGRESS_KEY, null);
    ownsProgress.current = false;
    elapsedBefore.current = 0;
    openedAt.current = Date.now();
    finished.current = false;
    setCorrect(0);
    setResult(null);
    startExercise(0);
    setToast('Lesson restarted');
  };

  const next = () => {
    if (index < ex.length - 1) startExercise(index + 1);
    else void finish();
  };

  // Keys: A–D pick an option, Enter checks / moves on.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (result || tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || e.metaKey || e.ctrlKey || e.altKey) return;
      if (document.querySelector('[role="dialog"]')) return;
      const cur = ex[index];
      if (!cur) return;
      if (!checked && /^[a-z]$/i.test(e.key)) {
        const o = cur.options.find((x) => x.key.toLowerCase() === e.key.toLowerCase());
        if (o) setSelected(o.key);
      } else if (e.key === 'Enter' && tag !== 'BUTTON' && tag !== 'A') {
        if (!checked) check();
        else next();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const cur = ex[index];
  const isLast = index >= ex.length - 1;
  const dir = lesson.rtl ? 'rtl' : undefined;

  const header = (
    <div className={s.head}>
      <Link href={BASE} className={s.iconBtn} aria-label="Back to lessons">
        <Icon name="arrow_back" size={20} />
      </Link>
      <div className={s.headText}>
        <span className={s.overline}>
          Lesson {lesson.number} of {lesson.count}
        </span>
        <h1 className={s.h1} dir={dir}>
          {lesson.title}
        </h1>
      </div>
      <LessonMenu entries={menu} base={BASE} currentDone={currentDone || Boolean(result)} onRestart={restart} onMarkDone={() => void finish(true)} onLocked={setToast} />
    </div>
  );

  if (result) {
    return (
      <>
        {header}
        <div className={`${s.card} ${s.complete}`}>
          <Nexi pose="grad" height={130} />
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
        <Toast msg={toast} />
      </>
    );
  }

  let label: string;
  let action: (() => void) | null;
  if (!checked) {
    label = 'Check answer';
    action = selected == null ? null : check;
  } else {
    label = isLast ? 'Finish lesson' : 'Next exercise';
    action = next;
  }

  return (
    <>
      {header}
      <div className={s.segments} role="progressbar" aria-label="Exercises" aria-valuemin={1} aria-valuemax={ex.length} aria-valuenow={index + 1}>
        {ex.map((e, i) => (
          <span key={e.id || i} className={i <= index ? s.segOn : ''} />
        ))}
      </div>
      <LangSwitch current={lesson.lang} langs={lesson.langs} />
      <div className={s.split}>
        <div className={`${s.card} ${s.keyCard}`} dir={dir}>
          {lesson.keyIdeaLabel && <span className={s.lavenderPill}>{lesson.keyIdeaLabel}</span>}
          <p className={s.keyIdea}>{bold(lesson.keyIdea)}</p>
          {lesson.uses.length > 0 && (
            <div className={s.uses}>
              {lesson.uses.map((u, i) => (
                <div key={i} className={s.use}>
                  <span>{u.label}</span>
                  <b>{u.value}</b>
                </div>
              ))}
            </div>
          )}
        </div>

        {cur ? (
          <section className={s.card} aria-label={`Exercise ${index + 1} of ${ex.length}`}>
            <div className={s.exHead}>
              <span>
                Exercise · {index + 1} of {ex.length}
              </span>
              <span className={s.timer} aria-label={`${secondsLeft} seconds left`}>
                <Icon name="timer" size={14} /> {clock(secondsLeft)}
              </span>
            </div>
            <blockquote className={s.quote}>{cur.quote}</blockquote>
            <p className={s.question}>{cur.question}</p>
            <div className={s.options} role="radiogroup" aria-label={cur.question}>
              {cur.options.map((o) => {
                const state = !checked ? '' : o.key === cur.answer ? s.optCorrect : o.key === selected ? s.optWrong : '';
                return (
                  <button
                    key={o.key}
                    type="button"
                    role="radio"
                    aria-checked={selected === o.key}
                    disabled={checked}
                    className={`${s.option} ${selected === o.key ? s.optSelected : ''} ${state}`}
                    onClick={() => setSelected(o.key)}
                  >
                    <span className={s.optKey}>{o.key}</span>
                    <span className={s.optText}>{o.text}</span>
                    {checked && o.key === cur.answer && <Icon name="check_circle" size={20} />}
                    {checked && o.key === selected && o.key !== cur.answer && <Icon name="cancel" size={20} />}
                  </button>
                );
              })}
            </div>
            {checked && selected == null && <p className={s.muted}>Time’s up. The correct answer is {cur.answer}.</p>}
            <button type="button" className={`${s.primaryBtn} ${s.block}`} disabled={!action || busy} onClick={() => action?.()}>
              {busy ? 'Saving…' : label}
            </button>
          </section>
        ) : (
          <div className={s.card}>
            <p className={s.muted}>This lesson has no exercises yet.</p>
          </div>
        )}
      </div>
      <Toast msg={toast} />
    </>
  );
}
