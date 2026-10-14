'use client';

import { useEffect, useRef, useState } from 'react';
import { kvSetRead, kvSetToggle } from '@/lib/extras/kv-client';
import type { PlanWeek } from '@/lib/extras/mock-plan';
import { Card, HeroCard, Icon, PrimaryButton, SoftButton } from '../ui';
import x from './extras.module.css';

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');

let seq = 0;
const taskId = () => `tsk_${(Date.now() * 1000).toString(36)}${++seq}`;

function useToast(): [string, (m: string) => void] {
  const [msg, setMsg] = useState('');
  const t = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => {
    if (t.current) clearTimeout(t.current);
  }, []);
  return [
    msg,
    (m: string) => {
      setMsg(m);
      if (t.current) clearTimeout(t.current);
      t.current = setTimeout(() => setMsg(''), 2600);
    },
  ];
}

/**
 * Week cards with tickable items (kv `mock.plan.<attemptId>`) and "Add plan
 * to schedule" (study tasks + kv `mock.planScheduled`), as in the app.
 */
export function PlanBoard({ attemptId, weeks, initialDone, initialScheduled }: { attemptId: string; weeks: PlanWeek[]; initialDone: string[]; initialScheduled: boolean }) {
  const key = `mock.plan.${attemptId}`;
  const [done, setDone] = useState(() => new Set(initialDone));
  const [scheduled, setScheduled] = useState(initialScheduled);
  const [busy, setBusy] = useState(false);
  const [toast, show] = useToast();

  async function toggle(id: string) {
    const on = !done.has(id);
    setDone((s) => {
      const n = new Set(s);
      if (on) n.add(id);
      else n.delete(id);
      return n;
    });
    const saved = await kvSetToggle(key, id, on);
    if (saved) setDone(saved);
    else show('Couldn’t save that. Check your connection.');
  }

  async function schedule() {
    if (busy) return;
    setBusy(true);
    try {
      if (scheduled || (await kvSetRead('mock.planScheduled')).has(attemptId)) {
        setScheduled(true);
        show('This plan is already in your schedule');
        return;
      }
      for (const w of weeks) {
        for (const it of w.items) {
          const id = taskId();
          const res = await fetch(`/api/v1/tasks/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id, title: it.title, skill: it.skill, date: it.date, time: it.time, durationMin: it.durationMin, target: it.target, done: false }),
          }).catch(() => null);
          if (!res?.ok) {
            show('Couldn’t add the plan right now. Please try again.');
            return;
          }
        }
      }
      await kvSetToggle('mock.planScheduled', attemptId, true);
      setScheduled(true);
      show('Plan added to your schedule');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className={x.weeks}>
        {weeks.map((w) => {
          const onHero = w.tint === 'lavender' || w.tint === 'pink';
          const body = (
            <div className={cx(onHero && x.onHero)}>
              <div className={x.weekHead}>
                <span className={x.weekLabel}>{w.label}</span>
                <span className={x.weekDates}>{w.dates}</span>
              </div>
              {w.items.map((it) => {
                const on = done.has(it.id);
                return (
                  <button key={it.id} type="button" className={x.item} role="checkbox" aria-checked={on} onClick={() => toggle(it.id)}>
                    <span className={cx(x.check, on && x.checkOn)}>{on && <Icon name="check" size={15} />}</span>
                    <span className={x.itemText}>
                      <span className={cx(x.itemTitle, on && x.itemDone)}>{it.title}</span>
                      <span className={x.itemDetail}>{it.detail}</span>
                    </span>
                  </button>
                );
              })}
            </div>
          );
          return onHero ? (
            <HeroCard key={w.label} padding={16} radius={24}>
              {body}
            </HeroCard>
          ) : (
            <Card key={w.label} padding="12px 16px" radius={24}>
              {body}
            </Card>
          );
        })}
      </div>
      <div className={x.footer}>
        <PrimaryButton leading="calendar_month" onClick={schedule} disabled={busy}>
          {scheduled ? 'In your schedule' : busy ? 'Adding…' : 'Add plan to schedule'}
        </PrimaryButton>
        <SoftButton href="/app/plan" leading="event">
          Open my schedule
        </SoftButton>
      </div>
      {toast && (
        <div className={x.toast} role="status" aria-live="polite">
          {toast}
        </div>
      )}
    </>
  );
}
