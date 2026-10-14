'use client';

import { useState } from 'react';
import { Icon } from '@/components/ui';
import { NOTIF_GROUPS } from '@/lib/home/notif';
import h from './home.module.css';

const GROUPS = 'notif.groups';
const TIME = 'notif.time';
const LEGACY_STUDY = 'home.studyReminders';


async function readState(prefix: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(`/api/v1/state?prefix=${encodeURIComponent(prefix)}`).catch(() => null);
  if (!res?.ok) return null;
  return ((await res.json()) as { state?: Record<string, unknown> }).state ?? {};
}

async function putState(values: Record<string, unknown>): Promise<boolean> {
  const res = await fetch('/api/v1/state', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ values }) }).catch(() => null);
  return Boolean(res?.ok);
}

const fmt = (hhmm: string) => {
  const [hs, ms = '00'] = hhmm.split(':');
  const hr = Number(hs) || 0;
  return `${hr % 12 === 0 ? 12 : hr % 12}:${ms} ${hr < 12 ? 'AM' : 'PM'}`;
};

/** Profile › Notifications (notification_settings_screen.dart), kept in the same kv as the app. */
export function NotificationSettings({ groups: initial, time: initialTime }: { groups: Record<string, boolean>; time: string }) {
  const [groups, setGroups] = useState(initial);
  const [time, setTime] = useState(initialTime);
  const [msg, setMsg] = useState('');

  const toggle = async (id: string) => {
    const value = !groups[id];
    setGroups((g) => ({ ...g, [id]: value }));
    // Read-merge-write: the app may have changed other groups.
    const cur = await readState(GROUPS);
    const stored = cur && typeof cur[GROUPS] === 'object' && cur[GROUPS] ? (cur[GROUPS] as Record<string, unknown>) : {};
    const ok = await putState({ [GROUPS]: { ...stored, [id]: value }, ...(id === 'study' ? { [LEGACY_STUDY]: value } : {}) });
    if (!ok) {
      setGroups((g) => ({ ...g, [id]: !value }));
      setMsg('Could not save. Please try again.');
    } else setMsg('');
  };

  const saveTime = async (raw: string) => {
    const [hs, ms] = raw.split(':');
    const m = (Number(hs) || 0) * 60 + (Number(ms) || 0);
    const clamped = Math.min(22 * 60 + 30, Math.max(8 * 60, m));
    const v = `${String(Math.floor(clamped / 60)).padStart(2, '0')}:${String(clamped % 60).padStart(2, '0')}`;
    setTime(v);
    const ok = await putState({ [TIME]: v });
    setMsg(!ok ? 'Could not save. Please try again.' : clamped !== m ? 'Reminders are sent between 8:00 AM and 10:30 PM' : `Daily reminder set for ${fmt(v)}`);
  };

  const studyOn = groups.study !== false;
  return (
    <>
      <div className={h.settings}>
        {NOTIF_GROUPS.map((g) => {
          const on = groups[g.id] !== false;
          return (
            <div key={g.id} className={h.setting}>
              <Icon name={g.icon} size={22} className={h.settingIcon} />
              <span className={h.settingText}>
                <span id={`ng-${g.id}`}>{g.label}</span>
                <span className={h.settingSub} style={{ whiteSpace: 'normal' }}>
                  {g.description}
                </span>
              </span>
              <button type="button" role="switch" aria-checked={on} aria-labelledby={`ng-${g.id}`} className={`${h.switch} ${on ? h.switchOn : ''}`} onClick={() => toggle(g.id)} />
            </div>
          );
        })}
      </div>
      <label className={`${h.setting} ${studyOn ? '' : h.dim}`}>
        <Icon name="schedule" size={22} className={h.settingIcon} />
        <span className={h.settingText}>
          <span>Daily reminder</span>
          <span className={h.settingSub}>When we remind you to study</span>
        </span>
        <input type="time" className={h.timeInput} value={time} min="08:00" max="22:30" step={300} disabled={!studyOn} onChange={(e) => e.target.value && saveTime(e.target.value)} />
      </label>
      <p className={h.note} role="status">
        {msg}
      </p>
    </>
  );
}
