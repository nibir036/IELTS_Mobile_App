import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { mediaUrl } from '@/lib/media';
import { rows, str, strs } from '@/lib/practice/marking';
import { lessonMenu } from '@/lib/lessons/menu';
import { lessonsDone, listeningLessons, listeningSaved } from '@/lib/lessons/server';
import { ListeningLesson, type ListeningLessonView } from './listening-lesson';

export const metadata: Metadata = { title: 'Listening lesson' };

/** F6 · Listening Bite-size Lesson: a lesson note, a clip of a real recording and a gap-fill. */
export default async function ListeningLessonPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ note?: string }> }) {
  const [{ id }, q] = await Promise.all([params, searchParams]);
  const [lessons, done, saved] = await Promise.all([listeningLessons(), lessonsDone('listening'), listeningSaved()]);
  const i = lessons.findIndex((l) => str(l.id) === id);
  if (i < 0) notFound();
  const l = lessons[i];
  const view: ListeningLessonView = {
    id,
    title: str(l.title),
    body: str(l.body),
    audioUrl: mediaUrl(str(l.audio)),
    duration: Number(l.audioDurationSeconds) || 0,
    instruction: str(l.instruction),
    rows: rows(l.rows).map((r) => ({
      number: Number(r.number) || 0,
      before: str(r.before),
      after: str(r.after),
      answer: str(r.answer),
      accepted: strs(r.accepted),
    })),
    number: i + 1,
    count: lessons.length,
    next: i + 1 < lessons.length ? { id: str(lessons[i + 1].id), number: i + 2 } : null,
  };
  return (
    <ListeningLesson
      key={id}
      lesson={view}
      menu={lessonMenu(lessons, done, new Set(saved.keys()), id)}
      currentDone={done.has(id)}
      saved={saved.get(id) ?? null}
      note={q.note === 'marked' ? 'marked' : ''}
    />
  );
}
