import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { RichText } from '@/components/rich-text';
import { Card, Icon } from '@/components/ui';
import { articles } from '@/lib/server/articles';
import w from '../../../writing/writing.module.css';

export const metadata: Metadata = { title: 'Tips' };

export default async function ArticlePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const all = await articles();
  const a = all.find((x) => x.id === id);
  if (!a) notFound();
  const same = all.filter((x) => x.series === a.series);
  const next = same[same.indexOf(a) + 1];
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href={`/app/resources/tips/${a.series}`} className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> {a.series[0]?.toUpperCase()}
            {a.series.slice(1)} tips
          </Link>
          <h1 className={w.title}>{a.title}</h1>
          <p className={w.sub}>{a.meta}</p>
        </div>
      </div>
      <nav className={w.chips}>
        {a.tips.map((t, i) => (
          <a key={i} href={`#tip${i + 1}`} className={w.chip}>
            {i + 1}. {t.title}
          </a>
        ))}
      </nav>
      {a.tips.map((t, i) => (
        <Card key={i} padding={20}>
          <h2 id={`tip${i + 1}`} style={{ margin: '0 0 10px', fontSize: 19, fontWeight: 600, scrollMarginTop: 16 }}>
            {i + 1}. {t.title}
          </h2>
          <RichText text={t.body} />
        </Card>
      ))}
      {next && (
        <Card href={`/app/resources/article/${next.id}`} padding={16}>
          <span className={w.sub}>Next guide</span>
          <p className={w.qTitle}>{next.title}</p>
        </Card>
      )}
    </>
  );
}
