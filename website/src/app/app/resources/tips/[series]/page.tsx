import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon, Tag } from '@/components/ui';
import { articles } from '@/lib/server/articles';
import w from '../../../writing/writing.module.css';

export const metadata: Metadata = { title: 'Tips & strategies' };

const SERIES: Array<[string, string]> = [
  ['all', 'All'],
  ['writing', 'Writing'],
  ['speaking', 'Speaking'],
  ['reading', 'Reading'],
  ['listening', 'Listening'],
];

/** Tips & strategies (article_tips_screen.dart). */
export default async function TipsList({ params }: { params: Promise<{ series: string }> }) {
  const { series } = await params;
  const all = await articles();
  const list = series === 'all' ? all : all.filter((a) => a.series === series);
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/resources" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Resources
          </Link>
          <h1 className={w.title}>Tips &amp; strategies</h1>
          <p className={w.sub}>{list.length} guides from the nextED books</p>
        </div>
      </div>
      <nav className={w.chips}>
        {SERIES.map(([k, label]) => (
          <Link key={k} href={`/app/resources/tips/${k}`} className={`${w.chip} ${series === k ? w.chipOn : ''}`}>
            {label}
          </Link>
        ))}
      </nav>
      <div className={w.qList}>
        {list.map((a) => (
          <Card key={a.id} href={`/app/resources/article/${a.id}`} padding={16} radius={22}>
            <Tag tone="peach">{a.chip || a.series}</Tag>
            <p className={w.qTitle} style={{ marginTop: 8 }}>
              {a.title}
            </p>
            <p className={w.qText}>
              {a.meta} · {a.tips.length} sections
            </p>
          </Card>
        ))}
      </div>
    </>
  );
}
