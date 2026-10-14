import type { Metadata } from 'next';
import { Card, HeroCard, Nexi, Tag } from '@/components/ui';
import { str } from '@/lib/practice/marking';
import { attempts } from '@/lib/server/attempts';
import { getMe } from '@/lib/server/me';
import { mockList } from '@/lib/server/mocks';
import { formatBand } from '@/lib/writing/analysis';
import w from '../writing/writing.module.css';

export const metadata: Metadata = { title: 'Mock tests' };

/** Full Mock Tests (mock_library_screen.dart): all four skills in one sitting. */
export default async function MocksPage() {
  const [tests, mine, me] = await Promise.all([mockList(), attempts({ skill: 'mock', limit: 200 }), getMe()]);
  const best = new Map<string, number>();
  for (const a of mine) if (typeof a.band === 'number' && a.band > (best.get(a.refId) ?? -1)) best.set(a.refId, a.band);
  const latest = mine[0];
  const lim = (me.usage.limits?.mock ?? null) as { left?: number } | null;
  const free = me.usage.plan !== 'pro';
  const freeLeft = free && lim ? Number(lim.left ?? 0) : null;
  return (
    <>
      <HeroCard>
        <div className={w.row} style={{ alignItems: 'center' }}>
          <div className={w.grow}>
            <div className={w.taskLabel}>Full Mock Tests</div>
            <h1 className={w.taskTitle}>The real exam, start to finish</h1>
            <p style={{ margin: '6px 0 0', color: 'var(--hero-muted)', fontSize: 13.5 }}>
              Listening 40 min · Reading 60 min · Writing 60 min · Speaking 11–14 min
            </p>
            <div className={w.stats} style={{ marginTop: 10 }}>
              <span>
                <b>{tests.length}</b> tests
              </span>
              <span>
                <b>{mine.length}</b> done
              </span>
              {latest && typeof latest.band === 'number' && (
                <span>
                  Last band <b>{formatBand(latest.band)}</b>
                </span>
              )}
            </div>
          </div>
          <Nexi pose="grad" height={110} />
        </div>
      </HeroCard>

      {freeLeft !== null && (
        <Card padding={14} radius={20}>
          <p style={{ margin: 0, fontSize: 14 }}>
            {freeLeft > 0
              ? 'Your plan includes one free Full Mock Test with AI scoring. Pro unlocks all of them.'
              : 'Your free Full Mock Test is used. Upgrade to Pro to take the rest.'}
          </p>
        </Card>
      )}

      {mine.length > 0 && (
        <>
          <div className={w.moreHead}>Your results</div>
          <div className={w.qList}>
            {mine.slice(0, 5).map((a) => (
              <Card key={a.id} href={`/app/mocks/result/${a.id}`} padding={14} radius={22}>
                <div className={w.q}>
                  <span className={w.qNum}>{formatBand(a.band)}</span>
                  <div className={w.grow}>
                    <p className={w.qTitle}>{a.title}</p>
                    <p className={w.qText}>
                      {new Date(a.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Dhaka' })}
                    </p>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </>
      )}

      <div className={w.moreHead}>All mock tests</div>
      <div className={w.qList}>
        {tests.map((t) => {
          const id = str(t.id);
          return (
            <Card key={id} href={`/app/mocks/${id}`} padding={14} radius={22}>
              <div className={w.q}>
                <span className={w.qNum}>{str(t.number)}</span>
                <div className={w.grow}>
                  <p className={w.qTitle}>{str(t.title)}</p>
                  <div className={w.qMeta}>
                    <Tag>4 skills · about 3 hours</Tag>
                    {best.has(id) && <span className={w.done}>Best band {formatBand(best.get(id))}</span>}
                  </div>
                </div>
              </div>
            </Card>
          );
        })}
      </div>
    </>
  );
}
