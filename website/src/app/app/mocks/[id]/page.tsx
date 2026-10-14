import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { MockRunner } from '@/components/mock-runner';
import { getMe } from '@/lib/server/me';
import { mockData } from '@/lib/server/mocks';

export const metadata: Metadata = { title: 'Full Mock Test' };

export default async function MockPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [mock, me] = await Promise.all([mockData(decodeURIComponent(id)), getMe()]);
  if (!mock) notFound();
  const lim = (me.usage.limits?.mock ?? null) as { left?: number; writingDone?: boolean } | null;
  // Free plan: one mock. A mock already started (writing scored) can still be finished.
  const blocked = me.usage.plan !== 'pro' && !!lim && Number(lim.left ?? 0) === 0 && !lim.writingDone;
  return <MockRunner mock={mock} blocked={blocked} />;
}
