import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon } from '@/components/ui';
import f from '@/components/full-test.module.css';
import { attempts } from '@/lib/server/attempts';
import { speakingTests } from '@/lib/server/speaking';
import r from '../../writing/result/[id]/result.module.css';

export const metadata: Metadata = { title: 'Speaking full tests' };

/** Speaking Test 1–10: Part 1, the cue card and Part 3 in order (SpeakingTestsScreen). */
export default async function SpeakingTestsPage() {
  const [tests, mine] = await Promise.all([speakingTests(), attempts({ skill: 'speaking', limit: 400 })]);
  const done = new Set(mine.map((a) => a.refId));
  return (
    <>
      <div className={r.top}>
        <Link href="/app/speaking" className={r.back} aria-label="Back to Speaking">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div>
          <h1 className={r.h1}>Speaking full tests</h1>
          <p className={r.muted} style={{ margin: 0 }}>
            {tests.length} tests · Parts 1, 2 and 3 · 11–14 min
          </p>
        </div>
      </div>
      {tests.length === 0 && <p className={r.muted}>Full tests will appear here.</p>}
      {tests.map((t) => {
        const d = [Boolean(t.part1 && done.has(t.part1.id)), Boolean(t.card && done.has(t.card.id))];
        const finished = d.every(Boolean);
        const started = d.some(Boolean);
        const p3 = t.part3.map((x) => x.topic).join(' · ');
        const rows: Array<{ icon: string; title: string; sub: string; href: string; done: boolean }> = [
          ...(t.part1
            ? [{ icon: 'chat', title: 'Part 1 · Interview', sub: `${t.part1.topic} · ${t.part1.questions.length} questions · 4–5 min`, href: `/app/speaking/session/1/${encodeURIComponent(t.part1.id)}`, done: d[0] }]
            : []),
          ...(t.card
            ? [
                { icon: 'mic', title: 'Part 2 · Cue card', sub: `${t.card.title} · 1 min to prepare, 2 min to speak`, href: `/app/speaking/cue/${encodeURIComponent(t.card.id)}`, done: d[1] },
                { icon: 'forum', title: 'Part 3 · Discussion', sub: `${p3 || 'Follow-up questions'} · 4–5 min`, href: `/app/speaking/session/3/${encodeURIComponent(t.card.id)}`, done: false },
              ]
            : []),
        ];
        return (
          <details key={t.id} className={f.test}>
            <summary>
              <span className={f.badge}>{t.number}</span>
              <span className={f.text}>
                <span className={f.titleRow}>
                  <span className={f.title}>{t.title}</span>
                  {finished ? <span className={`${f.tag} ${f.tagDone}`}>Done</span> : started ? <span className={f.tag}>Started</span> : null}
                </span>
                {t.part1 && <span className={f.line}>Part 1 · {t.part1.topic}</span>}
                {t.card && <span className={f.line}>Part 2 · {t.card.title}</span>}
                {p3 && <span className={f.line}>Part 3 · {p3}</span>}
              </span>
              <Icon name="chevron_right" size={18} className={f.chev} />
            </summary>
            <div className={f.parts}>
              <p className={f.hint}>Take the parts in order, like the real interview.</p>
              {rows.map((x) => (
                <Link key={x.href} href={x.href} className={f.part}>
                  <span className={f.partIcon}>
                    <Icon name={x.icon} size={18} />
                  </span>
                  <span className={f.partText}>
                    <span className={f.partTitle}>{x.title}</span>
                    <span className={f.partSub}>{x.sub}</span>
                  </span>
                  <Icon name={x.done ? 'check_circle' : 'chevron_right'} size={20} color={x.done ? 'var(--success)' : 'var(--text-muted)'} filled={x.done} />
                </Link>
              ))}
            </div>
          </details>
        );
      })}
    </>
  );
}
