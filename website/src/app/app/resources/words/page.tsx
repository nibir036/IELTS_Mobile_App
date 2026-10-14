import type { Metadata } from 'next';
import Link from 'next/link';
import { bold } from '@/components/rich-text';
import { SaveWord } from '@/components/save-word';
import { Card, Icon, Tag } from '@/components/ui';
import { str, strs } from '@/lib/practice/marking';
import { stateValue } from '@/lib/server/attempts';
import { resourcesBank, type Raw } from '@/lib/server/resources';
import w from '../../writing/writing.module.css';
import s from './words.module.css';

export const metadata: Metadata = { title: 'Vocabulary' };

const TABS: Array<[string, string]> = [
  ['vocab', 'IELTS words'],
  ['academic', 'Academic words'],
  ['phrasal', 'Phrasal verbs'],
  ['idioms', 'Idioms'],
  ['topics', 'Topic vocabulary'],
  ['connectors', 'Linking words'],
  ['irregular', 'Irregular verbs'],
];
const PAGE = 40;

interface Entry {
  id: string;
  head: string;
  sub: string;
  meaning: string;
  examples: string[];
  extra: string[];
  band?: number;
  group?: string;
}

function entries(tab: string, b: Awaited<ReturnType<typeof resourcesBank>>): Entry[] {
  switch (tab) {
    case 'academic':
      return b.academicWords.map((x) => ({ id: str(x.id), head: str(x.word), sub: str(x.pos), meaning: str(x.definition), examples: [str(x.example)].filter(Boolean), extra: strs(x.family), group: str(x.list) }));
    case 'phrasal':
      return b.phrasalVerbs.map((x) => ({ id: str(x.id), head: str(x.phrase), sub: 'phrasal verb', meaning: str(x.meaning), examples: [str(x.example)].filter(Boolean), extra: [] }));
    case 'idioms':
      return b.idioms.map((x) => ({ id: str(x.id), head: str(x.phrase), sub: 'idiom', meaning: str(x.meaning), examples: [str(x.example)].filter(Boolean), extra: [] }));
    case 'topics':
      return b.topics.flatMap((t) =>
        ((t.items ?? []) as Raw[]).map((x) => ({ id: str(x.id), head: str(x.term), sub: str(t.title), meaning: str(x.meaning), examples: [str(x.example)].filter(Boolean), extra: [], group: str(t.title) })),
      );
    case 'connectors':
      return b.connectors.flatMap((c) =>
        ((c.items ?? []) as Raw[]).map((x) => ({ id: str(x.id), head: str(x.word), sub: `${str(c.title)}${x.register ? ` · ${str(x.register)}` : ''}`, meaning: str(x.use), examples: [str(x.example)].filter(Boolean), extra: [], group: str(c.title) })),
      );
    case 'irregular':
      return b.irregularVerbs.map((x) => ({ id: `iv_${str(x.base)}`, head: `${str(x.base)} · ${str(x.past)} · ${str(x.participle)}`, sub: 'base · past · past participle', meaning: str(x.meaning), examples: [str(x.example)].filter(Boolean), extra: [] }));
    default:
      return b.vocab.map((x) => ({
        id: str(x.id),
        head: str(x.word),
        sub: [str(x.ipa), str(x.pos)].filter(Boolean).join(' · '),
        meaning: str(x.definition),
        examples: strs(x.examples),
        extra: strs(x.synonyms),
        band: Number(x.band) || undefined,
      }));
  }
}

type Search = Promise<{ tab?: string; q?: string; band?: string; page?: string; saved?: string; group?: string }>;

