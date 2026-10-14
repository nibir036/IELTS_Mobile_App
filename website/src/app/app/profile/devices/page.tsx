import type { Metadata } from 'next';
import Link from 'next/link';
import h from '@/components/home/home.module.css';
import { Card, Icon, IconCircle, PrimaryButton, Tag } from '@/components/ui';
import { weekdayDate, dayKey } from '@/lib/home/time';
import { api, ApiError } from '@/lib/server/api';
import { RemoveDeviceButton } from '../actions';

export const metadata: Metadata = { title: 'Your devices' };

interface Device {
  id: string;
  name: string;
  platform: string | null;
  status: 'active' | 'locked';
  current: boolean;
  lockedUntil: string | null;
  lastSeenAt: string;
}
interface Devices {
  maxDevices: number;
  lockHours: number;
  removeCooldownDays: number;
  nextRemovalAt: string | null;
  devices: Device[];
}

const when = (iso: string) =>
  new Date(iso).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Dhaka' });

const iconFor = (d: Device) => (d.status === 'locked' ? 'lock' : ['Web', 'Windows', 'macOS', 'Linux'].includes(d.platform ?? '') ? 'devices' : 'smartphone');

/** Settings › Your devices (devices_screen.dart): up to 2 devices, one screen at a time. */
export default async function DevicesPage() {
  let data: Devices | null = null;
  let error = '';
  try {
    data = await api<Devices>('/v1/me/devices');
  } catch (e) {
    error = e instanceof ApiError ? e.message : 'Your devices could not be loaded.';
  }
  const max = data?.maxDevices ?? 2;
  const lockHours = data?.lockHours ?? 48;
  const cooldown = data?.removeCooldownDays ?? 30;
  const active = (data?.devices ?? []).filter((d) => d.status === 'active').length;

  return (
    <div className={h.narrow}>
      <div className={h.top}>
        <Link href="/app/profile" className={h.back} aria-label="Back to Profile">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={h.topText}>
          <h1 className={h.h1} style={{ fontSize: 24, fontWeight: 600 }}>
            Your devices
          </h1>
          <p className={h.sub}>Up to {max} devices · one screen at a time</p>
        </div>
      </div>

      <Card radius={22} style={{ background: 'var(--surface-alt)' }}>
        <div style={{ fontSize: 15.5, fontWeight: 600, marginBottom: 6 }}>How it works</div>
        <ul style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4, fontSize: 13.5, lineHeight: 1.4, color: 'var(--text-soft)' }}>
          <li>Your account works on up to {max} devices.</li>
          <li>Only one can be signed in at a time: signing in on one signs the other out.</li>
          <li>Signing in on a further device locks that device for {lockHours} hours.</li>
          <li>You can remove a device once every {cooldown} days.</li>
        </ul>
      </Card>

      {error ? (
        <Card>
          <div className={h.emptyState}>
            <Icon name="devices" size={40} color="var(--text-muted)" />
            <h2>Couldn’t load your devices</h2>
            <p>{error}</p>
            <PrimaryButton href="/app/profile/devices">Try again</PrimaryButton>
          </div>
        </Card>
      ) : (
        <>
          <h2 className={h.cardTitle} style={{ fontSize: 15, margin: '4px 4px -6px' }}>
            {active} of {max} in use
          </h2>
          {(data?.devices ?? []).map((d) => (
            <Card key={d.id} radius={22} padding={14}>
              <div className={h.identity} style={{ gap: 12 }}>
                <IconCircle icon={iconFor(d)} size={44} bg={d.status === 'locked' ? 'var(--danger-soft)' : undefined} fg={d.status === 'locked' ? 'var(--danger)' : undefined} />
                <div className={h.rowText}>
                  <span className={h.rowTitle}>{d.name}</span>
                  <span className={h.rowSub}>
                    {d.status === 'locked'
                      ? `Locked until ${d.lockedUntil ? when(d.lockedUntil) : '-'}`
                      : d.current
                        ? 'You’re using this device'
                        : `Last active ${when(d.lastSeenAt)}`}
                    {d.platform ? ` · ${d.platform}` : ''}
                  </span>
                </div>
                {d.current ? <Tag tone="primary">This device</Tag> : d.status === 'active' ? <RemoveDeviceButton id={d.id} name={d.name} /> : null}
              </div>
            </Card>
          ))}
          {data?.nextRemovalAt && <p className={h.note}>You can remove another device from {weekdayDate(dayKey(new Date(data.nextRemovalAt)))}.</p>}
        </>
      )}
    </div>
  );
}
