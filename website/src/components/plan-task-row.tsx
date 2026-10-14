'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { skillIcon, taskHref, type PlanTask } from '@/lib/plan/plan';
import { Icon } from './ui';
import p from './plan.module.css';

/**
 * One plan task (PlanTaskRow): tick circle, title, minutes and why; the row
 * opens the exact lesson / set / test. [preview] rows can't be opened or ticked.
 */
export function PlanTaskRow({ task, showReason = true, preview = false }: { task: PlanTask; showReason?: boolean; preview?: boolean }) {
  const router = useRouter();
  const [done, setDone] = useState(Boolean(task.done));
  const [busy, setBusy] = useState(false);
  const checkpoint = task.kind === 'checkpoint' || Boolean(task.checkpoint);
  const meta = [checkpoint ? 'Checkpoint' : '', task.durationMin > 0 ? `${task.durationMin} min` : ''].filter(Boolean).join(' · ');

  const toggle = async () => {
    if (preview || busy) return;
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

  const body = (
    <>
      <span className={p.taskText}>
        <span className={`${p.taskTitle} ${done ? p.taskTitleDone : ''}`}>{task.title}</span>
        {meta && <span className={`${p.taskMeta} ${checkpoint ? p.taskMetaCheckpoint : ''}`}>{meta}</span>}
        {showReason && task.reason && <span className={p.taskMeta}>{task.reason}</span>}
      </span>
      {!preview && !done && <Icon name="arrow_forward" size={18} className={p.arrow} />}
    </>
  );

  return (
    <div className={p.task}>
      <button
        type="button"
        className={`${p.tick} ${done ? p.tickDone : checkpoint ? p.tickCheckpoint : ''}`}
        onClick={toggle}
        disabled={preview}
        title={preview ? undefined : done ? 'Mark as not done' : 'Mark as done'}
        aria-label={preview ? task.title : done ? 'Mark as not done' : 'Mark as done'}
        aria-pressed={preview ? undefined : done}
      >
        <Icon name={done ? 'check' : checkpoint ? 'flag' : skillIcon(task.skill)} size={19} />
      </button>
      {preview ? (
        <span className={p.taskLink}>{body}</span>
      ) : (
        <Link href={taskHref(task)} className={p.taskLink}>
          {body}
        </Link>
      )}
    </div>
  );
}
