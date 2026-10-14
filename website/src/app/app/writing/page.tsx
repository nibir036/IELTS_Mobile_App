import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, HeroCard, Icon, Nexi } from '@/components/ui';
import { attempts, stateValue } from '@/lib/server/attempts';
import { uiPack } from '@/lib/server/packs';
import { writingPrompts } from '@/lib/server/writing';
import { formatBand, wordCount } from '@/lib/writing/analysis';
import { TASK1_TYPES, TASK2_TYPES } from '@/lib/writing/prompts';
import s from './writing.module.css';

export const metadata: Metadata = { title: 'Writing' };

type TaskCopy = { id: string; label: string; title: string; minutes: number; words: number; previewBars?: number[]; highlightBar?: number };
type MoreRow = { id: string; title: string; subtitle: string; meta: string; icon: string; tone: string; target: string };

const SHORT: Record<string, string> = {
  line: 'Line', bar: 'Bar', pie: 'Pie', table: 'Table', process: 'Process', map: 'Map', mixed: 'Mixed',
  opinion: 'Opinion', discussion: 'Discussion', advantages: 'Advantages', problem: 'Problem–solution',
  'two-part': 'Two-part', 'positive-negative': 'Positive / negative',
};

const MORE_ICON: Record<string, string> = {
  guide: 'school', lessons: 'auto_stories', booster: 'layers', template: 'description', ideas: 'tag',
  tips: 'lightbulb', tests: 'timer', samples: 'article',
};
const TONE: Record<string, [string, string]> = {
  lavender: ['#dce6ff', '#151515'],
  rose: ['#ffd2c4', '#151515'],
  mist: ['var(--surface-alt2)', 'var(--text)'],
  pink: ['#ffe2d8', '#151515'],
};
const MORE_HREF: Record<string, string> = {
  writingSampleAnswer: '/app/writing/samples',
  writingTests: '/app/writing/tests',
  writingCourse: '/app/courses/writing',
  masterclass: '/app/writing/lessons',
  sentenceBuilder: '/app/writing/sentence-builder',
  writingTemplate: '/app/writing/templates',
  ideasTopics: '/app/writing/ideas',
  articleTips: '/app/resources/tips/writing',
};