/** Vocab Vault and the word lists (vocab_vault_screen, phrase_list_screen, academic_words_screen …). */
export default async function Words({ searchParams }: { searchParams: Search }) {
  const sp = await searchParams;
  const tab = TABS.some(([k]) => k === sp.tab) ? (sp.tab as string) : 'vocab';
  const [bank, savedRaw] = await Promise.all([resourcesBank(), stateValue<string[]>('resources.savedWords')]);
  const saved = new Set(Array.isArray(savedRaw) ? savedRaw : []);
  const all = entries(tab, bank);
  const groups = [...new Set(all.map((e) => e.group).filter(Boolean))] as string[];
  const q = (sp.q ?? '').trim().toLowerCase();
  const band = Number(sp.band) || 0;
  let list = all;
  if (q) list = list.filter((e) => e.head.toLowerCase().includes(q) || e.meaning.toLowerCase().includes(q));
  if (band) list = list.filter((e) => (e.band ?? 0) >= band);
  if (sp.saved) list = list.filter((e) => saved.has(e.id));
  if (sp.group) list = list.filter((e) => e.group === sp.group);
  const pages = Math.max(1, Math.ceil(list.length / PAGE));
  const page = Math.min(pages, Math.max(1, Number(sp.page) || 1));
  const shown = list.slice((page - 1) * PAGE, page * PAGE);
  const link = (o: Record<string, string | number | undefined>) => {
    const p = new URLSearchParams();
    const merged = { tab, q: sp.q, band: sp.band, saved: sp.saved, group: sp.group, ...o };
    for (const [k, v] of Object.entries(merged)) if (v !== undefined && v !== '') p.set(k, String(v));
    return `/app/resources/words?${p}`;
  };

  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/resources" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Resources
          </Link>
          <h1 className={w.title}>Vocabulary</h1>
          <p className={w.sub}>
            {all.length.toLocaleString('en-US')} entries · {saved.size} saved
          </p>
        </div>
      </div>

      <nav className={w.chips}>
        {TABS.map(([k, label]) => (
          <Link key={k} href={`/app/resources/words?tab=${k}`} className={`${w.chip} ${tab === k ? w.chipOn : ''}`}>
            {label}
          </Link>
        ))}
      </nav>

      {tab === 'irregular' && (
        <Card href="/app/resources/irregular-verbs" padding="12px 16px" radius={20}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <Icon name="edit_note" size={22} />
            <span style={{ flex: 1, minWidth: 0 }}>
              <b style={{ display: 'block', fontWeight: 600 }}>Practise irregular verbs</b>
              <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>Type the past simple and past participle · by letter or pattern</span>
            </span>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </span>
        </Card>
      )}

      <form className={s.search} action="/app/resources/words">
        <input type="hidden" name="tab" value={tab} />
        <Icon name="search" size={20} color="var(--text-muted)" />
        <input name="q" defaultValue={sp.q ?? ''} placeholder="Search words and meanings" className={s.searchInput} />
        {tab === 'vocab' && (
          <select name="band" defaultValue={sp.band ?? ''} className={s.select} aria-label="Band">
            <option value="">All bands</option>
            {[6, 7, 8, 9].map((b) => (
              <option key={b} value={b}>
                Band {b}+
              </option>
            ))}
          </select>
        )}
        {groups.length > 0 && (
          <select name="group" defaultValue={sp.group ?? ''} className={s.select} aria-label="Group">
            <option value="">All</option>
            {groups.map((g) => (
              <option key={g} value={g}>
                {g}
              </option>
            ))}
          </select>
        )}
        <label className={s.check}>
          <input type="checkbox" name="saved" value="1" defaultChecked={Boolean(sp.saved)} /> Saved
        </label>
        <button type="submit" className={s.go}>
          Search
        </button>
      </form>

      <p className={w.sub}>
        {list.length.toLocaleString('en-US')} results{pages > 1 ? ` · page ${page} of ${pages}` : ''}
      </p>

      <div className={s.list}>
        {shown.map((e) => (
          <Card key={e.id} padding={0} radius={18}>
            <details className={s.item}>
              <summary className={s.summary}>
                <span className={s.headWrap}>
                  <span className={s.head}>{e.head}</span>
                  <span className={s.subText}>{e.sub}</span>
                  <span className={s.meaning}>{e.meaning}</span>
                </span>
                {e.band ? <Tag>Band {e.band}</Tag> : null}
                {tab !== 'irregular' && <SaveWord id={e.id} saved={saved.has(e.id)} />}
              </summary>
              <div className={s.body}>
                {e.examples.map((x, i) => (
                  <p key={i} className={s.example}>
                    {bold(x)}
                  </p>
                ))}
                {e.extra.length > 0 && (
                  <p className={s.extra}>
                    {tab === 'academic' ? 'Word family' : 'Synonyms'}: {e.extra.join(', ')}
                  </p>
                )}
              </div>
            </details>
          </Card>
        ))}
      </div>

      {pages > 1 && (
        <nav className={s.pager}>
          {page > 1 && (
            <Link href={link({ page: page - 1 })} className={w.chip}>
              ← Previous
            </Link>
          )}
          <span className={w.sub}>
            {page} / {pages}
          </span>
          {page < pages && (
            <Link href={link({ page: page + 1 })} className={w.chip}>
              Next →
            </Link>
          )}
        </nav>
      )}
    </>
  );
}
