import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon, Nexi, PrimaryButton } from '@/components/ui';
import { attempts } from '@/lib/server/attempts';
import { formatBand } from '@/lib/writing/analysis';
import s from '../writing.module.css';

export const metadata: Metadata = { title: 'Essay history' };

const FILTERS: Array<[string, string]> = [
  ['all', 'All'],
  ['task1', 'Task 1'],
  ['task2', 'Task 2'],
  ['mock', 'Mock'],
];

/** Essay history (essay_history_screen.dart): every essay, newest first. */
export default async function History({ searchParams }: { searchParams: Promise<{ f?: string }> }) {
  const { f = 'all' } = await searchParams;
  const all = await attempts({ skill: 'writing', limit: 300 });
  const list = all.filter((a) => (f === 'all' ? true : f === 'mock' ? a.kind.startsWith('mock') || a.kind === 'test' : a.kind === f));
  return (
    <>
      <div className={s.head}>
        <div>
          <Link href="/app/writing" className={s.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Writing
          </Link>
          <h1 className={s.title}>Essay history</h1>
          <p className={s.sub}>{all.length} essays</p>
        </div>
      </div>
      <nav className={s.chips}>
        {FILTERS.map(([k, label]) => (
          <Link key={k} href={k === 'all' ? '/app/writing/history' : `/app/writing/history?f=${k}`} className={`${s.chip} ${f === k ? s.chipOn : ''}`}>
            {label}
          </Link>
        ))}
      </nav>
      {list.length === 0 ? (
        <Card padding={24}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
            <Nexi pose="writing" height={100} />
            <div style={{ flex: 1, minWidth: 200 }}>
              <h2 style={{ margin: '0 0 6px', fontSize: 20 }}>No essays yet</h2>
              <p style={{ margin: '0 0 12px', color: 'var(--text-soft)' }}>
                Write a Task 1 report or a Task 2 essay to get your band score and line-by-line AI feedback.
              </p>
              <PrimaryButton href="/app/writing">Start writing</PrimaryButton>
            </div>
          </div>
        </Card>
      ) : (
        <div className={s.qList}>
          {list.map((a) => (
            <Card key={a.id} href={`/app/writing/result/${a.id}`} padding={14} radius={22}>
              <div className={s.q}>
                <span className={s.qNum} style={{ width: 48, fontSize: 16 }}>
                  {formatBand(a.band)}
                </span>
                <div className={s.grow}>
                  <p className={s.qTitle}>{a.title || 'Essay'}</p>
                  <p className={s.qText}>
                    {a.kind === 'task1' ? 'Task 1' : a.kind === 'task2' ? 'Task 2' : 'Writing test'} ·{' '}
                    {new Date(a.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Dhaka' })}
                  </p>
                </div>
                <Icon name="chevron_right" size={20} color="var(--text-muted)" />
              </div>
            </Card>
          ))}
        </div>
      )}
    </>
  );
}
