'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
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
import { overallBand, roundHalf } from '@/lib/practice/overall';
import type { MockData } from '@/lib/server/mocks';
import { wordCount } from '@/lib/writing/analysis';
import { QuestionGroups, type GroupView } from './question-groups';
import { submitSpeakingSession } from './speaking-submit';
import { Card, HeroCard, Icon, Nexi, PrimaryButton, SoftButton, Tag } from './ui';
import { ConfirmDialog, UpgradeDialog } from './upgrade-dialog';
import { blobToBase64, speak, useRecorder, type Clip } from './use-recorder';
import p from './practice.module.css';
import sp from './speaking.module.css';

type Stage = 'intro' | 'listening' | 'reading' | 'writing' | 'speaking' | 'scoring';
const ORDER: Stage[] = ['listening', 'reading', 'writing', 'speaking'];
const MINUTES: Record<string, number> = { listening: 40, reading: 60, writing: 60, speaking: 14 };
const LABEL: Record<string, string> = { listening: 'Listening', reading: 'Reading', writing: 'Writing', speaking: 'Speaking' };

const clock = (sec: number) => `${Math.floor(Math.max(0, sec) / 60)}:${String(Math.max(0, sec) % 60).padStart(2, '0')}`;
const newId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
const strings = (v: unknown): string[] =>
  Array.isArray(v) ? v.map((e) => (typeof e === 'string' ? e : str((e as Raw)?.text ?? (e as Raw)?.note))).map((x) => x.trim()).filter(Boolean) : [];

function offsetsOf(parts: Raw[], listening: boolean): number[] {
  const out: number[] = [];
  let off = 0;
  for (const part of parts) {
    out.push(off);
    for (const g of rows(part.groups)) {
      for (const q of rows(g.questions)) {
        const pick = Number(g.pick) || 0;
        const nums = q.numbers;
        off += listening ? (pick > 1 ? pick : 1) : Array.isArray(nums) && nums.length > 1 ? nums.length : 1;
      }
    }
  }
  return out;
}

type Saved = { stage: Stage; listening: Record<number, string>; reading: Record<number, string>; writing: [string, string]; startedAt: number };

