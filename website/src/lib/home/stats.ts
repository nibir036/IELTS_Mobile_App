// The app's derived stats (lib/app/data/store.dart › derived stats), worked
// out from the student's attempts on the server, so web and app agree.

import { addDaysKey, dayKey, todayKey, weekdayIndex } from './time';

export interface AttemptLike {
  id: string;
  skill: string;
  kind: string;
  title: string;
  refId: string;
  band: number | null;
  durationSec: number;
  createdAt: string;
  data: Record<string, unknown>;
}

export const CORE_SKILLS = ['listening', 'reading', 'writing', 'speaking'] as const;

export function skillLabel(skill: string): string {
  return (
    { listening: 'Listening', reading: 'Reading', writing: 'Writing', speaking: 'Speaking', mock: 'Mock', vocab: 'Vocabulary' }[skill] ?? skill
  );
}

export function skillLetter(skill: string): string {
  return { listening: 'L', reading: 'R', writing: 'W', speaking: 'S', mock: 'M', vocab: 'V' }[skill] ?? '•';
}

/** Material Symbols name for a home.json icon key (homeIconFor). */
export function homeIcon(key: string): string {
  const m: Record<string, string> = {
    listening: 'headphones',
    reading: 'menu_book',
    writing: 'edit_note',
    speaking: 'mic',
    mic: 'mic',
    check: 'check',
    chart: 'bar_chart',
    doc: 'description',
    pen: 'edit',
    article: 'article',
    sparkle: 'auto_awesome',
    clock: 'schedule',
    chat: 'chat_bubble',
    bookmark: 'bookmark',
    calendar: 'calendar_month',
    medal: 'workspace_premium',
    school: 'school',
    mock: 'fact_check',
    vocab: 'translate',
    bell: 'notifications',
  };
  return m[key] ?? 'info';
}

export const roundBand = (v: number) => Math.min(9, Math.max(0, Math.round(v * 2) / 2));

/** 6.5 → "6.5", 7 → "7.0", null → "–". */
export const formatBand = (b: number | null | undefined) => (b == null || !Number.isFinite(b) ? '–' : b.toFixed(1));

/** "+0.5", "0.0", "-0.5". */
export function signedBand(v: number): string {
  if (v > 0) return `+${v.toFixed(1)}`;
  if (v < 0) return v.toFixed(1);
  return '0.0';
}

const minutes = (a: AttemptLike) => Math.round((a.durationSec || 0) / 60);

/** Mean of the last 3 band-scored attempts of [skill] (mock sections count), to .5. */
export function skillBand(attempts: AttemptLike[], skill: string): number | null {
  const bands: number[] = [];
  for (const a of attempts) {
    if (bands.length >= 3) break;
    if (a.skill === skill && a.band != null) bands.push(a.band);
    else if (a.skill === 'mock') {
      const s = a.data?.sections as Record<string, unknown> | undefined;
      if (s && typeof s[skill] === 'number') bands.push(s[skill] as number);
    }
  }
  if (!bands.length) return null;
  return roundBand(bands.reduce((x, y) => x + y, 0) / bands.length);
}

export function estimatedBand(attempts: AttemptLike[]): number | null {
  const b = CORE_SKILLS.map((k) => skillBand(attempts, k)).filter((x): x is number => x != null);
  if (!b.length) return null;
  return roundBand(b.reduce((x, y) => x + y, 0) / b.length);
}

/** 0..1 of a skill band toward the target (7.0 when unset). */
export function skillProgress(attempts: AttemptLike[], skill: string, target: number | null): number {
  const b = skillBand(attempts, skill);
  if (b == null) return 0;
  return Math.min(1, Math.max(0, b / (target ?? 7)));
}

