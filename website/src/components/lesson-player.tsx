'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { lessonIcon, moduleIcon, nexiFor } from '@/lib/content/lang';
import { tickPlanTasks } from '@/lib/client/plan';
import type { LessonView, StepView } from '@/lib/content/lesson-view';
import { formatBand } from '@/lib/writing/analysis';
import { GuideBlock } from './guide-block';
import { LangSwitch } from './lang-switch';
import { bold } from './rich-text';
import { Icon, Nexi, type NexiPose } from './ui';
import c from './course.module.css';

const DONE_KEY = 'lessons.done';

type DoneEntry = { module: string; stage: string; xp: number; minutes: number; at: string };

/** Records the lesson as finished in the shared kv state (first time only). */
async function completeLesson(l: LessonView, minutes: number): Promise<{ firstTime: boolean; done: Record<string, DoneEntry> }> {
  const res = await fetch(`/api/v1/state?prefix=${encodeURIComponent(DONE_KEY)}`).catch(() => null);
  const cur: Record<string, DoneEntry> =
    res && res.ok ? ((((await res.json()) as { state?: Record<string, unknown> }).state?.[DONE_KEY] as Record<string, DoneEntry> | undefined) ?? {}) : {};
  if (cur[l.id]) return { firstTime: false, done: cur };
  const next = { ...cur, [l.id]: { module: l.module, stage: l.stageId, xp: l.xp, minutes, at: new Date().toISOString() } };
  await fetch(`/api/v1/state/${encodeURIComponent(DONE_KEY)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ value: next }),
  }).catch(() => null);
  void tickPlanTasks(l.id);
  return { firstTime: true, done: next };
}

function NexiSays({ pose, text, height = 100 }: { pose: NexiPose; text: string; height?: number }) {
  return (
    <div className={c.nexiSays}>
      <Nexi pose={pose} height={height} />
      <div className={c.bubble}>{bold(text)}</div>
    </div>
  );
}

/** One lesson as a row of short screens: cover → steps → completion (lesson_screen.dart). */
export function LessonPlayer({ lesson }: { lesson: LessonView }) {
  const router = useRouter();
  const steps = lesson.steps;
  const n = steps.length;
  const last = n + 1;
  const [at, setAt] = useState(0);
  const [forward, setForward] = useState(true);
  const [answers, setAnswers] = useState<Record<number, number>>({});
  const started = useRef<number | null>(null);
  const [result, setResult] = useState<{ minutes: number; firstTime: boolean; stageDone: boolean } | null>(null);
  const bodyRef = useRef<HTMLDivElement>(null);

  const step = at > 0 && at < last ? steps[at - 1] : null;
  const dark = at === 0 || at === last || step?.type === 'concepts' || step?.type === 'sampleFeedback';
  const canNext = !step || step.type !== 'choice' || answers[at - 1] !== undefined;

  const go = (to: number) => {
    if (to < 0 || to > last) return;
    if (to > 0 && started.current === null) started.current = Date.now();
    if (to === last && !result) {
      const minutes = Math.max(1, Math.ceil((Date.now() - (started.current ?? Date.now())) / 60000));
      setResult({ minutes, firstTime: true, stageDone: false });
      void completeLesson(lesson, minutes).then(({ firstTime, done }) => {
        const stageDone = lesson.stageLessonIds.every((id) => done[id]);
        setResult({ minutes, firstTime, stageDone });
        router.refresh();
      });
    }
    setForward(to > at);
    setAt(to);
    bodyRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' });
  };

  // ← / → keys move between screens.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
      if (e.key === 'ArrowRight' && at > 0 && at < last && canNext) go(at + 1);
      if (e.key === 'ArrowLeft' && at > 1 && at < last) go(at - 1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const asked = steps.filter((s) => s.type === 'choice').length;
  const correct = Object.entries(answers).filter(([i, v]) => {
    const s = steps[Number(i)];
    return s?.type === 'choice' && s.answer === v;
  }).length;

  const label = at === n ? 'Finish' : step?.type === 'roadmap' ? "Let's start" : 'Next';
  const dir = lesson.rtl ? 'rtl' : undefined;

  return (
    <div ref={bodyRef} className={`${c.player} ${dark ? c.dark : ''}`}>
      <div className={c.playerHead}>
        <Link href={`/app/courses/${lesson.module}`} className={c.iconBtn} aria-label="Back to the course">
          <Icon name="arrow_back" size={20} />
        </Link>
        {at > 0 && at < last ? (
          <>
            <div className={`${c.bar} ${dark ? c.barHero : ''}`} style={{ flex: 1 }}>
              <span style={{ width: `${(at / n) * 100}%` }} />
            </div>
            <span className={c.count}>
              {at}/{n}
            </span>
          </>
        ) : (
          <span style={{ flex: 1 }} />
        )}
      </div>

      <div key={at} className={`${c.playerBody} ${forward ? '' : c.fromLeft}`} dir={dir}>
        {at === 0 ? (
          <Cover lesson={lesson} onStart={() => go(1)} />
        ) : at === last ? (
          <Complete lesson={lesson} result={result} correct={correct} asked={asked} onReview={() => go(1)} />
        ) : step ? (
          <Step step={step} picked={answers[at - 1]} onPick={(i) => setAnswers((a) => ({ ...a, [at - 1]: i }))} />
        ) : null}
      </div>

      {at > 0 && at < last && (
        <div className={c.playerFoot}>
          {at > 1 && (
            <button type="button" className={c.round} onClick={() => go(at - 1)} aria-label="Previous">
              <Icon name="chevron_left" />
            </button>
          )}
          <button type="button" className={c.nextBtn} disabled={!canNext} onClick={() => go(at + 1)}>
            {label}
            {!dark && <Icon name="arrow_forward" size={20} />}
          </button>
        </div>
      )}
    </div>
  );
}

// ── cover ────────────────────────────────────────────────────────────────
function countConcepts(steps: StepView[]) {
  return steps.reduce((a, s) => a + (s.type === 'concepts' ? s.cards.length : s.type === 'contrast' || s.type === 'read' ? 1 : 0), 0);
}

function Cover({ lesson, onStart }: { lesson: LessonView; onStart: () => void }) {
  const concepts = countConcepts(lesson.steps);
  const practice = lesson.steps.filter((s) => s.type === 'choice' || s.type === 'practice').length;
  return (
    <div className={c.cover}>
      <div className={c.coverHead}>
        <span className={c.coverIcon}>
          <Icon name={moduleIcon(lesson.module)} size={22} />
        </span>
        <div>
          <div style={{ fontSize: 13, fontWeight: 500 }}>
            {lesson.moduleName} · Stage {lesson.stageIndex + 1}
          </div>
          <div style={{ fontSize: 12.5, color: 'var(--hero-muted)' }}>
            Lesson {lesson.lessonIndex + 1} of {lesson.stageLessons}
          </div>
        </div>
      </div>
      <h1 className={c.coverTitle}>{lesson.title}</h1>
      {lesson.english && lesson.english !== lesson.title && <p className={c.coverEnglish}>{lesson.english}</p>}
      <p style={{ margin: '12px 0 0', fontSize: 15, lineHeight: 1.5, color: 'var(--hero-muted)' }}>{lesson.intro}</p>
      <div className={c.chips}>
        <span>
          <Icon name="schedule" size={17} /> {lesson.minutes} min
        </span>
        <span>
          <Icon name="lightbulb" size={17} /> {concepts} {concepts === 1 ? 'concept' : 'concepts'}
        </span>
        {practice > 0 && (
          <span>
            <Icon name="edit" size={17} /> {practice} practice
          </span>
        )}
        <span>
          <Icon name="star" size={17} /> +{lesson.xp} XP
        </span>
      </div>
      <LangSwitch current={lesson.lang} langs={lesson.langs} />
      <button type="button" className={c.peachBtn} style={{ marginTop: 16, width: '100%', height: 54 }} onClick={onStart}>
        Start lesson
      </button>
      <div style={{ marginTop: 26 }}>
        <NexiSays
          pose={nexiFor(lesson.module)}
          height={130}
          text={[lesson.firstName ? `Hi ${lesson.firstName}!` : '', lesson.greeting || "Let's go through this one step at a time."].filter(Boolean).join(' ')}
        />
      </div>
    </div>
  );
}

// ── completion ───────────────────────────────────────────────────────────
const CONFETTI = ['#ff9c82', '#5b7cf0', '#ffc857', '#ffb8a3', '#8da6ff', '#7fd1a6'];

function Complete({
  lesson,
  result,
  correct,
  asked,
  onReview,
}: {
  lesson: LessonView;
  result: { minutes: number; firstTime: boolean; stageDone: boolean } | null;
  correct: number;
  asked: number;
  onReview: () => void;
}) {
  const concepts = countConcepts(lesson.steps);
  const next = lesson.next;
  const firstTime = result?.firstTime ?? true;
  const stageDone = Boolean(result?.stageDone) && !next?.sameStage;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div className={c.confetti} aria-hidden>
        {Array.from({ length: 30 }, (_, i) => (
          <i
            key={i}
            style={{
              left: `${(i * 37) % 100}%`,
              background: CONFETTI[i % CONFETTI.length],
              animationDelay: `${-((i * 7919) % 1000) / 250}s`,
              animationDuration: `${i % 2 ? 2 : 4}s`,
            }}
          />
        ))}
        <Nexi pose="grad" height={150} />
      </div>
      <h2 className={c.completeTitle}>{stageDone ? 'Stage complete! 🎉' : 'Lesson complete! 🎉'}</h2>
      <p className={c.completeSub}>{lesson.title}</p>
      <div className={c.stats}>
        <div className={`${c.darkGlass} ${c.stat}`}>
          <Icon name="schedule" size={24} />
          <b>{result?.minutes ?? 1} min</b>
          <span>Study time</span>
        </div>
        <div className={`${c.darkGlass} ${c.stat}`}>
          <Icon name="star" size={24} color="#ffc857" filled />
          <b>{firstTime ? `+${lesson.xp}` : lesson.xp}</b>
          <span>{firstTime ? 'XP earned' : 'XP (already earned)'}</span>
        </div>
        <div className={`${c.darkGlass} ${c.stat}`}>
          <Icon name={asked ? 'check' : 'menu_book'} size={24} color="var(--blue)" />
          <b>{asked ? `${correct}/${asked}` : `${concepts}/${concepts}`}</b>
          <span>{asked ? 'Correct' : 'Concepts'}</span>
        </div>
      </div>
      {lesson.learned.length > 0 && (
        <div className={c.darkGlass}>
          <b style={{ fontSize: 15 }}>What you&apos;ve learned</b>
          {lesson.learned.slice(0, 6).map((x) => (
            <div key={x} className={c.point}>
              <span className={c.check}>
                <Icon name="check" size={14} />
              </span>
              <span>{x}</span>
            </div>
          ))}
        </div>
      )}
      {next && (
        <Link href={`/app/courses/lesson/${next.id}`} className={`${c.darkGlass} ${c.nextUp}`}>
          <span className={c.nextPlay}>
            <Icon name="play_arrow" />
          </span>
          <span style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={{ fontSize: 12, color: 'var(--hero-muted)' }}>Next up</span>
            <b style={{ fontSize: 14.5 }}>{next.title}</b>
            <span style={{ fontSize: 12, color: 'var(--hero-muted)' }}>
              Stage {next.stageIndex + 1} · Lesson {next.lessonIndex + 1} of {next.stageLessons} · ~{next.minutes} min
            </span>
          </span>
          <Icon name="chevron_right" />
        </Link>
      )}
      <div className={c.two}>
        <button type="button" className={c.ghostBtn} onClick={onReview}>
          Review lesson
        </button>
        <Link href={next ? `/app/courses/lesson/${next.id}` : `/app/courses/${lesson.module}`} className={c.peachBtn}>
          {next ? 'Next lesson' : 'Back to course'}
        </Link>
      </div>
    </div>
  );
}

// ── steps ────────────────────────────────────────────────────────────────
function Step({ step, picked, onPick }: { step: StepView; picked: number | undefined; onPick: (i: number) => void }) {
  switch (step.type) {
    case 'choice':
      return <Choice step={step} picked={picked} onPick={onPick} />;
    case 'roadmap':
      return (
        <>
          <h2 className={c.stepTitle}>{step.title}</h2>
          <p className={c.stepIntro}>By the end of this lesson, you&apos;ll be able to:</p>
          {step.items.map((x, i) => (
            <div key={i} className={c.row} style={{ animationDelay: `${i * 70}ms` }}>
              <span className={`${c.num} ${i % 2 ? c.numAlt : ''}`}>{i + 1}</span>
              <span style={{ flex: 1 }}>{bold(x)}</span>
            </div>
          ))}
          {step.note && <NexiSays pose="thumbs" height={96} text={step.note} />}
        </>
      );
    case 'concepts':
      return <Concepts step={step} />;
    case 'contrast': {
      const ex = (e: { label: string; text: string; mark: string }, good: boolean) => {
        const i = e.mark ? e.text.indexOf(e.mark) : -1;
        return (
          <div className={`${c.example} ${good ? c.exampleGood : ''}`}>
            <div className={c.exampleHead}>
              <span>{e.label}</span>
              <span className={c.fbDot} style={{ width: 26, height: 26, background: good ? 'var(--blue)' : 'var(--danger)' }}>
                <Icon name={good ? 'check' : 'close'} size={16} />
              </span>
            </div>
            <p dir="ltr">
              {i < 0 ? (
                e.text
              ) : (
                <>
                  {e.text.slice(0, i)}
                  <mark>{e.mark}</mark>
                  {e.text.slice(i + e.mark.length)}
                </>
              )}
            </p>
          </div>
        );
      };
      return (
        <>
          <h2 className={c.stepTitle}>{step.title}</h2>
          {step.intro && <p className={c.stepIntro}>{step.intro}</p>}
          {ex(step.weak, false)}
          {ex(step.strong, true)}
          {step.tip && (
            <div className={c.panel} style={{ display: 'flex', gap: 12 }}>
              <Icon name="lightbulb" size={24} color="#ffb020" filled />
              <div>
                <b style={{ color: 'var(--text)' }}>Tip</b>
                <div>{bold(step.tip)}</div>
              </div>
            </div>
          )}
        </>
      );
    }
    case 'read':
      return (
        <>
          {step.title && <h2 className={c.stepTitle}>{step.title}</h2>}
          <div className={c.readCard}>
            {step.blocks.map((b, i) => (
              <GuideBlock key={i} block={b} />
            ))}
          </div>
        </>
      );
    case 'practice':
      return <Practice step={step} />;
    case 'sampleFeedback':
      return (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <h2 className={c.stepTitle} style={{ flex: 1 }}>
              {step.title}
            </h2>
            <span className={c.pill}>Example</span>
          </div>
          {step.intro && <p className={c.stepIntro}>{step.intro}</p>}
          <div className={c.darkGlass} style={{ flexDirection: 'row', alignItems: 'center', gap: 16 }}>
            <div className={c.ring} style={{ ['--v' as string]: `${Math.min(1, step.band / 9) * 100}%` }}>
              <span className={c.ringBand}>{formatBand(step.band)}</span>
              <span style={{ fontSize: 11, color: 'var(--hero-muted)' }}>Band</span>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
              {step.criteria.map((k) => (
                <div key={k.name}>
                  <div style={{ display: 'flex', fontSize: 12 }}>
                    <span style={{ flex: 1 }}>{k.name}</span>
                    <b>{formatBand(k.band)}</b>
                  </div>
                  <div className={`${c.bar} ${c.barHero}`} style={{ height: 5, marginTop: 4 }}>
                    <span style={{ width: `${(k.band / 9) * 100}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
          {step.good.length > 0 && (
            <div className={c.darkGlass}>
              <b>What you did well</b>
              {step.good.map((g) => (
                <div key={g} className={c.point}>
                  <span className={c.pointMark}>
                    <Icon name="check" size={14} />
                  </span>
                  {g}
                </div>
              ))}
            </div>
          )}
          {step.improve.length > 0 && (
            <div className={c.darkGlass}>
              <b>Main areas to improve</b>
              {step.improve.map((g) => (
                <div key={g} className={c.point}>
                  <span className={`${c.pointMark} ${c.pointMarkPeach}`}>
                    <Icon name="arrow_forward" size={14} />
                  </span>
                  {g}
                </div>
              ))}
            </div>
          )}
        </>
      );
    default:
      return null;
  }
}

