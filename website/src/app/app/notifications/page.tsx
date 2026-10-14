import type { Metadata } from 'next';
import Link from 'next/link';
import h from '@/components/home/home.module.css';
import { MarkAllRead, NotificationRow, type NoteView } from '@/components/home/notification-bits';
import { Card, HeroCard, Icon, PrimaryButton } from '@/components/ui';
import { appHref } from '@/lib/home/routes';
import { homeSection, myAttempts, notifications } from '@/lib/home/server';
import { homeIcon, minutesOn, resultHref, streakDays } from '@/lib/home/stats';
import { addDaysKey, dayKey, relativeDay, timeAgo, todayKey, WD, weekdayIndex } from '@/lib/home/time';
import { lessonsDone } from '@/lib/server/lessons';

export const metadata: Metadata = { title: 'Activity' };

/** Types each filter chip shows. */
const FILTER_TYPES: Record<string, string[]> = {
  ai: ['score', 'ai'],
  reminder: ['reminder', 'system'],
  community: ['community'],
};

type Raw = Record<string, unknown>;

/** B6 · Notifications & activity (notifications_screen.dart). */
export default async function NotificationsPage({ searchParams }: { searchParams: Promise<{ filter?: string }> }) {
  const sp = await searchParams;
  const [data, home, mine, done] = await Promise.all([notifications(200), homeSection(), myAttempts(), lessonsDone()]);
  const filters = (((home.notifications ?? {}) as Raw).filters as Array<{ id: string; label: string }> | undefined) ?? [{ id: 'all', label: 'All' }];
  const filter = filters.some((f) => f.id === sp.filter) ? (sp.filter as string) : 'all';
  const items = data?.items ?? [];
  const types = FILTER_TYPES[filter];
  const visible = (filter === 'all' || !types ? items : items.filter((n) => types.includes(n.type))).sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  );
  const byId = new Map(mine.map((a) => [a.id, a]));

  const view = (n: (typeof items)[number]): NoteView => {
    const args = (n.args ?? {}) as Raw;
    const att = typeof args.attemptId === 'string' ? byId.get(args.attemptId) : undefined;
    const href = att ? resultHref(att) : n.target ? appHref(n.target, args) : '';
    let icon = 'bell';
    let tone: NoteView['tone'] = 'neutral';
    if (typeof args.icon === 'string' && args.icon) {
      icon = args.icon;
      tone = (['primary', 'pink', 'lavender'].includes(String(args.tone)) ? args.tone : 'neutral') as NoteView['tone'];
    } else if (n.type === 'score' || n.type === 'ai') {
      icon = n.skill === 'speaking' ? 'mic' : 'sparkle';
      tone = n.skill === 'speaking' ? 'pink' : 'primary';
    } else if (n.type === 'reminder') {
      icon = 'clock';
      tone = 'lavender';
    } else if (n.type === 'community') {
      icon = 'chat';
    }
    return { id: n.id, title: n.title, body: n.body, time: timeAgo(n.createdAt), read: n.read, href, icon: homeIcon(icon), tone };
  };

  const groups: Array<{ label: string; items: NoteView[] }> = [];
  for (const n of visible) {
    const g = relativeDay(n.createdAt);
    let grp = groups.find((x) => x.label === g);
    if (!grp) groups.push((grp = { label: g, items: [] }));
    grp.items.push(view(n));
  }

  // Streak card: the last 7 days with practice.
  const streak = streakDays(mine, done);
  const today = todayKey();
  const active = new Set(mine.map((a) => dayKey(new Date(a.createdAt))));
  const week = Array.from({ length: 7 }, (_, i) => {
    const k = addDaysKey(today, i - 6);
    return { k, label: WD[weekdayIndex(k)].slice(0, 1), done: active.has(k), today: i === 6 };
  });
  const studiedToday = week[6].done;
  const subtitle = studiedToday ? `You studied ${minutesOn(mine, today)} min today` : streak > 0 ? 'Study 20 min today to keep it' : 'Practise today to start a streak';

  return (
    <>
      <div className={h.top}>
        <Link href="/app" className={h.back} aria-label="Back to Home">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={h.spacer} />
        {(data?.unread ?? 0) > 0 && <MarkAllRead />}
        <Link href="/app/notifications/settings" className={h.iconBtn} aria-label="Notification settings" title="Notification settings">
          <Icon name="settings" size={21} />
        </Link>
      </div>
      <h1 className={h.h1} style={{ fontWeight: 500 }}>
        Activity
      </h1>
      <nav className={h.chips} aria-label="Filter">
        {filters.map((f, i) => (
          <Link
            key={f.id}
            href={f.id === 'all' ? '/app/notifications' : `/app/notifications?filter=${encodeURIComponent(f.id)}`}
            replace
            scroll={false}
            className={`${h.chip} ${f.id === filter ? h.chipOn : ''}`}
            aria-current={f.id === filter ? 'page' : undefined}
          >
            {f.label}
            {i === 0 && <span className={h.chipCount}>{items.length}</span>}
          </Link>
        ))}
      </nav>

      <div className={h.grid2}>
        <HeroCard radius={26} padding={18}>
          <div className={h.rowBetween}>
            <div>
              <div style={{ fontSize: 20, fontWeight: 500 }}>{streak === 1 ? '1-day streak' : `${streak}-day streak`}</div>
              <div className={h.heroMuted}>{subtitle}</div>
            </div>
            <span className={h.fireBox}>
              <Icon name="local_fire_department" size={22} />
            </span>
          </div>
          <div className={h.week} role="img" aria-label={`Practice this week: ${week.map((d) => `${WD[weekdayIndex(d.k)]} ${d.done ? 'done' : 'no practice'}`).join(', ')}`}>
            {week.map((d) => (
              <span key={d.k} className={`${h.weekDay} ${d.done ? h.weekDone : ''} ${d.today ? h.weekToday : ''}`}>
                <i />
                {d.label}
              </span>
            ))}
          </div>
        </HeroCard>

        <div className={h.stack} style={{ gap: 12 }}>
          {!data && (
            <Card>
              <div className={h.emptyState}>
                <Icon name="wifi_off" size={40} color="var(--text-muted)" />
                <h2>Couldn’t load your notifications</h2>
                <PrimaryButton href="/app/notifications">Try again</PrimaryButton>
              </div>
            </Card>
          )}
          {groups.map((g) => (
            <section key={g.label} className={h.stack} style={{ gap: 10 }} aria-label={g.label}>
              <h2 className={h.groupLabel} style={{ fontWeight: 400, margin: '0 4px' }}>
                {g.label}
              </h2>
              <Card radius={24} padding={6}>
                {g.items.map((n) => (
                  <NotificationRow key={n.id} n={n} />
                ))}
              </Card>
            </section>
          ))}
          {data && visible.length === 0 && <p className={h.emptyNote}>You’re all caught up</p>}
        </div>
      </div>
    </>
  );
}
