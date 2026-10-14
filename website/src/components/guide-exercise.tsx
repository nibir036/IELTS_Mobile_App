'use client';

import { useState } from 'react';
import { bold } from './rich-text';
import { Icon } from './ui';
import c from './course.module.css';

export interface ExerciseData {
  title?: string;
  kind?: string;
  instructions?: string;
  items?: Array<{ prompt?: string; answer?: string; accepted?: string[]; reason?: string }>;
}

const norm = (v: string) =>
  v
    .toLowerCase()
    .replace(/[‘’`]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[.,!?;:"/()]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

/**
 * An exercise inside a guide chapter (GuideExercise): short answers get a
 * box with Check and Show answer; essay edits reveal the model answer.
 */
export function GuideExercise({ data }: { data: ExerciseData }) {
  const items = Array.isArray(data.items) ? data.items : [];
  const long = data.kind === 'essay_edit';
  const [inputs, setInputs] = useState<Record<number, string>>({});
  const [results, setResults] = useState<Record<number, boolean>>({});
  const [shown, setShown] = useState<Set<number>>(new Set());
  const score = Object.values(results).filter(Boolean).length;
  const show = (i: number, on: boolean) =>
    setShown((p) => {
      const n = new Set(p);
      if (on) n.add(i);
      else n.delete(i);
      return n;
    });
  const check = (i: number) => {
    const given = norm(inputs[i] ?? '');
    if (!given) return;
    const it = items[i];
    const ok = [String(it.answer ?? ''), ...(it.accepted ?? []).map(String)].map(norm).includes(given);
    setResults((r) => ({ ...r, [i]: ok }));
    show(i, true);
  };
  return (
    <div className={c.ex}>
      <div className={c.exHead}>
        <span className={c.exIcon}>
          <Icon name="edit" size={16} />
        </span>
        <b className={c.exTitle}>{data.title}</b>
        {!long && Object.keys(results).length > 0 && (
          <span className={c.exScore}>
            {score}/{items.length}
          </span>
        )}
      </div>
      {data.instructions && <p className={c.exText}>{bold(data.instructions)}</p>}
      {items.map((it, i) => {
        const r = results[i];
        const open = shown.has(i);
        return (
          <div key={i} className={c.exItem}>
            <div className={c.exPrompt} dir="ltr">
              <b>{i + 1}.</b>
              {long ? <div className={c.exLong}>{it.prompt}</div> : <span>{it.prompt}</span>}
            </div>
            {!long && (
              <input
                dir="ltr"
                className={c.exInput}
                placeholder="Your answer"
                value={inputs[i] ?? ''}
                onChange={(e) => setInputs((p) => ({ ...p, [i]: e.target.value }))}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') check(i);
                }}
              />
            )}
            <div className={c.exBtns}>
              {!long && (
                <button type="button" className={c.exBtnCheck} onClick={() => check(i)}>
                  Check
                </button>
              )}
              <button type="button" className={c.exBtn} onClick={() => show(i, !open)}>
                {open ? 'Hide answer' : long ? 'Show model answer' : 'Show answer'}
              </button>
              <span style={{ flex: 1 }} />
              {r === true && (
                <span className={c.exOk}>
                  <Icon name="check" size={16} /> Correct
                </span>
              )}
              {r === false && <span className={c.exDiff}>Compare with the answer</span>}
            </div>
            {open && (
              <div className={c.exAnswer}>
                <div dir="ltr" style={{ fontWeight: 500 }}>
                  {it.answer}
                </div>
                {it.reason && <div className={c.gWhy}>{bold(it.reason)}</div>}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
