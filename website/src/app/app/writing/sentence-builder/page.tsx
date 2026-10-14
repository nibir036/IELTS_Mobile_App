import type { Metadata } from 'next';
import Link from 'next/link';
import { HeroCard, Icon, Nexi } from '@/components/ui';
import c from '@/components/course.module.css';
import { lessonIcon } from '@/lib/content/lang';
import { attempt, attempts } from '@/lib/server/attempts';
import { bestScores, findSet, nextSet, resumeSet, sentenceBank } from '@/lib/server/sentences';
import { Drills } from './drills';

export const metadata: Metadata = { title: 'Sentence Builder' };

/** Writing Booster (sentence_bank_screen + sentence_builder_screen): `?set=` runs a set, `?attempt=` shows a result. */
export default async function SentenceBuilderPage({ searchParams }: { searchParams: Promise<{ set?: string; attempt?: string }> }) {
  const q = await searchParams;
  const [bank, mine, shown] = await Promise.all([
    sentenceBank(),
    attempts({ skill: 'writing', kind: 'drill', limit: 500 }),
    q.attempt ? attempt(q.attempt) : Promise.resolve(null),
  ]);
  const setId = shown && shown.kind === 'drill' ? shown.refId : q.set;
  const run = setId ? findSet(bank, setId) : null;
  if (run) {
    const next = nextSet(bank, run.id);
    return (
      <Drills
        key={run.id + (shown?.id ?? '')}
        setId={run.id}
        title={run.title}
        instruction={bank.instruction}
        drills={run.set.drills}
        next={next ? { id: next.id, title: next.title } : null}
        result={shown && shown.kind === 'drill' ? { score: shown.score ?? 0, total: shown.total ?? run.set.drills.length, createdAt: shown.createdAt, results: (shown.data.results as Array<{ id: string; correct: boolean }>) ?? [] } : null}
      />
    );
  }

  const best = bestScores(mine);
  const resume = resumeSet(bank, mine);
  const setsTotal = bank.categories.reduce((n, x) => n + x.sets.length, 0);
  const setsDone = Object.keys(best).filter((id) => findSet(bank, id)).length;
  return (
    <>
      <div className={c.top}>
        <Link href="/app/writing" className={c.back} aria-label="Back to Writing">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={c.topText}>
          <h1 className={c.h1}>Sentence Builder</h1>
          <p className={c.sub}>
            {bank.total} sentences · {bank.categories.length} categories
          </p>
        </div>
      </div>
      <HeroCard padding={20} radius={28}>
        <div className={c.continue}>
          <div className={c.continueText}>
            <span className={c.overline}>{!resume ? 'All sets done' : setsDone === 0 ? 'Start here' : 'Continue'}</span>
            <h2 className={c.continueTitle}>{resume?.title ?? 'You finished every set'}</h2>
            <span className={c.heroMuted}>Join two sentences with the right linking word.</span>
            <div className={`${c.bar} ${c.barHero}`}>
              <span style={{ width: `${setsTotal ? (setsDone / setsTotal) * 100 : 0}%` }} />
            </div>
            <span className={c.heroMuted}>
              {setsDone} of {setsTotal} sets done
            </span>
            {resume && (
              <Link className={c.peachBtn} href={`/app/writing/sentence-builder?set=${resume.id}`}>
                {setsDone === 0 ? 'Start' : 'Continue'} <Icon name="arrow_forward" size={18} />
              </Link>
            )}
          </div>
          <Nexi pose="writing" height={110} />
        </div>
      </HeroCard>
      {bank.categories.map((cat) => {
        const done = cat.sets.filter((x) => best[x.id] !== undefined).length;
        const complete = cat.sets.length > 0 && done === cat.sets.length;
        return (
          <details key={cat.id} className={c.stage} open={resume?.category.id === cat.id}>
            <summary>
              <span className={`${c.stageBadge} ${complete ? c.stageBadgeDone : ''}`}>
                <Icon name={complete ? 'check' : lessonIcon(cat.icon)} size={21} />
              </span>
              <span className={c.stageText}>
                <span className={c.stageMeta}>
                  {cat.count} sentences · {done}/{cat.sets.length} sets
                </span>
                <div className={c.stageTitle}>{cat.title}</div>
                <div className={c.stageSub}>{cat.subtitle}</div>
              </span>
              <Icon name="expand_more" size={20} className={c.chev} />
            </summary>
            <div className={`${c.bar} ${c.stageBar}`}>
              <span style={{ width: `${cat.sets.length ? (done / cat.sets.length) * 100 : 0}%` }} />
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, padding: '12px 6px 6px' }}>
              {cat.sets.map((x) => {
                const sc = best[x.id];
                const perfect = sc !== undefined && sc >= x.drills.length;
                return (
                  <Link
                    key={x.id}
                    href={`/app/writing/sentence-builder?set=${x.id}`}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 6,
                      padding: '10px 14px',
                      borderRadius: 14,
                      fontSize: 13.5,
                      fontWeight: 600,
                      background: perfect ? 'var(--peach)' : sc !== undefined ? 'rgba(255,156,130,.22)' : 'var(--glass-fill)',
                      border: sc !== undefined ? '1px solid transparent' : '1px solid var(--border)',
                      color: perfect ? '#151515' : 'var(--text)',
                    }}
                  >
                    {perfect && <Icon name="check" size={15} />}
                    {x.title}
                    <span style={{ fontSize: 12, fontWeight: 400, color: perfect ? '#151515' : 'var(--text-muted)' }}>{sc !== undefined ? `${sc}/${x.drills.length}` : x.drills.length}</span>
                  </Link>
                );
              })}
            </div>
          </details>
        );
      })}
    </>
  );
}
