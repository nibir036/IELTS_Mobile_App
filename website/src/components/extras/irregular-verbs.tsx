'use client';

import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { boldSegments } from '@/lib/extras/format';
import { kvGet, kvPut } from '@/lib/extras/kv-client';
import d from '../dialog.module.css';
import { Card, HeroCard, Icon, PrimaryButton, SoftButton, Tag } from '../ui';
import { SpeakButton } from './speak-button';
import x from './extras.module.css';
import v from './verbs.module.css';
import { Portal } from '@/components/portal';

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');

export interface Verb {
  base: string;
  past: string;
  participle: string;
  meaning: string;
  example: string;
}

export interface Best {
  score: number;
  total: number;
  pct: number;
  at?: string;
}

/** kv key of the best practice round {score, total, pct, at}. */
const BEST_KEY = 'resources.irregularBest';
const PATTERNS = ['All verbs', 'Same past & participle', 'All three forms differ'];
const PAIRS: Record<string, string> = {
  learnt: 'learned',
  burnt: 'burned',
  dreamt: 'dreamed',
  spelt: 'spelled',
  spilt: 'spilled',
  spoilt: 'spoiled',
  smelt: 'smelled',
  leapt: 'leaped',
  leant: 'leaned',
  knelt: 'kneeled',
  dwelt: 'dwelled',
  lit: 'lighted',
  dived: 'dove',
};

/** Accepted spellings for one form (acceptedForms): listed alternatives plus British / American pairs. */
export function acceptedForms(value: string, participle = false): string[] {
  const out = new Set<string>();
  for (const raw of value.toLowerCase().split(/\s*(?:\/|,|\bor\b)\s*/)) {
    const w = raw.trim();
    if (!w) continue;
    out.add(w);
    for (const [a, b] of Object.entries(PAIRS)) {
      if (w === a) out.add(b);
      if (w === b) out.add(a);
    }
  }
  if (participle && out.has('got')) out.add('gotten');
  return [...out];
}

const isRight = (given: string, value: string, participle = false) => {
  const g = given.trim().toLowerCase().replace(/\s+/g, ' ');
  return Boolean(g) && acceptedForms(value, participle).includes(g);
};

const forms = (vb: Verb) => `${vb.base}, ${vb.past}, ${vb.participle}`;

