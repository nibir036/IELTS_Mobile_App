import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Card, Icon, PrimaryButton, Tag } from '@/components/ui';
import { attempts } from '@/lib/server/attempts';
import { writingPrompts } from '@/lib/server/writing';
import { formatBand } from '@/lib/writing/analysis';
import { typeName } from '@/lib/writing/prompts';
import s from '../../writing.module.css';

export const metadata: Metadata = { title: 'Writing questions' };

type Params = Promise<{ task: string }>;
type Search = Promise<{ type?: string }>;

/** Every question of a task: filter by type, pick one or a random one (question_lists_screens.dart). */
export default async function Questions({ params, searchParams }: { params: Params; searchParams: Search }) {
  const { task: raw } = await params;
  const { type } = await searchParams;
  if (raw !== '1' && raw !== '2') notFound();
  const task = raw === '1' ? 1 : 2;
  const [all, essays] = await Promise.all([writingPrompts(task), attempts({ skill: 'writing', kind: `task${task}`, limit: 300 })]);
  const types = [...new Set(all.map((p) => p.type))];
  const list = type ? all.filter((p) => p.type === type) : all;
  const best = new Map<string, number>();
  for (const a of essays) {
    if (typeof a.band === 'number' && a.band > (best.get(a.refId) ?? -1)) best.set(a.refId, a.band);
  }
  const untried = list.filter((p) => !best.has(p.id));
  const pick = (untried.length ? untried : list)[Math.floor(Math.random() * Math.max(1, (untried.length ? untried : list).length))];

  return (
    <>
      <div className={s.head}>
        <div>
          <Link href="/app/writing" className={s.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Writing
          </Link>
          <h1 className={s.title}>Task {task} questions</h1>
          <p className={s.sub}>
            {list.length} questions · {task === 1 ? '20 min · 150+ words' : '40 min · 250+ words'}
          </p>
        </div>
        {pick && (
          <PrimaryButton href={`/app/writing/write/${pick.id}`} leading="shuffle">
            Random question
          </PrimaryButton>
        )}
      </div>

      <nav className={s.chips} aria-label="Question type">
        <Link href={`/app/writing/questions/${task}`} className={`${s.chip} ${!type ? s.chipOn : ''}`}>
          All
        </Link>
        {types.map((t) => (
          <Link key={t} href={`/app/writing/questions/${task}?type=${encodeURIComponent(t)}`} className={`${s.chip} ${type === t ? s.chipOn : ''}`}>
            {typeName(task, t)}
          </Link>
        ))}
      </nav>

      <div className={s.qList}>
        {list.map((p) => (
          <Card key={p.id} href={`/app/writing/write/${p.id}`} padding={14} radius={22}>
            <div className={s.q}>
              <span className={s.qNum}>{p.number || '·'}</span>
              <div className={s.grow}>
                <p className={s.qTitle}>{p.title}</p>
                <p className={s.qText}>{p.statement || p.prompt}</p>
                <div className={s.qMeta}>
                  <Tag>{p.typeName}</Tag>
                  {p.topic && <Tag>{p.topic}</Tag>}
                  {best.has(p.id) && <span className={s.done}>Best band {formatBand(best.get(p.id))}</span>}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
