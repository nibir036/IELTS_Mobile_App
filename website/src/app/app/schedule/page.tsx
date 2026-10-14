import type { Metadata } from 'next';
import Link from 'next/link';
import h from '@/components/home/home.module.css';
import { AddTaskButton, ScheduleTaskRow, type TaskView } from '@/components/home/schedule-bits';
import { Card, HeroCard, Icon, PrimaryButton } from '@/components/ui';
import { appHref } from '@/lib/home/routes';
import { homeSection, tasks as loadTasks, type Task } from '@/lib/home/server';
import { homeIcon, skillLabel } from '@/lib/home/stats';
import { addDaysKey, daysBetween, fmtDuration, fmtTime, keyDate, MO_LONG, shortDate, todayKey, WD, WD_LONG, weekdayDate, weekdayIndex } from '@/lib/home/time';
import { skillLanding, taskHref, type PlanTask } from '@/lib/plan/plan';

export const metadata: Metadata = { title: 'Schedule' };

const isPlan = (t: Task) => t.kind === 'plan' || t.kind === 'checkpoint';

function subtitle(t: Task): string {
  const kind = { goal: 'Daily goal', deadline: 'Deadline', reminder: 'Reminder' }[t.kind] ?? '';
  return [kind, t.skill ? skillLabel(t.skill) : '', t.time ? fmtTime(t.time) : '', fmtDuration(t.durationMin)].filter(Boolean).join(' · ');
}

function hrefOf(t: Task): string {
  if (isPlan(t)) return taskHref(t as unknown as PlanTask);
  return (t.target && appHref(t.target, t.args)) || skillLanding(t.skill);
}