/** C1 · Writing (lib/features/writing/writing_selector_screen.dart). */
export default async function WritingHub() {
  const [ui, prompts, essays, d1, d2] = await Promise.all([
    uiPack(),
    writingPrompts(),
    attempts({ skill: 'writing', limit: 200 }),
    stateValue<{ promptId: string; text: string; updatedAt?: string }>('writing.draft.task1'),
    stateValue<{ promptId: string; text: string; updatedAt?: string }>('writing.draft.task2'),
  ]);
  const data = ((ui.writing ?? {}) as { selector?: { subtitle?: string; tasks?: TaskCopy[]; fullMock?: { title: string; subtitle: string }; more?: MoreRow[] } }).selector ?? {};
  const drafts = [
    ...(d1?.text?.trim() ? [{ ...d1, task: 1 }] : []),
    ...(d2?.text?.trim() ? [{ ...d2, task: 2 }] : []),
  ].sort((a, b) => String(b.updatedAt ?? '').localeCompare(String(a.updatedAt ?? '')));
  const draft = drafts[0];
  const draftPrompt = draft ? prompts.find((p) => p.id === draft.promptId) : undefined;
  const more = (data.more ?? []).filter((r) => MORE_HREF[r.target]);

  return (
    <>
      <div className={s.head}>
        <div>
          <h1 className={s.title}>Pick a task</h1>
          <p className={s.sub}>{data.subtitle}</p>
        </div>
        <Link href="/app/writing/history" className={s.iconBox} title="Essay history" aria-label="Essay history">
          <Icon name="history" size={20} />
        </Link>
      </div>

      <div className={s.tasks}>
        {(data.tasks ?? []).map((task) => {
          const n: 1 | 2 = task.id === 'task1' ? 1 : 2;
          const list = prompts.filter((p) => p.task === n);
          const mine = essays.filter((a) => a.kind === `task${n}`);
          const written = new Set(mine.map((a) => a.refId).filter((id) => list.some((p) => p.id === id))).size;
          const bands = mine.map((a) => a.band).filter((b): b is number => typeof b === 'number');
          const best = bands.length ? Math.max(...bands) : null;
          const progress = mine.length
            ? `${written} of ${list.length} prompts · best ${formatBand(best)} · last ${formatBand(mine[0].band)}`
            : `No essays yet · ${list.length} prompts to try`;
          const types = [...new Set(list.map((p) => p.type))].map((t) => SHORT[t] ?? (n === 1 ? TASK1_TYPES : TASK2_TYPES)[t] ?? t);
          const stats = (
            <>
              <span>
                <b>{task.minutes}</b> min
              </span>
              <span>
                <b>{task.words}</b> words
              </span>
              <span>
                <b>{list.length}</b> prompts
              </span>
            </>
          );
          return (
            <Link key={task.id} href={`/app/writing/questions/${n}`}>
              <HeroCard padding={18}>
                <div className={s.taskCard}>
                  <div className={s.row}>
                    <div className={s.grow}>
                      <div className={s.taskLabel}>{task.label}</div>
                      <h2 className={s.taskTitle}>{task.title}</h2>
                    </div>
                    <span className={s.arrow}>
                      <Icon name="north_east" size={18} />
                    </span>
                  </div>
                  {n === 1 ? (
                    <>
                      <div className={s.row} style={{ alignItems: 'flex-end' }}>
                        <div className={s.bars}>
                          {(task.previewBars ?? []).map((b, i) => (
                            <span key={i} className={`${s.bar} ${i === task.highlightBar ? s.barHi : ''}`} style={{ height: `${Math.max(5, Math.min(100, b * 100))}%` }} />
                          ))}
                        </div>
                        <div className={`${s.stats} ${s.statsCol}`}>{stats}</div>
                      </div>
                      <div className={s.progress}>{progress}</div>
                    </>
                  ) : (
                    <div className={s.row} style={{ alignItems: 'flex-end' }}>
                      <div className={s.grow} style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                        <div className={s.stats}>{stats}</div>
                        <div className={s.progress}>{progress}</div>
                      </div>
                      <Nexi pose="writing" height={110} />
                    </div>
                  )}
                  <div className={s.pills}>
                    {types.map((t) => (
                      <span key={t} className={s.pill}>
                        {t}
                      </span>
                    ))}
                  </div>
                </div>
              </HeroCard>
            </Link>
          );
        })}
      </div>

      {draft && draftPrompt && (
        <Card href={`/app/writing/write/${draftPrompt.id}`} padding="12px 12px 12px 14px" radius={22}>
          <div className={s.moreRow}>
            <span className={s.wideIcon} style={{ background: 'var(--surface-alt2)' }}>
              <Icon name="edit" size={18} />
            </span>
            <span className={s.twoLine}>
              <b>Continue draft</b>
              <span>
                Task {draft.task} · {draftPrompt.shortTitle} · {wordCount(draft.text)} words
              </span>
            </span>
            <Icon name="chevron_right" size={20} color="var(--text-muted)" />
          </div>
        </Card>
      )}

      {data.fullMock && (
        <Link href="/app/writing/tests" className={`${s.wide} ${s.peachCard}`}>
          <span className={s.wideIcon} style={{ background: 'var(--on-peach)', color: '#ffb8a3' }}>
            <Icon name="schedule" size={18} />
          </span>
          <span className={s.twoLine}>
            <b>{data.fullMock.title}</b>
            <span>{data.fullMock.subtitle}</span>
          </span>
          <Icon name="chevron_right" size={20} />
        </Link>
      )}

      <div className={s.moreHead}>
        More in Writing <span>{more.length} sections</span>
      </div>
      <div className={s.more}>
        {more.map((row) => {
          const [bg, fg] = TONE[row.tone] ?? TONE.pink;
          return (
            <Card key={row.id} href={MORE_HREF[row.target]} padding="10px 12px 10px 10px" radius={20}>
              <div className={s.moreRow}>
                <span className={s.wideIcon} style={{ width: 42, height: 42, background: bg, color: fg }}>
                  <Icon name={MORE_ICON[row.icon] ?? 'edit_note'} size={18} />
                </span>
                <span className={s.twoLine}>
                  <b>{row.title}</b>
                  <span style={{ color: 'var(--text-muted)', opacity: 1 }}>{row.subtitle}</span>
                </span>
                {row.meta && <span className={s.moreMeta}>{row.meta}</span>}
                <Icon name="chevron_right" size={16} color="var(--text-muted)" />
              </div>
            </Card>
          );
        })}
      </div>
    </>
  );
}
