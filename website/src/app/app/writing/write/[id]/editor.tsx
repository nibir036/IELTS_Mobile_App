'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ConfirmDialog, UpgradeDialog } from '@/components/upgrade-dialog';
import { Card, Icon, PrimaryButton, Tag } from '@/components/ui';
import { aiIssues, roundBand, wordCount } from '@/lib/writing/analysis';
import s from './editor.module.css';

export interface EditorPrompt {
  id: string;
  task: 1 | 2;
  title: string;
  shortTitle: string;
  typeName: string;
  prompt: string;
  minWords: number;
  timeSeconds: number;
  image: string;
  dataText: string;
  hasSamples: boolean;
}

const STEPS = [
  ['Task Response', 'Position and ideas checked'],
  ['Coherence & Cohesion', 'Paragraphs and linking'],
  ['Lexical Resource', 'Checking word choice'],
  ['Grammatical Range & Accuracy', 'Sentence variety and errors'],
];

const clock = (sec: number) => {
  const a = Math.abs(sec);
  return `${Math.floor(a / 60)}:${String(a % 60).padStart(2, '0')}`;
};

const newId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

async function call(path: string, method: string, body?: unknown) {
  const res = await fetch(`/api/v1/${path}`, {
    method,
    headers: body !== undefined ? { 'Content-Type': 'application/json' } : undefined,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  return { ok: res.ok, status: res.status, data };
}

const strings = (v: unknown): string[] =>
  Array.isArray(v)
    ? v
        .map((e) => (typeof e === 'string' ? e : e && typeof e === 'object' ? String((e as Record<string, unknown>).text ?? (e as Record<string, unknown>).note ?? '') : ''))
        .map((x) => x.trim())
        .filter(Boolean)
    : [];

export function Editor({
  prompt,
  initialText,
  initialElapsed,
  otherDraft,
}: {
  prompt: EditorPrompt;
  initialText: string;
  initialElapsed: number;
  otherDraft: boolean;
}) {
  const router = useRouter();
  const [text, setText] = useState(initialText);
  const [elapsed, setElapsed] = useState(initialElapsed);
  const [saved, setSaved] = useState<'idle' | 'saving' | 'saved'>(initialText ? 'saved' : 'idle');
  const [busy, setBusy] = useState(false);
  const [step, setStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [upgrade, setUpgrade] = useState<string | null>(null);
  const [confirmShort, setConfirmShort] = useState(false);
  const [showPrompt, setShowPrompt] = useState(true);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const latest = useRef({ text, elapsed });
  latest.current = { text, elapsed };

  const words = wordCount(text);
  const left = prompt.timeSeconds - elapsed;
  const key = `writing.draft.task${prompt.task}`;

  useEffect(() => {
    const t = setInterval(() => setElapsed((e) => e + 1), 1000);
    return () => clearInterval(t);
  }, []);

  const saveDraft = useCallback(async () => {
    const { text: t, elapsed: e } = latest.current;
    setSaved('saving');
    if (!t.trim()) {
      await call(`state/${encodeURIComponent(key)}`, 'DELETE');
    } else {
      await call(`state/${encodeURIComponent(key)}`, 'PUT', {
        value: { promptId: prompt.id, text: t, updatedAt: new Date().toISOString(), elapsedSec: e },
      });
    }
    setSaved('saved');
  }, [key, prompt.id]);

  function onChange(v: string) {
    setText(v);
    setSaved('idle');
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => void saveDraft(), 1200);
  }

  // Keep the draft when leaving the page.
  useEffect(() => {
    const flush = () => {
      if (!latest.current.text.trim()) return;
      void fetch(`/api/v1/state/${encodeURIComponent(key)}`, {
        method: 'PUT',
        keepalive: true,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          value: { promptId: prompt.id, text: latest.current.text, updatedAt: new Date().toISOString(), elapsedSec: latest.current.elapsed },
        }),
      }).catch(() => undefined);
    };
    window.addEventListener('pagehide', flush);
    return () => window.removeEventListener('pagehide', flush);
  }, [key, prompt.id]);

  useEffect(() => {
    if (!busy) return;
    const t = setInterval(() => setStep((x) => Math.min(STEPS.length - 1, x + 1)), 1400);
    return () => clearInterval(t);
  }, [busy]);

  async function submit() {
    setConfirmShort(false);
    setError(null);
    setBusy(true);
    setStep(0);
    if (timer.current) clearTimeout(timer.current);
    const id = newId();
    const durationSec = Math.max(60, elapsed);
    const r = await call('writing/evaluate', 'POST', {
      task: prompt.task,
      prompt: prompt.task === 1 && prompt.dataText ? `${prompt.prompt}\n\nData shown in the visual:\n${prompt.dataText}` : prompt.prompt,
      text,
      attemptId: id,
      promptId: prompt.id,
      title: prompt.shortTitle,
      durationSec,
    });
    if (!r.ok || typeof r.data.band !== 'number') {
      setBusy(false);
      if (r.status === 402) {
        setUpgrade(String(r.data.feature ?? `writing_task${prompt.task}`));
      } else {
        setError(String(r.data.error ?? 'We couldn’t score your essay right now. Please try again.'));
      }
      void saveDraft();
      return;
    }
    const e = r.data;
    const overall = roundBand(e.band as number);
    const crit = (e.criteria ?? {}) as Record<string, unknown>;
    const cb = (k: string) => (typeof crit[k] === 'number' ? roundBand(crit[k] as number) : overall);
    // The app's own copy of the attempt (same id), so it shows in the app too.
    await call('attempts', 'POST', {
      id,
      skill: 'writing',
      kind: `task${prompt.task}`,
      title: prompt.shortTitle,
      refId: prompt.id,
      band: overall,
      durationSec,
      createdAt: new Date().toISOString(),
      data: {
        text,
        prompt: prompt.prompt,
        promptId: prompt.id,
        task: prompt.task,
        criteria: { TA: cb('TA'), CC: cb('CC'), LR: cb('LR'), GRA: cb('GRA') },
        words: typeof e.words === 'number' ? e.words : words,
        feedback: strings(e.feedback),
        summary: String(e.summary ?? ''),
        criteriaFeedback: e.criteriaFeedback ?? {},
        ...(e.enhancedSnippet ? { enhancedSnippet: String(e.enhancedSnippet) } : {}),
        aiStrengths: strings(e.strengths),
        issues: aiIssues(text, Array.isArray(e.issues) ? (e.issues as Array<Record<string, unknown>>) : []),
        source: 'ai',
      },
    });
    await call(`state/${encodeURIComponent(key)}`, 'DELETE');
    router.push(`/app/writing/result/${id}`);
  }

  function onSubmit() {
    if (words < 20) {
      setError('Write at least 20 words to get AI feedback.');
      return;
    }
    if (words < prompt.minWords) {
      setConfirmShort(true);
      return;
    }
    void submit();
  }

  return (
    <>
      <div className={s.top}>
        <Link href={`/app/writing/questions/${prompt.task}`} className={s.back} aria-label="Back to questions">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={s.topText}>
          <span className={s.kicker}>Task {prompt.task} · {prompt.typeName}</span>
          <h1 className={s.h1}>{prompt.title}</h1>
        </div>
        <span className={`${s.pill} ${left < 0 ? s.over : left < 300 ? s.low : ''}`} title="Time">
          <Icon name="timer" size={16} />
          {left >= 0 ? clock(left) : `+${clock(left)}`}
        </span>
      </div>

      {otherDraft && (
        <p className={s.note}>
          You have a saved Task {prompt.task} draft for another question. Writing here replaces it.
        </p>
      )}

      <div className={s.layout}>
        <Card padding={18} className={s.promptCard}>
          <button type="button" className={s.promptToggle} onClick={() => setShowPrompt(!showPrompt)} aria-expanded={showPrompt}>
            <span>Question</span>
            <Icon name={showPrompt ? 'expand_less' : 'expand_more'} size={20} />
          </button>
          {showPrompt && (
            <div className={s.promptBody}>
              {prompt.prompt.split('\n').filter(Boolean).map((line, i) => (
                <p key={i}>{line}</p>
              ))}
              {prompt.image && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={prompt.image} alt={`${prompt.typeName}: ${prompt.title}`} className={s.visual} />
              )}
              <div className={s.tags}>
                <Tag>{prompt.timeSeconds / 60} minutes</Tag>
                <Tag>At least {prompt.minWords} words</Tag>
              </div>
            </div>
          )}
        </Card>

        <Card padding={0} className={s.editorCard}>
          <textarea
            className={s.textarea}
            value={text}
            onChange={(e) => onChange(e.target.value)}
            placeholder={prompt.task === 1 ? 'Start with an overview of the main features…' : 'Start with your introduction and your position…'}
            spellCheck={false}
            autoCorrect="off"
            autoCapitalize="sentences"
            aria-label="Your answer"
            disabled={busy}
          />
          <div className={s.footer}>
            <span className={`${s.count} ${words >= prompt.minWords ? s.countOk : ''}`}>
              {words} / {prompt.minWords} words
            </span>
            <span className={s.saved}>{saved === 'saving' ? 'Saving…' : saved === 'saved' ? 'Draft saved' : ''}</span>
          </div>
        </Card>
      </div>

      {error && <p className={s.error}>{error}</p>}

      <div className={s.actions}>
        {prompt.hasSamples && (
          <Link href={`/app/writing/samples/${prompt.id}`} className={s.link}>
            See sample answers
          </Link>
        )}
        <PrimaryButton onClick={onSubmit} disabled={busy || !text.trim()} trailing="arrow_forward">
          Get my band score
        </PrimaryButton>
      </div>

      {busy && (
        <div className={s.loading} role="status" aria-live="polite">
          <Card padding={24} className={s.loadingCard} style={{ background: 'var(--sheet)' }}>
            <h2 className={s.loadingTitle}>Scoring your {prompt.task === 1 ? 'report' : 'essay'}</h2>
            <p className={s.loadingSub}>AI feedback takes about 20 seconds.</p>
            <ol className={s.steps}>
              {STEPS.map(([t, d], i) => (
                <li key={t} className={i < step ? s.stepDone : i === step ? s.stepNow : ''}>
                  <Icon name={i < step ? 'check_circle' : i === step ? 'progress_activity' : 'radio_button_unchecked'} size={20} />
                  <span>
                    <b>{t}</b>
                    <small>{d}</small>
                  </span>
                </li>
              ))}
            </ol>
            <p className={s.tip}>
              While you wait: examiners reward a clear position in the introduction <b>and</b> the conclusion.
            </p>
          </Card>
        </div>
      )}

      {confirmShort && (
        <ConfirmDialog
          title={`Submit ${words} words?`}
          message={`IELTS asks for at least ${prompt.minWords} words. Shorter answers lose marks for ${prompt.task === 1 ? 'Task Achievement' : 'Task Response'}.`}
          confirm="Submit anyway"
          cancel="Keep writing"
          onConfirm={() => void submit()}
          onCancel={() => setConfirmShort(false)}
        />
      )}
      {upgrade && <UpgradeDialog feature={upgrade} onClose={() => setUpgrade(null)} />}
    </>
  );
}
