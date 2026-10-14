'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { HeroCard, Icon } from '@/components/ui';
import d from '@/components/dialog.module.css';
import type { IdeaPrompt } from '@/lib/server/writing';
import r from '../result/[id]/result.module.css';
import s from './ideas.module.css';
import { Portal } from '@/components/portal';

const KEY = 'writing.ideas.bookmarks';
type Ideas = IdeaPrompt['ideas'];

/** Reading time of an idea set (ideaMinutes). */
function minutes(i: Ideas) {
  const n = i.for.length + i.against.length;
  return Math.max(3, 2 + Math.floor((n + 1) / 2) + Math.floor(i.vocabulary.length / 6));
}

function merge(list: IdeaPrompt[]): Ideas {
  const out: Ideas = { for: [], against: [], vocabulary: [] };
  for (const p of list) for (const k of ['for', 'against', 'vocabulary'] as const) for (const x of p.ideas[k]) if (!out[k].includes(x)) out[k].push(x);
  return out;
}

export function Ideas({ prompts, initialSaved }: { prompts: IdeaPrompt[]; initialSaved: string[] }) {
  const topics = useMemo(() => [...new Set(prompts.map((p) => p.topic).filter(Boolean))], [prompts]);
  const [sel, setSel] = useState(-1);
  const [query, setQuery] = useState('');
  const [saved, setSaved] = useState(new Set(initialSaved));
  const [sheet, setSheet] = useState<{ label: string; title: string; ideas: Ideas; prompt?: IdeaPrompt } | null>(null);

  const all = sel < 0;
  const topic = all ? 'All topics' : topics[sel];
  const inTopic = all ? prompts : prompts.filter((p) => p.topic === topic);
  const featured = merge(inTopic);
  const args = featured.for.length + featured.against.length;
  const q = query.trim().toLowerCase();
  const matches = (p: IdeaPrompt) =>
    [p.title, p.prompt, p.topic, ...p.ideas.for, ...p.ideas.against, ...p.ideas.vocabulary].some((x) => x.toLowerCase().includes(q));
  const items = q ? prompts.filter(matches) : inTopic;

  const toggle = async (id: string) => {
    const next = new Set(saved);
    if (!next.delete(id)) next.add(id);
    setSaved(next);
    const cur = await fetch(`/api/v1/state?prefix=${encodeURIComponent(KEY)}`).catch(() => null);
    const server = new Set(cur?.ok ? ((((await cur.json()) as { state?: Record<string, unknown> }).state?.[KEY] as string[]) ?? []) : []);
    if (next.has(id)) server.add(id);
    else server.delete(id);
    void fetch(`/api/v1/state/${encodeURIComponent(KEY)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ value: [...server] }),
    }).catch(() => null);
  };

  const list = (heading: string, xs: string[], dot: string) =>
    xs.length ? (
      <div className={s.list}>
        <b>
          {heading} · {xs.length}
        </b>
        {xs.map((x) => (
          <div key={x} className={s.point}>
            <i style={{ background: dot }} />
            <span>{x}</span>
          </div>
        ))}
      </div>
    ) : null;

  return (
    <div className={s.wrap}>
      <div className={r.top}>
        <Link href="/app/writing" className={r.back} aria-label="Back to Writing">
          <Icon name="arrow_back" size={18} />
        </Link>
        <h1 className={r.h1}>IELTS Ideas &amp; Topics</h1>
      </div>
      <label className={s.search}>
        <Icon name="search" size={18} color="var(--text-muted)" />
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search a topic, question or idea" aria-label="Search ideas" />
        {query && (
          <button type="button" onClick={() => setQuery('')} aria-label="Clear search">
            <Icon name="close" size={18} />
          </button>
        )}
      </label>
      <div className={s.chips}>
        <button type="button" className={`${s.chip} ${all ? s.chipOn : ''}`} onClick={() => setSel(-1)}>
          All <small>{prompts.length}</small>
        </button>
        {topics.map((t, i) => (
          <button key={t} type="button" className={`${s.chip} ${i === sel ? s.chipOn : ''}`} onClick={() => setSel(i)}>
            {t} <small>{prompts.filter((p) => p.topic === t).length}</small>
          </button>
        ))}
      </div>
      {!q && !all && args > 0 && (
        <button
          type="button"
          className={s.featured}
          onClick={() => setSheet({ label: `${topic} · idea set`, title: `${topic} - ${args} arguments both ways`, ideas: featured })}
        >
          <HeroCard padding={18} radius={28}>
            <div className={s.featMeta}>
              <Icon name="tag" size={14} color="var(--peach)" />
              <span style={{ flex: 1 }}>{topic}</span>
              <span>Idea set · {minutes(featured)} min</span>
            </div>
            <div className={s.featTitle}>
              {topic} - {args} arguments both ways
            </div>
            <span className={s.featOpen}>
              Open idea set <Icon name="arrow_forward" size={16} />
            </span>
          </HeroCard>
        </button>
      )}
      <div className={s.card}>
        <div className={s.cardHead}>
          <span>{q ? `Results · ${items.length}` : `${topic} · ${inTopic.length}`}</span>
          <span>Task 2 questions</span>
        </div>
        {items.map((p) => {
          const tags = [...(q || all ? [p.topic] : []), p.typeName, ...(p.hasModel ? ['Model answer'] : [])].filter(Boolean);
          const on = saved.has(p.id);
          return (
            <div key={p.id} className={s.row}>
              <button type="button" className={s.rowMain} onClick={() => setSheet({ label: `${p.topic} · ${p.typeName}`, title: p.title, ideas: p.ideas, prompt: p })}>
                <b>{p.title}</b>
                <span className={s.tags}>
                  {tags.map((t) => (
                    <span key={t}>{t}</span>
                  ))}
                </span>
              </button>
              <span className={s.mins}>{minutes(p.ideas)} min</span>
              <button type="button" className={s.mark} onClick={() => void toggle(p.id)} aria-pressed={on} aria-label={on ? 'Remove bookmark' : 'Bookmark'} title={on ? 'Saved' : 'Save'}>
                <Icon name="bookmark" size={18} filled={on} color={on ? 'var(--text)' : 'var(--text-muted)'} />
              </button>
            </div>
          );
        })}
        {!items.length && <p className={s.empty}>No matching topics</p>}
      </div>

      {sheet && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label={sheet.title} onClick={() => setSheet(null)}>
          <div className={`${d.sheet} ${s.sheet}`} onClick={(e) => e.stopPropagation()}>
            <span className={s.sheetLabel}>{sheet.label}</span>
            <h2 className={d.title}>{sheet.title}</h2>
            <div className={s.sheetBody}>
              {sheet.prompt && <p className={s.question}>{sheet.prompt.prompt}</p>}
              {list('Arguments for', sheet.ideas.for, 'var(--success)')}
              {list('Arguments against', sheet.ideas.against, 'var(--alert)')}
              {sheet.ideas.vocabulary.length > 0 && (
                <div className={s.list}>
                  <b>Useful vocabulary · {sheet.ideas.vocabulary.length}</b>
                  <div className={s.vocab}>
                    {sheet.ideas.vocabulary.map((v) => (
                      <span key={v}>{v}</span>
                    ))}
                  </div>
                </div>
              )}
            </div>
            {sheet.prompt && (
              <div className={s.sheetFoot}>
                {sheet.prompt.hasModel && (
                  <Link href={`/app/writing/samples/${encodeURIComponent(sheet.prompt.id)}`} className={s.soft}>
                    Sample answer
                  </Link>
                )}
                <Link href={`/app/writing/write/${encodeURIComponent(sheet.prompt.id)}`} className={s.primary}>
                  Write this essay
                </Link>
              </div>
            )}
          </div>
        </div></Portal>
      )}
    </div>
  );
}
