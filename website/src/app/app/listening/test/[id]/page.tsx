import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { PracticeTest } from '@/components/practice-test';
import { str, strs } from '@/lib/practice/marking';
import { listeningTests } from '@/lib/server/practice';

export const metadata: Metadata = { title: 'Listening test' };

/** F3 · full test answer sheet (listening_answer_sheet_screen.dart). */
export default async function ListeningTest({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const { tests, sets } = await listeningTests();
  const test = tests.find((t) => str(t.id) === decodeURIComponent(id));
  if (!test) notFound();
  const parts = strs(test.sets)
    .map((sid) => sets.find((s) => str(s.id) === sid))
    .filter((s): s is NonNullable<typeof s> => Boolean(s));
  return (
    <PracticeTest
      setup={{
        skill: 'listening',
        kind: 'test',
        refId: str(test.id),
        title: str(test.title),
        label: 'Full listening test · 4 parts',
        back: '/app/listening',
        minutes: 40,
        parts,
        extra: { testId: str(test.id), source: 'sheet' },
      }}
    />
  );
}
