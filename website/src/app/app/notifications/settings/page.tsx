import type { Metadata } from 'next';
import Link from 'next/link';
import h from '@/components/home/home.module.css';
import { NotificationSettings } from '@/components/home/notif-settings';
import { NOTIF_GROUPS } from '@/lib/home/notif';
import { Icon, Notice } from '@/components/ui';
import { stateValue } from '@/lib/home/server';

export const metadata: Metadata = { title: 'Notifications' };

/** Profile › Notifications (notification_settings_screen.dart). */
export default async function NotificationSettingsPage() {
  const [groups, legacyStudy, time] = await Promise.all([
    stateValue<Record<string, unknown>>('notif.groups'),
    stateValue<boolean>('home.studyReminders'),
    stateValue<string>('notif.time'),
  ]);
  const on: Record<string, boolean> = {};
  for (const g of NOTIF_GROUPS) {
    const v = groups && typeof groups === 'object' ? groups[g.id] : undefined;
    on[g.id] = typeof v === 'boolean' ? v : g.id === 'study' ? legacyStudy !== false : true;
  }
  const validTime = typeof time === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(time) ? time : '20:00';
  return (
    <div className={h.narrow}>
      <div className={h.top}>
        <Link href="/app/profile" className={h.back} aria-label="Back to Profile">
          <Icon name="arrow_back" size={20} />
        </Link>
      </div>
      <h1 className={h.h1} style={{ fontWeight: 500 }}>
        Notifications
      </h1>
      <Notice icon="smartphone" title="Sent by the IELTS AI app">
        Reminders and alerts arrive on your phone through the IELTS AI by nextED app. What you choose here is saved to your account, so the app follows it.
      </Notice>
      <NotificationSettings groups={on} time={validTime} />
      <p className={h.note}>
        We never send study reminders between 10:30 PM and 8 AM, and at most one a day. Notifications use your explanation language.
      </p>
      <Link href="/app/notifications" className={h.setting}>
        <Icon name="notifications" size={22} className={h.settingIcon} />
        <span className={h.settingText}>
          <span>Activity</span>
          <span className={h.settingSub}>Your scores, reminders and updates</span>
        </span>
        <Icon name="chevron_right" size={20} className={h.settingIcon} />
      </Link>
    </div>
  );
}
