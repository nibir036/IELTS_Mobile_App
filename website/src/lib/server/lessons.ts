// Courses: module → stages → lessons → steps (content packs course.<module>),
// plus lesson progress and XP in the kv state `lessons.done` - the same
// record the app keeps (lib/app/data/lessons.dart), so progress is shared.

import { COURSE_MODULES } from '../content/lang';
import { attempts, stateValue } from './attempts';
import { getPack } from './packs';

type Raw = Record<string, unknown>;

export const DONE_KEY = 'lessons.done';

export interface DoneEntry {
  module: string;
  stage: string;
  xp: number;
  minutes: number;
  at: string;
}
export type DoneMap = Record<string, DoneEntry>;

export interface LessonRef {
  module: string;
  stage: Raw;
  lesson: Raw;
  stageIndex: number;
  lessonIndex: number;
  stageLessons: number;
  id: string;
}

const list = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);

export function stages(course: Raw): Raw[] {
  return list(course.stages);
}

export function lessonsOf(stage: Raw): Raw[] {
  return list(stage.lessons);
}

export function allLessons(course: Raw): Raw[] {
  return stages(course).flatMap(lessonsOf);
}

export function findIn(module: string, course: Raw, id: string): LessonRef | null {
  const st = stages(course);
  for (let si = 0; si < st.length; si++) {
    const ls = lessonsOf(st[si]);
    for (let li = 0; li < ls.length; li++) {
      if (String(ls[li].id) === id) {
        return { module, stage: st[si], lesson: ls[li], stageIndex: si, lessonIndex: li, stageLessons: ls.length, id };
      }
    }
  }
  return null;
}

export function nextIn(module: string, course: Raw, id: string): LessonRef | null {
  const ls = allLessons(course);
  const i = ls.findIndex((l) => String(l.id) === id);
  if (i < 0 || i + 1 >= ls.length) return null;
  return findIn(module, course, String(ls[i + 1].id));
}

export function resumeIn(module: string, course: Raw, done: DoneMap): LessonRef | null {
  const l = allLessons(course).find((x) => !done[String(x.id)]);
  return l ? findIn(module, course, String(l.id)) : null;
}

export function doneIn(stage: Raw, done: DoneMap): number {
  return lessonsOf(stage).filter((l) => done[String(l.id)]).length;
}

export function xpOf(done: DoneMap): number {
  return Object.values(done).reduce((a, v) => a + (typeof v?.xp === 'number' ? v.xp : 0), 0);
}

export function course(module: string): Promise<Raw> {
  return getPack<Raw>(`course.${module}`).catch(() => ({}) as Raw);
}

/** Which module a lesson id belongs to (ids start with the module's letter, but search to be sure). */
export async function findLesson(id: string): Promise<{ ref: LessonRef; course: Raw } | null> {
  for (const m of COURSE_MODULES) {
    const c = await course(m);
    const ref = findIn(m, c, id);
    if (ref) return { ref, course: c };
  }
  return null;
}

export async function lessonsDone(): Promise<DoneMap> {
  const v = await stateValue<DoneMap>(DONE_KEY);
  return v && typeof v === 'object' && !Array.isArray(v) ? v : {};
}

const dayKey = (d: Date) => d.toLocaleDateString('en-CA', { timeZone: 'Asia/Dhaka' });

/** Days in a row (ending today or yesterday) with an attempt or a finished lesson (Store.streakDays). */
export async function streakDays(done?: DoneMap): Promise<number> {
  const [mine, d] = await Promise.all([attempts({ limit: 400 }).catch(() => []), done ? Promise.resolve(done) : lessonsDone()]);
  const days = new Set<string>(mine.map((a) => dayKey(new Date(a.createdAt))));
  for (const v of Object.values(d)) if (v?.at) days.add(dayKey(new Date(v.at)));
  if (!days.size) return 0;
  const day = new Date();
  if (!days.has(dayKey(day))) day.setDate(day.getDate() - 1);
  let n = 0;
  while (days.has(dayKey(day))) {
    n++;
    day.setDate(day.getDate() - 1);
  }
  return n;
}
