import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { rows, str } from '@/lib/practice/marking';
import { moduleTranslation } from '@/lib/server/content';
import { skillLesson } from '@/lib/lessons/l10n';
import { lessonMenu } from '@/lib/lessons/menu';
import { lessonsDone, readingProgress, readingSkillLessons } from '@/lib/lessons/server';
import { ReadingLesson, type ReadingLessonView } from './reading-lesson';

export const metadata: Metadata = { title: 'Reading lesson' };

/** E6 · Reading Lesson & Exercise: one skill lesson with timed exercises. */
export default async function ReadingLessonPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ note?: string }> }) {
  const [{ id }, q] = await Promise.all([params, searchParams]);
  const [lessons, done, progress, l10n] = await Promise.all([readingSkillLessons(), lessonsDone('reading'), readingProgress(), moduleTranslation('reading')]);
  const i = lessons.findIndex((l) => str(l.id) === id);
  if (i < 0) notFound();
  const english = lessons[i];
  const lesson = skillLesson(english, l10n.tr);
  const exercises = rows(english.exercises).map((e) => ({
    id: str(e.id),
    seconds: Number(e.seconds) || 60,
    quote: str(e.quote),
    question: str(e.question),
    options: rows(e.options).map((o) => ({ key: str(o.key), text: str(o.text) })),
    answer: str(e.answer),
  }));
  const started = new Set(progress && !done.has(progress.lessonId) ? [progress.lessonId] : []);
  const mine = progress?.lessonId === id;
  const view: ReadingLessonView = {
    id,
    englishTitle: str(english.title),
    title: str(lesson.title),
    keyIdeaLabel: str(english.keyIdeaLabel),
    keyIdea: str(lesson.keyIdea),
    uses: rows(lesson.uses).map((u) => ({ label: str(u.label), value: str(u.value) })),
    exercises,
    number: i + 1,
    count: lessons.length,
    next: i + 1 < lessons.length ? { id: str(lessons[i + 1].id), number: i + 2 } : null,
    lang: l10n.lang.code,
    langs: l10n.langs,
    rtl: Boolean(l10n.lang.rtl) && lesson !== english,
  };
  return (
    <ReadingLesson
      key={id}
      lesson={view}
      menu={lessonMenu(lessons, done, started, id)}
      currentDone={done.has(id)}
      resume={mine && progress ? { index: progress.index, correct: progress.correct, elapsedSec: progress.elapsedSec } : null}
      progressIsMine={mine}
      note={q.note === 'marked' ? 'marked' : ''}
    />
  );
}
