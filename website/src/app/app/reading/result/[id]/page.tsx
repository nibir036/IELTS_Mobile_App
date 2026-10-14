import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { PracticeResult } from '@/components/practice-result';
import { str, strs, type Raw } from '@/lib/practice/marking';
import { attempt } from '@/lib/server/attempts';
import { readingContent } from '@/lib/server/practice';

export const metadata: Metadata = { title: 'Reading results' };

export default async function ReadingResult({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const a = await attempt(decodeURIComponent(id));
  if (!a || a.skill !== 'reading') notFound();
  const c = await readingContent();
  const all = [...c.bankPassages, ...c.testPassages];
  const ids = strs(a.data.passages).length ? strs(a.data.passages) : [str(a.data.passageId) || a.refId];
  const parts = ids.map((pid) => all.find((p) => str(p.id) === pid)).filter((p): p is Raw => Boolean(p));
  return <PracticeResult a={a} parts={parts} retry={`/app/reading/do/${a.refId}`} hub="/app/reading" />;
}