function shuffle<T>(list: T[]): T[] {
  const a = [...list];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function speak(text: string) {
  const synth = typeof window !== 'undefined' ? window.speechSynthesis : undefined;
  if (!synth) return;
  synth.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.lang = 'en-GB';
  u.rate = 0.9;
  synth.speak(u);
}

function VerbDialog({ verb, onClose }: { verb: Verb; onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby="verb-title" onClick={onClose}>
      <div className={d.sheet} onClick={(e) => e.stopPropagation()}>
        <div className={x.cardCol} style={{ gap: 10 }}>
          <div className={x.cardHead}>
            <h2 id="verb-title" className={d.title} style={{ flex: 1, margin: 0 }}>
              {verb.base} – {verb.past} – {verb.participle}
            </h2>
            <SpeakButton text={forms(verb)} className={x.iconBtn} />
          </div>
          {verb.meaning && <p style={{ margin: 0, fontSize: 16, lineHeight: 1.45 }}>{verb.meaning}</p>}
          {verb.example && (
            <div className={x.box} style={{ background: 'var(--surface-alt)' }}>
              <p className={x.boxText}>
                {boldSegments(verb.example).map((s, i) => (s.bold ? <b key={i}>{s.text}</b> : <span key={i}>{s.text}</span>))}
              </p>
            </div>
          )}
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <button type="button" className={x.chip} onClick={onClose} autoFocus>
              Close
            </button>
          </div>
        </div>
      </div>
    </div></Portal>
  );
}

/** One practice round over [verbs] (IrregularVerbPracticeScreen). */
function Practice({ verbs, onExit }: { verbs: Verb[]; onExit: () => void }) {
  const [round, setRound] = useState(() => shuffle(verbs));
  const [retry, setRetry] = useState(false);
  const [index, setIndex] = useState(0);
  const [past, setPast] = useState('');
  const [part, setPart] = useState('');
  const [checked, setChecked] = useState<null | { past: boolean; part: boolean }>(null);
  const [score, setScore] = useState(0);
  const [wrong, setWrong] = useState<Verb[]>([]);
  const [finished, setFinished] = useState(false);
  const [newBest, setNewBest] = useState(false);
  const [best, setBest] = useState<Best | null>(null);
  const [hint, setHint] = useState('');
  const pastRef = useRef<HTMLInputElement>(null);
  const nextRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    void kvGet<Best>(BEST_KEY).then((b) => setBest(b && typeof b === 'object' ? b : null));
  }, []);
  useEffect(() => {
    if (finished) return;
    if (checked) nextRef.current?.focus();
    else pastRef.current?.focus();
  }, [checked, index, finished]);

  function start(list: Verb[], isRetry: boolean) {
    setRound(shuffle(list));
    setRetry(isRetry);
    setIndex(0);
    setPast('');
    setPart('');
    setChecked(null);
    setScore(0);
    setWrong([]);
    setFinished(false);
    setNewBest(false);
  }

  const verb = round[index];

  function check() {
    if (!past.trim() && !part.trim()) {
      setHint('Type both forms first');
      return;
    }
    setHint('');
    const r = { past: isRight(past, verb.past), part: isRight(part, verb.participle, true) };
    setChecked(r);
    if (r.past && r.part) setScore((s) => s + 1);
    else setWrong((w) => [...w, verb]);
  }

  async function finish(final: number) {
    const total = round.length;
    setFinished(true);
    if (retry || !total) return;
    const cur = await kvGet<Best>(BEST_KEY);
    const pct = Math.round((final * 100) / total);
    const bestPct = cur && typeof cur.pct === 'number' ? cur.pct : -1;
    if (pct > bestPct || (pct === bestPct && total > (cur?.total ?? 0))) {
      const b = { score: final, total, pct, at: new Date().toISOString() };
      if (await kvPut(BEST_KEY, b)) {
        setBest(b);
        setNewBest(true);
      }
    } else if (cur) setBest(cur);
  }

  function next() {
    if (index + 1 < round.length) {
      setIndex((i) => i + 1);
      setChecked(null);
      setPast('');
      setPart('');
      return;
    }
    void finish(score);
  }

  if (finished) {
    const total = round.length;
    return (
      <>
        <div className={x.top}>
          <button type="button" className={x.iconBtn} onClick={onExit} aria-label="Back to the verb list">
            <Icon name="arrow_back" size={20} />
          </button>
          <div className={x.topText}>
            <span className={x.topSub}>Your score</span>
            <h1 className={x.topTitle}>Irregular verbs practice</h1>
          </div>
          <span className={x.spacer} />
        </div>
        <HeroCard padding={22} radius={28}>
          <span className={v.overline}>{retry ? 'Retry round' : 'Score'}</span>
          <div className={v.big} style={{ margin: '6px 0' }}>
            {score}/{total}
          </div>
          <p style={{ margin: '0 0 12px', fontSize: 14, color: 'var(--hero-text)' }}>
            {newBest ? 'New best score!' : best ? `Best: ${best.score}/${best.total} (${best.pct}%)` : 'Finish a full round to set your best score.'}
          </p>
          <div className={x.heroTrack} role="progressbar" aria-valuemin={0} aria-valuemax={total} aria-valuenow={score} aria-label="Score">
            <span style={{ width: `${total ? (score / total) * 100 : 0}%` }} />
          </div>
        </HeroCard>
        {wrong.length > 0 ? (
          <>
            <h2 className={x.unitTitle}>To review</h2>
            <Card padding="4px 16px" radius={22}>
              {wrong.map((w) => (
                <div key={w.base} className={v.reviewRow}>
                  <span style={{ flex: 1, minWidth: 0 }}>
                    <b style={{ fontWeight: 500 }}>{w.base}</b>
                    <span className={x.small} style={{ display: 'block' }}>
                      {w.past} · {w.participle}
                    </span>
                  </span>
                  <Icon name="close" size={18} color="var(--danger)" />
                </div>
              ))}
            </Card>
          </>
        ) : (
          <Card>
            <div className={x.empty}>
              <Icon name="emoji_events" size={34} color="var(--peach)" />
              <h2 className={x.emptyTitle}>Every verb correct</h2>
              <p className={x.emptyText}>Try another letter or the “All three forms differ” filter for a harder set.</p>
            </div>
          </Card>
        )}
        <div className={v.actions}>
          <SoftButton onClick={onExit}>Done</SoftButton>
          <PrimaryButton onClick={() => (wrong.length ? start(wrong, true) : start(verbs, false))} leading={wrong.length ? 'replay' : 'refresh'}>
            {wrong.length ? `Retry ${wrong.length} wrong` : 'Practise again'}
          </PrimaryButton>
        </div>
      </>
    );
  }

  const ok = checked && checked.past && checked.part;
  return (
    <>
      <div className={x.top}>
        <button type="button" className={x.iconBtn} onClick={onExit} aria-label="Stop practice">
          <Icon name="close" size={20} />
        </button>
        <div className={x.topText}>
          <h1 className={x.topTitle}>{retry ? 'Retry wrong verbs' : 'Practise irregular verbs'}</h1>
        </div>
        <Tag>
          {index + 1}/{round.length}
        </Tag>
      </div>
      <div className={v.progress} role="progressbar" aria-valuemin={0} aria-valuemax={round.length} aria-valuenow={index + (checked ? 1 : 0)} aria-label="Progress">
        <span style={{ width: `${((index + (checked ? 1 : 0)) / round.length) * 100}%` }} />
      </div>
      <HeroCard padding={20} radius={26}>
        <span className={v.overline}>Base form</span>
        <p className={v.base}>{verb.base}</p>
        <p className={v.heroSub}>Type the past simple and the past participle.</p>
      </HeroCard>
      <form
        className={x.cardCol}
        onSubmit={(e) => {
          e.preventDefault();
          if (checked) next();
          else check();
        }}
      >
        <div className={v.fields}>
          <label className={v.field}>
            Past simple
            <input
              ref={pastRef}
              className={cx(v.input, checked && (checked.past ? v.inputOk : v.inputBad))}
              value={past}
              onChange={(e) => setPast(e.target.value)}
              placeholder="e.g. went"
              autoComplete="off"
              autoCapitalize="none"
              spellCheck={false}
              readOnly={Boolean(checked)}
            />
          </label>
          <label className={v.field}>
            Past participle
            <input
              className={cx(v.input, checked && (checked.part ? v.inputOk : v.inputBad))}
              value={part}
              onChange={(e) => setPart(e.target.value)}
              placeholder="e.g. gone"
              autoComplete="off"
              autoCapitalize="none"
              spellCheck={false}
              readOnly={Boolean(checked)}
            />
          </label>
        </div>
        {hint && (
          <p className={x.small} role="alert">
            {hint}
          </p>
        )}
        {checked && (
          <div className={cx(v.result, ok ? v.resultOk : v.resultBad)} role="status">
            <p className={v.resultTitle}>{ok ? 'Both correct' : 'Not quite'}</p>
            {(
              [
                ['Past simple', checked.past, verb.past],
                ['Past participle', checked.part, verb.participle],
              ] as const
            ).map(([label, good, answer]) => (
              <p key={label} className={v.resultLine}>
                <Icon name={good ? 'check_circle' : 'error'} size={18} color={good ? 'var(--success)' : 'var(--danger)'} />
                {good ? `${label}: correct` : `${label}: ${answer}`}
              </p>
            ))}
            <p className={x.small}>
              {verb.base} – {verb.past} – {verb.participle}
            </p>
          </div>
        )}
        <div className={v.actions}>
          {checked ? (
            <button ref={nextRef} type="submit" className={cx(x.chip, x.chipOn)} style={{ height: 56, padding: '0 24px', fontSize: 16, fontWeight: 600 }}>
              {index + 1 < round.length ? 'Next verb' : 'See score'} <Icon name="arrow_forward" size={18} />
            </button>
          ) : (
            <PrimaryButton type="submit">Check</PrimaryButton>
          )}
          <SoftButton onClick={() => speak(forms(verb))} leading="volume_up">
            Listen
          </SoftButton>
        </div>
      </form>
    </>
  );
}