/** Study minutes for Mon..Sun of this week. */
export function weekMinutes(attempts: AttemptLike[]): number[] {
  const today = todayKey();
  const monday = addDaysKey(today, -weekdayIndex(today));
  const out = [0, 0, 0, 0, 0, 0, 0];
  for (const a of attempts) {
    const k = dayKey(new Date(a.createdAt));
    for (let i = 0; i < 7; i++) {
      if (addDaysKey(monday, i) === k) {
        out[i] += minutes(a);
        break;
      }
    }
  }
  return out;
}

export function minutesOn(attempts: AttemptLike[], key: string): number {
  return attempts.filter((a) => dayKey(new Date(a.createdAt)) === key).reduce((s, a) => s + minutes(a), 0);
}

export function totalMinutes(attempts: AttemptLike[]): number {
  return attempts.reduce((s, a) => s + minutes(a), 0);
}

type Done = Record<string, { at?: string; xp?: number; module?: string } | null | undefined>;

/** Days with an attempt or a finished lesson. */
export function activeDays(attempts: AttemptLike[], done: Done = {}): Set<string> {
  const days = new Set(attempts.map((a) => dayKey(new Date(a.createdAt))));
  for (const v of Object.values(done)) if (v?.at) days.add(dayKey(new Date(v.at)));
  return days;
}

/** Days in a row, ending today or yesterday (Store.streakDays). */
export function streakDays(attempts: AttemptLike[], done: Done = {}): number {
  const days = activeDays(attempts, done);
  if (!days.size) return 0;
  let k = todayKey();
  if (!days.has(k)) k = addDaysKey(k, -1);
  let n = 0;
  while (days.has(k)) {
    n++;
    k = addDaysKey(k, -1);
  }
  return n;
}

/** The web page with an attempt's result (resultRouteFor). */
export function resultHref(a: Pick<AttemptLike, 'id' | 'skill' | 'kind'>): string {
  const id = encodeURIComponent(a.id);
  switch (a.skill) {
    case 'listening':
      return `/app/listening/result/${id}`;
    case 'reading':
      return a.kind === 'lesson' ? '/app/reading' : `/app/reading/result/${id}`;
    case 'writing':
      return a.kind === 'drill' ? '/app/writing/sentence-builder' : `/app/writing/result/${id}`;
    case 'speaking':
      return a.kind === 'pronunciation' ? '/app/speaking/pronunciation' : `/app/speaking/result/${id}`;
    case 'mock':
      return `/app/mocks/result/${id}`;
    case 'vocab':
      return '/app/resources/vocab-quiz';
    default:
      return '/app';
  }
}

/** Profile fields the app keeps (Account.targetBand / examDate / plan). */
export function profileOf(profile: Record<string, unknown>) {
  const tb = profile.targetBand;
  const targetBand = typeof tb === 'number' ? tb : typeof tb === 'string' && tb && Number.isFinite(Number(tb)) ? Number(tb) : null;
  const ed = typeof profile.examDate === 'string' && /^\d{4}-\d{2}-\d{2}/.test(profile.examDate) ? profile.examDate.slice(0, 10) : null;
  const photo = typeof profile.photo === 'string' && profile.photo ? profile.photo : null;
  return { targetBand, examDate: ed, photo, micAllowed: profile.micAllowed === true };
}

export function initials(name: string): string {
  const p = name.trim().split(/\s+/).filter(Boolean);
  if (!p.length) return '?';
  if (p.length === 1) return p[0].slice(0, 1).toUpperCase();
  return (p[0].slice(0, 1) + p[p.length - 1].slice(0, 1)).toUpperCase();
}

/** "+880 1734 ••• 208" from the stored phone (any +880 / 0 prefix). */
export function phoneMasked(phone: string): string {
  const demo = /^demo(\d)$/.exec(phone);
  if (demo) return `Demo ${demo[1]}`;
  const n = phone.replace(/\D/g, '').replace(/^880/, '').replace(/^0/, '');
  if (n.length < 7) return `+880 ${n}`;
  return `+880 ${n.slice(0, 4)} ••• ${n.slice(-3)}`;
}
