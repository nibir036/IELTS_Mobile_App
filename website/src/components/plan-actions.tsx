'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { ConfirmDialog } from './upgrade-dialog';
import { Icon } from './ui';
import d from './dialog.module.css';
import p from './plan.module.css';
import { Portal } from '@/components/portal';

type Sheet = null | 'menu' | 'pause' | 'end';

/** The plan's "…" menu: pause / resume, re-plan, change, end (study_plan_screen.dart). */
export function PlanActions({ paused }: { paused: boolean }) {
  const router = useRouter();
  const [sheet, setSheet] = useState<Sheet>(null);
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState('');
  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(''), 4000);
    return () => clearTimeout(id);
  }, [toast]);

  const run = async (init: RequestInit, done: string) => {
    setSheet(null);
    setBusy(true);
    setToast('');
    const res = await fetch('/api/v1/plan', { headers: { 'Content-Type': 'application/json' }, ...init }).catch(() => null);
    setBusy(false);
    if (!res) return setToast('Can’t reach the server. Check your connection.');
    const body = (await res.json().catch(() => ({}))) as { error?: string };
    if (!res.ok) return setToast(body.error ?? 'That didn’t work. Please try again.');
    setToast(done);
    router.refresh();
  };
  const change = (body: Record<string, unknown>, done: string) => run({ method: 'PATCH', body: JSON.stringify(body) }, done);

  const item = (icon: string, title: string, sub: string, onClick: () => void) => (
    <button type="button" className={p.menuItem} onClick={onClick}>
      <Icon name={icon} size={22} color="var(--text-muted)" />
      <span>
        <b>{title}</b>
        <span>{sub}</span>
      </span>
    </button>
  );

  return (
    <>
      <button type="button" className={p.back} onClick={() => setSheet('menu')} disabled={busy} aria-label="Plan options" title="Plan options">
        <Icon name={busy ? 'progress_activity' : 'more_horiz'} size={20} />
      </button>
      {toast && (
        <div role="status" style={{ position: 'fixed', left: '50%', bottom: 90, transform: 'translateX(-50%)', zIndex: 60 }}>
          <div
            style={{ background: 'var(--primary)', color: 'var(--on-primary)', padding: '10px 16px', borderRadius: 14, fontSize: 14, boxShadow: '0 8px 24px rgba(0,0,0,.2)' }}
          >
            {toast}{' '}
            <button type="button" onClick={() => setToast('')} style={{ marginInlineStart: 8, border: 0, background: 'none', color: 'inherit', cursor: 'pointer' }} aria-label="Dismiss">
              ✕
            </button>
          </div>
        </div>
      )}
      {sheet === 'menu' && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label="Plan options" onClick={() => setSheet(null)}>
          <div className={d.sheet} onClick={(e) => e.stopPropagation()}>
            <h2 className={d.title}>Plan options</h2>
            <div className={p.menu}>
              {paused
                ? item('play_arrow', 'Resume now', 'Pick up where you stopped', () => change({ action: 'resume' }, 'Welcome back. Your plan is on again.'))
                : item('pause', 'Take a break', 'Pause for a few days; the plan moves later', () => setSheet('pause'))}
              {item('refresh', 'Re-plan from my results', 'Rebuild the coming days from your latest scores', () =>
                change({ action: 'rebalance' }, 'Plan rebuilt from your latest results.'),
              )}
              {item('calendar_month', 'Change target or schedule', 'Band, exam date, days, minutes, time', () => router.push('/app/plan/setup?edit=1'))}
              {item('delete', 'End this plan', 'Finished tasks stay in your history', () => setSheet('end'))}
            </div>
          </div>
        </div></Portal>
      )}
      {sheet === 'pause' && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label="Pause" onClick={() => setSheet(null)}>
          <div className={d.sheet} onClick={(e) => e.stopPropagation()}>
            <h2 className={d.title}>Pause for how long?</h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[3, 7, 14].map((n) => (
                <button key={n} type="button" className={p.option} onClick={() => change({ action: 'pause', days: n }, `Paused for ${n} days. Your plan moves ${n} days later.`)}>
                  {n} days
                </button>
              ))}
            </div>
          </div>
        </div></Portal>
      )}
      {sheet === 'end' && (
        <ConfirmDialog
          title="End your study plan?"
          message="Open tasks are removed from your schedule. You can make a new plan any time."
          confirm="End plan"
          cancel="Keep it"
          onConfirm={() => run({ method: 'DELETE' }, 'Plan ended')}
          onCancel={() => setSheet(null)}
        />
      )}
    </>
  );
}
