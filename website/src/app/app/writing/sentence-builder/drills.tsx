'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { HeroCard, Icon } from '@/components/ui';
import c from '@/components/course.module.css';
import type { Drill } from '@/lib/server/sentences';
import s from './drills.module.css';

type Result = { score: number; total: number; createdAt: string; results: Array<{ id: string; correct: boolean }> };

const newId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

/** C7 · Sentence Builder drill: tap the pieces into order, check, next (sentence_builder_screen.dart). */
export function Drills({
  setId,
  title,
  instruction,
  drills,
  next,
  result: initial,
}: {
  setId: string;
  title: string;
  instruction: string;
  drills: Drill[];
  next: { id: string; title: string } | null;
  result: Result | null;
}) {
  const router = useRouter();
  const [i, setI] = useState(0);
  const d = drills[i];
  const pre = Math.min(d?.prefilled ?? 0, d?.answer.length ?? 0);
  const [placed, setPlaced] = useState<string[]>(() => d?.answer.slice(0, pre) ?? []);
  const [bank, setBank] = useState<string[]>(() => [...(d?.bank ?? [])]);
  const [first, setFirst] = useState<Record<string, boolean>>({});
  const [result, setResult] = useState<Result | null>(initial);
  const [toast, setToast] = useState('');
  const [wrong, setWrong] = useState(false);
  const [started] = useState(() => Date.now());

  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(''), 2600);
    return () => clearTimeout(id);
  }, [toast]);

  const load = (k: number) => {
    const x = drills[k];
    const p = Math.min(x.prefilled, x.answer.length);
    setPlaced(x.answer.slice(0, p));
    setBank([...x.bank]);
    setWrong(false);
  };

  const finish = async (firstTry: Record<string, boolean>) => {
    const correct = Object.values(firstTry).filter(Boolean).length;
    const r: Result = {
      score: correct,
      total: drills.length,
      createdAt: new Date().toISOString(),
      results: drills.map((x) => ({ id: x.id, correct: firstTry[x.id] === true })),
    };
    setResult(r);
    await fetch('/api/v1/attempts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: newId(),
        skill: 'writing',
        kind: 'drill',
        title,
        refId: setId,
        score: correct,
        total: drills.length,
        durationSec: Math.max(60, Math.round((Date.now() - started) / 1000)),
        createdAt: r.createdAt,
        data: { results: r.results },
      }),
    }).catch(() => null);
    router.refresh();
  };

  const check = () => {
    if (placed.length < d.answer.length) return setToast('Fill every slot first');
    const ok = placed.join(' ') === d.answer.join(' ');
    const ft = d.id in first ? first : { ...first, [d.id]: ok };
    setFirst(ft);
    if (!ok) {
      setWrong(true);
      return setToast('Not quite - try a different order');
    }
    if (i + 1 < drills.length) {
      setToast('Correct!');
      setI(i + 1);
      load(i + 1);
    } else void finish(ft);
  };

  const restart = () => {
    setResult(null);
    setFirst({});
    setI(0);
    load(0);
  };

  // Keyboard: 1–9 picks a word from the bank, Backspace takes the last one back, Enter checks.
  useEffect(() => {
    if (result) return;
    const onKey = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement | null)?.tagName === 'INPUT') return;
      const n = Number(e.key);
      if (n >= 1 && n <= bank.length) {
        setPlaced((p) => [...p, bank[n - 1]]);
        setBank((b) => b.filter((_, k) => k !== n - 1));
        setWrong(false);
      } else if (e.key === 'Backspace' && placed.length > pre) {
        e.preventDefault();
        setBank((b) => [...b, placed[placed.length - 1]]);
        setPlaced((p) => p.slice(0, -1));
        setWrong(false);
      } else if (e.key === 'Enter') check();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  if (result) {
    const label = (id: string) => {
      const x = drills.find((k) => k.id === id);
      return x ? `Use “${x.connector}” · ${x.function}` : id;
    };
    return (
      <div className={s.wrap}>
        <div className={c.top}>
          <Link href="/app/writing/sentence-builder" className={c.back} aria-label="All sets">
            <Icon name="arrow_back" size={20} />
          </Link>
          <h1 className={c.h1}>Sentence Builder</h1>
        </div>
        <HeroCard padding={20} radius={28}>
          <span className={c.heroMuted}>{title}</span>
          <div className={s.big}>
            {result.score}/{result.total}
          </div>
          <span className={c.heroMuted}>sentences right first time</span>
          <div className={`${c.bar} ${c.barHero}`} style={{ marginTop: 10 }}>
            <span style={{ width: `${result.total ? (result.score / result.total) * 100 : 0}%` }} />
          </div>
        </HeroCard>
        <div className={s.results}>
          {result.results.map((x) => (
            <div key={x.id} className={s.resultRow}>
              <Icon name={x.correct ? 'check_circle' : 'replay'} size={18} color={x.correct ? 'var(--text)' : 'var(--text-muted)'} filled={x.correct} />
              <span style={{ flex: 1 }}>{label(x.id)}</span>
              <small>{x.correct ? 'First try' : 'Retried'}</small>
            </div>
          ))}
        </div>
        <div className={s.foot}>
          {next ? (
            <>
              <button type="button" className={s.soft} onClick={restart}>
                Practise again
              </button>
              <Link href={`/app/writing/sentence-builder?set=${next.id}`} className={s.primary}>
                Next set <Icon name="arrow_forward" size={18} />
              </Link>
            </>
          ) : (
            <>
              <Link href="/app/writing/sentence-builder" className={s.soft}>
                All sets
              </Link>
              <button type="button" className={s.primary} onClick={restart}>
                Practise again
              </button>
            </>
          )}
        </div>
      </div>
    );
  }

  if (!d) return null;
  const empty = Math.max(0, d.answer.length - placed.length);

  return (
    <div className={s.wrap}>
      <div className={s.head}>
        <Link href="/app/writing/sentence-builder" className={c.back} aria-label="All sets">
          <Icon name="arrow_back" size={18} />
        </Link>
        <div className={c.bar} style={{ flex: 1, height: 8 }}>
          <span style={{ width: `${((i + 1) / drills.length) * 100}%` }} />
        </div>
        <b style={{ fontSize: 14, fontWeight: 500 }}>
          {i + 1}/{drills.length}
        </b>
      </div>
      <div>
        <p className={c.sub} style={{ margin: 0 }}>
          {title}
        </p>
        <h2 className={s.instruction}>{d.instruction || instruction}</h2>
      </div>
      <HeroCard padding={18} radius={26}>
        <div className={s.useRow}>
          <span className={s.use}>Use: {d.connector}</span>
          <span className={c.heroMuted}>{d.function}</span>
        </div>
        {d.sentences.map((x, k) => (
          <div key={k} className={s.sentence}>
            <b>{k + 1}</b>
            <span>{x}</span>
          </div>
        ))}
      </HeroCard>
      <div className={`${s.slots} ${wrong ? s.slotsWrong : ''}`} aria-label="Your sentence" aria-live="polite">
        {placed.map((w, k) => (
          <button
            key={`${w}-${k}`}
            type="button"
            className={`${s.word} ${s.wordPlaced}`}
            disabled={k < pre}
            onClick={() => {
              if (k < pre) return;
              setBank((b) => [...b, w]);
              setPlaced((p) => p.filter((_, j) => j !== k));
              setWrong(false);
            }}
            title={k < pre ? 'Given' : 'Tap to take it back'}
          >
            {w}
          </button>
        ))}
        {Array.from({ length: empty }, (_, k) => (
          <span key={`e${k}`} className={k === 0 ? s.slotNext : s.slot} />
        ))}
      </div>
      <p className={c.sub} style={{ margin: '0 4px' }}>
        Tap words to add them <span className={s.keys}>· keys 1–{Math.max(1, bank.length)}, Backspace, Enter</span>
      </p>
      <div className={s.bank}>
        {bank.map((w, k) => (
          <button
            key={`${w}-${k}`}
            type="button"
            className={s.word}
            onClick={() => {
              setPlaced((p) => [...p, w]);
              setBank((b) => b.filter((_, j) => j !== k));
              setWrong(false);
            }}
          >
            <span className={s.key}>{k + 1}</span>
            {w}
          </button>
        ))}
      </div>
      <div className={s.foot}>
        <button type="button" className={s.hint} onClick={() => setToast(d.hint)} title="Hint" aria-label="Hint">
          <Icon name="lightbulb" size={22} />
        </button>
        <button type="button" className={s.primary} onClick={check}>
          Check sentence
        </button>
      </div>
      {toast && (
        <div className={s.toast} role="status">
          {toast}
        </div>
      )}
    </div>
  );
}
