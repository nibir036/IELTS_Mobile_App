'use client';

import { Fragment, type ReactNode } from 'react';
import { correctLabel, optionObjects, rows, str, strs, type Item, type Raw } from '@/lib/practice/marking';
import s from './questions.module.css';

export interface GroupView {
  part: number;
  offset: number;
  group: Raw;
  items: Item[];
}

export interface QuestionProps {
  groups: GroupView[];
  answers: Record<number, string>;
  onAnswer: (n: number, v: string) => void;
  /** After submitting: numbers answered correctly (shows the key). */
  correct?: Set<number>;
  /** Image URL for a map / diagram path. */
  media?: (path: string) => string;
  onFocus?: (n: number) => void;
}

const LETTER_TYPES = new Set(['matching', 'map', 'matching_features', 'sentence_endings', 'heading', 'tfng', 'ynng']);
const BLANK = /\((\d+)\)\s*_{2,}|_{3,}/g;

function letterChoices(g: Raw): Array<{ key: string; text: string }> {
  const t = str(g.type);
  if (t === 'heading') return rows(g.headings).map((h) => ({ key: str(h.key), text: str(h.text) }));
  if (t === 'tfng') return ['TRUE', 'FALSE', 'NOT GIVEN'].map((k) => ({ key: k, text: '' }));
  if (t === 'ynng') return ['YES', 'NO', 'NOT GIVEN'].map((k) => ({ key: k, text: '' }));
  const objs = optionObjects(g);
  if (objs.length) return objs.map((o) => ({ key: str(o.key), text: str(o.text) }));
  return strs(g.options).map((k) => ({ key: k, text: '' }));
}

