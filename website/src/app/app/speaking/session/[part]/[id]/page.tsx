import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { SpeakingSession } from '@/components/speaking-session';
import { shortCueTitle, withHints } from '@/lib/speaking/bank';
import { speakingBankWithTests, speakingCopy } from '@/lib/server/speaking';

export const metadata: Metadata = { title: 'Speaking practice' };

/** Part 1 (a topic) or Part 3 (a discussion topic, or a cue card's follow-up questions). */
export default async function Session({ params }: { params: Promise<{ part: string; id: string }> }) {
  const { part, id: rawId } = await params;
  const id = decodeURIComponent(rawId);
  const [bank, copy] = await Promise.all([speakingBankWithTests(), speakingCopy()]);
  if (part === '1') {
    const t = bank.part1.find((x) => x.id === id);
    if (!t) notFound();
    const c = copy.sessionCopy?.part1;
    return (
      <SpeakingSession
        setup={{
          mode: 'qa',
          kind: 'part1',
          part: 1,
          title: `Part 1 · ${t.topic}`,
          refId: t.id,
          cardTitle: `Topic: ${t.topic}`,
          label: c?.label ?? 'Part 1 · Short Q&A',
          back: '/app/speaking/part1',
          questions: withHints(t.id, t.questions, c?.hints ?? [], t.samples),
          aimSeconds: [c?.aimSeconds?.[0] ?? 20, c?.aimSeconds?.[1] ?? 30],
        }}
      />
    );
  }
  if (part === '3') {
    const c = copy.sessionCopy?.part3;
    const topic = bank.part3.find((x) => x.id === id);
    const card = topic ? undefined : bank.cards.find((x) => x.id === id);
    if (!topic && !card) notFound();
    const name = topic ? topic.topic : shortCueTitle(card!.title);
    const questions = topic
      ? withHints(topic.id, topic.questions.map((q) => q.q), c?.hints ?? [], topic.questions.map((q) => ({ q: q.q, answer: q.answer })))
      : withHints(card!.id, card!.part3, c?.hints ?? [], card!.part3Samples);
    return (
      <SpeakingSession
        setup={{
          mode: 'qa',
          kind: 'part3',
          part: 3,
          title: `Part 3 · ${name}`,
          refId: id,
          cardTitle: `Topic: ${name}`,
          label: c?.label ?? 'Part 3 · Discussion',
          back: '/app/speaking/part3',
          questions,
          aimSeconds: [c?.aimSeconds?.[0] ?? 45, c?.aimSeconds?.[1] ?? 60],
        }}
      />
    );
  }
  notFound();
}
