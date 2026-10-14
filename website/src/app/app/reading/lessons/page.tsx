import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { Card, HeroCard, Icon, Nexi, Notice } from '@/components/ui';
import { rows, str, type Raw } from '@/lib/practice/marking';
import { attempt } from '@/lib/server/attempts';
import { moduleTranslation } from '@/lib/server/content';
import { uiPack } from '@/lib/server/packs';
import { typeLesson } from '@/lib/lessons/l10n';
import { MenuRow } from '@/lib/lessons/lesson-menu';
import { defaultLessonId, lessonMenu } from '@/lib/lessons/menu';
import { lessonsDone, readingProgress, readingSkillLessons, readingTypeLessons, typeLessonsRead } from '@/lib/lessons/server';
import s from '@/lib/lessons/lessons.module.css';

export const metadata: Metadata = { title: 'Reading lessons' };

const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {});

/**
 * Reading strategy lessons: the skill lessons (E6, opened from the Reading
 * landing's "Lesson & Exercise") and the "How to attempt …" lesson of every
 * question type. `?attempt=` opens the lesson of a lesson attempt.
 */
export default async function ReadingLessons({ searchParams }: { searchParams: Promise<{ attempt?: string; note?: string }> }) {
  const q = await searchParams;
  if (q.attempt) {
    const a = await attempt(q.attempt);
    if (a && a.skill === 'reading' && a.kind === 'lesson' && a.refId) redirect(`/app/reading/lessons/${encodeURIComponent(a.refId)}`);
  }
  const [lessons, done, progress, types, read, l10n, ui] = await Promise.all([
    readingSkillLessons(),
    lessonsDone('reading'),
    readingProgress(),
    readingTypeLessons(),
    typeLessonsRead(),
    moduleTranslation('reading'),
    uiPack(),
  ]);
  const card = rows(obj(obj(ui.reading).landing).modules).find((m) => str(m.id) === 'lessons') ?? {};
  const started = new Set(progress && !done.has(progress.lessonId) ? [progress.lessonId] : []);
  const nextId = defaultLessonId(lessons, done, started);
  const menu = lessonMenu(lessons, done, started, '');
  const next = menu.find((e) => e.id === nextId);
  const doneCount = menu.filter((e) => e.done).length;
  const allDone = lessons.length > 0 && doneCount === lessons.length;
  const dir = l10n.lang.rtl ? 'rtl' : undefined;

  return (
    <>
      <div className={s.head}>
        <Link href="/app/reading" className={s.iconBtn} aria-label="Back to Reading">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={s.headText}>
          <h1 className={s.h1}>{str(card.title) || 'Lesson & Exercise'}</h1>
          <p className={s.sub}>{str(card.subtitle) || 'Build one reading skill at a time'}</p>
        </div>
      </div>

      {q.note === 'last' && (
        <Notice icon="celebration" title="Marked as done">
          That was the last lesson.
        </Notice>
      )}

      {next && (
        <HeroCard padding={20} radius={28}>
          <div className={s.heroRow}>
            <div className={s.heroText}>
              <span className={s.overline}>{allDone ? 'All lessons done' : started.has(next.id) ? 'Continue' : doneCount ? 'Up next' : 'Start here'}</span>
              <h2 className={s.heroTitle}>
                Lesson {next.number} · {next.title}
              </h2>
              <div className={`${s.heroBar}`} aria-hidden>
                <span style={{ width: `${lessons.length ? (doneCount / lessons.length) * 100 : 0}%` }} />
              </div>
              <span className={s.heroMuted}>
                {doneCount} of {lessons.length} lessons done
              </span>
              <Link href={`/app/reading/lessons/${next.id}`} className={s.peachBtn}>
                {allDone ? 'Practise again' : started.has(next.id) ? 'Resume lesson' : 'Start lesson'} <Icon name="arrow_forward" size={18} />
              </Link>
            </div>
            <Nexi pose="reading" height={120} />
          </div>
        </HeroCard>
      )}

      <section className={s.card} aria-labelledby="skill-lessons">
        <h2 id="skill-lessons" className={s.cardTitle}>
          Reading skills
        </h2>
        <div className={s.rowList}>
          {menu.map((e) => (
            <MenuRow key={e.id} entry={e} href={`/app/reading/lessons/${e.id}`} />
          ))}
        </div>
      </section>

      {types.length > 0 && (
        <>
          <div className={s.sectionHead}>
            <h2 className={s.sectionTitle}>How to attempt each question type</h2>
            <p className={s.sub}>A short strategy lesson for every question type in the bank</p>
          </div>
          <div className={s.grid}>
            {types.map((en) => {
              const t = typeLesson(en, l10n.tr);
              const type = str(en.questionType);
              const isRead = read.includes(type);
              return (
                <Card key={type} href={`/app/reading/lessons/type/${encodeURIComponent(type)}`} padding={14} radius={22}>
                  <div className={s.typeRow}>
                    <span className={s.typeIcon}>
                      <Icon name="lightbulb" size={20} />
                    </span>
                    <span className={s.rowText}>
                      <b dir={dir}>{str(t.title)}</b>
                      <span>
                        {str(en.name)} · {rows(en.sections).length} parts
                      </span>
                    </span>
                    {isRead ? <Icon name="check_circle" size={20} color="var(--success)" /> : <Icon name="chevron_right" size={20} color="var(--text-muted)" />}
                  </div>
                </Card>
              );
            })}
          </div>
        </>
      )}
    </>
  );
}
