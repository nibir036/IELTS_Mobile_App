import type { Metadata } from 'next';
import { SearchView, type MineEntry } from '@/components/home/search-view';
import { homeSection, myAttempts, stateValue } from '@/lib/home/server';
import { formatBand, resultHref, skillLabel } from '@/lib/home/stats';
import { dayKey, shortDate } from '@/lib/home/time';
import { currentLang } from '@/lib/server/content';

export const metadata: Metadata = { title: 'Search' };

/** B8 · Search (search_screen.dart + search_index.dart). */
export default async function SearchPage({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const sp = await searchParams;
  const [home, mine, recent, lang] = await Promise.all([homeSection(), myAttempts(), stateValue<unknown[]>('search.recent'), currentLang()]);
  const filters = (((home.search ?? {}) as Record<string, unknown>).filters as Array<{ id: string; label: string }> | undefined) ?? [{ id: 'all', label: 'All' }];

  // The student's own work (essays, recordings, tests), searched first.
  const own: MineEntry[] = mine
    .filter((a) => a.kind !== 'session')
    .map((a) => {
      const type = a.skill === 'writing' ? 'Essay' : a.skill === 'speaking' ? 'Recording' : a.skill === 'mock' ? 'Mock' : 'Result';
      const title = a.title || skillLabel(a.skill);
      return {
        id: a.id,
        type,
        title,
        subtitle: [`Your ${skillLabel(a.skill).toLowerCase()}`, a.band != null ? `Band ${formatBand(a.band)}` : '', shortDate(dayKey(new Date(a.createdAt)))].filter(Boolean).join(' · '),
        href: resultHref(a),
        hay: `${title} ${skillLabel(a.skill)} ${type} ${a.kind}`.toLowerCase(),
      };
    });

  return (
    <SearchView
      lang={lang.code}
      filters={filters}
      mine={own}
      recent={Array.isArray(recent) ? recent.map(String).slice(0, 6) : []}
      initialQuery={typeof sp.q === 'string' ? sp.q.slice(0, 200) : ''}
    />
  );
}
