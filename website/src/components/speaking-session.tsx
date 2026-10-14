'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { scoreSpeaking, type SpeakingJob } from './speaking-submit';
import { Card, HeroCard, Icon, PrimaryButton, SoftButton, Tag } from './ui';
import { UpgradeDialog } from './upgrade-dialog';
import { speak, useRecorder, type Clip } from './use-recorder';
import s from './speaking.module.css';

export interface SessionSetup {
  mode: 'qa' | 'cue';
  kind: SpeakingJob['kind'];
  part: 1 | 2 | 3;
  title: string;
  refId: string;
  cardTitle: string;
  label: string;
  back: string;
  questions: Array<{ text: string; hint: string; sample: string }>;
  aimSeconds: [number, number];
  /** Part 2 */
  bullets?: string[];
  prepSeconds?: number;
  limitSeconds?: number;
}

const clock = (sec: number) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;

/** Renders a sample answer with its [[highlighted]] phrases. */
function Sample({ text }: { text: string }) {
  const parts = text.split(/(\[\[[^\]]+\]\])/g);
  return (
    <p className={s.sample}>
      {parts.map((p, i) => (p.startsWith('[[') ? <mark key={i}>{p.slice(2, -2)}</mark> : <span key={i}>{p}</span>))}
    </p>
  );
}

