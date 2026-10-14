import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon, Nexi, PrimaryButton } from '@/components/ui';
import { attempts } from '@/lib/server/attempts';
import { formatBand } from '@/lib/writing/analysis';
import w from '../../writing/writing.module.css';

export const metadata: Metadata = { title: 'Speaking history' };

const FILTERS: Array<[string, string]> = [
  ['all', 'All'],
  ['part1', 'Part 1'],
  ['part2', 'Part 2'],
  ['part3', 'Part 3'],
];

export default async function SpeakingHistory({ searchParams }: { searchParams: Promise<{ f?: string }> }) {
  const { f = 'all' } = await searchParams;
  const all = (await attempts({ skill: 'speaking', limit: 300 })).filter((a) => a.data.source || a.data.status === 'processing');
  const list = f === 'all' ? all : all.filter((a) => a.kind === f);
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/speaking" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Speaking
          </Link>
          <h1 className={w.title}>Speaking history</h1>
          <p className={w.sub}>{all.length} sessions</p>
        </div>
      </div>
      <nav className={w.chips}>
        {FILTERS.map(([k, label]) => (
          <Link key={k} href={k === 'all' ? '/app/speaking/history' : `/app/speaking/history?f=${k}`} className={`${w.chip} ${f === k ? w.chipOn : ''}`}>
            {label}
          </Link>
        ))}
      </nav>
      {list.length === 0 ? (
        <Card padding={24}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
            <Nexi pose="speaking" height={100} />
            <div style={{ flex: 1, minWidth: 200 }}>
              <h2 style={{ margin: '0 0 6px', fontSize: 20 }}>No speaking sessions yet</h2>
              <p style={{ margin: '0 0 12px', color: 'var(--text-soft)' }}>Answer a few Part 1 questions to get your first band score.</p>
              <PrimaryButton href="/app/speaking/part1">Start Part 1</PrimaryButton>
            </div>
          </div>
        </Card>
      ) : (
        <div className={w.qList}>
          {list.map((a) => (
            <Card key={a.id} href={`/app/speaking/result/${a.id}`} padding={14} radius={22}>
              <div className={w.q}>
                <span className={w.qNum} style={{ width: 48, fontSize: 16 }}>
                  {a.band == null ? '…' : formatBand(a.band)}
                </span>
                <div className={w.grow}>
                  <p className={w.qTitle}>{a.title}</p>
                  <p className={w.qText}>
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
