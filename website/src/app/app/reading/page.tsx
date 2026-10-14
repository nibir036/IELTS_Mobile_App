import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, HeroCard, Icon, Nexi, Tag } from '@/components/ui';
import { str } from '@/lib/practice/marking';
import { attempts } from '@/lib/server/attempts';
import { readingContent } from '@/lib/server/practice';
import { formatBand } from '@/lib/writing/analysis';
import w from '../writing/writing.module.css';

export const metadata: Metadata = { title: 'Reading' };

/** E1 · Reading (reading_landing_screen.dart): full tests, short practice tests, the question bank by type. */
export default async function ReadingHub() {
  const [c, mine] = await Promise.all([readingContent(), attempts({ skill: 'reading', limit: 300 })]);
  const best = new Map<string, number>();
  for (const a of mine) if (typeof a.band === 'number' && a.band > (best.get(a.refId) ?? -1)) best.set(a.refId, a.band);
  const types = new Map<string, { name: string; count: number }>();
  for (const p of c.bankPassages) {
    const t = str(p.questionType);
    const e = types.get(t) ?? { name: str(p.questionTypeName) || t, count: 0 };
    e.count++;
    types.set(t, e);
  }
  return (
    <>
      <HeroCard>
        <div className={w.row} style={{ alignItems: 'center' }}>
          <div className={w.grow}>
            <div className={w.taskLabel}>Reading</div>
            <h1 className={w.taskTitle}>Read faster, answer smarter</h1>
            <div className={w.stats} style={{ marginTop: 10 }}>
              <span>
                <b>{c.fullTests.length}</b> full tests
              </span>
              <span>
                <b>{c.practiceTests.length}</b> short tests
              </span>
              <span>
                <b>{c.bankPassages.length}</b> passages
              </span>
            </div>
          </div>
          <Nexi pose="reading" height={110} />
        </div>
      </HeroCard>

      <div className={w.qList}>
        <Card href="/app/courses/reading" padding={14} radius={22}>
          <div className={w.q}>
            <span className={w.qNum}>
              <Icon name="school" size={20} />
            </span>
            <div className={w.grow}>
              <p className={w.qTitle}>Reading Course</p>
              <p className={w.qText}>Bite-sized lessons with quick checks, from the nextED Reading book</p>
            </div>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </div>
        </Card>
        <Card href="/app/reading/lessons" padding={14} radius={22}>
          <div className={w.q}>
            <span className={w.qNum}>
              <Icon name="lightbulb" size={20} />
            </span>
            <div className={w.grow}>
              <p className={w.qTitle}>Strategy lessons</p>
              <p className={w.qText}>Reading skills with timed exercises, and how to attempt each question type</p>
            </div>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </div>
        </Card>
        <Card href="/app/guides/reading" padding={14} radius={22}>
          <div className={w.q}>
            <span className={w.qNum}>
              <Icon name="article" size={20} />
            </span>
            <div className={w.grow}>
              <p className={w.qTitle}>Reading Guide</p>
              <p className={w.qText}>The full book, chapter by chapter, with exercises</p>
            </div>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </div>
        </Card>
      </div>

      <div className={w.moreHead}>
        Full reading tests · 60 min <Link href="/app/reading/history">History</Link>
      </div>
      <div className={w.qList}>
        {c.fullTests.map((t) => (
          <Card key={str(t.id)} href={`/app/reading/do/${str(t.id)}`} padding={14} radius={22}>
            <div className={w.q}>
              <span className={w.qNum}>{str(t.number)}</span>
              <div className={w.grow}>
                <p className={w.qTitle}>{str(t.title)}</p>
                <div className={w.qMeta}>
                  <Tag>3 passages · 40 questions</Tag>
                  {best.has(str(t.id)) && <span className={w.done}>Best band {formatBand(best.get(str(t.id)))}</span>}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <div className={w.moreHead}>Short practice tests</div>
      <div className={w.qList}>
        {c.practiceTests.map((t) => (
          <Card key={str(t.id)} href={`/app/reading/do/${str(t.id)}`} padding={14} radius={22}>
            <div className={w.q}>
              <span className={w.qNum}>{str(t.number)}</span>
              <div className={w.grow}>
                <p className={w.qTitle}>{str(t.title)}</p>
                <div className={w.qMeta}>
                  <Tag>
                    {str(t.questionCount)} questions · {str(t.minutes)} min
                  </Tag>
                  {best.has(str(t.id)) && <span className={w.done}>Best band {formatBand(best.get(str(t.id)))}</span>}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <div className={w.moreHead}>Question bank by type</div>
      <div className={w.more}>
        {[...types.entries()].map(([t, e]) => (
          <Card key={t} href={`/app/reading/type/${t}`} padding={14} radius={20}>
            <div className={w.moreRow}>
              <span className={w.twoLine}>
                <b>{e.name}</b>
                <span style={{ color: 'var(--text-muted)', opacity: 1 }}>{e.count} passages</span>
              </span>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