/** H8 · Irregular verbs: searchable, letter-filtered table and the practice round (irregular_verbs_screen + _practice). */
export function IrregularVerbs({ verbs, defaultLetter, best }: { verbs: Verb[]; defaultLetter: string; best: Best | null }) {
  const letters = useMemo(() => [...new Set(verbs.map((vb) => vb.base.charAt(0).toUpperCase()).filter(Boolean))].sort(), [verbs]);
  const [letter, setLetter] = useState(letters.includes(defaultLetter) ? defaultLetter : (letters[0] ?? ''));
  const [query, setQuery] = useState('');
  const [pattern, setPattern] = useState(0);
  const [open, setOpen] = useState<Verb | null>(null);
  const [practice, setPractice] = useState<Verb[] | null>(null);

  const visible = verbs.filter((vb) => {
    const q = query.trim().toLowerCase();
    if (q) {
      if (!(vb.base.includes(q) || vb.past.includes(q) || vb.participle.includes(q))) return false;
    } else if (letter && !vb.base.toUpperCase().startsWith(letter)) return false;
    if (pattern === 1 && vb.past !== vb.participle) return false;
    if (pattern === 2 && (vb.base === vb.past || vb.past === vb.participle || vb.base === vb.participle)) return false;
    return true;
  });

  if (practice) return <Practice verbs={practice} onExit={() => setPractice(null)} />;

  return (
    <>
      <div className={x.top}>
        <Link href="/app/resources/words?tab=irregular" className={x.iconBtn} aria-label="Back to Vocabulary">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div style={{ flex: 1, minWidth: 0 }}>
          <h1 className={x.h1} style={{ fontSize: 26 }}>
            Irregular Verbs
          </h1>
          {best && (
            <p className={x.lead} style={{ marginTop: 2 }}>
              Best practice score {best.score}/{best.total} ({best.pct}%)
            </p>
          )}
        </div>
      </div>

      <div className={x.chips} role="group" aria-label="Filter verbs">
        {PATTERNS.map((p, i) => (
          <button key={p} type="button" className={cx(x.chip, pattern === i && x.chipOn)} aria-pressed={pattern === i} onClick={() => setPattern(i)}>
            {p}
          </button>
        ))}
      </div>

      <label className={x.note} style={{ alignItems: 'center', height: 50, padding: '0 14px', borderRadius: 18, background: 'var(--surface)', border: '1px solid var(--border)' }}>
        <Icon name="search" size={18} />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={`Search ${verbs.length} verbs`}
          aria-label={`Search ${verbs.length} verbs`}
          style={{ flex: 1, minWidth: 0, border: 0, outline: 0, background: 'transparent', color: 'var(--text)', fontSize: 15, height: '100%' }}
        />
      </label>

      {!query.trim() && (
        <div className={v.letters} role="group" aria-label="First letter">
          {letters.map((l) => (
            <button key={l} type="button" className={cx(v.letter, l === letter && v.letterOn)} aria-pressed={l === letter} onClick={() => setLetter(letter === l ? '' : l)}>
              {l}
            </button>
          ))}
        </div>
      )}

      <Card padding="4px 16px 6px" radius={24}>
        <table className={v.table}>
          <thead>
            <tr>
              <th scope="col">Base</th>
              <th scope="col">Past simple</th>
              <th scope="col">Past participle</th>
              <th scope="col" className={v.speakCol}>
                <span className="sr-only" style={{ position: 'absolute', width: 1, height: 1, overflow: 'hidden', clip: 'rect(0 0 0 0)' }}>
                  Listen
                </span>
              </th>
            </tr>
          </thead>
          <tbody>
            {visible.length === 0 && (
              <tr>
                <td colSpan={4} style={{ color: 'var(--text-muted)', fontWeight: 400, fontSize: 14 }}>
                  No verbs match.
                </td>
              </tr>
            )}
            {visible.map((vb) => (
              <tr key={vb.base}>
                <td>
                  {vb.meaning ? (
                    <button type="button" className={v.verbLink} onClick={() => setOpen(vb)} aria-haspopup="dialog">
                      {vb.base}
                    </button>
                  ) : (
                    vb.base
                  )}
                </td>
                <td>{vb.past}</td>
                <td>{vb.participle}</td>
                <td>
                  <SpeakButton text={forms(vb)} label={`Play ${vb.base}`} className={v.speak} size={16} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      <div className={v.actions}>
        <SoftButton leading="volume_up" onClick={() => visible[0] && speak(forms(visible[0]))} disabled={!visible.length}>
          Listen
        </SoftButton>
        <PrimaryButton onClick={() => visible.length && setPractice(visible)} disabled={!visible.length} leading="edit_note">
          {visible.length ? `Practise these ${visible.length} verbs` : 'No verbs to practise'}
        </PrimaryButton>
      </div>

      {open && <VerbDialog verb={open} onClose={() => setOpen(null)} />}
    </>
  );
}
