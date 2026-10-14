import type { Metadata } from 'next';
import { PLAN_MODULES } from '@/lib/plan/plan';
import { getMe } from '@/lib/server/me';
import { currentPlan } from '@/lib/server/plan';
import { QuickCheck } from './quick-check';

export const metadata: Metadata = { title: 'Quick check' };

/** The plan's quick check (quick_check_screen.dart). Pro only. */
export default async function QuickCheckPage({ searchParams }: { searchParams: Promise<{ modules?: string; back?: string }> }) {
  const { modules, back } = await searchParams;
  const [{ plan }, me] = await Promise.all([currentPlan(), getMe()]);
  const mods = (modules ?? '')
    .split(',')
    .filter((m) => (PLAN_MODULES as readonly string[]).includes(m));
  const target = Number(plan?.inputs.targetBand ?? me.user.profile?.targetBand);
  // Only same-site pages under /app can be the way back.
  const safeBack = back && /^\/app\/[\w/?=&.-]*$/.test(back) ? back : '/app/plan';
  return (
    <QuickCheck
      modules={mods.length ? mods : plan?.inputs.modules ?? [...PLAN_MODULES]}
      pro={me.usage.plan === 'pro'}
      target={Number.isFinite(target) && target > 0 ? target : null}
      back={safeBack}
    />
  );
}