export function QuestionGroups({ groups, answers, onAnswer, correct, media, onFocus }: QuestionProps) {
  const review = Boolean(correct);

  const mark = (n: number) =>
    review ? <span className={correct!.has(n) ? s.ok : s.bad}>{correct!.has(n) ? '✓' : '✗'}</span> : null;

  const keyFor = (it: Item) =>
    review && !correct!.has(it.number) ? <span className={s.key}>Answer: {correctLabel(it)}</span> : null;

  /** A typed or lettered answer box for question [n]. */
  const box = (it: Item | undefined, n: number, inline = true): ReactNode => {
    const v = answers[n] ?? '';
    if (!it) return <span className={s.missing}>({n})</span>;
    const choices = letterChoices(it.group);
    const lettered = (LETTER_TYPES.has(str(it.group.type)) || optionObjects(it.group).length > 0) && choices.length > 0;
    return (
      <span className={inline ? s.inlineBox : s.blockBox}>
        <span className={s.num}>{n}</span>
        {lettered ? (
          <select
            className={s.select}
            value={v}
            disabled={review}
            onChange={(e) => onAnswer(n, e.target.value)}
            onFocus={() => onFocus?.(n)}
            aria-label={`Question ${n}`}
          >
            <option value="">–</option>
            {choices.map((c) => (
              <option key={c.key} value={c.key}>
                {c.key}
                {c.text && !inline ? ` · ${c.text}` : ''}
              </option>
            ))}
          </select>
        ) : (
          <input
            className={s.input}
            value={v}
            disabled={review}
            onChange={(e) => onAnswer(n, e.target.value)}
            onFocus={() => onFocus?.(n)}
            aria-label={`Question ${n}`}
            autoComplete="off"
            autoCorrect="off"
            autoCapitalize="off"
            spellCheck={false}
          />
        )}
        {mark(n)}
        {keyFor(it)}
      </span>
    );
  };

  /** Text with "(3) ______" (or a lone "______" for [single]) turned into answer boxes. */
  const blanked = (text: string, g: GroupView, single?: Item): ReactNode => {
    const out: ReactNode[] = [];
    let last = 0;
    let m: RegExpExecArray | null;
    BLANK.lastIndex = 0;
    let k = 0;
    while ((m = BLANK.exec(text))) {
      out.push(<Fragment key={k++}>{text.slice(last, m.index)}</Fragment>);
      const local = m[1] ? Number(m[1]) : single?.local;
      const it = g.items.find((x) => x.local === local) ?? single;
      out.push(<Fragment key={k++}>{box(it, (local ?? 0) + g.offset)}</Fragment>);
      last = m.index + m[0].length;
    }
    out.push(<Fragment key={k++}>{text.slice(last)}</Fragment>);
    return out;
  };

  const hasBlankFor = (text: string) => /\(\d+\)\s*_{2,}/.test(text);

  return (
    <div className={s.groups}>
      {groups.map((g) => {
        const t = str(g.group.type);
        const nums = g.items.map((x) => x.number);
        const range = nums.length > 1 ? `Questions ${Math.min(...nums)}–${Math.max(...nums)}` : `Question ${nums[0]}`;
        const choices = letterChoices(g.group);
        const optionBox =
          (t === 'heading' || t === 'sentence_endings' || t === 'matching_features' || t === 'map' || (t === 'matching' && choices.some((c) => c.text)) || (t === 'summary' && optionObjects(g.group).length > 0)) &&
          choices.length > 0;
        const covered = new Set<number>();
        let context: ReactNode = null;

        // Context blocks with the blanks inside them.
        if (t === 'table' && Array.isArray(g.group.rows)) {
          const cols = strs(g.group.columns);
          context = (
            <div className={s.tableWrap}>
              <table className={s.table}>
                {cols.length > 0 && (
                  <thead>
                    <tr>
                      {cols.map((c, i) => (
                        <th key={i}>{c}</th>
                      ))}
                    </tr>
                  </thead>
                )}
                <tbody>
                  {(g.group.rows as unknown[]).map((r, i) => (
                    <tr key={i}>
                      {(Array.isArray(r) ? r : []).map((cell, j) => (
                        <td key={j}>{blanked(str(cell), g)}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          );
          for (const r of g.group.rows as unknown[]) for (const c of Array.isArray(r) ? r : []) for (const mm of str(c).matchAll(/\((\d+)\)/g)) covered.add(Number(mm[1]));
        } else if ((t === 'summary' && (g.group.summary || g.group.text)) || (t === 'notes' && Array.isArray(g.group.lines))) {
          if (t === 'notes') {
            context = (
              <div className={s.notes}>
                {rows(g.group.lines).map((l, i) => (
                  <p key={i} style={{ paddingLeft: (Number(l.level) || 0) * 18 }} className={Number(l.level) ? '' : s.noteHead}>
                    {blanked(str(l.text), g)}
                  </p>
                ))}
              </div>
            );
            for (const l of rows(g.group.lines)) for (const mm of str(l.text).matchAll(/\((\d+)\)/g)) covered.add(Number(mm[1]));
          } else {
            const text = str(g.group.summary || g.group.text);
            context = <p className={s.summary}>{blanked(text, g)}</p>;
            for (const mm of text.matchAll(/\((\d+)\)/g)) covered.add(Number(mm[1]));
          }
        } else if (t === 'flowchart' && Array.isArray(g.group.steps)) {
          context = (
            <ol className={s.flow}>
              {strs(g.group.steps).map((st, i) => (
                <li key={i}>{blanked(st, g)}</li>
              ))}
            </ol>
          );
          for (const st of strs(g.group.steps)) for (const mm of st.matchAll(/\((\d+)\)/g)) covered.add(Number(mm[1]));
        } else if (t === 'diagram' && Array.isArray(g.group.labels)) {
          context = (
            <div className={s.notes}>
              {g.group.caption ? <p className={s.noteHead}>{str(g.group.caption)}</p> : null}
              {rows(g.group.labels).map((l, i) => (
                <p key={i}>{blanked(str(l.text), g)}</p>
              ))}
            </div>
          );
          for (const l of rows(g.group.labels)) for (const mm of str(l.text).matchAll(/\((\d+)\)/g)) covered.add(Number(mm[1]));
        } else if (t === 'form') {
          context = (
            <div className={s.form}>
              {g.group.formTitle ? <p className={s.noteHead}>{str(g.group.formTitle)}</p> : null}
              {g.items.map((it) => (
                <p key={it.number} className={s.formRow}>
                  <span className={s.formLabel}>{str(it.q.label)}</span>
                  <span>
                    {str(it.q.before)} {box(it, it.number)} {str(it.q.after)}
                  </span>
                </p>
              ))}
            </div>
          );
          g.items.forEach((it) => covered.add(it.local));
        }

        // Questions not placed in the context block.
        const seenMulti = new Set<string>();
        const rest = g.items.filter((it) => !covered.has(it.local));
        return (
          <section key={`${g.part}-${str(g.group.id)}-${g.offset}`} className={s.group}>
            <p className={s.range}>{range}</p>
            {g.group.title ? <h3 className={s.title}>{str(g.group.title)}</h3> : null}
            {g.group.instruction ? <p className={s.instruction}>{str(g.group.instruction)}</p> : null}
            {t === 'map' && g.group.image && media ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={media(str(g.group.image))} alt={str(g.group.title) || 'Map'} className={s.map} />
            ) : null}
            {optionBox && (
              <div className={s.optionBox}>
                {g.group.headingsTitle || g.group.endingsTitle || g.group.optionsTitle ? (
                  <p className={s.noteHead}>{str(g.group.headingsTitle || g.group.endingsTitle || g.group.optionsTitle)}</p>
                ) : null}
                {choices.map((c) => (
                  <p key={c.key}>
                    <b>{c.key}</b> {c.text}
                  </p>
                ))}
              </div>
            )}
            {context}
            {rest.map((it) => {
              if (it.multi) {
                const key = it.multi.join(',');
                if (seenMulti.has(key)) return null;
                seenMulti.add(key);
                const opts = rows(it.q.options);
                const chosen = it.multi.map((n) => answers[n] ?? '').filter(Boolean);
                const toggle = (k: string) => {
                  const next = chosen.includes(k) ? chosen.filter((x) => x !== k) : chosen.length < it.multi!.length ? [...chosen, k] : chosen;
                  it.multi!.forEach((n, i) => onAnswer(n, next[i] ?? ''));
                };
                return (
                  <div key={key} className={s.q}>
                    <p className={s.qText}>
                      <span className={s.num}>{`${it.multi[0]}–${it.multi[it.multi.length - 1]}`}</span> {str(it.q.text)}
                    </p>
                    <div className={s.options}>
                      {opts.map((o) => (
                        <label key={str(o.key)} className={`${s.option} ${chosen.includes(str(o.key)) ? s.optionOn : ''}`}>
                          <input type="checkbox" disabled={review} checked={chosen.includes(str(o.key))} onChange={() => toggle(str(o.key))} />
                          <b>{str(o.key)}</b> {str(o.text)}
                        </label>
                      ))}
                    </div>
                    {review && (
                      <p className={s.key}>
                        {it.multi.filter((n) => correct!.has(n)).length} of {it.multi.length} correct · Answer: {correctLabel(it)}
                      </p>
                    )}
                  </div>
                );
              }
              const qt = str(it.q.type || t);
              if (qt === 'mcq' && Array.isArray(it.q.options)) {
                return (
                  <div key={it.number} className={s.q}>
                    <p className={s.qText}>
                      <span className={s.num}>{it.number}</span> {str(it.q.text)} {mark(it.number)}
                    </p>
                    <div className={s.options}>
                      {rows(it.q.options).map((o) => (
                        <label key={str(o.key)} className={`${s.option} ${answers[it.number] === str(o.key) ? s.optionOn : ''}`}>
                          <input
                            type="radio"
                            name={`q${it.number}`}
                            disabled={review}
                            checked={answers[it.number] === str(o.key)}
                            onChange={() => onAnswer(it.number, str(o.key))}
                            onFocus={() => onFocus?.(it.number)}
                          />
                          <b>{str(o.key)}</b> {str(o.text)}
                        </label>
                      ))}
                    </div>
                    {keyFor(it)}
                  </div>
                );
              }
              const text = str(it.q.text);
              if (text && /_{3,}/.test(text) && !hasBlankFor(text)) {
                return (
                  <p key={it.number} className={s.qLine}>
                    {blanked(text, g, it)}
                  </p>
                );
              }
              return (
                <div key={it.number} className={s.qRow}>
                  <span className={s.qRowText}>{text || str(it.q.label) || `Question ${it.number}`}</span>
                  {box(it, it.number, false)}
                </div>
              );
            })}
          </section>
        );
      })}
    </div>
  );
}
