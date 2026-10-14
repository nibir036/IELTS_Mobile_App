import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, HeroCard, Icon, Nexi, Tag } from '@/components/ui';
import { str } from '@/lib/practice/marking';
import { attempts } from '@/lib/server/attempts';
import { listeningBankSets, listeningTests } from '@/lib/server/practice';
import { formatBand } from '@/lib/writing/analysis';
import w from '../writing/writing.module.css';

export const metadata: Metadata = { title: 'Listening' };

const PART_INFO: Record<number, string> = {
  1: 'Everyday conversation · forms and notes',
  2: 'Talk about a place or event · maps and choices',
  3: 'Students and a tutor discussing · matching and choices',
  4: 'Academic lecture · notes and summaries',
};

/** F1 · Listening (listening_landing_screen.dart): full tests and practice by part. */
export default async function ListeningHub({ searchParams }: { searchParams: Promise<{ part?: string }> }) {
  const { part } = await searchParams;
  const [sets, full, mine] = await Promise.all([listeningBankSets(), listeningTests(), attempts({ skill: 'listening', limit: 300 })]);
  const best = new Map<string, number>();
  for (const a of mine) if (typeof a.band === 'number' && a.band > (best.get(a.refId) ?? -1)) best.set(a.refId, a.band);
  const p = Number(part) || 0;
  const shown = p ? sets.filter((x) => Number(x.part) === p) : sets;
  return (
    <>
      <HeroCard>
        <div className={w.row} style={{ alignItems: 'center' }}>
          <div className={w.grow}>
            <div className={w.taskLabel}>Listening</div>
            <h1 className={w.taskTitle}>Train your ear</h1>
            <div className={w.stats} style={{ marginTop: 10 }}>
              <span>
                <b>{full.tests.length}</b> full tests
              </span>
              <span>
                <b>{sets.length}</b> practice sets
              </span>
              <span>
                <b>{mine.length}</b> done
              </span>
            </div>
          </div>
          <Nexi pose="listening" height={110} />
        </div>
      </HeroCard>

      <div className={w.qList}>
        <Card href="/app/courses/listening" padding={14} radius={22}>
          <div className={w.q}>
            <span className={w.qNum}>
              <Icon name="school" size={20} />
            </span>
            <div className={w.grow}>
              <p className={w.qTitle}>Listening Course</p>
              <p className={w.qText}>Bite-sized lessons with quick checks, from the nextED Listening book</p>
            </div>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </div>
        </Card>
        <Card href="/app/listening/lessons" padding={14} radius={22}>
          <div className={w.q}>
            <span className={w.qNum}>
              <Icon name="lightbulb" size={20} />
            </span>
            <div className={w.grow}>
              <p className={w.qTitle}>Bite-size Lessons</p>
              <p className={w.qText}>Short lessons, each with an audio exercise</p>
            </div>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </div>
        </Card>
        <Card href="/app/guides/listening" padding={14} radius={22}>
          <div className={w.q}>
            <span className={w.qNum}>
              <Icon name="article" size={20} />
            </span>
            <div className={w.grow}>
              <p className={w.qTitle}>Listening Guide</p>
              <p className={w.qText}>The full book, chapter by chapter, with exercises</p>
            </div>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </div>
        </Card>
      </div>

      <div className={w.moreHead}>
        Full listening tests <Link href="/app/listening/history">History</Link>
      </div>
      <div className={w.qList}>
        {full.tests.map((t) => (
          <Card key={str(t.id)} href={`/app/listening/test/${str(t.id)}`} padding={14} radius={22}>
            <div className={w.q}>
              <span className={w.qNum}>{str(t.number)}</span>
              <div className={w.grow}>
                <p className={w.qTitle}>{str(t.title)}</p>
                <p className={w.qText}>{str(t.description)}</p>
                <div className={w.qMeta}>
                  <Tag>4 parts · 40 questions</Tag>
                  {best.has(str(t.id)) && <span className={w.done}>Best band {formatBand(best.get(str(t.id)))}</span>}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <div className={w.moreHead}>Practice by part</div>
      <nav className={w.chips}>
        <Link href="/app/listening" className={`${w.chip} ${!p ? w.chipOn : ''}`}>
          All parts
        </Link>
        {[1, 2, 3, 4].map((n) => (
          <Link key={n} href={`/app/listening?part=${n}`} className={`${w.chip} ${p === n ? w.chipOn : ''}`}>
            Part {n}
          </Link>
        ))}
      </nav>
      {p ? <p className={w.sub}>{PART_INFO[p]}</p> : null}
      <div className={w.qList}>
        {shown.map((x) => (
          <Card key={str(x.id)} href={`/app/listening/set/${str(x.id)}`} padding={14} radius={22}>
            <div className={w.q}>
              <span className={w.qNum}>P{str(x.part)}</span>
              <div className={w.grow}>
                <p className={w.qTitle}>{str(x.title)}</p>
                <p className={w.qText}>{str(x.scenario || x.context)}</p>
                <div className={w.qMeta}>
                  <Tag>{str(x.formatLabel)}</Tag>
                  <Tag>{str(x.questionCount)} questions</Tag>
                  {best.has(str(x.id)) && <span className={w.done}>Best band {formatBand(best.get(str(x.id)))}</span>}
                </div>
              </div>
              <Icon name="headphones" size={20} color="var(--text-muted)" />
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
