'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { Icon } from '@/components/ui';
import d from '@/components/dialog.module.css';
import type { MenuEntry } from './menu';
import s from './lessons.module.css';

/**
 * The lesson menu (lesson_menu.dart → showLessonMenu): every lesson with its
 * status (done / current / up next / locked), "Restart lesson" and
 * "Mark as done". [base] is the lesson route, e.g. '/app/reading/lessons'.
 */
export function LessonMenu({
  entries,
  base,
  currentDone,
  onRestart,
  onMarkDone,
  onLocked,
}: {
  entries: MenuEntry[];
  base: string;
  currentDone: boolean;
  onRestart: () => void;
  onMarkDone: () => void;
  onLocked: (msg: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const closeRef = useRef<HTMLButtonElement>(null);
  const doneCount = entries.filter((e) => e.done).length;

  useEffect(() => {
    if (!open) return;
    closeRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open]);

  return (
    <>
      <button type="button" className={s.iconBtn} aria-label="Lesson menu" aria-haspopup="dialog" onClick={() => setOpen(true)}>
        <Icon name="more_horiz" size={22} />
      </button>
      {open && (
        <div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby="lesson-menu-title" onClick={() => setOpen(false)}>
          <div className={`${d.sheet} ${s.menuSheet}`} onClick={(e) => e.stopPropagation()}>
            <div className={s.menuHead}>
              <h2 id="lesson-menu-title" className={s.menuTitle}>
                Lessons
              </h2>
              <span className={s.muted}>
                {doneCount} of {entries.length} done
              </span>
              <button ref={closeRef} type="button" className={s.iconBtnSmall} aria-label="Close" onClick={() => setOpen(false)}>
                <Icon name="close" size={18} />
              </button>
            </div>
            <div className={s.menuList}>
              {entries.map((e) => (
                <MenuRow
                  key={e.id}
                  entry={e}
                  href={`${base}/${e.id}`}
                  onPick={() => {
                    if (e.locked) {
                      onLocked(`Finish Lesson ${e.number - 1} to unlock this one`);
                      return false;
                    }
                    setOpen(false);
                    return true;
                  }}
                />
              ))}
            </div>
            <div className={s.menuActions}>
              <button
                type="button"
                className={s.softBtn}
                onClick={() => {
                  setOpen(false);
                  onRestart();
                }}
              >
                <Icon name="refresh" size={18} /> Restart lesson
              </button>
              <button
                type="button"
                className={s.primaryBtn}
                disabled={currentDone}
                onClick={() => {
                  setOpen(false);
                  onMarkDone();
                }}
              >
                <Icon name="check" size={18} /> {currentDone ? 'Done' : 'Mark as done'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}

function Badge({ e }: { e: MenuEntry }) {
  const cls = e.done ? s.badgeDone : e.current ? s.badgeCurrent : s.badgeIdle;
  return (
    <span className={`${s.badge} ${cls}`}>
      {e.done ? <Icon name="check" size={16} /> : e.locked ? <Icon name="lock" size={15} /> : e.number}
    </span>
  );
}

/** One lesson row; also used by the lesson lists. */
export function MenuRow({ entry: e, href, onPick }: { entry: MenuEntry; href: string; onPick?: () => boolean }) {
  const inner = (
    <>
      <Badge e={e} />
      <span className={s.rowText}>
        <b>
          Lesson {e.number} · {e.title}
        </b>
        <span>{e.subtitle}</span>
      </span>
      {e.current ? <span className={s.currentTag}>Current</span> : <Icon name={e.locked ? 'lock' : 'chevron_right'} size={18} color="var(--text-muted)" />}
    </>
  );
  if (e.locked) {
    return (
      <button type="button" className={`${s.row} ${s.rowLocked}`} aria-disabled="true" onClick={() => onPick?.()}>
        {inner}
      </button>
    );
  }
  return (
    <Link
      href={href}
      className={s.row}
      aria-current={e.current ? 'page' : undefined}
      onClick={(ev) => {
        if (onPick && !onPick()) ev.preventDefault();
      }}
    >
      {inner}
    </Link>
  );
}

/** Small status toast (the app's SnackBar). */
export function useToast(): [string, (msg: string) => void] {
  const [msg, setMsg] = useState('');
  useEffect(() => {
    if (!msg) return;
    const t = setTimeout(() => setMsg(''), 3200);
    return () => clearTimeout(t);
  }, [msg]);
  return [msg, setMsg];
}

export function Toast({ msg }: { msg: string }) {
  return msg ? (
    <div className={s.toast} role="status" aria-live="polite">
      {msg}
    </div>
  ) : null;
}
