// Lesson course order, unlocking and status, ported from ReadingLessons
// (lib/features/reading/lessons.dart) and ListeningLessons
// (lib/features/listening/lesson_menu.dart). Pure: used on the server to
// build the lesson list and the lesson menu.

import { str, type Raw } from '../practice/marking';

/** One row of the lesson menu (LessonMenuEntry). */
export interface MenuEntry {
  id: string;
  number: number;
  title: string;
  subtitle: string;
  done: boolean;
  current: boolean;
  locked: boolean;
}

/** The newest lesson attempt per lesson id (attempts arrive newest first). */
export interface LessonDone {
  score: number;
  total: number;
  createdAt: string;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "14 Nov" (Store.shortDate). */
export function shortDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const parts = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'numeric', timeZone: 'Asia/Dhaka' }).formatToParts(d);
  const day = parts.find((p) => p.type === 'day')?.value ?? String(d.getDate());
  const month = Number(parts.find((p) => p.type === 'month')?.value ?? d.getMonth() + 1);
  return `${Number(day)} ${MONTHS[(month - 1 + 12) % 12]}`;
}

/** Latest lesson attempt per refId from a newest-first attempt list. */
export function latestByLesson(list: Array<{ refId: string; score: number | null; total: number | null; createdAt: string }>): Map<string, LessonDone> {
  const out = new Map<string, LessonDone>();
  for (const a of list) {
    if (!a.refId || out.has(a.refId)) continue;
    out.set(a.refId, { score: a.score ?? 0, total: a.total ?? 0, createdAt: a.createdAt });
  }
  return out;
}

/** Lesson to open without one picked: one in progress, else the first not done. */
export function defaultLessonId(lessons: Raw[], done: Map<string, LessonDone>, started: Set<string>): string {
  if (!lessons.length) return '';
  for (const l of lessons) if (!done.has(str(l.id)) && started.has(str(l.id))) return str(l.id);
  for (const l of lessons) if (!done.has(str(l.id))) return str(l.id);
  return str(lessons[0].id);
}

/**
 * Menu rows: a lesson is open when it is the first, already done or
 * started, or the lesson before it is done.
 */
export function lessonMenu(lessons: Raw[], done: Map<string, LessonDone>, started: Set<string>, currentId: string): MenuEntry[] {
  return lessons.map((l, i) => {
    const id = str(l.id);
    const isDone = done.has(id);
    const isStarted = started.has(id);
    const open = i === 0 || isDone || isStarted || id === currentId || done.has(str(lessons[i - 1].id));
    const last = done.get(id);
    let subtitle: string;
    if (last) subtitle = `Done · ${last.score}/${last.total} · ${shortDate(last.createdAt)}`;
    else if (id === currentId || isStarted) subtitle = 'In progress';
    else if (open) subtitle = 'Up next';
    else subtitle = 'Locked';
    return { id, number: i + 1, title: str(l.title), subtitle, done: isDone, current: id === currentId, locked: !open };
  });
}

/** Attempt id in the app's style (Store.newId('att')). */
export const newAttemptId = () => `att_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

/** Saves one kv value through the same-origin API proxy (null clears it). */
export async function putState(key: string, value: unknown): Promise<boolean> {
  const res = await fetch(`/api/v1/state/${encodeURIComponent(key)}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ value }),
    keepalive: true,
  }).catch(() => null);
  return Boolean(res?.ok);
}

/** Reads one kv value through the API proxy (null when unset / offline). */
export async function getState<T = unknown>(key: string): Promise<T | null> {
  const res = await fetch(`/api/v1/state?prefix=${encodeURIComponent(key)}`).catch(() => null);
  if (!res || !res.ok) return null;
  try {
    const body = (await res.json()) as { state?: Record<string, unknown> };
    return (body.state?.[key] as T | undefined) ?? null;
  } catch {
    return null;
  }
}

/** Saves a finished attempt (app-shaped). */
export async function postAttempt(a: {
  id: string;
  skill: 'reading' | 'listening';
  kind: string;
  title: string;
  refId: string;
  band: number | null;
  score: number;
  total: number;
  durationSec: number;
  createdAt: string;
  data: Record<string, unknown>;
}): Promise<boolean> {
  const res = await fetch('/api/v1/attempts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(a),
  }).catch(() => null);
  return Boolean(res?.ok);
}
