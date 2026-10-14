import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Card, HeroCard, Icon, Tag } from '@/components/ui';
import { typeLesson } from '@/lib/lessons/l10n';
import { typeLessonsRead } from '@/lib/lessons/server';
import { passageQuestionCount, str } from '@/lib/practice/marking';
import { attempts } from '@/lib/server/attempts';
import { moduleTranslation } from '@/lib/server/content';
import { readingContent } from '@/lib/server/practice';
import { formatBand } from '@/lib/writing/analysis';
import w from '../../../writing/writing.module.css';

export const metadata: Metadata = { title: 'Reading question bank' };

export default async function ReadingType({ params }: { params: Promise<{ type: string }> }) {
  const { type } = await params;
  const [c, mine, l10n, read] = await Promise.all([
    readingContent(),
    attempts({ skill: 'reading', kind: 'mini', limit: 300 }),
    moduleTranslation('reading'),
    typeLessonsRead(),
  ]);
  const enLesson = c.lessons.find((l) => str(l.questionType) === type);
  const lesson = enLesson ? typeLesson(enLesson, l10n.tr) : null;
  const intro = lesson && Array.isArray(lesson.sections) && lesson.sections.length ? str((lesson.sections[0] as Record<string, unknown>).text) : '';
  const lessonDir = l10n.lang.rtl && lesson !== enLesson ? 'rtl' : undefined;
  const list = c.bankPassages.filter((p) => str(p.questionType) === type);
  if (!list.length) notFound();
  const best = new Map<string, number>();
  for (const a of mine) if (typeof a.band === 'number' && a.band > (best.get(a.refId) ?? -1)) best.set(a.refId, a.band);
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/reading" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Reading
          </Link>
          <h1 className={w.title}>{str(list[0].questionTypeName)}</h1>
          <p className={w.sub}>{list.length} passages from easy to hard</p>
        </div>
      </div>
      {lesson && (
        <Link href={`/app/reading/lessons/type/${encodeURIComponent(type)}`} style={{ display: 'block', textDecoration: 'none', color: 'inherit' }}>
          <HeroCard padding={16} radius={24}>
            <div className={w.row} style={{ alignItems: 'center' }}>
              <div className={w.grow}>
                <div className={w.taskLabel} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <Icon name="lightbulb" size={14} /> {read.includes(type) ? 'Lesson · read' : 'Start here · lesson'}
                </div>
                <p dir={lessonDir} style={{ margin: '4px 0 0', fontSize: 16, fontWeight: 500 }}>
                  {str(lesson.title)}
                </p>
                {intro && (
                  <p dir={lessonDir} className={w.qText} style={{ color: 'var(--hero-muted)' }}>
                    {intro}
                  </p>
                )}
              </div>
              <span className={w.arrow} style={{ borderRadius: '50%' }}>
                <Icon name="arrow_forward" size={18} />
              </span>
            </div>
          </HeroCard>
        </Link>
      )}
      <div className={w.qList}>
        {list.map((p) => (
          <Card key={str(p.id)} href={`/app/reading/do/${str(p.id)}`} padding={14} radius={22}>
            <p className={w.qTitle}>{str(p.title)}</p>
            <p className={w.qText}>{str(p.topic)}</p>
            <div className={w.qMeta}>
              <Tag>{str(p.difficulty)}</Tag>
              <Tag>{passageQuestionCount(p)} questions</Tag>
              {best.has(str(p.id)) && <span className={w.done}>Best band {formatBand(best.get(str(p.id)))}</span>}
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
