import type { Metadata } from 'next';
import { getMe } from '@/lib/server/me';
import { pronunciationSet } from '@/lib/server/pronunciation';
import { Trainer } from './trainer';

export const metadata: Metadata = { title: 'Pronunciation Trainer' };

/** D7 · Pronunciation & intonation trainer (pronunciation_screen.dart). `?vocab=a,b&title=` practises given words; `?topic=` a topic. */
export default async function PronunciationPage({ searchParams }: { searchParams: Promise<{ vocab?: string; title?: string; topic?: string }> }) {
  const q = await searchParams;
  const [set, me] = await Promise.all([
    pronunciationSet({ vocab: q.vocab ? q.vocab.split(',').map((x) => x.trim()).filter(Boolean) : [], title: q.title, topic: q.topic ?? null }),
    getMe(),
  ]);
  const lim = (me.usage.limits?.pronunciation ?? null) as { left?: number } | null;
  const usedUp = me.usage.plan !== 'pro' && !!lim && Number(lim.left ?? 1) <= 0;
  return <Trainer key={`${set.refId}:${set.topic ?? ''}`} set={set} usedUp={usedUp} />;
}
