// Dates the way the app shows them (Store.relativeDay, weekdayDate, timeAgo …).
// Server pages use the students' zone (Asia/Dhaka), like the rest of the site.

export const TZ = 'Asia/Dhaka';
export const WD = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
export const WD_LONG = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
export const MO = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export const MO_LONG = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/** 'YYYY-MM-DD' of [d] in [tz] (the browser's own zone when tz is null). */
export function dayKey(d: Date, tz: string | null = TZ): string {
  if (tz === null) return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return d.toLocaleDateString('en-CA', { timeZone: tz });
}

export const todayKey = (tz: string | null = TZ) => dayKey(new Date(), tz);

/** A day key as a Date at noon UTC (safe for day maths). */
export function keyDate(k: string): Date {
  return new Date(`${k.slice(0, 10)}T12:00:00Z`);
}

export function addDaysKey(k: string, n: number): string {
  const d = keyDate(k);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** Whole days from [a] to [b] (keys). */
export function daysBetween(a: string, b: string): number {
  return Math.round((keyDate(b).getTime() - keyDate(a).getTime()) / 86_400_000);
}

/** 0 = Monday … 6 = Sunday. */
export function weekdayIndex(k: string): number {
  return (keyDate(k).getUTCDay() + 6) % 7;
}

/** "Sat 14 Nov". */
export function weekdayDate(k: string): string {
  const d = keyDate(k);
  return `${WD[weekdayIndex(k)]} ${d.getUTCDate()} ${MO[d.getUTCMonth()]}`;
}

/** "21 Sep". */
export function shortDate(k: string): string {
  const d = keyDate(k);
  return `${d.getUTCDate()} ${MO[d.getUTCMonth()]}`;
}

/** "21 Sep 2026". */
export function longDate(k: string): string {
  const d = keyDate(k);
  return `${d.getUTCDate()} ${MO[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}

/** "Today", "Yesterday", "Sat 3 Oct". */
export function relativeDay(iso: string | Date, tz: string | null = TZ): string {
  const k = dayKey(typeof iso === 'string' ? new Date(iso) : iso, tz);
  const diff = daysBetween(k, todayKey(tz));
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  return weekdayDate(k);
}

/** "Just now", "2 min ago", "3 h ago", "Yesterday", "21 Sep". */
export function timeAgo(iso: string, tz: string | null = TZ): string {
  const ms = Date.now() - new Date(iso).getTime();
  const min = Math.floor(ms / 60_000);
  if (min < 1) return 'Just now';
  if (min < 60) return `${min} min ago`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${h} h ago`;
  if (Math.floor(h / 24) === 1) return 'Yesterday';
  return shortDate(dayKey(new Date(iso), tz));
}

/** Hour (0–23) now in [tz]. */
export function hourNow(tz: string = TZ): number {
  return Number(new Intl.DateTimeFormat('en-GB', { hour: 'numeric', hourCycle: 'h23', timeZone: tz }).format(new Date())) % 24;
}

/** "Good morning / afternoon / evening". */
export function greeting(tz: string = TZ): string {
  const h = hourNow(tz);
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/** '19:30' → '7:30 PM'. */
export function fmtTime(hhmm: string): string {
  const p = hhmm.split(':');
  if (p.length !== 2) return hhmm;
  const h = Number(p[0]) || 0;
  const m = Number(p[1]) || 0;
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
}

/** 160 → '2 h 40 min', 20 → '20 min'. */
export function fmtDuration(min: number): string {
  if (!min || min <= 0) return '';
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

/** 2300 → "38h 20m". */
export function studyTimeLabel(minutes: number): string {
  return `${Math.floor(minutes / 60)}h ${String(minutes % 60).padStart(2, '0')}m`;
}