/** Part 1 / 3 question-by-question session and the Part 2 cue card (speaking_part13_screen, cue_card_screen). */
export function SpeakingSession({ setup }: { setup: SessionSetup }) {
  const router = useRouter();
  const rec = useRecorder();
  const n = setup.questions.length;
  const [index, setIndex] = useState(0);
  const [clips, setClips] = useState<Array<Clip | null>>(() => Array(Math.max(1, n)).fill(null));
  const [showSample, setShowSample] = useState(false);
  const [stage, setStage] = useState<string | null>(null);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [upgrade, setUpgrade] = useState<string | null>(null);
  const [prep, setPrep] = useState(setup.mode === 'cue' ? setup.prepSeconds ?? 60 : 0);
  const started = useRef(Date.now());
  const q = setup.questions[Math.min(index, n - 1)];

  // Part 2: one minute to prepare, then speaking starts by itself.
  useEffect(() => {
    if (setup.mode !== 'cue' || prep <= 0 || clips[0]) return;
    const t = setTimeout(() => setPrep((p) => p - 1), 1000);
    return () => clearTimeout(t);
  }, [prep, setup.mode, clips]);
  useEffect(() => {
    if (setup.mode === 'cue' && prep === 0 && !rec.recording && !clips[0]) void rec.start();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [prep]);
  // Part 2: stop at the time limit.
  useEffect(() => {
    if (setup.mode === 'cue' && rec.recording && rec.seconds >= (setup.limitSeconds ?? 120)) void stopAnswer();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rec.seconds]);
  // Part 1 / 3: the examiner reads each question.
  useEffect(() => {
    if (setup.mode === 'qa' && q) speak(q.text);
  }, [index, setup.mode, q]);

  async function stopAnswer() {
    const clip = await rec.stop();
    if (clip) setClips((c) => c.map((x, i) => (i === (setup.mode === 'cue' ? 0 : index) ? clip : x)));
  }

  async function next() {
    if (rec.recording) await stopAnswer();
    setShowSample(false);
    if (index < n - 1) setIndex(index + 1);
  }

  async function finish(current = clips) {
    if (rec.recording) {
      const clip = await rec.stop();
      if (clip) {
        current = current.map((x, i) => (i === (setup.mode === 'cue' ? 0 : index) ? clip : x));
        setClips(current);
      }
    }
    setError(null);
    setStage('Uploading…');
    const out = await scoreSpeaking(
      {
        kind: setup.kind,
        title: setup.title,
        refId: setup.refId,
        part: setup.part,
        clips: current,
        questions: setup.questions.map((x) => x.text),
        expectedSec: setup.mode === 'cue' ? 120 : n * 30,
        durationSec: Math.round((Date.now() - started.current) / 1000),
        cueCard: setup.mode === 'cue' ? [setup.cardTitle, ...(setup.bullets ?? [])].join('\n') : undefined,
        cardTitle: setup.cardTitle,
      },
      (st, p) => {
        setStage(st);
        setProgress(p);
      },
    );
    if (out.ok) {
      router.push(`/app/speaking/result/${out.attemptId}`);
      return;
    }
    setStage(null);
    if (out.upgrade) setUpgrade(out.upgrade);
    else setError(out.message);
  }

  const answered = clips.filter(Boolean).length;
  const current = clips[setup.mode === 'cue' ? 0 : index];
  const aimHigh = setup.mode === 'cue' ? setup.limitSeconds ?? 120 : setup.aimSeconds[1];

  return (
    <>
      <div className={s.top}>
        <Link href={setup.back} className={s.back} aria-label="Leave">
          <Icon name="close" size={20} />
        </Link>
        <div className={s.topText}>
          <span className={s.kicker}>{setup.label}</span>
          <h1 className={s.h1}>{setup.cardTitle}</h1>
        </div>
        {setup.mode === 'qa' && (
          <Tag>
            {index + 1} / {n}
          </Tag>
        )}
      </div>

      {!rec.supported && (
        <Card padding={16}>
          This browser can&rsquo;t record audio. Please use Chrome or Edge on a computer or Android phone.
        </Card>
      )}
      {rec.error && <p className={s.error}>{rec.error}</p>}

      {setup.mode === 'cue' ? (
        <HeroCard padding={22}>
          <div className={s.cue}>
            <span className={s.cueBadge}>Part 2</span>
            <h2 className={s.cueTitle}>{setup.cardTitle}</h2>
            <p className={s.cueSay}>You should say:</p>
            <ul className={s.bullets}>
              {(setup.bullets ?? []).map((b) => (
                <li key={b}>{b}</li>
              ))}
            </ul>
          </div>
        </HeroCard>
      ) : (
        <HeroCard padding={22}>
          <div className={s.question}>
            <span className={s.cueBadge}>Question {index + 1}</span>
            <h2 className={s.qText}>{q?.text}</h2>
            {q?.hint && <p className={s.hint}>Tip: {q.hint}</p>}
            <button type="button" className={s.listen} onClick={() => q && speak(q.text)}>
              <Icon name="volume_up" size={18} /> Listen again
            </button>
          </div>
        </HeroCard>
      )}

      <Card padding={20}>
        <div className={s.recBox}>
          {setup.mode === 'cue' && prep > 0 && !clips[0] ? (
            <>
              <span className={s.big}>{clock(prep)}</span>
              <span className={s.muted}>Preparation time · make a few notes</span>
              <PrimaryButton onClick={() => setPrep(0)} leading="mic">
                Start speaking now
              </PrimaryButton>
            </>
          ) : rec.recording ? (
            <>
              <span className={s.big}>{clock(rec.seconds)}</span>
              <div className={s.meter} aria-hidden>
                <span style={{ width: `${Math.round(rec.level * 100)}%` }} />
              </div>
              <div className={s.aim}>
                <span style={{ width: `${Math.min(100, (rec.seconds / aimHigh) * 100)}%` }} />
              </div>
              <span className={s.muted}>
                {setup.mode === 'cue' ? `Keep going up to ${clock(aimHigh)}` : `Aim for ${setup.aimSeconds[0]}–${setup.aimSeconds[1]} seconds`}
              </span>
              <PrimaryButton onClick={() => void stopAnswer()} leading="stop" dark>
                Stop
              </PrimaryButton>
            </>
          ) : current ? (
            <>
              <span className={s.done}>
                <Icon name="check_circle" size={20} /> Answer recorded ({current.seconds}s)
              </span>
              <SoftButton onClick={() => void rec.start()} leading="replay">
                Record again
              </SoftButton>
            </>
          ) : (
            <>
              <span className={s.muted}>Press record and answer out loud.</span>
              <PrimaryButton onClick={() => void rec.start()} leading="mic" disabled={!rec.supported}>
                Record answer
              </PrimaryButton>
            </>
          )}
        </div>
      </Card>

      {setup.mode === 'qa' && current && q?.sample && (
        <Card padding={18}>
          <button type="button" className={s.sampleToggle} onClick={() => setShowSample(!showSample)}>
            <span>Sample answer</span>
            <Icon name={showSample ? 'expand_less' : 'expand_more'} size={20} />
          </button>
          {showSample && <Sample text={q.sample} />}
        </Card>
      )}

      {error && <p className={s.error}>{error}</p>}

      <div className={s.actions}>
        {setup.mode === 'qa' && index < n - 1 ? (
          <>
            <SoftButton onClick={() => void finish()} disabled={!answered && !rec.recording}>
              Finish &amp; score
            </SoftButton>
            <PrimaryButton onClick={() => void next()} trailing="arrow_forward">
              Next question
            </PrimaryButton>
          </>
        ) : (
          <PrimaryButton onClick={() => void finish()} disabled={!answered && !rec.recording} trailing="arrow_forward">
            Get my band score
          </PrimaryButton>
        )}
      </div>

      {stage && (
        <div className={s.overlay} role="status" aria-live="polite">
          <Card padding={24} style={{ background: 'var(--sheet)', width: '100%', maxWidth: 420 }}>
            <h2 className={s.overlayTitle}>{stage}</h2>
            <p className={s.muted}>The examiner listens to every answer. This usually takes about a minute.</p>
            <div className={s.aim} style={{ marginTop: 14 }}>
              <span style={{ width: `${Math.round(progress * 100)}%` }} />
            </div>
          </Card>
        </div>
      )}
      {upgrade && <UpgradeDialog feature={upgrade} onClose={() => setUpgrade(null)} />}
    </>
  );
}
