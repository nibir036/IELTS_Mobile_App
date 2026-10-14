// Small date / number formatters shared by the extras pages (the app's
// Store.weekdayDate, Store.shortDate, mockShortClock …). Pure: server or client.

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** The student's calendar day ("2026-10-13") of an ISO time, in Bangladesh time. */
export function dhakaDay(iso: string | Date): string {
  const d = typeof iso === 'string' ? new Date(iso) : iso;
  return Number.isNaN(d.getTime()) ? '' : d.toLocaleDateString('en-CA', { timeZone: 'Asia/Dhaka' });
}

function utcNoon(key: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(key);
  return m ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], 12)) : null;
}

export function dayKey(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

export function plusDays(key: string, n: number): string {
  const d = utcNoon(key);
  if (!d) return key;
  d.setUTCDate(d.getUTCDate() + n);
  return dayKey(d);
}

/** ISO weekday of a day key: Monday 1 … Sunday 7. */
export function isoWeekday(key: string): number {
  const d = utcNoon(key);
  const w = d ? d.getUTCDay() : 1;
  return w === 0 ? 7 : w;
}

/** "Sat 14 Nov". */
export function weekdayDate(key: string): string {
  const d = utcNoon(key);
  return d ? `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}` : '';
}

/** "14 Nov". */
export function shortDate(key: string): string {
  const d = utcNoon(key);
  return d ? `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}` : '';
}

export function dayOfMonth(key: string): number {
  return utcNoon(key)?.getUTCDate() ?? 0;
}

export function monthShortOf(key: string): string {
  const d = utcNoon(key);
  return d ? MONTHS[d.getUTCMonth()] : '';
}

/** 6.5 → "6.5", null → "–". */
export function band(v: number | null | undefined): string {
  return typeof v === 'number' && Number.isFinite(v) ? v.toFixed(1) : '–';
}

/** 75 → "1:15". */
export function clock(seconds: number): string {
  const s = Math.max(0, Math.round(seconds || 0));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export function wordCount(text: string): number {
  const t = text.trim();
  return t ? t.split(/\s+/).filter(Boolean).length : 0;
}

/** "**bold**" → segments (odd parts bold). */
export function boldSegments(text: string): Array<{ text: string; bold?: boolean }> {
  return text
    .split('**')
    .map((t, i) => ({ text: t, bold: i % 2 === 1 }))
    .filter((x) => x.text);
}

/** [text] with each phrase (case-insensitive, first match, no overlaps) marked. */
export function highlightSegments(text: string, phrases: string[]): Array<{ text: string; hi?: boolean }> {
  const lower = text.toLowerCase();
  const ranges: Array<[number, number]> = [];
  for (const p of phrases) {
    const phrase = p.trim().toLowerCase();
    if (!phrase) continue;
    const start = lower.indexOf(phrase);
    if (start < 0) continue;
    const end = start + phrase.length;
    if (!ranges.some(([a, b]) => start < b && end > a)) ranges.push([start, end]);
  }
  ranges.sort((a, b) => a[0] - b[0]);
  const out: Array<{ text: string; hi?: boolean }> = [];
  let at = 0;
  for (const [a, b] of ranges) {
    if (a > at) out.push({ text: text.slice(at, a) });
    out.push({ text: text.slice(a, b), hi: true });
    at = b;
  }
  if (at < text.length) out.push({ text: text.slice(at) });
  return out;
}