/** G1–G9 · Full Mock Test: Listening → Reading → Writing → Speaking, then one band report (mock_session.dart). */
export function MockRunner({ mock, blocked }: { mock: MockData; blocked: boolean }) {
  const router = useRouter();
  const key = `ia_mock_${mock.id}`;
  const [stage, setStage] = useState<Stage>('intro');
  const [listening, setListening] = useState<Record<number, string>>({});
  const [reading, setReading] = useState<Record<number, string>>({});
  const [writing, setWriting] = useState<[string, string]>(['', '']);
  const [part, setPart] = useState(0);
  const [task, setTask] = useState<0 | 1>(0);
  const [left, setLeft] = useState(0);
  const [confirm, setConfirm] = useState(false);
  const [upgrade, setUpgrade] = useState<string | null>(blocked ? 'mock' : null);
  const startedAt = useRef(Date.now());

  // Speaking: one recording per part.
  const rec = useRecorder();
  const [clips, setClips] = useState<Record<number, Clip>>({});
  const [spPart, setSpPart] = useState<1 | 2 | 3>(1);
  const [qIndex, setQIndex] = useState(0);
  const [prep, setPrep] = useState(60);

  // Scoring.
  const [steps, setSteps] = useState<Record<string, 'wait' | 'done' | 'failed'>>({});
  const [scoreError, setScoreError] = useState<string | null>(null);
  const results = useRef<{ w?: Raw | null; s?: Raw | null; keys?: Record<string, string> }>({});

  const lOff = useMemo(() => offsetsOf(mock.listening, true), [mock.listening]);
  const rOff = useMemo(() => offsetsOf(mock.reading, false), [mock.reading]);
  const lItems = useMemo<Item[]>(() => mock.listening.flatMap((s, i) => listeningItems(s, lOff[i], i)), [mock.listening, lOff]);
  const rItems = useMemo<Item[]>(() => readingItems(mock.reading.map((x, i) => [x, rOff[i]] as [Raw, number])), [mock.reading, rOff]);

  // Resume after a refresh (answers only; recordings live in memory).
  useEffect(() => {
    try {
      const s = JSON.parse(localStorage.getItem(key) ?? 'null') as Saved | null;
      if (s) {
        setListening(s.listening ?? {});
        setReading(s.reading ?? {});
        setWriting(s.writing ?? ['', '']);
        startedAt.current = s.startedAt ?? Date.now();
        if (s.stage && s.stage !== 'intro' && s.stage !== 'scoring') begin(s.stage);
      }
    } catch {}
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useEffect(() => {
    if (stage === 'intro') return;
    try {
      localStorage.setItem(key, JSON.stringify({ stage, listening, reading, writing, startedAt: startedAt.current } satisfies Saved));
    } catch {}
  }, [stage, listening, reading, writing, key]);
  useEffect(() => {
    if (stage === 'intro' || stage === 'scoring') return;
    const t = setInterval(() => setLeft((x) => x - 1), 1000);
    return () => clearInterval(t);
  }, [stage]);
  // Part 2 preparation, then recording starts by itself.
  useEffect(() => {
    if (stage !== 'speaking' || spPart !== 2 || clips[2] || rec.recording) return;
    if (prep <= 0) {
      void rec.start();
      return;
    }
    const t = setTimeout(() => setPrep((x) => x - 1), 1000);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stage, spPart, prep, clips]);
  useEffect(() => {
    if (stage === 'speaking' && spPart === 2 && rec.recording && rec.seconds >= 120) void stopPart();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rec.seconds]);
  useEffect(() => {
    if (stage !== 'speaking') return;
    const q = spPart === 1 ? mock.part1.questions[qIndex] : spPart === 3 ? mock.cue.part3[qIndex] : null;
    if (q) speak(q);
  }, [stage, spPart, qIndex, mock.part1.questions, mock.cue.part3]);

  function begin(s: Stage) {
    setStage(s);
    setPart(0);
    setLeft((MINUTES[s] ?? 0) * 60);
    window.scrollTo({ top: 0 });
  }

  function next() {
    setConfirm(false);
    const i = ORDER.indexOf(stage);
    if (i < ORDER.length - 1) begin(ORDER[i + 1]);
    else void score();
  }

  async function stopPart() {
    const clip = await rec.stop();
    if (clip) setClips((c) => ({ ...c, [spPart]: clip }));
  }

  // ── scoring ────────────────────────────────────────────────────────────
  async function scoreWriting(): Promise<Raw | null> {
    if (results.current.w !== undefined && results.current.w !== null) return results.current.w;
    const [t1, t2] = writing.map((x) => x.trim());
    if (!t1 && !t2) return (results.current.w = {});
    const body: Raw =
      t1 && t2
        ? {
            testId: mock.id,
            context: 'mock',
            title: `${mock.title} · Writing`,
            task1: { promptId: mock.task1?.id, prompt: mock.task1?.prompt, text: t1 },
            task2: { promptId: mock.task2?.id, prompt: mock.task2?.prompt, text: t2 },
          }
        : {
            task: t1 ? 1 : 2,
            promptId: (t1 ? mock.task1 : mock.task2)?.id,
            prompt: (t1 ? mock.task1 : mock.task2)?.prompt,
            text: t1 || t2,
            context: 'mock',
            title: `${mock.title} · Writing`,
          };
    const res = await fetch('/api/v1/writing/evaluate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).catch(() => null);
    const data = res ? ((await res.json().catch(() => ({}))) as Raw) : {};
    if (res?.status === 402) {
      setUpgrade(str(data.feature) || 'mock');
      return null;
    }
    if (!res?.ok) return null;
    const out: Raw = t1 && t2 ? { task1: data.task1, task2: data.task2 } : { [`task${t1 ? 1 : 2}`]: data };
    results.current.w = out;
    return out;
  }

  async function scoreSpeaking(): Promise<Raw | null> {
    if (results.current.s) return results.current.s;
    const parts = ([1, 2, 3] as const).filter((n) => clips[n]);
    if (!parts.length) return (results.current.s = {});
    const question = (n: number) =>
      n === 1 ? mock.part1.questions.join('\n') : n === 2 ? [mock.cue.title, mock.cue.bullets.length ? `You should say: ${mock.cue.bullets.join('; ')}` : ''].filter(Boolean).join('\n') : mock.cue.part3.join('\n');
    const segments = await Promise.all(
      parts.map(async (n) => ({ id: `part${n}`, partNumber: n, label: `Part ${n}`, questionText: question(n) || `Part ${n}`, audioBase64: await blobToBase64(clips[n].blob), format: clips[n].format })),
    );
    const spoken = parts.reduce((a, n) => a + clips[n].seconds, 0);
    const r = await submitSpeakingSession({ mode: 'mock', title: `${mock.title} · Speaking`, refId: mock.id, durationSec: spoken, segments }, () => undefined);
    if (!r.ok) {
      if (r.upgrade) setUpgrade(r.upgrade);
      setScoreError(r.message || null);
      return null;
    }
    results.current.keys = Object.fromEntries(r.recordings.map((x) => [x.id.replace('part', ''), x.key]));
    results.current.s = r.evaluation;
    return r.evaluation;
  }

  async function score() {
    setStage('scoring');
    setScoreError(null);
    setSteps({ w1: 'wait', w2: 'wait', s: 'wait' });
    const [w, s] = await Promise.all([
      scoreWriting().then((x) => {
        setSteps((st) => ({ ...st, w1: x ? 'done' : 'failed', w2: x ? 'done' : 'failed' }));
        return x;
      }),
      scoreSpeaking().then((x) => {
        setSteps((st) => ({ ...st, s: x ? 'done' : 'failed' }));
        return x;
      }),
    ]);
    if (!w || !s) {
      setScoreError((e) => e ?? 'Some sections couldn’t be scored right now. Your answers are kept: try again.');
      return;
    }
    await record(w, s);
  }

  async function record(w: Raw, s: Raw) {
    const lCorrect = markListening(lItems, listening);
    const rCorrect = markReading(rItems, reading);
    const lBand = lItems.length ? listeningBand(lCorrect.length, lItems.length) : 0;
    const rBand = rItems.length ? readingBand(rCorrect.length, rItems.length) : 0;
    const task = (n: 1 | 2): Raw => {
      const e = (w[`task${n}`] ?? null) as Raw | null;
      if (!e || typeof e.band !== 'number') return { band: 0, TA: 0, CC: 0, LR: 0, GRA: 0, words: 0, summary: '', strengths: [], feedback: [], issues: [], source: 'blank' };
      const band = roundHalf(e.band as number);
      const c = (e.criteria ?? {}) as Record<string, number>;
      const cb = (k: string) => (typeof c[k] === 'number' ? roundHalf(c[k]) : band);
      return { band, TA: cb('TA'), CC: cb('CC'), LR: cb('LR'), GRA: cb('GRA'), words: Number(e.words) || wordCount(writing[n - 1]), summary: str(e.summary), strengths: strings(e.strengths), feedback: strings(e.feedback), issues: Array.isArray(e.issues) ? e.issues : [], source: 'ai' };
    };
    const w1 = task(1);
    const w2 = task(2);
    const W = ['TA', 'CC', 'LR', 'GRA'];
    const wBand = roundHalf((Number(w1.band) + 2 * Number(w2.band)) / 3);
    const sBand = typeof s.band === 'number' ? roundHalf(s.band) : 0;
    const sc = (s.criteria ?? {}) as Record<string, number>;
    const overall = overallBand([lBand, rBand, wBand, sBand]);
    const transcripts = Object.fromEntries(
      (Array.isArray(s.segments) ? (s.segments as Raw[]) : []).map((x) => [str(x.id).replace('part', ''), str(x.transcript).trim()]).filter(([, t]) => t),
    );
    const byPart = mock.listening.map((set, i) => {
      const mine = lItems.filter((it) => it.part === i).map((it) => it.number);
      return { label: `Part ${Number(set.part) || i + 1}`, correct: lCorrect.filter((n) => mine.includes(n)).length, total: mine.length };
    });
    const id = newId();
    const spoken = Object.values(clips).reduce((a, c) => a + c.seconds, 0);
    const res = await fetch('/api/v1/attempts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id,
        skill: 'mock',
        kind: 'mock',
        title: `Full Mock Test ${mock.number}`,
        refId: mock.id,
        band: overall,
        durationSec: Math.max(60, Math.round((Date.now() - startedAt.current) / 1000)),
        createdAt: new Date().toISOString(),
        data: {
          mockId: mock.id,
          mockTitle: mock.title,
          sections: { listening: lBand, reading: rBand, writing: wBand, speaking: sBand },
          source: { writing: w1.source === 'ai' || w2.source === 'ai' ? 'ai' : 'blank', speaking: s.band != null ? 'ai' : 'blank' },
          overall,
          average: (lBand + rBand + wBand + sBand) / 4,
          listeningScore: { correct: lCorrect.length, total: lItems.length },
          readingScore: { correct: rCorrect.length, total: rItems.length },
          listeningByPart: byPart,
          answers: { listening, reading },
          writing: {
            task1: writing[0],
            task2: writing[1],
            task1Band: w1.band,
            task2Band: w2.band,
            task1Words: w1.words,
            task2Words: w2.words,
            task1Source: w1.source,
            task2Source: w2.source,
            task1Criteria: Object.fromEntries(W.map((k) => [k, w1[k]])),
            task2Criteria: Object.fromEntries(W.map((k) => [k, w2[k]])),
            task1Summary: w1.summary,
            task2Summary: w2.summary,
            strengths: [...(w1.strengths as string[]), ...(w2.strengths as string[])],
            feedback: [...(w1.feedback as string[]), ...(w2.feedback as string[])],
            task1Issues: w1.issues,
            task2Issues: w2.issues,
          },
          writingCriteria: Object.fromEntries(W.map((k) => [k, roundHalf((Number(w1[k]) + 2 * Number(w2[k])) / 3)])),
          writingSummary: [w1.summary ? `Task 1 · ${w1.summary}` : '', w2.summary ? `Task 2 · ${w2.summary}` : ''].filter(Boolean).join('\n'),
          speakingCriteria: { FC: sc.FC ?? sBand, LR: sc.LR ?? sBand, GRA: sc.GRA ?? sBand, P: sc.P ?? sBand },
          speakingSummary: str(s.summary).trim(),
          speaking: {
            feedback: strings(s.feedback),
            errors: Array.isArray(s.errors) ? s.errors : [],
            transcripts,
            recordingKeys: results.current.keys ?? {},
            recordings: Object.fromEntries(Object.entries(clips).map(([n, c]) => [n, { path: '', durationSec: c.seconds, format: c.format }])),
          },
          speakingSec: Object.fromEntries(Object.entries(clips).map(([n, c]) => [n, c.seconds])),
          spokenSec: spoken,
        },
      }),
    }).catch(() => null);
    if (!res?.ok) {
      setScoreError('Your report couldn’t be saved. Check your connection and try again.');
      return;
    }
    try {
      localStorage.removeItem(key);
    } catch {}
    router.push(`/app/mocks/result/${id}`);
  }

  // ── views ──────────────────────────────────────────────────────────────
  const header = (title: string, extra?: ReactNode) => (
    <div className={p.top}>
      <Link href="/app/mocks" className={p.back} aria-label="Leave the mock test">
        <Icon name="close" size={20} />
      </Link>
      <div className={p.topText}>
        <span className={p.kicker}>
          {mock.title} · {title}
        </span>
        <h1 className={p.h1}>{title}</h1>
      </div>
      {extra}
      {stage !== 'intro' && stage !== 'scoring' && (
        <span className={`${p.pill} ${left < 0 ? p.over : left < 300 ? p.low : ''}`}>
          <Icon name="timer" size={16} />
          {left >= 0 ? clock(left) : `+${clock(-left)}`}
        </span>
      )}
    </div>
  );

  const progress = (
    <nav className={p.tabs} aria-label="Sections">
      {ORDER.map((s, i) => (
        <span key={s} className={`${p.tab} ${s === stage ? p.tabOn : ''}`} style={{ cursor: 'default', opacity: ORDER.indexOf(stage) > i ? 0.6 : 1 }}>
          {i + 1}. {LABEL[s]}
        </span>
      ))}
    </nav>
  );

  if (stage === 'intro') {
    return (
      <>
        {header('Before you start')}
        <HeroCard>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ flex: 1 }}>
              <h2 style={{ margin: 0, fontSize: 26, fontWeight: 500 }}>{mock.title}</h2>
              <p style={{ margin: '6px 0 0', color: 'var(--hero-muted)' }}>All four skills under exam timing, about 2 hours 50 minutes. Your band report comes at the end.</p>
            </div>
            <Nexi pose="grad" height={110} />
          </div>
        </HeroCard>
        <Card padding={18}>
          <ol style={{ margin: 0, paddingLeft: 20, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <li>Listening · 4 parts, 40 questions · about 40 minutes. Use headphones.</li>
            <li>Reading · 3 passages, 40 questions · 60 minutes.</li>
            <li>Writing · Task 1 and Task 2 · 60 minutes.</li>
            <li>Speaking · Parts 1, 2 and 3 recorded · 11–14 minutes. Allow the microphone.</li>
          </ol>
          <p style={{ margin: '12px 0 0', color: 'var(--text-muted)', fontSize: 13.5 }}>
            Your answers are kept if you refresh the page. Recordings are kept until you leave the page, so do the Speaking section in one go.
          </p>
        </Card>
        <Card padding={18}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, flexWrap: 'wrap' }}>
            <div style={{ flex: 1, minWidth: 200 }}>
              <b>Microphone check</b>
              <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: 13.5 }}>{rec.error ?? (rec.level > 0 ? 'Microphone is on.' : 'Allow the microphone now so Speaking works later.')}</p>
            </div>
            <div className={sp.meter} style={{ maxWidth: 160 }}>
              <span style={{ width: `${Math.round(rec.level * 100)}%` }} />
            </div>
            <SoftButton onClick={() => void rec.ensureStream()} leading="mic">
              Test microphone
            </SoftButton>
          </div>
        </Card>
        <div className={p.actions}>
          <PrimaryButton onClick={() => (blocked ? setUpgrade('mock') : begin('listening'))} trailing="arrow_forward">
            Start Listening
          </PrimaryButton>
        </div>
        {upgrade && <UpgradeDialog feature={upgrade} onClose={() => setUpgrade(null)} />}
      </>
    );
  }

  if (stage === 'listening' || stage === 'reading') {
    const isL = stage === 'listening';
    const parts = isL ? mock.listening : mock.reading;
    const offs = isL ? lOff : rOff;
    const items = isL ? lItems : rItems;
    const answers = isL ? listening : reading;
    const set = isL ? setListening : setReading;
    const current = parts[part] ?? {};
    const groups: GroupView[] = rows(current.groups).map((g) => ({ part, offset: offs[part], group: g, items: items.filter((it) => it.part === part && it.group === g) }));
    const qs = <QuestionGroups groups={groups} answers={answers} onAnswer={(n, v) => set((a) => ({ ...a, [n]: v }))} media={mediaUrl} />;
    const answered = items.filter((it) => (answers[it.number] ?? '').trim()).length;
    return (
      <>
        {header(LABEL[stage])}
        {progress}
        <nav className={p.tabs}>
          {parts.map((x, i) => (
            <button key={i} type="button" className={`${p.tab} ${i === part ? p.tabOn : ''}`} onClick={() => setPart(i)}>
              {isL ? `Part ${Number(x.part) || i + 1}` : `Passage ${i + 1}`}
            </button>
          ))}
        </nav>
        {isL ? (
          <>
            <Card padding={16}>
              <p className={p.partTitle}>{str(current.title)}</p>
              {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
              <audio key={str(current.id)} src={mediaUrl(str(current.audio))} controls preload="metadata" className={p.audio} />
              <p className={p.muted}>In the real test you hear each recording once.</p>
            </Card>
            <Card padding={18}>{qs}</Card>
          </>
        ) : (
          <div className={p.split}>
            <Card padding={20} className={p.passage}>
              <h2 className={p.passageTitle}>{str(current.title)}</h2>
              {rows(current.paragraphs).map((x, i) => (
                <p key={i} className={p.para}>
                  {x.letter ? <b className={p.letter}>{str(x.letter)}</b> : null}
                  {str(x.text)}
                </p>
              ))}
            </Card>
            <Card padding={18} className={p.qPane}>
              {qs}
            </Card>
          </div>
        )}
        <div className={p.actions}>
          <span className={p.muted}>
            {answered} of {items.length} answered
          </span>
          {part < parts.length - 1 && <SoftButton onClick={() => setPart(part + 1)}>{isL ? 'Next part' : 'Next passage'}</SoftButton>}
          <PrimaryButton onClick={() => setConfirm(true)} trailing="arrow_forward">
            Finish {LABEL[stage]}
          </PrimaryButton>
        </div>
        {confirm && (
          <ConfirmDialog
            title={`Finish ${LABEL[stage]}?`}
            message={`You can’t come back to this section.${answered < items.length ? ` ${items.length - answered} questions are unanswered.` : ''}`}
            confirm="Go to the next section"
            cancel="Keep working"
            onConfirm={next}
            onCancel={() => setConfirm(false)}
          />
        )}
      </>
    );
  }

  if (stage === 'writing') {
    const pr = task === 0 ? mock.task1 : mock.task2;
    const words = wordCount(writing[task]);
    return (
      <>
        {header('Writing')}
        {progress}
        <nav className={p.tabs}>
          {(['Task 1', 'Task 2'] as const).map((t, i) => (
            <button key={t} type="button" className={`${p.tab} ${i === task ? p.tabOn : ''}`} onClick={() => setTask(i as 0 | 1)}>
              {t} · {wordCount(writing[i])} words
            </button>
          ))}
        </nav>
        <div className={p.split}>
          <Card padding={18} className={p.passage}>
            <Tag>{task === 0 ? 'Spend about 20 minutes · at least 150 words' : 'Spend about 40 minutes · at least 250 words'}</Tag>
            {(pr?.prompt ?? '').split('\n').filter(Boolean).map((l, i) => (
              <p key={i} className={p.para}>
                {l}
              </p>
            ))}
            {pr?.image ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={mediaUrl(pr.image)} alt={pr.title} style={{ width: '100%', borderRadius: 14, background: '#fff', marginTop: 10 }} />
            ) : null}
          </Card>
          <Card padding={0} className={p.qPane}>
            <textarea
              value={writing[task]}
              onChange={(e) => setWriting((w) => (task === 0 ? [e.target.value, w[1]] : [w[0], e.target.value]))}
              placeholder={task === 0 ? 'Write your report here…' : 'Write your essay here…'}
              spellCheck={false}
              style={{ width: '100%', minHeight: '55vh', border: 0, outline: 0, background: 'transparent', padding: 18, fontSize: 16, lineHeight: 1.7, resize: 'vertical' }}
            />
            <div style={{ padding: '10px 18px', borderTop: '1px solid var(--divider)', fontSize: 13, color: words >= (task === 0 ? 150 : 250) ? 'var(--success)' : 'var(--text-muted)' }}>
              {words} words
            </div>
          </Card>
        </div>
        <div className={p.actions}>
          {task === 0 && <SoftButton onClick={() => setTask(1)}>Go to Task 2</SoftButton>}
          <PrimaryButton onClick={() => setConfirm(true)} trailing="arrow_forward">
            Finish Writing
          </PrimaryButton>
        </div>
        {confirm && (
          <ConfirmDialog
            title="Finish Writing?"
            message={`Task 1: ${wordCount(writing[0])} words · Task 2: ${wordCount(writing[1])} words. You can’t come back to this section.`}
            confirm="Go to Speaking"
            cancel="Keep writing"
            onConfirm={next}
            onCancel={() => setConfirm(false)}
          />
        )}
      </>
    );
  }

  if (stage === 'speaking') {
    const questions = spPart === 1 ? mock.part1.questions : spPart === 3 ? mock.cue.part3 : [];
    const clip = clips[spPart];
    return (
      <>
        {header('Speaking')}
        {progress}
        <nav className={p.tabs}>
          {([1, 2, 3] as const).map((n) => (
            <span key={n} className={`${p.tab} ${n === spPart ? p.tabOn : ''}`} style={{ cursor: 'default' }}>
              Part {n} {clips[n] ? '✓' : ''}
            </span>
          ))}
        </nav>
        {rec.error && <p className={sp.error}>{rec.error}</p>}
        <HeroCard padding={22}>
          {spPart === 2 ? (
            <div className={sp.cue}>
              <span className={sp.cueBadge}>Part 2 · Cue card</span>
              <h2 className={sp.cueTitle}>{mock.cue.title}</h2>
              <p className={sp.cueSay}>You should say:</p>
              <ul className={sp.bullets}>
                {mock.cue.bullets.map((b) => (
                  <li key={b}>{b}</li>
                ))}
              </ul>
            </div>
          ) : (
            <div className={sp.question}>
              <span className={sp.cueBadge}>
                Part {spPart} · Question {Math.min(qIndex + 1, questions.length)} of {questions.length}
              </span>
              <h2 className={sp.qText}>{questions[qIndex]}</h2>
              <button type="button" className={sp.listen} onClick={() => speak(questions[qIndex] ?? '')}>
                <Icon name="volume_up" size={18} /> Listen again
              </button>
            </div>
          )}
        </HeroCard>
        <Card padding={20}>
          <div className={sp.recBox}>
            {spPart === 2 && !clip && !rec.recording ? (
              <>
                <span className={sp.big}>{clock(prep)}</span>
                <span className={sp.muted}>One minute to prepare</span>
                <PrimaryButton onClick={() => setPrep(0)} leading="mic">
                  Start speaking now
                </PrimaryButton>
              </>
            ) : rec.recording ? (
              <>
                <span className={sp.big}>{clock(rec.seconds)}</span>
                <div className={sp.meter}>
                  <span style={{ width: `${Math.round(rec.level * 100)}%` }} />
                </div>
                {spPart !== 2 && qIndex < questions.length - 1 && (
                  <SoftButton onClick={() => setQIndex(qIndex + 1)} leading="skip_next">
                    Next question
                  </SoftButton>
                )}
                <PrimaryButton dark onClick={() => void stopPart()} leading="stop">
                  End Part {spPart}
                </PrimaryButton>
              </>
            ) : clip ? (
              <span className={sp.done}>
                <Icon name="check_circle" size={20} /> Part {spPart} recorded ({clip.seconds}s)
              </span>
            ) : (
              <>
                <span className={sp.muted}>Recording runs for the whole part. Move to each new question as you finish the last.</span>
                <PrimaryButton onClick={() => void rec.start()} leading="mic" disabled={!rec.supported}>
                  Start Part {spPart}
                </PrimaryButton>
              </>
            )}
          </div>
        </Card>
        <div className={p.actions}>
          {spPart < 3 ? (
            <PrimaryButton
              disabled={rec.recording}
              onClick={() => {
                setSpPart((spPart + 1) as 2 | 3);
                setQIndex(0);
                setPrep(60);
              }}
              trailing="arrow_forward"
            >
              Go to Part {spPart + 1}
            </PrimaryButton>
          ) : (
            <PrimaryButton disabled={rec.recording} onClick={() => void score()} trailing="arrow_forward">
              Finish and get my band report
            </PrimaryButton>
          )}
        </div>
      </>
    );
  }

  // scoring
  const icon = (st?: string) => (st === 'done' ? 'check_circle' : st === 'failed' ? 'error' : 'progress_activity');
  return (
    <>
      {header('Scoring your test')}
      <Card padding={24}>
        <h2 style={{ margin: '0 0 6px', fontSize: 22 }}>Marking your test</h2>
        <p className={p.muted}>Listening and Reading are marked at once. Writing and Speaking are scored by the AI examiner, usually within two minutes.</p>
        <ul style={{ listStyle: 'none', padding: 0, margin: '16px 0 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[
            ['w1', 'Writing Task 1'],
            ['w2', 'Writing Task 2'],
            ['s', 'Speaking'],
          ].map(([k, l]) => (
            <li key={k} style={{ display: 'flex', alignItems: 'center', gap: 10, color: steps[k] === 'failed' ? 'var(--danger)' : steps[k] === 'done' ? 'var(--success)' : 'var(--text)' }}>
              <Icon name={icon(steps[k])} size={20} />
              {l}
            </li>
          ))}
        </ul>
        {scoreError && (
          <>
            <p style={{ color: 'var(--danger)', margin: '16px 0 10px' }}>{scoreError}</p>
            <PrimaryButton onClick={() => void score()} leading="refresh">
              Try again
            </PrimaryButton>
          </>
        )}
      </Card>
      {upgrade && <UpgradeDialog feature={upgrade} onClose={() => setUpgrade(null)} />}
    </>
  );
}
