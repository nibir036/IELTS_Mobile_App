import type { Metadata } from 'next';
import { stateValue } from '@/lib/server/attempts';
import { ideaPrompts } from '@/lib/server/writing';
import { Ideas } from './ideas';

export const metadata: Metadata = { title: 'IELTS Ideas & Topics' };

/** C11 · Ideas & topics library (ideas_topics_screen.dart). */
export default async function IdeasPage() {
  const [prompts, saved] = await Promise.all([ideaPrompts(), stateValue<string[]>('writing.ideas.bookmarks')]);
  return <Ideas prompts={prompts} initialSaved={Array.isArray(saved) ? saved : []} />;
}
