import type { Metadata } from 'next';
import Link from 'next/link';
import { WordCard } from '@/components/extras/word-card';
import { Card, Icon, Tag } from '@/components/ui';
import { libraryBank, samplesHref, savedKey, vocabEntry, wordKeys, type SamplePart } from '@/lib/extras/speaking-library';
import { rows, str, strs, type Raw } from '@/lib/practice/marking';
import { stateValue } from '@/lib/server/attempts';
import x from '@/components/extras/extras.module.css';
import r from '@/components/extras/speaking.module.css';

export const metadata: Metadata = { title: 'Speaking sample answers' };

const TABS: Array<[string, string]> = [
  ['part1', 'Part 1'],
  ['part2', 'Part 2'],
  ['part3', 'Part 3'],
  ['words', 'Words'],
];
const LEVELS = ['B2', 'C1', 'C2'];
const PAGE = 60;
const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');

type Search = Promise<{ tab?: string; q?: string; f?: string; page?: string }>;

/** D11 · Speaking question bank & vocabulary (speaking_library_screen.dart): every Part 1 topic, cue card and Part 3 topic with sample answers, plus the word list. */
export default async function SpeakingLibrary({ searchParams }: { searchParams: Search }) {
  const sp = await searchParams;
  const tab = TABS.some(([k]) => k === sp.tab) ? (sp.tab as string) : 'part1';
  const part = (tab === 'words' ? 0 : Number(tab.slice(4))) as 0 | SamplePart;
  const bank = await libraryBank();
  const saved = part ? await stateValue<unknown[]>(savedKey(part)) : null;
  const savedSet = new Set(Array.isArray(saved) ? saved.map(String) : []);
  const counts = (bank.meta.counts ?? {}) as Raw;
  const keys = wordKeys(bank.vocab);
  const q = (sp.q ?? '').trim().toLowerCase();
  const f = sp.f ?? '';
  const has = (fields: string[]) => !q || fields.some((s) => s.toLowerCase().includes(q));
  const cats = part ? rows(bank.meta[`part${part}Categories`]).map((c) => ({ id: str(c.id), label: str(c.label) })) : [];
  const filters: Array<[string, string]> = part ? [['', 'All'], ['saved', 'Saved'], ...cats.map((c) => [c.id, c.label] as [string, string])] : [['', 'All'], ...LEVELS.map((l) => [l, l] as [string, string])];
  const catOk = (m: Raw) => !f || (f === 'saved' ? savedSet.has(str(m.id)) : str(m.category) === f);

  type Row = { id: string; title: string; subtitle: string; level?: string };
  let list: Row[] = [];
  if (part === 1) {
    list = bank.part1
      .filter((t) => catOk(t) && has([str(t.topic), ...strs(t.questions)]))
      .map((t) => ({ id: str(t.id), title: str(t.topic), subtitle: `${rows(t.samples).length} questions · ${str(t.categoryLabel)}` }));
  } else if (part === 2) {
    list = bank.cards
      .filter((c) => catOk(c) && has([str(c.title), ...strs(c.bullets)]))
      .map((c) => ({ id: str(c.id), title: str(c.title), subtitle: `${str(c.categoryLabel)} · ${Number((c.sample as Raw | undefined)?.words) || 0}-word sample talk` }));
  } else if (part === 3) {
    list = bank.part3
      .filter((t) => catOk(t) && has([str(t.topic), str(t.description), ...rows(t.questions).map((x) => str(x.q))]))
      .map((t) => ({ id: str(t.id), title: str(t.topic), subtitle: `${rows(t.questions).length} questions · ${str(t.categoryLabel)}` }));
  } else {
    for (const k of keys) {
      const e = vocabEntry(bank.vocab, k);
      if (!e || (f && e.level !== f)) continue;
      if (!has([e.headword, e.meaning, ...e.synonyms])) continue;
      list.push({ id: k, title: e.headword, subtitle: e.meaning, level: e.level });
    }
  }
  const pages = Math.max(1, Math.ceil(list.length / PAGE));
  const page = Math.min(pages, Math.max(1, Number(sp.page) || 1));
  const shown = part ? list : list.slice((page - 1) * PAGE, page * PAGE);
  const link = (o: Record<string, string | number | undefined>) => {
    const p = new URLSearchParams();
    for (const [k, v] of Object.entries({ tab, q: sp.q, f, ...o })) if (v !== undefined && v !== '') p.set(k, String(v));
    return `/app/speaking/library?${p}`;
  };
  const hasBank = bank.cards.length > 0;

  return (
    <div className={x.page}>
      <div className={x.top}>
        <Link href="/app/speaking" className={x.iconBtn} aria-label="Back to Speaking">
          <Icon name="arrow_back" size={20} />
        </Link>
      </div>
      <div>
        <h1 className={x.h1}>Sample answers</h1>
        <p className={x.lead}>
          {hasBank
            ? `${Number(counts.part1Topics) || bank.part1.length} Part 1 topics · ${Number(counts.part2Cards) || bank.cards.length} cue cards · ${Number(counts.part3Topics) || bank.part3.length} Part 3 topics · ${keys.length} words`
            : 'The speaking question bank is not available right now.'}
        </p>
      </div>

      <nav className={x.seg} aria-label="Part">
        {TABS.map(([k, label]) => (
          <Link key={k} href={`/app/speaking/library?tab=${k}`} className={cx(x.segBtn, tab === k && x.segOn)} aria-current={tab === k ? 'page' : undefined}>
            {label}
          </Link>
        ))}
      </nav>

      <form className={r.search} action="/app/speaking/library" role="search">
        <input type="hidden" name="tab" value={tab} />
        {f && <input type="hidden" name="f" value={f} />}
        <Icon name="search" size={18} color="var(--text-muted)" />
        <input
          name="q"
          defaultValue={sp.q ?? ''}
          className={r.searchInput}
          placeholder={part ? 'Search topics and questions' : 'Search a word or meaning'}
          aria-label={part ? 'Search topics and questions' : 'Search a word or meaning'}
        />
        <button type="submit" className={r.go}>
          Search
        </button>
      </form>

      <nav className={x.chips} aria-label="Filter">
        {filters.map(([id, label]) => (
          <Link key={id || 'all'} href={link({ f: id, page: undefined })} className={cx(x.chip, f === id && x.chipOn)} aria-current={f === id ? 'true' : undefined}>
            {id === 'saved' && <Icon name="bookmark" size={16} />}
            {label}
          </Link>
        ))}
      </nav>

      <p className={x.small}>
        {list.length.toLocaleString('en-US')} {part ? 'items' : 'words'}
        {!part && pages > 1 ? ` · page ${page} of ${pages}` : ''}
      </p>

      {shown.length === 0 ? (
        <Card>
          <div className={x.empty}>
            <Icon name={f === 'saved' ? 'bookmark' : 'search_off'} size={32} color="var(--text-muted)" />
            <p className={x.emptyText}>
              {f === 'saved' && !q ? 'Nothing saved yet. Tap the bookmark on a sample answer page to keep it here.' : 'Nothing matches your search.'}
            </p>
          </div>
        </Card>
      ) : part ? (
        <Card padding="4px 18px" radius={24}>
          <div className={cx(r.list, r.listGrid)}>
            {shown.map((row) => (
              <Link key={row.id} href={samplesHref(row.id)} className={r.listRow}>
                <span className={r.listText}>
                  <span className={r.listTitle}>{row.title}</span>
                  <span className={r.listSub}>{row.subtitle}</span>
                </span>
                {savedSet.has(row.id) && <Icon name="bookmark" size={18} filled color="var(--peach)" />}
                <Icon name="chevron_right" size={18} color="var(--text-muted)" />
              </Link>
            ))}
          </div>
        </Card>
      ) : (
        <Card padding="4px 18px" radius={24}>
          <div className={r.list}>
            {shown.map((row) => {
              const e = vocabEntry(bank.vocab, row.id);
              return (
                <details key={row.id} className={r.word}>
                  <summary>
                    <span className={r.listRow}>
                      <span className={r.listText}>
                        <span className={r.listTitle}>{row.title}</span>
                        <span className={r.listSub}>{row.subtitle}</span>
                      </span>
                      {row.level && <Tag>{row.level}</Tag>}
                      <Icon name="expand_more" size={18} color="var(--text-muted)" />
                    </span>
                  </summary>
                  {e && (
                    <div className={r.wordBody}>
                      <WordCard e={e} hideHead />
                    </div>
                  )}
                </details>
              );
            })}
          </div>
        </Card>
      )}

      {!part && pages > 1 && (
        <nav className={x.footer} style={{ justifyContent: 'center' }} aria-label="Pages">
          {page > 1 && (
            <Link href={link({ page: page - 1 })} className={x.chip}>
              ← Previous
            </Link>
          )}
          <span className={x.small}>
            {page} / {pages}
          </span>
          {page < pages && (
            <Link href={link({ page: page + 1 })} className={x.chip}>
              Next →
            </Link>
          )}
        </nav>
      )}
    </div>
  );
}
