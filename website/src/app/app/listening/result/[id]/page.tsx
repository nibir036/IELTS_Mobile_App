import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { PracticeResult } from '@/components/practice-result';
import { str, strs, type Raw } from '@/lib/practice/marking';
import { attempt } from '@/lib/server/attempts';
import { listeningSet, listeningTests } from '@/lib/server/practice';

export const metadata: Metadata = { title: 'Listening results' };

export default async function ListeningResult({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const a = await attempt(decodeURIComponent(id));
  if (!a || a.skill !== 'listening') notFound();
  const testId = str(a.data.testId);
  let parts: Raw[] = [];
  let retry = '/app/listening';
  if (testId) {
    const { tests, sets } = await listeningTests();
    const t = tests.find((x) => str(x.id) === testId);
    parts = strs(t?.sets).map((sid) => sets.find((s) => str(s.id) === sid)).filter((s): s is NonNullable<typeof s> => Boolean(s));
    retry = `/app/listening/test/${testId}`;
  } else {
    const set = await listeningSet(str(a.data.setId) || a.refId);
    parts = set ? [set] : [];
    if (set) retry = `/app/listening/set/${str(set.id)}`;
  }
  return <PracticeResult a={a} parts={parts} retry={retry} hub="/app/listening" />;
}
