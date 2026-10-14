import Link from 'next/link';
import type { Attempt } from '@/lib/server/attempts';
import { formatBand } from '@/lib/writing/analysis';
import { Card, Icon } from './ui';
import w from '@/app/app/writing/writing.module.css';

/** A list of past attempts (band, title, score, date). */
export function HistoryList({ title, back, backLabel, items, base }: { title: string; back: string; backLabel: string; items: Attempt[]; base: string }) {
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href={back} className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> {backLabel}
          </Link>
          <h1 className={w.title}>{title}</h1>
          <p className={w.sub}>{items.length} attempts</p>
        </div>
      </div>
      {items.length === 0 ? (
        <Card padding={20}>Nothing here yet. Your results will appear here after your first try.</Card>
      ) : (
        <div className={w.qList}>
          {items.map((a) => (
            <Card key={a.id} href={`${base}/${a.id}`} padding={14} radius={22}>
              <div className={w.q}>
                <span className={w.qNum} style={{ width: 48, fontSize: 16 }}>
                  {formatBand(a.band)}
                </span>
                <div className={w.grow}>
                  <p className={w.qTitle}>{a.title}</p>
                  <p className={w.qText}>
                    {a.score != null && a.total ? `${a.score} / ${a.total} correct · ` : ''}
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
