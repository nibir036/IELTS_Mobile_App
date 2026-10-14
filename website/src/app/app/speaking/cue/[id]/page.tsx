import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { SpeakingSession } from '@/components/speaking-session';
import { shortCueTitle } from '@/lib/speaking/bank';
import { speakingBankWithTests, speakingCopy } from '@/lib/server/speaking';

export const metadata: Metadata = { title: 'Cue card' };

/** Part 2: 1 minute to prepare, up to 2 minutes to speak (cue_card_screen + speaking_recording_screen). */
export default async function Cue({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [bank, copy] = await Promise.all([speakingBankWithTests(), speakingCopy()]);
  const card = bank.cards.find((x) => x.id === decodeURIComponent(id));
  if (!card) notFound();
  return (
    <SpeakingSession
      setup={{
        mode: 'cue',
        kind: 'part2',
        part: 2,
        title: `Part 2 · ${shortCueTitle(card.title)}`,
        refId: card.id,
        cardTitle: card.title,
        label: `Part 2 · Cue card ${card.number || ''}`.trim(),
        back: '/app/speaking/cards',
        questions: [{ text: card.title, hint: '', sample: card.sample }],
        aimSeconds: [60, 120],
        bullets: card.bullets,
        prepSeconds: copy.recording?.prepSeconds ?? 60,
        limitSeconds: copy.recording?.limitSeconds ?? 120,
      }}
    />
  );
}
