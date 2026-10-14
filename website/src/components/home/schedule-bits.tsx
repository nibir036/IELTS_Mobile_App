'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { ConfirmDialog } from '@/components/upgrade-dialog';
import { Icon, PrimaryButton } from '@/components/ui';
import d from '@/components/dialog.module.css';
import { skillLandingRoute } from '@/lib/home/routes';
import h from './home.module.css';
import { Portal } from '@/components/portal';

export interface TaskView {
  id: string;
  title: string;
  subtitle: string;
  done: boolean;
  deadline: boolean;
  icon: string;
  href: string;
}

/** One task of the day (_TaskRow): tick, open, delete. */
export function ScheduleTaskRow({ task }: { task: TaskView }) {
  const router = useRouter();
  const [done, setDone] = useState(task.done);
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);

  const toggle = async () => {
    if (busy) return;
    const next = !done;
    setDone(next);
    setBusy(true);
    const res = await fetch(`/api/v1/tasks/${encodeURIComponent(task.id)}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ done: next }),
    }).catch(() => null);
    setBusy(false);
    if (!res?.ok) setDone(!next);
    else router.refresh();
  };

  const remove = async () => {
    setConfirm(false);
    setBusy(true);
    await fetch(`/api/v1/tasks/${encodeURIComponent(task.id)}`, { method: 'DELETE' }).catch(() => null);
    setBusy(false);
    router.refresh();
  };

  return (
    <div className={h.taskRow}>
      <button
        type="button"
        className={`${h.taskTick} ${done ? h.taskTickDone : task.deadline ? h.taskTickDeadline : ''}`}
        onClick={toggle}
        disabled={busy}
        aria-pressed={done}
        aria-label={done ? `Mark “${task.title}” as not done` : `Mark “${task.title}” as done`}
        title={done ? 'Mark as not done' : 'Mark as done'}
      >
        <Icon name={done ? 'check' : task.deadline ? 'error' : task.icon} size={20} />
      </button>
      <Link href={task.href} className={h.taskMain}>
        <span className={`${h.taskTitle} ${done ? h.taskTitleDone : ''}`}>{task.title}</span>
        {task.subtitle && <span className={h.taskSub}>{task.subtitle}</span>}
      </Link>
      {!done && (
        <Link href={task.href} className={h.ghostBtn} aria-label={`Start “${task.title}”`} title="Start">
          <Icon name="play_arrow" size={22} />
        </Link>
      )}
      <button type="button" className={h.ghostBtn} onClick={() => setConfirm(true)} disabled={busy} aria-label={`Delete “${task.title}”`} title="Delete">
        <Icon name="delete" size={20} />
      </button>
      {confirm && <ConfirmDialog title="Delete task?" message={task.title} confirm="Delete" cancel="Cancel" onConfirm={remove} onCancel={() => setConfirm(false)} />}
    </div>
  );
}

const SKILLS: Array<[string, string]> = [
  ['listening', 'Listening'],
  ['reading', 'Reading'],
  ['writing', 'Writing'],
  ['speaking', 'Speaking'],
  ['mock', 'Mock'],
  ['vocab', 'Vocabulary'],
];
const DURATIONS = [15, 20, 30, 45, 60, 160];
const fmtDur = (m: number) => (m < 60 ? `${m} min` : m % 60 === 0 ? `${m / 60} h` : `${Math.floor(m / 60)} h ${m % 60} min`);

function newId(): string {
  return `tsk_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
}

/** "+" / "Add a task" (_AddTaskSheet): title, skill, time and duration. */
export function AddTaskButton({ day, dayLabel, variant }: { day: string; dayLabel: string; variant: 'icon' | 'soft' }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [skill, setSkill] = useState('writing');
  const [time, setTime] = useState('19:00');
  const [duration, setDuration] = useState(30);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const save = async () => {
    if (!title.trim() || busy) return;
    setBusy(true);
    setError('');
    const id = newId();
    const res = await fetch(`/api/v1/tasks/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, title: title.trim(), skill, date: day, time, durationMin: duration, done: false, target: skillLandingRoute(skill) }),
    }).catch(() => null);
    setBusy(false);
    if (!res?.ok) {
      const data = res ? ((await res.json().catch(() => ({}))) as { error?: string }) : {};
      setError(data.error ?? 'The task could not be added.');
      return;
    }
    setOpen(false);
    setTitle('');
    router.refresh();
  };

  return (
    <>
      {variant === 'icon' ? (
        <button type="button" className={h.iconBtn} onClick={() => setOpen(true)} aria-label="Add task" title="Add task">
          <Icon name="add" size={24} />
        </button>
      ) : (
        <button type="button" className={h.pill} style={{ border: 0, cursor: 'pointer', height: 44, fontSize: 14 }} onClick={() => setOpen(true)}>
          <Icon name="add" size={18} /> Add a task
        </button>
      )}
      {open && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby="add-task-title" onClick={() => setOpen(false)}>
          <form
            className={`${d.sheet} ${h.dialogScroll}`}
            onClick={(e) => e.stopPropagation()}
            onSubmit={(e) => {
              e.preventDefault();
              save();
            }}
          >
            <h2 id="add-task-title" className={d.title}>
              New task · {dayLabel}
            </h2>
            <div className={h.form}>
              <label className={h.form} style={{ gap: 6 }}>
                <span className={h.fieldLabel}>Title</span>
                <input className={h.input} value={title} maxLength={200} placeholder="e.g. Task 2 essay: technology" onChange={(e) => setTitle(e.target.value)} autoFocus />
              </label>
              <span className={h.fieldLabel} id="task-skill">
                Skill
              </span>
              <div className={h.pillChips} role="radiogroup" aria-labelledby="task-skill">
                {SKILLS.map(([id, label]) => (
                  <button key={id} type="button" role="radio" aria-checked={skill === id} className={`${h.pillChip} ${skill === id ? h.pillChipOn : ''}`} onClick={() => setSkill(id)}>
                    {label}
                  </button>
                ))}
              </div>
              <label className={h.form} style={{ gap: 6 }}>
                <span className={h.fieldLabel}>Time</span>
                <input className={h.input} type="time" value={time} onChange={(e) => e.target.value && setTime(e.target.value)} />
              </label>
              <span className={h.fieldLabel} id="task-dur">
                Duration
              </span>
              <div className={h.pillChips} role="radiogroup" aria-labelledby="task-dur">
                {DURATIONS.map((m) => (
                  <button key={m} type="button" role="radio" aria-checked={duration === m} className={`${h.pillChip} ${duration === m ? h.pillChipOn : ''}`} onClick={() => setDuration(m)}>
                    {fmtDur(m)}
                  </button>
                ))}
              </div>
              {error && <p className={h.error}>{error}</p>}
              <PrimaryButton type="submit" block disabled={!title.trim() || busy}>
                {busy ? 'Adding…' : 'Add task'}
              </PrimaryButton>
              <button type="button" className={h.outlineBtn} onClick={() => setOpen(false)}>
                Cancel
              </button>
            </div>
          </form>
        </div></Portal>
      )}
    </>
  );
}
