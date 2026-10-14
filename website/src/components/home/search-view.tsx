'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Icon } from '@/components/ui';
import type { SearchEntry } from '@/lib/home/search-index';
import h from './home.module.css';

export interface MineEntry {
  id: string;
  type: string;
  title: string;
  subtitle: string;
  href: string;
  hay: string;
}

interface Result {
  key: string;
  type: string;
  category: string;
  title: string;
  subtitle: string;
  href: string;
}

const RECENT = 'search.recent';
const MAX = 30;

const words = (q: string) => q.toLowerCase().split(/\s+/).filter(Boolean);

function badgeClass(type: string): string {
  if (type === 'Drill') return `${h.badge} ${h.badgeDrill}`;
  if (type === 'Vocab') return `${h.badge} ${h.badgeVocab}`;
  if (['Essay', 'Recording', 'Mock', 'Result'].includes(type)) return `${h.badge} ${h.badgeMine}`;
  return h.badge;
}

function Highlight({ text, q }: { text: string; q: string }) {
  const at = q ? text.toLowerCase().indexOf(q.toLowerCase()) : -1;
  if (at < 0) return <>{text}</>;
  return (
    <>
      {text.slice(0, at)}
      <mark className={h.mark}>{text.slice(at, at + q.length)}</mark>
      {text.slice(at + q.length)}
    </>
  );
}

