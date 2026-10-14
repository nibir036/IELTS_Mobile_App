import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { HeroCard, Icon, Nexi, Notice } from '@/components/ui';
import { rows, str, type Raw } from '@/lib/practice/marking';
import { attempt } from '@/lib/server/attempts';
import { uiPack } from '@/lib/server/packs';
import { MenuRow } from '@/lib/lessons/lesson-menu';
import { defaultLessonId, lessonMenu } from '@/lib/lessons/menu';
import { lessonsDone, listeningLessons, listeningSaved } from '@/lib/lessons/server';
import s from '@/lib/lessons/lessons.module.css';

export const metadata: Metadata = { title: 'Listening lessons' };

const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {});

/** Listening Bite-size Lessons (F6 course): `?attempt=` opens the lesson of a lesson attempt. */
export default async function ListeningLessons({ searchParams }: { searchParams: Promise<{ attempt?: string; note?: string }> }) {
  const q = await searchParams;
  if (q.attempt) {
    const a = await attempt(q.attempt);
    if (a && a.skill === 'listening' && a.kind === 'lesson' && a.refId) redirect(`/app/listening/lessons/${encodeURIComponent(a.refId)}`);
  }
  const [lessons, done, saved, ui] = await Promise.all([listeningLessons(), lessonsDone('listening'), listeningSaved(), uiPack()]);
  const card = rows(obj(obj(ui.listening).landing).modules).find((m) => str(m.id) === 'lessons') ?? {};
  const started = new Set([...saved.keys()].filter((id) => !done.has(id)));
  const nextId = defaultLessonId(lessons, done, started);
  const menu = lessonMenu(lessons, done, started, '');
  const next = menu.find((e) => e.id === nextId);
  const doneCount = menu.filter((e) => e.done).length;
  const allDone = lessons.length > 0 && doneCount === lessons.length;
  const nextLesson = lessons.find((l) => str(l.id) === nextId);

  return (
    <>
      <div className={s.head}>
        <Link href="/app/listening" className={s.iconBtn} aria-label="Back to Listening">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={s.headText}>
          <h1 className={s.h1}>{str(card.title) || 'Bite-size Lessons'}</h1>
          <p className={s.sub}>{str(card.subtitle) || 'Short lessons, each with an audio exercise'}</p>
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
              {nextLesson && <span className={s.heroMuted}>{str(obj(nextLesson.source).title) ? `Clip from “${str(obj(nextLesson.source).title)}”` : str(nextLesson.instruction)}</span>}
              <div className={s.heroBar} aria-hidden>
                <span style={{ width: `${lessons.length ? (doneCount / lessons.length) * 100 : 0}%` }} />
              </div>
              <span className={s.heroMuted}>
                {doneCount} of {lessons.length} lessons done
              </span>
              <Link href={`/app/listening/lessons/${next.id}`} className={s.peachBtn}>
                {allDone ? 'Practise again' : started.has(next.id) ? 'Resume lesson' : 'Start lesson'} <Icon name="arrow_forward" size={18} />
              </Link>
            </div>
            <Nexi pose="listening" height={120} />
          </div>
        </HeroCard>
      )}

      <section className={s.card} aria-labelledby="listening-lessons">
        <h2 id="listening-lessons" className={s.cardTitle}>
          Lessons
        </h2>
        <div className={s.rowList}>
          {menu.map((e) => (
            <MenuRow key={e.id} entry={e} href={`/app/listening/lessons/${e.id}`} />
          ))}
        </div>
      </section>
    </>
  );
}
