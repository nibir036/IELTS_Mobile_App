// Milestones (lib/features/home/certificates_screen.dart › evaluateCertificates):
// badges from home.json › certificates.items, checked against the student's
// attempts and finished lessons. Pure, so the server works them out.

import { dayKey } from './time';
import { formatBand, skillLabel, type AttemptLike } from './stats';

type Raw = Record<string, unknown>;
type Done = Record<string, { at?: string; xp?: number; module?: string } | null | undefined>;

export interface CertStatus {
  id: string;
  group: string;
  code: string;
  title: string;
  description: string;
  icon: string;
  earned: boolean;
  /** ISO time it was earned. */
  earnedAt: string | null;
  progress: number;
  progressLabel: string;
  detail: string;
  /** Where to work on a locked badge ('' = nowhere specific). */
  practiceHref: string;
}

export interface CertInputs {
  defs: Raw[];
  attempts: AttemptLike[];
  target: number;
  done: Done;
  /** Course packs by module (for stage / course rules). */
  courses: Record<string, Raw>;
  /** Listening set id → its part (1–4). */
  listeningPart: (setId: string) => number;
}

const str = (v: unknown) => (v == null ? '' : String(v));
const num = (v: unknown) => (typeof v === 'number' ? v : Number(v) || 0);
const list = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);
const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

/** Material Symbols name for a certificate icon key (_certIcon). */
export function certIcon(key: string): string {
  const m: Record<string, string> = {
    mock: 'fact_check',
    trophy: 'trophy',
    listening: 'headphones',
    reading: 'menu_book',
    writing: 'edit_note',
    speaking: 'mic',
    pen: 'edit',
    mic: 'mic',
    fire: 'local_fire_department',
    headphones: 'headset_mic',
    school: 'school',
    check: 'check',
    layers: 'layers',
    star: 'star',
    bolt: 'bolt',
  };
  return m[key] ?? 'workspace_premium';
}

function skillLandingHref(skill: string): string {
  return { listening: '/app/listening', reading: '/app/reading', writing: '/app/writing', speaking: '/app/speaking', mock: '/app/mocks', vocab: '/app/resources/words?saved=1' }[skill] ?? '';
}

function practiceHref(rule: Raw): string {
  switch (str(rule.type)) {
    case 'mockOverall':
      return '/app/mocks';
    case 'count':
    case 'skillTarget':
      return str(rule.skill) === 'mock' ? '/app/mocks' : skillLandingHref(str(rule.skill));
    case 'listeningParts':
      return '/app/listening';
    case 'lessons':
    case 'xp':
    case 'stage':
    case 'course':
      return '/app/courses';
    default:
      return '';
  }
}

function completions(done: Done): string[] {
  return Object.values(done)
    .map((v) => v?.at)
    .filter((x): x is string => typeof x === 'string' && !Number.isNaN(new Date(x).getTime()))
    .sort((a, b) => new Date(a).getTime() - new Date(b).getTime());
}