/** B8 · Search (search_screen.dart): live filtering over the content index and your own work. */
export function SearchView({
  lang,
  filters,
  mine,
  recent: initialRecent,
  initialQuery,
}: {
  lang: string;
  filters: Array<{ id: string; label: string }>;
  mine: MineEntry[];
  recent: string[];
  initialQuery: string;
}) {
  const router = useRouter();
  const [query, setQuery] = useState(initialQuery);
  const [filter, setFilter] = useState('all');
  const [index, setIndex] = useState<SearchEntry[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [recent, setRecent] = useState(initialRecent);
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    let live = true;
    fetch(`/app/search/data?lang=${encodeURIComponent(lang)}`)
      .then((r) => (r.ok ? r.json() : Promise.reject()))
      .then((d: { items?: SearchEntry[] }) => live && setIndex(d.items ?? []))
      .catch(() => live && setFailed(true));
    input.current?.focus();
    return () => {
      live = false;
    };
  }, [lang]);

  // Keep ?q= in the address bar so a search can be shared or reloaded.
  useEffect(() => {
    const t = setTimeout(() => {
      const url = query.trim() ? `/app/search?q=${encodeURIComponent(query.trim())}` : '/app/search';
      window.history.replaceState(window.history.state, '', url);
    }, 300);
    return () => clearTimeout(t);
  }, [query]);

  const hays = useMemo(() => (index ?? []).map((e) => `${e[2]} ${e[3]} ${e[0]} ${e[5]}`.toLowerCase()), [index]);

  const all: Result[] = useMemo(() => {
    const ws = words(query);
    if (!ws.length) return [];
    const phrase = query.trim().toLowerCase();
    const own = mine.filter((m) => ws.every((w) => m.hay.includes(w))).map((m) => ({ key: `m:${m.id}`, type: m.type, category: 'mine', title: m.title, subtitle: m.subtitle, href: m.href }));
    const scored: Array<[number, number, SearchEntry]> = [];
    (index ?? []).forEach((e, i) => {
      if (!ws.every((w) => hays[i].includes(w))) return;
      const title = e[2].toLowerCase();
      let sc = 1;
      if (title === phrase) sc = 5;
      else if (title.startsWith(phrase)) sc = 4;
      else if (ws.every((w) => title.includes(w))) sc = 3;
      else if (ws.every((w) => title.includes(w) || e[3].toLowerCase().includes(w))) sc = 2;
      scored.push([sc, i, e]);
    });
    scored.sort((a, b) => (a[0] !== b[0] ? b[0] - a[0] : a[1] - b[1]));
    return [...own, ...scored.map(([, i, e]) => ({ key: `i:${i}`, type: e[0], category: e[1], title: e[2], subtitle: e[3], href: e[4] }))];
  }, [query, mine, index, hays]);

  const inFilter = filter === 'all' ? all : all.filter((r) => r.category === filter);
  const shown = inFilter.slice(0, MAX);

  const remember = async (q: string) => {
    const v = q.trim();
    if (!v) return;
    const next = [v, ...recent.filter((x) => x !== v)].slice(0, 6);
    setRecent(next);
    await fetch(`/api/v1/state/${encodeURIComponent(RECENT)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ value: next }),
    }).catch(() => null);
  };
  const clearRecent = async () => {
    setRecent([]);
    await fetch(`/api/v1/state/${encodeURIComponent(RECENT)}`, { method: 'DELETE' }).catch(() => null);
  };

  return (
    <>
      <div className={h.top} style={{ gap: 8 }}>
        <button type="button" className={h.back} aria-label="Back" onClick={() => router.back()}>
          <Icon name="arrow_back" size={20} />
        </button>
        <form
          role="search"
          className={h.searchBox}
          onSubmit={(e) => {
            e.preventDefault();
            remember(query);
          }}
        >
          <Icon name="search" size={20} />
          <input
            ref={input}
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search tests, lessons, words, essays"
            aria-label="Search"
            enterKeyHint="search"
          />
          {query && (
            <button type="button" className={h.ghostBtn} style={{ width: 28, height: 28 }} aria-label="Clear search" onClick={() => setQuery('')}>
              <Icon name="close" size={20} />
            </button>
          )}
        </form>
      </div>

      <div className={h.chips} role="tablist" aria-label="Categories">
        {filters.map((f) => {
          const n = f.id === 'all' ? all.length : all.filter((r) => r.category === f.id).length;
          return (
            <button key={f.id} type="button" role="tab" aria-selected={filter === f.id} className={`${h.chip} ${filter === f.id ? h.chipOn : ''}`} style={{ height: 36, fontSize: 13 }} onClick={() => setFilter(f.id)}>
              {f.label} · {n}
            </button>
          );
        })}
      </div>

      {query.trim() && (
        <div style={{ borderRadius: 24, padding: '12px 16px 4px', background: 'var(--glass-fill)', border: '1px solid var(--glass-border)' }}>
          <div className={h.rowBetween} style={{ marginBottom: 6 }}>
            <span className={h.label} style={{ fontSize: 12 }} role="status">
              {!index && !failed ? 'Loading…' : inFilter.length > shown.length ? `Top ${shown.length} of ${inFilter.length} · add a word to narrow down` : 'Top results'}
            </span>
            <span className={h.label} style={{ fontSize: 12 }}>
              Relevance
            </span>
          </div>
          {failed && <p className={h.emptyNote}>Search is not available right now. Your own work is still searched.</p>}
          {(index || failed) && shown.length === 0 && <p className={h.emptyNote}>No results for “{query.trim()}”</p>}
          {shown.map((r) => (
            <Link key={r.key} href={r.href} className={h.row} onClick={() => remember(query)}>
              <span className={h.rowText}>
                <span className={h.rowTitle}>
                  <Highlight text={r.title} q={query.trim()} />
                </span>
                <span className={h.rowSub}>{r.subtitle}</span>
              </span>
              <span className={badgeClass(r.type)}>{r.type}</span>
            </Link>
          ))}
        </div>
      )}

      {recent.length > 0 && (
        <div style={{ borderRadius: 24, padding: '14px 16px', background: 'var(--glass-fill)', border: '1px solid var(--glass-border)' }}>
          <div className={h.rowBetween} style={{ marginBottom: 10 }}>
            <span className={h.label} style={{ fontSize: 12 }}>
              Recent searches
            </span>
            <button type="button" className={h.linkBtn} style={{ fontSize: 12, padding: 0, textDecoration: 'underline', color: 'var(--text)' }} onClick={clearRecent}>
              Clear
            </button>
          </div>
          <div className={h.pillChips} style={{ gap: 6 }}>
            {recent.map((r) => (
              <button key={r} type="button" className={h.recentChip} onClick={() => setQuery(r)}>
                <Icon name="schedule" size={14} />
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </>
  );
}