function Choice({ step, picked, onPick }: { step: Extract<StepView, { type: 'choice' }>; picked: number | undefined; onPick: (i: number) => void }) {
  const done = picked !== undefined;
  const right = done && picked === step.answer;
  return (
    <>
      <h2 className={c.stepTitle}>{step.title}</h2>
      {step.prompt && <p className={c.stepIntro}>{bold(step.prompt)}</p>}
      {step.passage && (
        <div className={c.panel} dir="ltr">
          {step.passage}
        </div>
      )}
      {step.options.map((o, i) => {
        const state = !done ? '' : i === step.answer ? c.optRight : i === picked ? c.optWrong : c.optDim;
        return (
          <button key={i} type="button" className={`${c.option} ${state}`} disabled={done} onClick={() => onPick(i)}>
            <span className={c.optLetter}>{String.fromCharCode(65 + i)}</span>
            <span className={c.optText}>
              <span>{o.text}</span>
              {o.sub && <span className={c.optSub}>{o.sub}</span>}
            </span>
            {done && i === step.answer && <Icon name="check_circle" size={24} color="var(--peach)" filled />}
            {done && i === picked && i !== step.answer && <Icon name="cancel" size={24} color="var(--danger)" filled />}
          </button>
        );
      })}
      {done && (
        <>
          {step.bars.length > 0 && (
            <div className={c.panel}>
              <div className={c.bars}>
                {step.bars.map((b) => (
                  <div key={b.label} className={c.barRow}>
                    <span>{b.label}</span>
                    <div className={c.bar}>
                      <span style={{ width: `${Math.max(0, Math.min(1, b.value)) * 100}%` }} />
                    </div>
                    <span>{b.text}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
          <div className={`${c.feedback} ${right ? '' : c.feedbackWrong}`} role="status">
            <span className={c.fbDot}>
              <Icon name={right ? 'check' : 'close'} size={18} />
            </span>
            <div>
              <div className={c.fbTitle}>{right ? step.right || 'Correct!' : `Not quite - the answer is ${String.fromCharCode(65 + step.answer)}.`}</div>
              {step.explain && <div className={c.fbBody}>{bold(step.explain)}</div>}
            </div>
          </div>
        </>
      )}
    </>
  );
}

function Concepts({ step }: { step: Extract<StepView, { type: 'concepts' }> }) {
  const [sel, setSel] = useState(0);
  if (!step.cards.length) return null;
  const card = step.cards[Math.min(sel, step.cards.length - 1)];
  return (
    <>
      <h2 className={c.stepTitle}>{step.title}</h2>
      {step.intro && <p className={c.stepIntro}>{step.intro}</p>}
      {step.cards.map((k, i) => (
        <button key={i} type="button" className={`${c.glass} ${i === sel ? c.glassOn : ''}`} onClick={() => setSel(i)} aria-pressed={i === sel}>
          <span className={c.glassNum}>{i + 1}</span>
          <Icon name={lessonIcon(k.icon)} size={20} className={c.glassIcon} />
          <span style={{ flex: 1 }}>{k.title}</span>
          <Icon name="chevron_right" size={18} color="var(--hero-muted)" />
        </button>
      ))}
      <div key={sel} className={c.concept}>
        <b style={{ fontSize: 15.5 }}>{card.title}</b>
        <p>{bold(card.body)}</p>
        <div className={c.dots}>
          {step.cards.map((_, i) => (
            <i key={i} className={i === sel ? c.on : ''} />
          ))}
          <button type="button" className={c.conceptNext} onClick={() => setSel((sel + 1) % step.cards.length)} aria-label="Next card">
            <Icon name="arrow_forward" size={20} />
          </button>
        </div>
      </div>
    </>
  );
}

function Practice({ step }: { step: Extract<StepView, { type: 'practice' }> }) {
  const [plan, setPlan] = useState(false);
  const [note, setNote] = useState('');
  return (
    <>
      <h2 className={c.stepTitle}>{step.title}</h2>
      {step.task && <div className={c.panel}>{bold(step.task)}</div>}
      {step.prompt && (
        <div className={c.panel} dir="ltr" style={{ whiteSpace: 'pre-wrap' }}>
          {step.prompt}
        </div>
      )}
      {step.items.map((it, i) => {
        const inner = (
          <>
            <span className={`${c.num} ${c.numPeach}`} style={i ? { background: 'var(--accent-soft2)' } : undefined}>
              {i + 1}
            </span>
            <span style={{ flex: 1, fontWeight: 500 }}>
              {it.text}
              {it.minutes > 0 ? ` (${it.minutes} min)` : ''}
            </span>
            <Icon name="chevron_right" size={18} color="var(--text-muted)" />
          </>
        );
        return it.href ? (
          <Link key={i} href={it.href} target="_blank" className={`${c.row} ${i === 0 ? c.rowFirst : ''}`}>
            {inner}
          </Link>
        ) : (
          <button
            key={i}
            type="button"
            className={`${c.row} ${i === 0 ? c.rowFirst : ''}`}
            onClick={() => (it.action === 'plan' ? setPlan(!plan) : setNote('Write your essay, then tap Submit - the AI report opens right after.'))}
          >
            {inner}
          </button>
        );
      })}
      {plan && step.plan.length > 0 && (
        <div className={c.panel}>
          <b style={{ color: 'var(--text)' }}>Plan your answer</b>
          <ol style={{ margin: '8px 0 0', paddingInlineStart: 20, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {step.plan.map((p, i) => (
              <li key={i}>{bold(p)}</li>
            ))}
          </ol>
        </div>
      )}
      {note && <p className={c.stepIntro}>{note}</p>}
      <p className={c.stepIntro} style={{ fontSize: 13 }}>
        {step.prompt ? 'Optional - you can come back to this question any time from Writing.' : 'Optional - you can do this now or later. Opens in a new tab.'}
      </p>
      {step.tip && <NexiSays pose="wave" text={step.tip} />}
    </>
  );
}
