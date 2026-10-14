import type { Metadata } from 'next';
import Link from 'next/link';
import { AiNotes } from '@/components/extras/ai-notes';
import { PlanBoard } from '@/components/extras/plan-board';
import { Card, Icon, PrimaryButton } from '@/components/ui';
import { dhakaDay } from '@/lib/extras/format';
import { buildPlan } from '@/lib/extras/mock-plan';
import { mockAttempt, mockAttempts, mockCopy } from '@/lib/extras/mock-server';
import { stateValue } from '@/lib/server/attempts';
import { getMe } from '@/lib/server/me';
import x from '@/components/extras/extras.module.css';

export const metadata: Metadata = { title: 'Improvement plan' };

/** Badge colours of the skills (same in Day and Night, dark ink). */
const TINT: Record<string, string> = { writing: '#FFE2D8', listening: '#DCE6FF', speaking: '#FFD2C4', reading: '#E9EFFF' };

/** G10 · AI Actionable Improvement Plan for one mock attempt (improvement_plan_screen.dart). */
export default async function ImprovementPlan({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const a = await mockAttempt(id);
  const top = (
    <div className={x.top} style={{ justifyContent: 'space-between' }}>
      <Link href={a ? `/app/mocks/result/${encodeURIComponent(a.id)}` : '/app/mocks'} className={x.iconBtn} aria-label="Back to the score report">
        <Icon name="arrow_back" size={20} />
      </Link>
      <Link href="/app/plan" className={x.iconBtn} aria-label="My schedule" title="My schedule">
        <Icon name="calendar_today" size={20} />
      </Link>
    </div>
  );
  if (!a) {
    return (
      <div className={x.page}>
        {top}
        <Card>
          <div className={x.empty}>
            <Icon name="auto_awesome" size={34} color="var(--text-muted)" />
            <h1 className={x.emptyTitle}>No plan yet</h1>
            <p className={x.emptyText}>Your improvement plan is built from your weakest sections after a full mock test.</p>
            <PrimaryButton href="/app/mocks">Start a mock test</PrimaryButton>
          </div>
        </Card>
      </div>
    );
  }

  const [copy, me, all, done, scheduled] = await Promise.all([
    mockCopy(),
    getMe(),
    mockAttempts(),
    stateValue<unknown[]>(`mock.plan.${a.id}`),
    stateValue<unknown[]>('mock.planScheduled'),
  ]);
  const target = Number(me.user.profile?.targetBand) || 7;
  const plan = buildPlan(a, dhakaDay(a.createdAt), copy, target, all.length);

  return (
    <div className={x.page}>
      {top}
      <div>
        <h1 className={x.h1}>{plan.title}</h1>
        {plan.subtitle && <p className={x.lead}>{plan.subtitle}</p>}
      </div>
      <AiNotes data={a.data} />
      <Card padding="12px 16px 6px" radius={24}>
        <div className={x.gainHead}>
          <Icon name="auto_awesome" size={16} color="var(--icon-accent)" /> Biggest gains for you
        </div>
        {plan.gains.map((g) => (
          <div key={g.skill} className={x.gain}>
            <span className={x.gainBadge} style={{ background: TINT[g.skill] ?? '#FFE2D8' }} aria-hidden>
              {g.letter}
            </span>
            <span className={x.gainText}>
              <span className={x.gainTitle}>{g.title}</span>
              <span className={x.small}>{g.skillName}</span>
            </span>
            <span className={x.gainScore}>{g.score}</span>
          </div>
        ))}
      </Card>
      <PlanBoard
        attemptId={a.id}
        weeks={plan.weeks}
        initialDone={Array.isArray(done) ? done.map(String) : []}
        initialScheduled={Array.isArray(scheduled) && scheduled.map(String).includes(a.id)}
      />
    </div>
  );
}
