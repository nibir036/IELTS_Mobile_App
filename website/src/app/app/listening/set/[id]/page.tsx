import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { PracticeTest } from '@/components/practice-test';
import { str } from '@/lib/practice/marking';
import { listeningSet } from '@/lib/server/practice';

export const metadata: Metadata = { title: 'Listening practice' };

/** F2 · one practice set (listening_player_screen.dart). */
export default async function ListeningSet({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const set = await listeningSet(decodeURIComponent(id));
  if (!set) notFound();
  const minutes = Math.max(10, Math.ceil((Number(set.durationSeconds) || 300) / 60) + 5);
  return (
    <PracticeTest
      setup={{
        skill: 'listening',
        kind: 'mini',
        refId: str(set.id),
        title: str(set.title),
        label: `Part ${str(set.part)} practice · ${str(set.formatLabel) || 'Listening'}`,
        back: '/app/listening',
        minutes,
        parts: [set],
        extra: { setId: str(set.id), part: Number(set.part) || 1, mode: 'Part Practice', source: 'player' },
      }}
    />
  );
}
