'use client';

import Link from 'next/link';
import { useRef, useState } from 'react';
import { Card, HeroCard, Icon, Nexi, PrimaryButton, SoftButton } from '@/components/ui';
import w from '../../writing/writing.module.css';

export interface QuizQuestion {
  id: string;
  word: string;
  pos: string;
  ipa: string;
  example: string;
  options: string[];
  answer: string;
}

const newId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

export function VocabQuiz({ questions, level, label, levels }: { questions: QuizQuestion[]; level: string; label: string; levels: Array<[string, string]> }) {
  const [i, setI] = useState(0);
  const [picked, setPicked] = useState<string | null>(null);
  const [answers, setAnswers] = useState<Array<{ id: string; word: string; chosen: string; correct: boolean }>>([]);
  const [done, setDone] = useState(false);
  const started = useRef(Date.now());
  const q = questions[i];
  const score = answers.filter((a) => a.correct).length;

  async function finish(all: typeof answers) {
    setDone(true);
    const elapsed = Math.round((Date.now() - started.current) / 1000);
    await fetch('/api/v1/attempts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: newId(),
        skill: 'vocab',
        kind: 'quiz',
        title: `Vocabulary Quiz · ${label}`,
        refId: `web_${level}`,
        score: all.filter((a) => a.correct).length,
        total: all.length,
        durationSec: Math.max(60, elapsed),
        createdAt: new Date().toISOString(),
        data: { answers: all, elapsedSec: elapsed, addedToLearning: [] },
      }),
    }).catch(() => null);
  }

  if (!questions.length) return <Card padding={20}>No words for this level yet.</Card>;

  if (done) {
    return (
      <>
        <HeroCard>
          <div className={w.row} style={{ alignItems: 'center' }}>
            <div className={w.grow}>
              <div className={w.taskLabel}>Round complete</div>
              <h1 className={w.taskTitle} style={{ fontSize: 40 }}>
                {score} / {questions.length}
              </h1>
              <p style={{ margin: 0, color: 'var(--hero-muted)' }}>{score >= 8 ? 'Excellent - try a harder level.' : score >= 5 ? 'Good work. Review the ones you missed.' : 'Keep going - every round makes these stick.'}</p>
            </div>
            <Nexi pose={score >= 8 ? 'thumbs' : 'point'} height={110} />
          </div>
        </HeroCard>
        <Card padding={18}>
          {answers.map((a, k) => (
            <p key={k} style={{ margin: '0 0 8px', display: 'flex', gap: 8, alignItems: 'center' }}>
              <Icon name={a.correct ? 'check_circle' : 'cancel'} size={18} color={a.correct ? 'var(--success)' : 'var(--danger)'} />
              <b>{a.word}</b>
              {!a.correct && <span style={{ color: 'var(--text-muted)' }}>· {questions[k].answer}</span>}
            </p>
          ))}
        </Card>
        <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
          <SoftButton href="/app/resources/words">Vocabulary lists</SoftButton>
          <PrimaryButton onClick={() => window.location.reload()} leading="replay">
            New round
          </PrimaryButton>
        </div>
      </>
    );
  }

  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/resources" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Resources
          </Link>
          <h1 className={w.title}>Vocabulary Quiz</h1>
          <p className={w.sub}>
            {label} · question {i + 1} of {questions.length} · {score} correct
          </p>
        </div>
      </div>
      {i === 0 && !picked && (
        <nav className={w.chips}>
          {levels.map(([k, l]) => (
            <Link key={k} href={`/app/resources/vocab-quiz?level=${k}`} className={`${w.chip} ${k === level ? w.chipOn : ''}`}>
              {l}
            </Link>
          ))}
        </nav>
      )}
      <HeroCard>
        <div className={w.taskLabel}>What does it mean?</div>
        <h2 className={w.taskTitle} style={{ fontSize: 34 }}>
          {q.word}
        </h2>
        <p style={{ margin: '4px 0 0', color: 'var(--hero-muted)' }}>
          {q.ipa} · {q.pos}
        </p>
      </HeroCard>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {q.options.map((o) => {
          const right = picked && o === q.answer;
          const wrong = picked === o && o !== q.answer;
          return (
            <button
              key={o}
              type="button"
              disabled={Boolean(picked)}
              onClick={() => {
                setPicked(o);
                setAnswers((a) => [...a, { id: q.id, word: q.word, chosen: o, correct: o === q.answer }]);
              }}
              style={{
                textAlign: 'left',
                padding: '14px 16px',
                borderRadius: 18,
                border: `1px solid ${right ? 'var(--success)' : wrong ? 'var(--danger)' : 'var(--border)'}`,
                background: right ? 'var(--success-soft)' : wrong ? 'var(--danger-soft)' : 'var(--surface)',
                fontSize: 15,
                cursor: picked ? 'default' : 'pointer',
              }}
            >
              {o}
            </button>
          );
        })}
      </div>
      {picked && (
        <>
          {q.example && <p style={{ margin: 0, color: 'var(--text-muted)', fontStyle: 'italic' }}>&ldquo;{q.example}&rdquo;</p>}
          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <PrimaryButton
              trailing="arrow_forward"
              onClick={() => {
                if (i < questions.length - 1) {
                  setI(i + 1);
                  setPicked(null);
                } else {
                  void finish(answers);
                }
              }}
            >
              {i < questions.length - 1 ? 'Next word' : 'See my score'}
            </PrimaryButton>
          </div>
        </>
      )}
    </>
  );
}
