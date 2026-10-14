// Server-side loaders shared by the Home-area pages.

import { api } from '../server/api';
import { attempts, stateValue, type Attempt } from '../server/attempts';
import { lessonsDone, type DoneMap } from '../server/lessons';
import { getPack, uiPack } from '../server/packs';
import { listeningBankSets, listeningTests } from '../server/practice';
import { evaluateCertificates, type CertStatus } from './certificates';

type Raw = Record<string, unknown>;

/** The student's attempts, newest first (the API's maximum page). */
export function myAttempts(): Promise<Attempt[]> {
  return attempts({ limit: 500 }).catch(() => []);
}

/** Unread notifications (the bell's dot). */
export async function unreadCount(): Promise<number> {
  try {
    return (await api<{ unread: number }>('/v1/notifications?limit=1')).unread ?? 0;
  } catch {
    return 0;
  }
}

export interface Notification {
  id: string;
  type: string;
  skill: string;
  title: string;
  body: string;
  read: boolean;
  target: string;
  args?: Raw;
  createdAt: string;
}

export async function notifications(limit = 200): Promise<{ items: Notification[]; unread: number } | null> {
  try {
    return await api<{ items: Notification[]; unread: number }>(`/v1/notifications?limit=${limit}`);
  } catch {
    return null;
  }
}

export interface Task {
  id: string;
  title: string;
  skill: string;
  kind: string;
  date: string;
  time: string;
  durationMin: number;
  done: boolean;
  target: string;
  args?: Raw;
  planId?: string;
  itemId?: string;
  ref?: string;
  reason?: string;
}

export async function tasks(range?: { from?: string; to?: string }): Promise<Task[] | null> {
  const p = new URLSearchParams();
  if (range?.from) p.set('from', range.from);
  if (range?.to) p.set('to', range.to);
  try {
    return (await api<{ items: Task[] }>(`/v1/tasks${p.size ? `?${p}` : ''}`)).items;
  } catch {
    return null;
  }
}

export async function homeSection(): Promise<Raw> {
  const ui = await uiPack().catch(() => ({}) as Raw);
  return (ui.home ?? {}) as Raw;
}

/** Every milestone, worked out for the signed-in student. */
export async function certificates(opts: { attempts?: Attempt[]; done?: DoneMap; target: number | null }): Promise<{ items: CertStatus[]; intro: string }> {
  const [home, all, done] = await Promise.all([homeSection(), opts.attempts ? Promise.resolve(opts.attempts) : myAttempts(), opts.done ? Promise.resolve(opts.done) : lessonsDone()]);
  const cert = (home.certificates ?? {}) as Raw;
  const defs = Array.isArray(cert.items) ? (cert.items as Raw[]) : [];
  const modules = new Set<string>();
  let needsListening = false;
  for (const d of defs) {
    const r = (d.rule ?? {}) as Raw;
    if (r.type === 'stage' || r.type === 'course') modules.add(String(r.module || 'writing'));
    if (r.type === 'listeningParts') needsListening = true;
  }
  const courses: Record<string, Raw> = {};
  await Promise.all(
    [...modules].map(async (m) => {
      courses[m] = await getPack<Raw>(`course.${m}`).catch(() => ({}) as Raw);
    }),
  );
  const parts = new Map<string, number>();
  if (needsListening) {
    const [bank, tests] = await Promise.all([listeningBankSets().catch(() => [] as Raw[]), listeningTests().catch(() => ({ sets: [] as Raw[] }))]);
    for (const st of [...bank, ...tests.sets]) parts.set(String(st.id), Number(st.part) || 0);
  }
  return {
    intro: String(cert.intro ?? ''),
    items: evaluateCertificates({ defs, attempts: all, target: opts.target ?? 7, done, courses, listeningPart: (id) => parts.get(id) ?? 0 }),
  };
}

export { stateValue };
