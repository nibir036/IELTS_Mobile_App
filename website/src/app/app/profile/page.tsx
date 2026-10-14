import type { Metadata } from 'next';
import Link from 'next/link';
import { Avatar } from '@/components/home/avatar';
import { EditProfileButton } from '@/components/home/edit-profile';
import h from '@/components/home/home.module.css';
import { Card, Icon } from '@/components/ui';
import { availableLangs } from '@/lib/server/content';
import { LANG_KEY } from '@/lib/content/lang';
import { targetHref } from '@/lib/home/routes';
import { certificates, homeSection, myAttempts, stateValue, tasks as loadTasks, unreadCount } from '@/lib/home/server';
import { formatBand, homeIcon, phoneMasked, profileOf, streakDays, totalMinutes } from '@/lib/home/stats';
import { daysBetween, studyTimeLabel, todayKey, weekdayDate } from '@/lib/home/time';
import { lessonsDone } from '@/lib/server/lessons';
import { getMe } from '@/lib/server/me';
import { uiPack } from '@/lib/server/packs';
import { AppearanceToggle, ChangePasswordRow, DeleteAccountRow, LanguageRow, LogoutRow } from './actions';

export const metadata: Metadata = { title: 'Profile' };

type Raw = Record<string, unknown>;

/** B7 · Profile & settings (profile_screen.dart). */
export default async function ProfilePage() {
  const [me, mine, done, home, ui, tasks, saved, groups, legacyStudy, lang, ready, unread] = await Promise.all([
    getMe(),
    myAttempts(),
    lessonsDone(),
    homeSection(),
    uiPack().catch(() => ({}) as Raw),
    loadTasks(),
    stateValue<unknown[]>('resources.savedWords'),
    stateValue<Raw>('notif.groups'),
    stateValue<boolean>('home.studyReminders'),
    stateValue<string>(LANG_KEY),
    availableLangs('reading'),
    unreadCount(),
  ]);
  const prof = profileOf(me.user.profile);
  const certs = await certificates({ attempts: mine, done, target: prof.targetBand });
  const pro = me.usage.plan === 'pro';
  const planName = pro ? 'Pro' : 'Free';
  const streak = streakDays(mine, done);
  const days = prof.examDate ? daysBetween(todayKey(), prof.examDate) : null;
  const today = todayKey();
  const reminders = typeof groups?.study === 'boolean' ? groups.study : legacyStudy !== false;
  const strengthLabels = ((((ui.access ?? {}) as Raw).signup ?? {}) as Raw).strengthLabels;

  const counts: Record<string, number> = {
    saved: Array.isArray(saved) ? saved.length : 0,
    calendar: (tasks ?? []).filter((t) => !t.done && t.date >= today).length,
    certificates: certs.items.filter((c) => c.earned).length,
    recordings: mine.filter((a) => a.skill === 'speaking' && a.kind !== 'session' && a.kind !== 'pronunciation').length,
  };
  const learning = (((home.profile ?? {}) as Raw).learning as Raw[] | undefined) ?? [];

  const row = (o: { href: string; icon: string; title: string; subtitle?: string; trail?: string }) => (
    <Link key={o.title} href={o.href} className={h.setting}>
      <Icon name={o.icon} size={22} className={h.settingIcon} />
      <span className={h.settingText}>
        <span>{o.title}</span>
        {o.subtitle && <span className={h.settingSub}>{o.subtitle}</span>}
      </span>
      {o.trail && <span className={h.settingTrail}>{o.trail}</span>}
      <Icon name="chevron_right" size={20} className={h.settingIcon} />
    </Link>
  );

  return (
    <>
      <div className={h.top}>
        <h1 className={`${h.h1} ${h.topText}`}>Profile &amp; Settings</h1>
        <Link href="/app/notifications" className={h.iconBtn} aria-label={unread ? `Notifications, ${unread} unread` : 'Notifications'} title="Notifications">
          <Icon name="notifications" size={22} />
          {unread > 0 && <span className={h.dot} />}
        </Link>
      </div>

      <div className={h.grid2}>
        <div className={h.stack}>
          <Card radius={30} padding={18}>
            <div className={h.identity}>
              <Avatar name={me.user.name} photo={prof.photo} size={72} />
              <div className={h.rowText}>
                <p className={h.idName}>{me.user.name}</p>
                <span className={h.idLine} style={{ fontSize: 14 }}>
                  {prof.targetBand == null ? 'No target yet' : `Target ${formatBand(prof.targetBand)}`} · Academic
                </span>
                <span className={h.idLine} style={{ fontSize: 12 }}>
                  {phoneMasked(me.user.phone)} · {planName} plan
                </span>
                <span className={h.idLine} style={{ fontSize: 12 }}>
                  {prof.examDate ? `Exam ${weekdayDate(prof.examDate)}${days != null && days >= 0 ? ` · ${days} days left` : ''}` : 'Exam date not set'}
                </span>
              </div>
              <EditProfileButton
                initial={{ name: me.user.name, targetBand: prof.targetBand, examDate: prof.examDate, photo: prof.photo }}
                className={h.editBtn}
                label="Edit profile"
              >
                <Icon name="edit" size={20} />
              </EditProfileButton>
            </div>
            <div className={h.statPills}>
              <Link href="/app/analytics" className={h.statPill}>
                <span className={h.statIcon}>
                  <Icon name="trending_up" size={18} />
                </span>
                <span className={h.rowText}>
                  <span className={h.rowTitle} style={{ fontSize: 14 }}>
                    Study time
                  </span>
                  <span className={h.rowSub}>{studyTimeLabel(totalMinutes(mine))}</span>
                </span>
              </Link>
              <Link href="/app/notifications" className={h.statPill}>
                <span className={h.statIcon} style={{ color: 'var(--warning)' }}>
                  <Icon name="local_fire_department" size={18} />
                </span>
                <span className={h.rowText}>
                  <span className={h.rowTitle} style={{ fontSize: 14 }}>
                    Streak
                  </span>
                  <span className={h.rowSub}>{streak === 1 ? '1 day' : `${streak} days`}</span>
                </span>
              </Link>
            </div>
          </Card>

          <h2 className={h.sectionLabel} style={{ fontWeight: 400 }}>
            Learning
          </h2>
          <div className={h.settings}>
            {learning.map((r) => {
              const id = String(r.id ?? '');
              const n = counts[id] ?? 0;
              return row({ href: targetHref(String(r.target ?? '')) || '/app', icon: homeIcon(String(r.icon ?? '')), title: String(r.title ?? ''), trail: n > 0 ? String(n) : undefined });
            })}
          </div>

          <h2 className={h.sectionLabel} style={{ fontWeight: 400 }}>
            Account
          </h2>
          <div className={h.settings}>
            {row({ href: '/app/profile/billing', icon: 'star', title: 'Plans & billing', subtitle: pro ? 'Your pass, auto-renewal and payment method' : 'Compare Free and Pro', trail: planName })}
            <ChangePasswordRow strengthLabels={Array.isArray(strengthLabels) ? strengthLabels.map(String) : []} />
            {row({ href: '/app/profile/devices', icon: 'devices', title: 'Your devices', subtitle: 'Up to 2 devices · one screen at a time' })}
            {row({ href: '/app/plan', icon: 'calendar_month', title: 'Study plan', subtitle: 'Your daily tasks and progress' })}
          </div>
        </div>

        <div className={h.stack}>
          <h2 className={h.sectionLabel} style={{ fontWeight: 400 }}>
            App settings
          </h2>
          <div className={h.settings}>
            <div className={h.setting}>
              <Icon name="dark_mode" size={22} className={h.settingIcon} />
              <span className={h.settingText}>
                <span>Appearance</span>
              </span>
              <AppearanceToggle />
            </div>
            {row({ href: '/app/notifications/settings', icon: 'notifications', title: 'Notifications', trail: reminders ? 'On' : 'Off' })}
            <LanguageRow current={typeof lang === 'string' ? lang : 'en'} ready={ready} />
            {row({ href: '/terms', icon: 'description', title: 'Terms of use' })}
            {row({ href: '/privacy', icon: 'shield', title: 'Privacy policy' })}
            <LogoutRow />
            <DeleteAccountRow isDemo={me.user.isDemo} />
          </div>
        </div>
      </div>
    </>
  );
}
