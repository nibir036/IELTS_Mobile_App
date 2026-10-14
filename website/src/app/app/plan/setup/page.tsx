import type { Metadata } from 'next';
import { PLAN_MODULES, type PlanInputs } from '@/lib/plan/plan';
import { getMe } from '@/lib/server/me';
import { currentPlan } from '@/lib/server/plan';
import { PlanSetup } from './setup';

export const metadata: Metadata = { title: 'Your study plan' };

/** Study plan set-up (plan_setup_screen.dart) and preview; `?edit=1` changes the current plan. */
export default async function SetupPage({ searchParams }: { searchParams: Promise<{ edit?: string; preview?: string }> }) {
  const { edit, preview } = await searchParams;
  const [{ plan }, me] = await Promise.all([currentPlan(), getMe()]);
  const profile = me.user.profile ?? {};
  const target = Number(profile.targetBand);
  const exam = typeof profile.examDate === 'string' ? profile.examDate.slice(0, 10) : null;
  const defaults: PlanInputs = plan?.inputs
    ? { ...plan.inputs }
    : {
        modules: [...PLAN_MODULES],
        levels: Object.fromEntries(PLAN_MODULES.map((m) => [m, 'intermediate'])),
        targetBand: Number.isFinite(target) && target >= 4 ? target : 7,
        testType: 'academic',
        examDate: exam,
        days: [1, 2, 3, 4, 5, 6],
        minutesPerDay: 30,
        studyTime: '20:00',
      };
  return <PlanSetup defaults={defaults} edit={edit === '1' && Boolean(plan)} quickCheckDone={Boolean(plan?.quickCheck.done)} pro={me.usage.plan === 'pro'} resume={preview === '1'} />;
}
