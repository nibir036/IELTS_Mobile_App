import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/ui';
import f from '@/components/full-test.module.css';
import { attempts } from '@/lib/server/attempts';
import { writingTests } from '@/lib/server/writing';
import r from '../result/[id]/result.module.css';

export const metadata: Metadata = { title: 'Writing full tests' };

/** Writing Test 1–10: each opens Task 1 and Task 2 in the editor (WritingTestsScreen). */
export default async function WritingTestsPage() {
  const [tests, mine] = await Promise.all([writingTests(), attempts({ skill: 'writing', limit: 400 })]);
  const done = new Set(mine.map((a) => a.refId));
  return (
    <>
      <div className={r.top}>
        <Link href="/app/writing" className={r.back} aria-label="Back to Writing">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div>
          <h1 className={r.h1}>Writing full tests</h1>
          <p className={r.muted} style={{ margin: 0 }}>
            {tests.length} tests · Task 1 + Task 2 · 60 min
          </p>
        </div>
      </div>
      {tests.length === 0 && <p className={r.muted}>Full tests will appear here.</p>}
      {tests.map((t) => {
        const d = [t.task1, t.task2].map((p) => Boolean(p && done.has(p.id)));
        const finished = d.every(Boolean);
        const started = d.some(Boolean);
        return (
          <details key={t.id} className={f.test}>
            <summary>
              <span className={f.badge}>{t.number}</span>
              <span className={f.text}>
                <span className={f.titleRow}>
                  <span className={f.title}>{t.title}</span>
                  {finished ? <span className={`${f.tag} ${f.tagDone}`}>Done</span> : started ? <span className={f.tag}>Started</span> : null}
                </span>
                {t.task1 && (
                  <span className={f.line}>
                    Task 1 · {t.task1.typeName}
                    {t.task1.title ? ` · ${t.task1.title}` : ''}
                  </span>
                )}
                {t.task2 && (
                  <span className={f.line}>
                    Task 2 · {t.task2.typeName}
                    {t.task2.title ? ` · ${t.task2.title}` : ''}
                  </span>
                )}
              </span>
              <Icon name="chevron_right" size={18} className={f.chev} />
            </summary>
            <div className={f.parts}>
              <p className={f.hint}>Do Task 1 first (20 min), then Task 2 (40 min).</p>
              {t.task1 && (
                <Link href={`/app/writing/write/${encodeURIComponent(t.task1.id)}`} className={f.part}>
                  <span className={f.partIcon}>
                    <Icon name="bar_chart" size={18} />
                  </span>
                  <span className={f.partText}>
                    <span className={f.partTitle}>Task 1 · {t.task1.typeName}</span>
                    <span className={f.partSub}>{t.task1.title || 'Report'} · 20 min · 150+ words</span>
                  </span>
                  <Icon name={d[0] ? 'check_circle' : 'chevron_right'} size={20} color={d[0] ? 'var(--success)' : 'var(--text-muted)'} filled={d[0]} />
                </Link>
              )}
              {t.task2 && (
                <Link href={`/app/writing/write/${encodeURIComponent(t.task2.id)}`} className={f.part}>
                  <span className={f.partIcon}>
                    <Icon name="edit" size={18} />
                  </span>
                  <span className={f.partText}>
                    <span className={f.partTitle}>Task 2 · {t.task2.typeName}</span>
                    <span className={f.partSub}>{t.task2.title || 'Essay'} · 40 min · 250+ words</span>
                  </span>
                  <Icon name={d[1] ? 'check_circle' : 'chevron_right'} size={20} color={d[1] ? 'var(--success)' : 'var(--text-muted)'} filled={d[1]} />
                </Link>
              )}
            </div>
          </details>
        );
      })}
    </>
  );
}
