import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon, Tag } from '@/components/ui';
import { writingPrompts } from '@/lib/server/writing';
import s from '../writing.module.css';

export const metadata: Metadata = { title: 'Sample answers' };

export default async function SampleList({ searchParams }: { searchParams: Promise<{ task?: string }> }) {
  const { task } = await searchParams;
  const t = task === '1' ? 1 : task === '2' ? 2 : undefined;
  const list = (await writingPrompts(t)).filter((p) => p.samples.length || p.modelAnswer);
  return (
    <>
      <div className={s.head}>
        <div>
          <Link href="/app/writing" className={s.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Writing
          </Link>
          <h1 className={s.title}>Sample answers</h1>
          <p className={s.sub}>Band 6, 7 and 8 answers for every question</p>
        </div>
      </div>
      <nav className={s.chips}>
        {[
          ['All', ''],
          ['Task 1', '1'],
          ['Task 2', '2'],
        ].map(([label, v]) => (
          <Link key={label} href={v ? `/app/writing/samples?task=${v}` : '/app/writing/samples'} className={`${s.chip} ${(task ?? '') === v ? s.chipOn : ''}`}>
            {label}
          </Link>
        ))}
      </nav>
      <div className={s.qList}>
        {list.map((p) => (
          <Card key={p.id} href={`/app/writing/samples/${p.id}`} padding={14} radius={22}>
            <div className={s.q}>
              <span className={s.qNum}>{p.number || '·'}</span>
              <div className={s.grow}>
                <p className={s.qTitle}>{p.title}</p>
                <p className={s.qText}>{p.statement || p.prompt}</p>
                <div className={s.qMeta}>
                  <Tag>Task {p.task}</Tag>
                  <Tag>{p.typeName}</Tag>
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
