import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { PracticeTest } from '@/components/practice-test';
import { passageQuestionCount, str, strs, type Raw } from '@/lib/practice/marking';
import { readingContent } from '@/lib/server/practice';

export const metadata: Metadata = { title: 'Reading' };

/** E2 / E3 · passage and questions side by side (reading_passage_screen + questions). */
export default async function ReadingDo({ params }: { params: Promise<{ id: string }> }) {
  const { id: raw } = await params;
  const id = decodeURIComponent(raw);
  const c = await readingContent();
  const all = [...c.bankPassages, ...c.testPassages];
  const full = c.fullTests.find((t) => str(t.id) === id);
  const short = c.practiceTests.find((t) => str(t.id) === id);
  const test = full ?? short;
  let parts: Raw[];
  let minutes: number;
  let label: string;
  if (test) {
    parts = strs(test.passages).map((pid) => all.find((p) => str(p.id) === pid)).filter((p): p is Raw => Boolean(p));
    minutes = Number(test.minutes) || (full ? 60 : 20);
    label = full ? 'Full reading test · 3 passages' : 'Short practice test';
  } else {
    const p = all.find((x) => str(x.id) === id);
    if (!p) notFound();
    parts = [p];
    const n = passageQuestionCount(p);
    minutes = Math.max(5, Math.floor((n * 3 + 1) / 2));
    label = `Question bank · ${str(p.questionTypeName) || 'Passage practice'}`;
  }
  if (!parts.length) notFound();
  return (
    <PracticeTest
      setup={{
        skill: 'reading',
        kind: test ? 'test' : 'mini',
        refId: id,
        title: test ? str(test.title) : str(parts[0].title),
        label,
        back: '/app/reading',
        minutes,
        parts,
        extra: test ? { testId: id } : { passageId: id },
      }}
    />
  );
}
