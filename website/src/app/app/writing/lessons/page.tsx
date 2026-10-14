import type { Metadata } from 'next';
import { stateValue } from '@/lib/server/attempts';
import { uiPack } from '@/lib/server/packs';
import { Masterclass, type McLesson } from './masterclass';

export const metadata: Metadata = { title: 'Paragraph Masterclass' };

/** C8 · Paragraph Structuring Masterclass (masterclass_screen.dart). */
export default async function LessonsPage() {
  const [ui, done, pos] = await Promise.all([
    uiPack().catch(() => ({}) as Record<string, unknown>),
    stateValue<string[]>('writing.lessons.done'),
    stateValue<Record<string, number>>('writing.lessons.pos'),
  ]);
  const lessons = ((((ui.writing ?? {}) as Record<string, unknown>).masterclass ?? {}) as { lessons?: McLesson[] }).lessons ?? [];
  return <Masterclass lessons={lessons} initialDone={Array.isArray(done) ? done : []} initialPos={pos && typeof pos === 'object' ? pos : {}} />;
}
