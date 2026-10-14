// Server-side data for the Reading / Listening strategy lessons: content from
// the 'ui' pack (demo_data.json → reading.lessons / listening.lessons) and the
// reading bank ('bank.reading' → lessons), progress from the API (attempts
// kind 'lesson' + the app's kv keys).

import { rows, str, type Raw } from '../practice/marking';
import { api } from '../server/api';
import { attempts, stateValue } from '../server/attempts';
import { getPack, uiPack } from '../server/packs';
import { latestByLesson, type LessonDone } from './menu';

/** kv key of the one reading lesson in progress ({lessonId, index, correct, elapsedSec}). */
export const READING_PROGRESS_KEY = 'reading.lessonProgress';
/** kv key of a listening lesson's unfinished answers ({answers, current}). */
export const listeningSavedKey = (id: string) => `listening.lesson.${id}`;
/** kv key of the "How to attempt …" lessons opened (list of question types). */
export const TYPE_LESSONS_READ_KEY = 'reading.typeLessonsRead';

export interface ReadingProgress {
  lessonId: string;
  index: number;
  correct: number;
  elapsedSec: number;
}

const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {});

export async function readingSkillLessons(): Promise<Raw[]> {
  return rows(obj((await uiPack()).reading).lessons);
}

export async function listeningLessons(): Promise<Raw[]> {
  return rows(obj((await uiPack()).listening).lessons);
}

/** The 14 "How to attempt …" lessons, one per bank question type. */
export async function readingTypeLessons(): Promise<Raw[]> {
  return rows((await getPack<Raw>('bank.reading')).lessons);
}

/** Bank sets of one question type, set 01 → 20. */
export async function bankSetsOf(type: string): Promise<Raw[]> {
  const all = rows((await getPack<Raw>('bank.reading')).passages);
  return all.filter((p) => str(p.questionType) === type).sort((a, b) => Number(a.bankSet) - Number(b.bankSet));
}

export async function lessonsDone(skill: 'reading' | 'listening'): Promise<Map<string, LessonDone>> {
  return latestByLesson(await attempts({ skill, kind: 'lesson', limit: 500 }).catch(() => []));
}

export async function readingProgress(): Promise<ReadingProgress | null> {
  const v = obj(await stateValue(READING_PROGRESS_KEY));
  if (typeof v.lessonId !== 'string' || !v.lessonId) return null;
  return { lessonId: v.lessonId, index: Number(v.index) || 0, correct: Number(v.correct) || 0, elapsedSec: Number(v.elapsedSec) || 0 };
}

/** Saved unfinished listening lessons: id → {answers, current}. */
export async function listeningSaved(): Promise<Map<string, { answers: Record<string, string>; current: number }>> {
  const out = new Map<string, { answers: Record<string, string>; current: number }>();
  try {
    const prefix = 'listening.lesson.';
    const r = await api<{ state: Record<string, unknown> }>(`/v1/state?prefix=${encodeURIComponent(prefix)}`);
    for (const [k, v] of Object.entries(r.state ?? {})) {
      if (!k.startsWith(prefix) || !v || typeof v !== 'object') continue;
      const m = v as Raw;
      const answers: Record<string, string> = {};
      for (const [n, a] of Object.entries(obj(m.answers))) if (a != null) answers[n] = String(a);
      out.set(k.slice(prefix.length), { answers, current: Number(m.current) || 0 });
    }
  } catch {}
  return out;
}

export async function typeLessonsRead(): Promise<string[]> {
  const v = await stateValue<unknown>(TYPE_LESSONS_READ_KEY);
  return Array.isArray(v) ? v.map(String) : [];
}
