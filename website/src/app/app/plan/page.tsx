import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import Link from 'next/link';
import { PlanActions } from '@/components/plan-actions';
import { QuickCheckOffer, RefreshSoon } from '@/components/plan-bits';
import { PlanTaskRow } from '@/components/plan-task-row';
import { HeroCard, Icon, PrimaryButton } from '@/components/ui';
import p from '@/components/plan.module.css';
import { addDays, formatHalf, planDayLabel, shortDay, type PlanTask } from '@/lib/plan/plan';
import { getMe } from '@/lib/server/me';
import { currentPlan } from '@/lib/server/plan';

export const metadata: Metadata = { title: 'My study plan' };

/** My study plan (study_plan_screen.dart): week, phase, progress, the next two weeks. */
export default async function PlanPage() {
  const [{ plan, error }, me] = await Promise.all([currentPlan(), getMe()]);
  const header = (sub?: string, actions?: ReactNode) => (
    <div className={p.top}>
      <Link href="/app" className={p.back} aria-label="Home">
        <Icon name="arrow_back" size={20} />
      </Link>
      <div className={p.topText}>
        <h1 className={p.h1}>My study plan</h1>
        {sub && <p className={p.sub}>{sub}</p>}
      </div>
      {actions}
    </div>
  );

  if (!plan) {
    return (
      <>
        {header()}
        <div className={p.empty}>
          <Icon name={error ? 'wifi_off' : 'calendar_month'} size={44} color="var(--text-muted)" />
          <h2>{error ? 'Could not load your plan' : 'No study plan yet'}</h2>
          <p>{error ?? 'Answer a few questions and get daily tasks matched to your level, time and exam date.'}</p>
          <PrimaryButton href={error ? '/app/plan' : '/app/plan/setup'}>{error ? 'Try again' : 'Make my plan'}</PrimaryButton>
        </div>
      </>
    );
  }

  const paused = plan.status === 'paused';
  const { weekDone, weekTotal } = plan.progress;
  const today = plan.today;
  const byDay = new Map<string, PlanTask[]>();
  for (const t of plan.tasks) {
    if (t.date < today) continue;
    const list = byDay.get(t.date) ?? [];
    list.push(t);
    byDay.set(t.date, list);
  }
  const days = [...byDay.keys()].sort();
  const pro = me.usage.plan === 'pro';
  const free = plan.access.plan === 'free';

  return (
    <>
      {header(`Week ${plan.week} of ${plan.weeks}`, <PlanActions paused={paused} />)}

      <HeroCard padding={20} radius={30}>
        <div className={p.hero}>
          <div className={p.heroText}>
            <span className={p.overline}>{paused ? 'Paused' : plan.phase.label}</span>
            <h2 className={p.heroTitle}>
              {paused && plan.pausedUntil ? `Back on ${planDayLabel(addDays(plan.pausedUntil, 1), today)}` : `Target band ${formatHalf(Number(plan.estimate.targetBand))}`}
            </h2>
            <p className={p.heroMuted}>{plan.summary}</p>
            {plan.checkpointThisWeek && (
              <span className={p.heroTag}>
                <Icon name="flag" size={14} /> Checkpoint this week
              </span>
            )}
          </div>
          <div className={p.ring} style={{ ['--v' as string]: `${weekTotal ? (weekDone / weekTotal) * 100 : 0}%` }}>
            <b>
              {weekDone}/{weekTotal}
            </b>
            <span>this week</span>
          </div>
        </div>
      </HeroCard>

      {free && (
        <div className={p.card}>
          <div className={p.cardRow}>
            <span className={p.circle} style={{ width: 40, height: 40 }}>
              <Icon name="military_tech" size={20} />
            </span>
            <span className={p.cardTitle}>{plan.access.ended ? 'Your 3-day free plan is over' : 'Free plan: your first 3 study days'}</span>
          </div>
          <p className={p.cardText} style={{ color: 'var(--text-soft)' }}>
            {plan.access.ended
              ? 'Upgrade to Pro for a plan that runs all the way to your exam and adapts to your results every week.'
              : `Tasks are planned up to ${plan.access.freeUntil ? shortDay(plan.access.freeUntil) : 'your third study day'}. Pro plans run to your exam and adapt every week.`}
          </p>
          <PrimaryButton href="/app/upgrade" block height={46}>
            See Pro plans
          </PrimaryButton>
        </div>
      )}

      {plan.weekNote && (
        <div className={p.card}>
          <div className={p.cardRow} style={{ gap: 8 }}>
            <Icon name="auto_awesome" size={18} color="var(--peach)" />
            <span className={p.cardTitle}>{plan.weekNote.title}</span>
          </div>
          <p className={p.cardText} style={{ fontSize: 13.5 }}>
            {plan.weekNote.body}
          </p>
          {plan.weekNote.focus?.length ? (
            <div className={p.tags}>
              {plan.weekNote.focus.map((f) => (
                <span key={f} className={p.tag}>
                  {f.charAt(0).toUpperCase() + f.slice(1)}
                </span>
              ))}
            </div>
          ) : null}
        </div>
      )}
      {plan.weekNote?.by === 'rules' && <RefreshSoon />}

      {!plan.quickCheck.done && plan.week <= 2 && <QuickCheckOffer pro={pro} modules={plan.inputs.modules} />}

      {days.length === 0 && !plan.access.ended && (
        <div className={p.empty}>
          <Icon name={paused ? 'pause_circle' : 'calendar_month'} size={40} color="var(--text-muted)" />
          <h2>{paused ? 'Enjoy your break' : 'Nothing planned yet'}</h2>
          <p>{paused ? 'Your tasks come back when the pause ends.' : 'Open the options (top right) and choose re-plan.'}</p>
        </div>
      )}

      {days.map((d) => {
        const list = byDay.get(d)!;
        return (
          <section key={d} className={p.day} aria-label={planDayLabel(d, today)}>
            <div className={p.dayHead}>
              <span className={d === today ? p.dayToday : ''}>{planDayLabel(d, today)}</span>
              <span>{list.reduce((m, x) => m + (x.durationMin || 0), 0)} min</span>
            </div>
            {list.map((t) => (
              <PlanTaskRow key={t.id} task={t} />
            ))}
          </section>
        );
      })}

      <p className={p.note}>Tasks tick themselves off when you finish them anywhere in the app or on the web. Missed ones move to your next study day.</p>
    </>
  );
}
