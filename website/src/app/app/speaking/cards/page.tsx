import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon, PrimaryButton, Tag } from '@/components/ui';
import { attempts } from '@/lib/server/attempts';
import { speakingBank } from '@/lib/server/speaking';
import { formatBand } from '@/lib/writing/analysis';
import w from '../../writing/writing.module.css';

export const metadata: Metadata = { title: 'Cue cards' };

/** Cue card vault (cue_card_vault_screen.dart): every Part 2 card by category. */
export default async function Cards({ searchParams }: { searchParams: Promise<{ c?: string }> }) {
  const { c } = await searchParams;
  const [bank, mine] = await Promise.all([speakingBank(), attempts({ skill: 'speaking', kind: 'part2', limit: 300 })]);
  const best = new Map<string, number>();
  for (const a of mine) if (typeof a.band === 'number' && a.band > (best.get(a.refId) ?? -1)) best.set(a.refId, a.band);
  const cats = [...new Map(bank.cards.map((x) => [x.category, x.categoryLabel])).entries()];
  const list = c ? bank.cards.filter((x) => x.category === c) : bank.cards;
  const fresh = list.filter((x) => !best.has(x.id));
  const pool = fresh.length ? fresh : list;
  const pick = pool[Math.floor(Math.random() * Math.max(1, pool.length))];
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/speaking" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Speaking
          </Link>
          <h1 className={w.title}>Part 2 · Cue cards</h1>
          <p className={w.sub}>{list.length} cards · 1 minute to prepare, up to 2 minutes to speak</p>
        </div>
        {pick && (
          <PrimaryButton href={`/app/speaking/cue/${pick.id}`} leading="shuffle">
            Random card
          </PrimaryButton>
        )}
      </div>
      <nav className={w.chips}>
        <Link href="/app/speaking/cards" className={`${w.chip} ${!c ? w.chipOn : ''}`}>
          All
        </Link>
        {cats.map(([id, label]) => (
          <Link key={id} href={`/app/speaking/cards?c=${id}`} className={`${w.chip} ${c === id ? w.chipOn : ''}`}>
            {label}
          </Link>
        ))}
      </nav>
      <div className={w.qList}>
        {list.map((x) => (
          <Card key={x.id} href={`/app/speaking/cue/${x.id}`} padding={14} radius={22}>
            <div className={w.q}>
              <span className={w.qNum}>{x.number || '·'}</span>
              <div className={w.grow}>
                <p className={w.qTitle}>{x.title}</p>
                <p className={w.qText}>You should say: {x.bullets.join(', ')}</p>
                <div className={w.qMeta}>
                  <Tag>{x.categoryLabel}</Tag>
                  {best.has(x.id) && <span className={w.done}>Best band {formatBand(best.get(x.id))}</span>}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