export function evaluateCertificates(inp: CertInputs): CertStatus[] {
  const chron = inp.attempts.filter((a) => a.kind !== 'session').sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
  const times = completions(inp.done);
  const doneCount = (module?: string) =>
    module ? Object.values(inp.done).filter((v) => v && v.module === module).length : Object.keys(inp.done).length;
  const xp = Object.values(inp.done).reduce((a, v) => a + (typeof v?.xp === 'number' ? v.xp : 0), 0);

  return inp.defs.map((def) => {
    const rule = (def.rule ?? {}) as Raw;
    const base = {
      id: str(def.id),
      group: str(def.group) || 'Practice',
      code: str(def.code),
      title: str(def.title),
      description: str(def.description),
      icon: str(def.icon),
      practiceHref: practiceHref(rule),
    };
    const out = (o: { earned: boolean; earnedAt?: string | null; progress: number; progressLabel: string; detail?: string }): CertStatus => ({
      ...base,
      earned: o.earned,
      earnedAt: o.earnedAt ?? null,
      progress: clamp01(o.progress),
      progressLabel: o.progressLabel,
      detail: o.detail ?? '',
    });
    const goalOf = (min = 1) => (num(rule.goal) < 1 ? min : Math.trunc(num(rule.goal)));

    switch (str(rule.type)) {
      case 'count': {
        const skill = str(rule.skill);
        const kinds = Array.isArray(rule.kinds) ? rule.kinds.map(String) : [];
        const goal = goalOf();
        const l = chron.filter((a) => a.skill === skill && (!kinds.length || kinds.includes(a.kind)));
        const n = l.length;
        const shown = Math.min(n, goal);
        const unit = str(def.unit);
        return out({ earned: n >= goal, earnedAt: n >= goal ? l[goal - 1].createdAt : null, progress: shown / goal, progressLabel: `${shown} of ${goal}${unit ? ` ${unit}` : ''}` });
      }
      case 'mockOverall': {
        const need = num(rule.band);
        let best: number | null = null;
        let at: string | null = null;
        let atBand: number | null = null;
        for (const a of chron) {
          if (a.skill !== 'mock') continue;
          const b = a.band ?? (typeof a.data?.overall === 'number' ? (a.data.overall as number) : null);
          if (b == null) continue;
          if (best == null || b > best) best = b;
          if (at == null && b >= need) {
            at = a.createdAt;
            atBand = b;
          }
        }
        return out({
          earned: at != null,
          earnedAt: at,
          progress: best == null || need <= 0 ? 0 : best / need,
          progressLabel: best == null ? `No mock test yet · need ${formatBand(need)}` : `Best ${formatBand(best)} of ${formatBand(need)}`,
          detail: atBand == null ? '' : `Overall Band ${formatBand(atBand)}`,
        });
      }
      case 'skillTarget': {
        const skill = str(rule.skill);
        let best: number | null = null;
        let at: string | null = null;
        let atBand: number | null = null;
        for (const a of chron) {
          let b: number | null = null;
          if (a.skill === skill) b = a.band;
          else if (a.skill === 'mock') {
            const sec = a.data?.sections as Raw | undefined;
            if (sec && typeof sec[skill] === 'number') b = sec[skill] as number;
          }
          if (b == null) continue;
          if (best == null || b > best) best = b;
          if (at == null && b >= inp.target) {
            at = a.createdAt;
            atBand = b;
          }
        }
        const tgt = formatBand(inp.target);
        return out({
          earned: at != null,
          earnedAt: at,
          progress: best == null ? 0 : best / inp.target,
          progressLabel: best == null ? `Not practised yet · target ${tgt}` : `Best ${formatBand(best)} of target ${tgt}`,
          detail: atBand == null ? '' : `${skillLabel(skill)} Band ${formatBand(atBand)}`,
        });
      }
      case 'streak': {
        const goal = goalOf();
        const days = [...new Set([...chron.map((a) => dayKey(new Date(a.createdAt))), ...times.map((t) => dayKey(new Date(t)))])].sort();
        let run = 0;
        let longest = 0;
        let prev: string | null = null;
        let at: string | null = null;
        for (const d of days) {
          if (prev != null && Math.round((new Date(`${d}T12:00:00Z`).getTime() - new Date(`${prev}T12:00:00Z`).getTime()) / 86_400_000) === 1) run++;
          else run = 1;
          prev = d;
          if (run > longest) longest = run;
          if (at == null && run >= goal) at = `${d}T12:00:00Z`;
        }
        const shown = Math.min(longest, goal);
        return out({
          earned: at != null,
          earnedAt: at,
          progress: shown / goal,
          progressLabel: `Best run ${shown} of ${goal} days`,
          detail: at == null ? '' : `Longest streak ${longest} days`,
        });
      }
      case 'lessons': {
        const goal = goalOf();
        const module = str(rule.module);
        const n = doneCount(module || undefined);
        const shown = Math.min(n, goal);
        return out({ earned: n >= goal, earnedAt: n >= goal && times.length >= goal ? times[goal - 1] : null, progress: shown / goal, progressLabel: `${shown} of ${goal} lessons` });
      }
      case 'xp': {
        const goal = goalOf();
        return out({ earned: xp >= goal, earnedAt: xp >= goal && times.length ? times[times.length - 1] : null, progress: xp / goal, progressLabel: `${Math.min(xp, goal)} of ${goal} XP` });
      }
      case 'stage':
      case 'course': {
        const module = str(rule.module) || 'writing';
        const stageId = str(rule.stage);
        const stages = list(inp.courses[module]?.stages);
        const lessons = stageId ? stages.filter((st) => str(st.id) === stageId).flatMap((st) => list(st.lessons)) : stages.flatMap((st) => list(st.lessons));
        const goal = lessons.length || 1;
        const n = lessons.filter((l) => inp.done[str(l.id)]).length;
        const earned = lessons.length > 0 && n === goal;
        return out({ earned, earnedAt: earned && times.length ? times[times.length - 1] : null, progress: n / goal, progressLabel: `${n} of ${goal} lessons` });
      }
      case 'listeningParts': {
        const goal = num(rule.goal) < 1 ? 4 : Math.trunc(num(rule.goal));
        const parts = new Set<number>();
        let at: string | null = null;
        for (const a of chron) {
          if (a.skill === 'listening' && a.kind === 'mini') {
            const p = inp.listeningPart(a.refId);
            if (p >= 1 && p <= 4) parts.add(p);
          } else if ((a.skill === 'listening' && a.kind === 'test') || a.skill === 'mock') {
            [1, 2, 3, 4].forEach((p) => parts.add(p));
          }
          if (at == null && parts.size >= goal) at = a.createdAt;
        }
        const shown = Math.min(parts.size, goal);
        return out({ earned: at != null, earnedAt: at, progress: shown / goal, progressLabel: `${shown} of ${goal} parts`, detail: at == null ? '' : 'Parts 1–4 completed' });
      }
      default:
        return out({ earned: false, progress: 0, progressLabel: '' });
    }
  });
}

/** "IA-FM-20260921-3K9Q": stable per account + certificate (certificateId). */
export function certificateId(accountId: string, c: Pick<CertStatus, 'id' | 'code' | 'earnedAt'>): string {
  let h = 7;
  const src = `${accountId}:${c.id}`;
  for (let i = 0; i < src.length; i++) h = (h * 31 + src.charCodeAt(i)) & 0xffffff;
  const date = dayKey(c.earnedAt ? new Date(c.earnedAt) : new Date()).replace(/-/g, '');
  const hash = h.toString(36).toUpperCase().padStart(4, '0');
  return `IA-${c.code || 'C'}-${date}-${hash.slice(-4)}`;
}

export const CERT_GROUPS = ['Learning', 'Practice', 'Streaks', 'Scores'];