/** B5 · Schedule & deadlines (schedule_screen.dart). */
export default async function SchedulePage({ searchParams }: { searchParams: Promise<{ day?: string; filter?: string }> }) {
  const sp = await searchParams;
  const today = todayKey();
  const day = sp.day && /^\d{4}-\d{2}-\d{2}$/.test(sp.day) && !Number.isNaN(keyDate(sp.day).getTime()) ? sp.day : today;
  const [all, home] = await Promise.all([loadTasks(), homeSection()]);
  const filters = (((home.schedule ?? {}) as Record<string, unknown>).filters as Array<{ id: string; label: string }> | undefined) ?? [{ id: 'all', label: 'All' }];
  const filter = filters.some((f) => f.id === sp.filter) ? (sp.filter as string) : 'all';
  const list = all ?? [];
  const on = (k: string) => list.filter((t) => t.date === k).sort((a, b) => (a.time || '').localeCompare(b.time || ''));
  const dayTasks = on(day);
  const visible = filter === 'all' ? dayTasks : dayTasks.filter((t) => t.skill === filter);
  const doneCount = dayTasks.filter((t) => t.done).length;
  const offset = daysBetween(today, day);
  const dayWord = offset === 0 ? 'Today' : offset === 1 ? 'Tomorrow' : offset === -1 ? 'Yesterday' : offset > 0 ? `In ${offset} days` : `${-offset} days ago`;
  const q = (o: { day?: string; filter?: string }) => {
    const p = new URLSearchParams();
    const dd = o.day ?? day;
    const ff = o.filter ?? filter;
    if (dd !== today) p.set('day', dd);
    if (ff !== 'all') p.set('filter', ff);
    return p.size ? `/app/schedule?${p}` : '/app/schedule';
  };

  // Next unfinished mock on the schedule.
  let mock: Task | null = null;
  for (const t of list) {
    if (t.skill !== 'mock' || t.done || t.date < today) continue;
    if (!mock || t.date < mock.date || (t.date === mock.date && (t.time || '') < (mock.time || ''))) mock = t;
  }
  const mockDays = mock ? daysBetween(today, mock.date) : 0;
  const dd = keyDate(day);
  const dayTitle = `${WD_LONG[weekdayIndex(day)]}, ${dd.getUTCDate()} ${MO_LONG[dd.getUTCMonth()]}`;

  const view = (t: Task): TaskView => ({
    id: t.id,
    title: t.title,
    subtitle: subtitle(t),
    done: t.done,
    deadline: t.kind === 'deadline',
    icon: homeIcon(t.skill),
    href: hrefOf(t),
  });

  return (
    <>
      <div className={h.top}>
        <Link href="/app" className={h.back} aria-label="Back to Home">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={h.spacer} />
        {day !== today && (
          <Link href={q({ day: today })} className={h.pill}>
            Today
          </Link>
        )}
        <AddTaskButton day={day} dayLabel={weekdayDate(day)} variant="icon" />
      </div>
      <h1 className={h.h1}>Schedule</h1>

      <nav className={h.strip} aria-label="Days">
        <Link href={q({ day: addDaysKey(day, -7) })} className={h.ghostBtn} aria-label="Previous week" replace scroll={false}>
          <Icon name="chevron_left" size={22} />
        </Link>
        {[-3, -2, -1, 0, 1, 2, 3].map((i) => {
          const k = addDaysKey(day, i);
          const dist = Math.abs(i);
          const has = on(k).length > 0;
          return (
            <Link
              key={k}
              href={q({ day: k })}
              replace
              scroll={false}
              className={`${h.dayCell} ${dist === 0 ? h.dayMid : dist === 1 ? h.dayNear : ''} ${has ? h.dayHas : ''}`}
              aria-current={dist === 0 ? 'date' : undefined}
              aria-label={`${weekdayDate(k)}${has ? ', has tasks' : ''}`}
            >
              <span>{WD[weekdayIndex(k)]}</span>
              <b>{keyDate(k).getUTCDate()}</b>
              <span className={h.dayDot} />
            </Link>
          );
        })}
        <Link href={q({ day: addDaysKey(day, 7) })} className={h.ghostBtn} aria-label="Next week" replace scroll={false}>
          <Icon name="chevron_right" size={22} />
        </Link>
      </nav>

      <nav className={h.chips} aria-label="Filter">
        {filters.map((f, i) => (
          <Link key={f.id} href={q({ filter: f.id })} replace scroll={false} className={`${h.chipOutline} ${f.id === filter ? h.chipOutlineOn : ''}`} aria-current={f.id === filter ? 'page' : undefined}>
            {f.label}
            {i === 0 && <i>{dayTasks.length}</i>}
          </Link>
        ))}
      </nav>

      <div className={h.grid2}>
        <Card radius={30} padding={18}>
          <div className={h.cardHead} style={{ padding: '0 4px 8px' }}>
            <div style={{ minWidth: 0 }}>
              <div className={h.dayTitle}>{dayTitle}</div>
              <div className={`${h.dayWord} ${offset === 0 ? h.dayWordToday : ''}`}>{dayWord}</div>
            </div>
            {dayTasks.length > 0 && (
              <span className={h.label}>
                {doneCount} of {dayTasks.length} done
              </span>
            )}
          </div>
          {all == null && <p className={h.emptyNote}>Your schedule could not be loaded. Please try again.</p>}
          {all != null && visible.length === 0 && (
            <div className={h.emptyState} style={{ padding: '12px 8px' }}>
              <p>{dayTasks.length === 0 ? 'Nothing scheduled for this day' : 'Nothing in this category'}</p>
              {dayTasks.length === 0 && <AddTaskButton day={day} dayLabel={weekdayDate(day)} variant="soft" />}
            </div>
          )}
          <div className={h.stack} style={{ gap: 10 }}>
            {visible.map((t) => (
              <ScheduleTaskRow key={t.id} task={view(t)} />
            ))}
          </div>
        </Card>

        <div className={h.stack}>
          {mock && (
            <Link href="/app/mocks" style={{ display: 'block' }}>
              <HeroCard radius={30} padding={18}>
                <div className={h.heroRow} style={{ gap: 14 }}>
                  <div className={h.heroCol} style={{ gap: 2 }}>
                    <span className={h.overline}>Upcoming mock test</span>
                    <span style={{ fontSize: 20, fontWeight: 500 }}>{mock.title}</span>
                    <span className={h.heroMuted}>
                      {[`${WD[weekdayIndex(mock.date)]}, ${shortDate(mock.date)}`, mock.time ? fmtTime(mock.time) : '', fmtDuration(mock.durationMin)].filter(Boolean).join(' · ')}
                    </span>
                  </div>
                  <span className={h.daysBox}>
                    <b>{mockDays}</b>
                    <span>{mockDays === 1 ? 'day' : 'days'}</span>
                  </span>
                </div>
              </HeroCard>
            </Link>
          )}
          <Card radius={26} padding={18}>
            <div className={h.rowBetween}>
              <div>
                <div style={{ fontSize: 16, fontWeight: 500 }}>Your study plan</div>
                <span className={h.label}>Plan tasks show up here day by day.</span>
              </div>
              <PrimaryButton href="/app/plan" height={42}>
                Open
              </PrimaryButton>
            </div>
          </Card>
        </div>
      </div>
    </>
  );
}
