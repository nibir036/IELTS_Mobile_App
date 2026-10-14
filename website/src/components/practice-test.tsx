'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { mediaUrl } from '@/lib/media';
import {
  listeningBand,
  listeningItems,
  markListening,
  markReading,
  readingBand,
  readingItems,
  rows,
  str,
  type Item,
  type Raw,
} from '@/lib/practice/marking';
import { ConfirmDialog } from './upgrade-dialog';
import { QuestionGroups, type GroupView } from './question-groups';
import { Card, Icon, PrimaryButton, SoftButton, Tag } from './ui';
import s from './practice.module.css';

export interface PracticeSetup {
  skill: 'listening' | 'reading';
  /** 'mini' (one set / passage) or 'test'. */
  kind: 'mini' | 'test';
  refId: string;
  title: string;
  label: string;
  back: string;
  minutes: number;
  /** Listening sets or reading passages, in order. */
  parts: Raw[];
  extra: Record<string, unknown>;
}

const clock = (sec: number) => `${Math.floor(Math.max(0, sec) / 60)}:${String(Math.max(0, sec) % 60).padStart(2, '0')}`;
const newId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

/** One Listening set / test or Reading passage / test, marked like the app. */
export function PracticeTest({ setup }: { setup: PracticeSetup }) {
  const router = useRouter();
  const listening = setup.skill === 'listening';
  const storeKey = `ia_practice_${setup.refId}`;

  // Parts with their global question offsets.
  const { offsets, items } = useMemo(() => {
    const offs: number[] = [];
    let off = 0;
    for (const p of setup.parts) {
      offs.push(off);
      let n = 0;
      for (const g of rows(p.groups)) {
        for (const q of rows(g.questions)) {
          const pick = Number(g.pick) || 0;
          const nums = q.numbers;
          n += listening ? (pick > 1 ? pick : 1) : Array.isArray(nums) && nums.length > 1 ? nums.length : 1;
        }
      }
      off += n;
    }
    const its: Item[] = listening
      ? setup.parts.flatMap((p, i) => listeningItems(p, offs[i], i))
      : readingItems(setup.parts.map((p, i) => [p, offs[i]] as [Raw, number]));
    return { offsets: offs, items: its };
  }, [setup.parts, listening]);

  const [answers, setAnswers] = useState<Record<number, string>>({});
  const [part, setPart] = useState(0);
  const [left, setLeft] = useState(setup.minutes * 60);
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const started = useRef(Date.now());

  useEffect(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(storeKey) ?? 'null') as { answers?: Record<number, string> } | null;
      if (saved?.answers) setAnswers(saved.answers);
    } catch {}
  }, [storeKey]);
  useEffect(() => {
    try {
      localStorage.setItem(storeKey, JSON.stringify({ answers }));
    } catch {}
  }, [answers, storeKey]);
  useEffect(() => {
    const t = setInterval(() => setLeft((x) => x - 1), 1000);
    return () => clearInterval(t);
  }, []);

  const groups: GroupView[] = setup.parts.flatMap((p, i) =>
    rows(p.groups).map((g) => ({
      part: i,
      offset: offsets[i],
      group: g,
      items: items.filter((it) => it.part === i && it.group === g),
    })),
  );
  const answered = items.filter((it) => (answers[it.number] ?? '').trim()).length;

  async function submit() {
    setConfirm(false);
    setBusy(true);
    setError(null);
    const correct = listening ? markListening(items, answers) : markReading(items, answers);
    const total = items.length;
    const given: Record<string, string> = {};
    for (const [k, v] of Object.entries(answers)) if (v.trim()) given[k] = v.trim();
    const durationSec = Math.max(60, Math.round((Date.now() - started.current) / 1000));
    const id = newId();
    const data: Record<string, unknown> = { ...setup.extra, answers: given, correct, total };
    if (listening) {
      data.parts = setup.parts.map((p, i) => {
        const mine = items.filter((it) => it.part === i).map((it) => it.number);
        return {
          setId: str(p.id),
          part: Number(p.part) || i + 1,
          from: offsets[i] + 1,
          to: offsets[i] + mine.length,
          correct: correct.filter((n) => mine.includes(n)).length,
          total: mine.length,
        };
      });
    } else {
      data.passages = setup.parts.map((p) => str(p.id));
      data.flagged = [];
    }
    const res = await fetch('/api/v1/attempts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id,
        skill: setup.skill,
        kind: setup.kind,
        title: setup.title,
        refId: setup.refId,
        band: listening ? listeningBand(correct.length, total) : readingBand(correct.length, total),
        score: correct.length,
        total,
        durationSec,
        createdAt: new Date().toISOString(),
        data,
      }),
    }).catch(() => null);
    if (!res || !res.ok) {
      setBusy(false);
      setError('Your answers couldn’t be saved. Check your connection and try again.');
      return;
    }
    try {
      localStorage.removeItem(storeKey);
    } catch {}
    router.push(`/app/${setup.skill}/result/${id}`);
  }

  const current = setup.parts[part] ?? {};
  const partGroups = groups.filter((g) => g.part === part);

  const questions = (
    <QuestionGroups
      groups={partGroups}
      answers={answers}
      onAnswer={(n, v) => setAnswers((a) => ({ ...a, [n]: v }))}
      media={(p) => mediaUrl(p)}
    />
  );

  return (
    <>
      <div className={s.top}>
        <Link href={setup.back} className={s.back} aria-label="Leave">
          <Icon name="close" size={20} />
        </Link>
        <div className={s.topText}>
          <span className={s.kicker}>{setup.label}</span>
          <h1 className={s.h1}>{setup.title}</h1>
        </div>
        <span className={`${s.pill} ${left < 0 ? s.over : left < 300 ? s.low : ''}`}>
          <Icon name="timer" size={16} />
          {left >= 0 ? clock(left) : `+${clock(-left)}`}
        </span>
      </div>

      {setup.parts.length > 1 && (
        <nav className={s.tabs}>
          {setup.parts.map((p, i) => (
            <button key={i} type="button" className={`${s.tab} ${i === part ? s.tabOn : ''}`} onClick={() => setPart(i)}>
              {listening ? `Part ${Number(p.part) || i + 1}` : `Passage ${i + 1}`}
            </button>
          ))}
        </nav>
      )}

      {listening ? (
        <>
          <Card padding={16}>
            <div className={s.audioRow}>
              <div className={s.grow}>
                <p className={s.partTitle}>{str(current.title)}</p>
                {current.context ? <p className={s.muted}>{str(current.context)}</p> : null}
              </div>
              <Tag>{str(current.accent) || `Part ${Number(current.part) || part + 1}`}</Tag>
            </div>
            {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
            <audio key={str(current.id)} src={mediaUrl(str(current.audio))} controls preload="metadata" className={s.audio} />
            {setup.kind === 'test' && <p className={s.muted}>In the real test you hear each recording once. Try not to pause or rewind.</p>}
          </Card>
          <Card padding={18}>{questions}</Card>
        </>
      ) : (
        <div className={s.split}>
          <Card padding={20} className={s.passage}>
            <h2 className={s.passageTitle}>{str(current.title)}</h2>
            {current.topic ? <p className={s.muted}>{str(current.topic)}</p> : null}
            {rows(current.paragraphs).map((p, i) => (
              <p key={i} className={s.para}>
                {p.letter ? <b className={s.letter}>{str(p.letter)}</b> : null}
                {str(p.text)}
              </p>
            ))}
          </Card>
          <Card padding={18} className={s.qPane}>
            {questions}
          </Card>
        </div>
      )}

      {error && <p className={s.error}>{error}</p>}
      <div className={s.actions}>
        <span className={s.muted}>
          {answered} of {items.length} answered
        </span>
        {part < setup.parts.length - 1 && (
          <SoftButton onClick={() => setPart(part + 1)}>{listening ? 'Next part' : 'Next passage'}</SoftButton>
        )}
        <PrimaryButton onClick={() => (answered < items.length ? setConfirm(true) : void submit())} disabled={busy} trailing="arrow_forward">
          {busy ? 'Marking…' : 'Submit answers'}
        </PrimaryButton>
      </div>

      {confirm && (
        <ConfirmDialog
          title={`Submit with ${items.length - answered} unanswered?`}
          message="Unanswered questions are marked wrong. In the real test, always write something."
          confirm="Submit anyway"
          cancel="Keep going"
          onConfirm={() => void submit()}
          onCancel={() => setConfirm(false)}
        />
      )}
    </>
  );
}
