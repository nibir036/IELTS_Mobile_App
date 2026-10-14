'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useState } from 'react';
import { HeroCard, Icon } from '@/components/ui';
import { UpgradeDialog } from '@/components/upgrade-dialog';
import p from '@/components/plan.module.css';
import { formatHalf } from '@/lib/plan/plan';
import { QC_CRITERIA, QC_ITEMS, QC_SECTIONS, QC_WRITING_QUESTION, qcBand, qcMeaning, type QcItem } from '@/lib/plan/quick-check';

type Stage = 'intro' | 'questions' | 'writing' | 'result';
type Writing = { band: number; criteria: Record<string, number>; feedback?: string };

const shuffle = (n: number) => {
  const a = Array.from({ length: n }, (_, i) => i);
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
const words = (t: string) => t.trim().split(/\s+/).filter(Boolean).length;
const capped = (b: number) => (b >= 8 ? '8.0+' : formatHalf(b));

export function QuickCheck({ modules, pro, target, back }: { modules: string[]; pro: boolean; target: number | null; back: string }) {
  const router = useRouter();
  const asked = useMemo(() => QC_ITEMS.filter((it) => it.section === 'grammar' || it.section === 'vocab' || modules.includes(it.section)), [modules]);
  const withWriting = modules.includes('writing');
  const [order, setOrder] = useState<Record<string, number[]>>({});
  useEffect(() => setOrder(Object.fromEntries(asked.map((it) => [it.id, shuffle(it.options.length)]))), [asked]);
  const [stage, setStage] = useState<Stage>('intro');
  const [i, setI] = useState(0);
  const [chosen, setChosen] = useState<Record<string, number>>({});
  const [text, setText] = useState('');
  const [writing, setWriting] = useState<Writing | null>(null);
  const [wError, setWError] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [result, setResult] = useState<Record<string, number>>({});
  const [playing, setPlaying] = useState(false);
  const [showAnswers, setShowAnswers] = useState(false);

  useEffect(() => () => window.speechSynthesis?.cancel(), []);

  if (!pro) return <UpgradeDialog feature="quick_check" onClose={() => router.push(back)} />;

  const say = (t: string) => {
    try {
      const synth = window.speechSynthesis;
      synth.cancel();
      const u = new SpeechSynthesisUtterance(t);
      const v = synth.getVoices().find((x) => /^en-(GB|US)/.test(x.lang));
      if (v) u.voice = v;
      u.lang = v?.lang ?? 'en-GB';
      u.rate = 0.95;
      u.onend = () => setPlaying(false);
      u.onerror = () => setPlaying(false);
      setPlaying(true);
      synth.speak(u);
    } catch {
      setPlaying(false);
    }
  };

  const finish = async (w: Writing | null) => {
    const bands: Record<string, unknown> = {};
    const shown: Record<string, number> = {};
    for (const sec of ['grammar', 'vocab', 'reading', 'listening']) {
      const list = asked.filter((it) => it.section === sec);
      if (list.length) bands[sec] = shown[sec] = qcBand(list, chosen);
    }
    if (w) bands.writing = { band: w.band, criteria: w.criteria };
    setBusy(true);
    setError('');
    const res = await fetch('/api/v1/plan/quick-check', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(bands),
    }).catch(() => null);
    setBusy(false);
    if (!res?.ok) {
      const b = (await res?.json().catch(() => ({}))) as { error?: string } | undefined;
      setError(b?.error ?? 'Your results couldn’t be saved. Please try again.');
      return;
    }
    setResult(shown);
    setStage('result');
    router.refresh();
  };

  const next = () => {
    window.speechSynthesis?.cancel();
    setPlaying(false);
    if (i + 1 < asked.length) setI(i + 1);
    else if (withWriting) setStage('writing');
    else void finish(null);
  };

  const scoreWriting = async () => {
    setBusy(true);
    setWError('');
    const res = await fetch('/api/v1/plan/quick-check/writing', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: QC_WRITING_QUESTION, text: text.trim() }),
    }).catch(() => null);
    const b = (await res?.json().catch(() => ({}))) as (Writing & { error?: string }) | undefined;
    if (!res?.ok || !b || typeof b.band !== 'number') {
      setBusy(false);
      setWError(b?.error ?? 'The paragraph couldn’t be scored.');
      return;
    }
    setWriting(b);
    await finish(b);
  };

  const top = (title: string, sub: string, onBack?: () => void) => (
    <div className={p.top}>
      {onBack ? (
        <button type="button" className={p.back} onClick={onBack} aria-label="Back">
          <Icon name="arrow_back" size={20} />
        </button>
      ) : (
        <Link href={back} className={p.back} aria-label="Back">
          <Icon name="arrow_back" size={20} />
        </Link>
      )}
      <div className={p.topText}>
        <h1 className={p.h1}>{title}</h1>
        <p className={p.sub}>{sub}</p>
      </div>
    </div>
  );
  const total = asked.length + (withWriting ? 1 : 0);

  if (stage === 'intro') {
    const sections = [...new Set([...asked.map((it) => it.section as string), ...(withWriting ? ['writing'] : [])])];
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16, maxWidth: 640 }}>
        {top('Quick check', `About ${withWriting ? 10 : 6} minutes`)}
        <h2 className={p.q} style={{ fontSize: 24 }}>
          Get a sharper plan
        </h2>
        <p className={p.qSub} style={{ fontSize: 14 }}>
          {asked.length} short questions{withWriting ? ' and one paragraph' : ''}. Your plan then starts from what you can do, not just your own guess.
        </p>
        <div className={p.tags}>
          {sections.map((s) => (
            <span key={s} className={p.tag} style={{ background: 'var(--surface-alt2)' }}>
              {QC_SECTIONS[s] ?? s}
            </span>
          ))}
        </div>
        <div className={p.card}>
          <div className={p.cardRow} style={{ gap: 12 }}>
            <Icon name="info" color="var(--peach)" />
            <p className={p.cardText}>No score is saved to your history. Do not look anything up; a guess is fine. Listening questions are read aloud, so turn your sound on.</p>
          </div>
        </div>
        <div className={p.foot}>
          <button type="button" className={p.next} onClick={() => setStage('questions')}>
            Start <Icon name="arrow_forward" size={20} />
          </button>
        </div>
      </div>
    );
  }

  if (stage === 'questions') {
    const it: QcItem = asked[i];
    const ord = order[it.id] ?? it.options.map((_, k) => k);
    const picked = chosen[it.id];
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, maxWidth: 640 }}>
        {top('Quick check', `Question ${i + 1} of ${asked.length}`, () => (i === 0 ? setStage('intro') : setI(i - 1)))}
        <div className={p.progress}>
          <span style={{ width: `${((i + 1) / total) * 100}%` }} />
        </div>
        <span className={p.tag} style={{ alignSelf: 'flex-start' }}>
          {QC_SECTIONS[it.section]}
        </span>
        {it.text && (
          <div className={p.card} style={{ fontSize: 15, lineHeight: 1.55 }}>
            {it.text}
          </div>
        )}
        {it.say && (
          <button type="button" className={p.outline} style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8 }} onClick={() => say(it.say!)}>
            <Icon name={playing ? 'volume_up' : 'play_arrow'} size={20} /> {playing ? 'Playing…' : 'Play the recording'}
          </button>
        )}
        <h2 style={{ margin: 0, fontSize: 18, fontWeight: 600, lineHeight: 1.35 }}>{it.q}</h2>
        {ord.map((k) => (
          <button
            key={k}
            type="button"
            className={`${p.option} ${picked === k ? p.optionOn : ''}`}
            style={{ fontWeight: 400 }}
            aria-pressed={picked === k}
            onClick={() => setChosen((c) => ({ ...c, [it.id]: k }))}
          >
            {it.options[k]}
            {picked === k && <Icon name="check_circle" size={22} color="var(--peach)" filled />}
          </button>
        ))}
        {it.say && <p className={p.sub}>You can play it again if you need to.</p>}
        {error && <p className={p.error}>{error}</p>}
        <div className={p.foot}>
          <button type="button" className={p.next} disabled={picked === undefined || busy} onClick={next}>
            {busy ? 'Saving…' : i + 1 < asked.length || withWriting ? 'Next' : 'Finish'}
          </button>
        </div>
      </div>
    );
  }

  if (stage === 'writing') {
    const n = words(text);
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, maxWidth: 640 }}>
        {top('Quick check', 'Last step: one paragraph', () => setStage('questions'))}
        <div className={p.progress}>
          <span style={{ width: '100%' }} />
        </div>
        <span className={p.tag} style={{ alignSelf: 'flex-start' }}>
          Writing
        </span>
        <h2 style={{ margin: 0, fontSize: 16.5, fontWeight: 600, lineHeight: 1.4 }}>{QC_WRITING_QUESTION}</h2>
        <textarea className={p.textarea} value={text} onChange={(e) => setText(e.target.value)} placeholder="Write your paragraph here…" aria-label="Your paragraph" />
        <p className={p.sub} style={{ color: n < 30 ? 'var(--text-muted)' : 'var(--text)' }}>
          {n} words{n < 30 ? ' · at least 30' : ''}
        </p>
        {wError && <p className={p.error}>{wError} You can skip this step; your plan still uses the other answers.</p>}
        {error && <p className={p.error}>{error}</p>}
        <div className={p.foot}>
          <button type="button" className={p.outline} disabled={busy} onClick={() => void finish(null)}>
            Skip
          </button>
          <button type="button" className={p.next} disabled={n < 30 || busy} onClick={scoreWriting}>
            {busy ? 'Scoring…' : 'Score my paragraph'}
          </button>
        </div>
      </div>
    );
  }

  // result
  const sections = ['grammar', 'vocab', 'reading', 'listening'].filter((k) => typeof result[k] === 'number');
  const bands: Record<string, number> = { ...Object.fromEntries(sections.map((k) => [k, result[k]])) };
  if (writing) bands.writing = writing.band;
  const vals = Object.values(bands);
  const overall = vals.length ? Math.round((vals.reduce((a, b) => a + b, 0) / vals.length) * 2) / 2 : 0;
  const gap = target == null ? null : target - overall;
  const weakest = Object.entries(bands)
    .sort((a, b) => a[1] - b[1])
    .slice(0, 2)
    .filter(([, v]) => vals.length > 1 && v < (target ?? 9))
    .map(([k]) => QC_SECTIONS[k] ?? k);
  const pos = (b: number) => Math.min(1, Math.max(0, (b - 4) / 5)) * 100;
  const bandBar = (b: number) => (
    <div className={p.bandBar}>
      <div className={p.bar}>
        <span style={{ width: `${pos(b)}%` }} />
      </div>
      {target != null && <i style={{ left: `calc(${pos(target)}% - 1px)` }} title={`Target ${formatHalf(target)}`} />}
    </div>
  );
  const right = asked.filter((it) => chosen[it.id] === it.answer).length;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, maxWidth: 720 }}>
      <div className={p.top}>
        <div className={p.topText}>
          <h1 className={p.h1}>Quick check results</h1>
          <p className={p.sub}>Saved to your plan</p>
        </div>
      </div>
      <HeroCard padding={20} radius={28}>
        <div className={p.heroText}>
          <span className={p.overline}>Your starting point</span>
          <h2 className={p.heroTitle} style={{ fontSize: 24 }}>
            About band {capped(overall)} overall
          </h2>
          {gap != null && (
            <p className={p.heroMuted} style={{ color: '#fff', fontSize: 13.5 }}>
              {gap <= 0
                ? `At or above your target of ${formatHalf(target!)}. The plan keeps you sharp and works on exam technique.`
                : `Your target is ${formatHalf(target!)}: about ${gap.toFixed(1)} band to go.`}
            </p>
          )}
          <p className={p.heroMuted} style={{ fontSize: 12 }}>
            Rough estimates from a short check (the average of the sections below). They get more accurate as you practise.
          </p>
        </div>
      </HeroCard>
      {sections.map((k) => {
        const list = asked.filter((it) => it.section === k);
        const ok = list.filter((it) => chosen[it.id] === it.answer).length;
        const missed = list.filter((it) => chosen[it.id] !== it.answer).map((it) => it.focus);
        return (
          <div key={k} className={p.card}>
            <div style={{ display: 'flex', alignItems: 'flex-end' }}>
              <div style={{ flex: 1 }}>
                <span className={p.cardTitle}>{QC_SECTIONS[k]}</span>
                <p className={p.cardText}>
                  {ok} of {list.length} correct
                </p>
              </div>
              <b style={{ fontSize: 18 }}>about {capped(bands[k])}</b>
            </div>
            {bandBar(bands[k])}
            <p className={p.cardText}>{qcMeaning(bands[k])}</p>
            {missed.length === 0 ? (
              <p className={p.cardText} style={{ color: 'var(--success)', fontWeight: 600 }}>
                Nothing missed in this section.
              </p>
            ) : (
              <>
                <p className={p.cardText} style={{ fontWeight: 600, fontSize: 12 }}>
                  To work on
                </p>
                <div className={p.tags}>
                  {missed.map((m) => (
                    <span key={m} className={p.tag}>
                      {m}
                    </span>
                  ))}
                </div>
              </>
            )}
          </div>
        );
      })}
      {writing && (
        <div className={p.card}>
          <div style={{ display: 'flex', alignItems: 'flex-end' }}>
            <div style={{ flex: 1 }}>
              <span className={p.cardTitle}>Writing</span>
              <p className={p.cardText}>Your paragraph, scored on the four IELTS criteria</p>
            </div>
            <b style={{ fontSize: 18 }}>about {formatHalf(writing.band)}</b>
          </div>
          {bandBar(writing.band)}
          {Object.entries(QC_CRITERIA).map(([k, name]) =>
            typeof writing.criteria[k] === 'number' ? (
              <div key={k} className={p.critRow}>
                <span>{name}</span>
                <div className={p.bar}>
                  <span style={{ width: `${(writing.criteria[k] / 9) * 100}%` }} />
                </div>
                <b>{formatHalf(writing.criteria[k])}</b>
              </div>
            ) : null,
          )}
          {writing.feedback && (
            <div className={p.tipBox}>
              <Icon name="lightbulb" size={20} color="var(--peach)" />
              <span>{writing.feedback}</span>
            </div>
          )}
        </div>
      )}
      <div className={p.card}>
        <div className={p.cardRow} style={{ gap: 10 }}>
          <Icon name="calendar_month" size={20} color="var(--peach)" />
          <span className={p.cardTitle}>What happens next</span>
        </div>
        <p className={p.cardText} style={{ fontSize: 13.5 }}>
          {weakest.length
            ? `Your study plan has been rebuilt from these results. It puts extra time on ${weakest.join(' and ')}, and courses start at your level.`
            : 'Your study plan has been rebuilt from these results: courses start at your level and the time split follows your scores.'}
        </p>
      </div>
      <button type="button" className={`${p.card} ${p.cardRow}`} style={{ cursor: 'pointer' }} onClick={() => setShowAnswers(!showAnswers)} aria-expanded={showAnswers}>
        <span style={{ flex: 1, fontWeight: 600 }}>
          {showAnswers ? 'Hide' : 'Review'} your answers ({right} of {asked.length} correct)
        </span>
        <Icon name={showAnswers ? 'expand_less' : 'expand_more'} color="var(--text-muted)" />
      </button>
      {showAnswers &&
        asked.map((it) => {
          const pk = chosen[it.id];
          const ok = pk === it.answer;
          return (
            <div key={it.id} className={p.card} style={{ gap: 4, padding: 14 }}>
              <div className={p.cardRow} style={{ gap: 8 }}>
                <Icon name={ok ? 'check_circle' : 'cancel'} size={18} color={ok ? 'var(--success)' : 'var(--alert)'} filled />
                <span style={{ fontSize: 12, color: 'var(--text-muted)', fontWeight: 600 }}>
                  {QC_SECTIONS[it.section]} · {it.focus}
                </span>
              </div>
              <span style={{ fontSize: 14 }}>{it.q}</span>
              {!ok && pk !== undefined && <span style={{ fontSize: 13, color: 'var(--alert)' }}>Your answer: {it.options[pk]}</span>}
              <span style={{ fontSize: 13, color: 'var(--success)', fontWeight: 600 }}>Correct answer: {it.options[it.answer]}</span>
            </div>
          );
        })}
      <div className={p.foot}>
        <button type="button" className={p.next} onClick={() => router.push(back)}>
          Done
        </button>
      </div>
    </div>
  );
}
