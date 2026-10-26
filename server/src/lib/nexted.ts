// nexted.app (study abroad) - shared helpers: the daily AI cap and the
// scholarship eligibility rules.
//
// The cap lives HERE, in the backend, around the code that actually issues an
// AI request - never in the mobile app. A phone can be inspected and edited,
// and a student must not be able to dodge the limit by switching between the
// web app and the phone (build guide, section 25.5).

import { prisma } from '../db';
import { HttpError } from './http';
import { isPro } from './users';

/**
 * AI actions per student per day (counsellor messages, course matching,
 * scholarship searches): 30 on the free plan, 50 on Pro. Change them with
 * NEXTED_AI_FREE_LIMIT / NEXTED_AI_PRO_LIMIT, without shipping a new app.
 */
const envLimit = (name: string, fallback: number) => {
  const n = Number(process.env[name]);
  return Number.isInteger(n) && n > 0 ? n : fallback;
};
export const FREE_AI_LIMIT = envLimit('NEXTED_AI_FREE_LIMIT', 30);
export const PRO_AI_LIMIT = envLimit('NEXTED_AI_PRO_LIMIT', 50);

/** This student's daily allowance (Pro gets more). */
export async function aiLimitFor(userId: string): Promise<number> {
  return (await isPro(userId)) ? PRO_AI_LIMIT : FREE_AI_LIMIT;
}

/** Today in Asia/Dhaka as YYYY-MM-DD - the day the counter belongs to. */
export function dhakaDay(now = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Dhaka',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

/** Midnight in Asia/Dhaka, when the counter resets. */
export function nextReset(now = new Date()): Date {
  const [y, m, d] = dhakaDay(now).split('-').map(Number);
  // Dhaka is UTC+6 all year (no daylight saving).
  return new Date(Date.UTC(y, m - 1, d + 1, 0, 0, 0) - 6 * 3600 * 1000);
}

export interface AiUsage {
  used: number;
  limit: number;
  left: number;
  resetsAt: string;
}

function shape(used: number, limit: number): AiUsage {
  return {
    used,
    limit,
    left: Math.max(0, limit - used),
    resetsAt: nextReset().toISOString(),
  };
}

/** Today's usage, without spending anything. */
export async function readAiUsage(userId: string): Promise<AiUsage> {
  const [row, limit] = await Promise.all([prisma.nextedAiUsage.findUnique({ where: { userId } }), aiLimitFor(userId)]);
  const today = dhakaDay();
  return shape(!row || row.quotaDate !== today ? 0 : row.usedToday, limit);
}

/**
 * Checks the cap and counts one AI action. Call this immediately before the
 * AI request, in the same handler - not in the app.
 *
 * Atomic: parallel requests can't go past the limit.
 * Throws 429 `ai_limit_reached` when the allowance is gone.
 */
export async function consumeAi(userId: string): Promise<AiUsage> {
  const today = dhakaDay();
  const limit = await aiLimitFor(userId);
  // One row per student; a new day starts from zero.
  await prisma.nextedAiUsage.upsert({
    where: { userId },
    create: { userId, usedToday: 0, quotaDate: today },
    update: {},
  });
  await prisma.nextedAiUsage.updateMany({ where: { userId, quotaDate: { not: today } }, data: { usedToday: 0, quotaDate: today } });
  const { count } = await prisma.nextedAiUsage.updateMany({
    where: { userId, quotaDate: today, usedToday: { lt: limit } },
    data: { usedToday: { increment: 1 } },
  });
  if (count === 0) {
    throw new HttpError(
      429,
      `You've used today's ${limit} AI actions. They reset at midnight.`,
      'ai_limit_reached',
      { usage: shape(limit, limit) },
    );
  }
  const row = await prisma.nextedAiUsage.findUnique({ where: { userId } });
  return shape(row?.usedToday ?? 1, limit);
}

// ── scholarship eligibility (plain rules, not the AI) ───────────────────────

export type Verdict = 'Eligible' | 'Borderline' | 'Not eligible';

export interface RuleResult {
  verdict: Verdict;
  /** Short facts the AI turns into readable reasons. */
  facts: string[];
}

const num = (v: unknown): number | null => {
  const n = Number(String(v ?? '').replace(/[^0-9.]/g, ''));
  return Number.isFinite(n) && n > 0 ? n : null;
};

/**
 * Compares the student's profile with the scholarship's stored criteria.
 * This decides the verdict; the AI only phrases it.
 */
export function eligibility(
  profile: { ieltsBand: string; result: string; nationality: string; highestLevel: string },
  s: { minIelts: number | null; minGpa: number | null; nationalities: string[]; level: string; title: string },
): RuleResult {
  const facts: string[] = [];
  let hardFail = false;
  let nearMiss = false;
  let unknown = false;

  const band = num(profile.ieltsBand);
  if (s.minIelts != null) {
    if (band == null) {
      unknown = true;
      facts.push(`IELTS band not in your profile; this scholarship needs ${s.minIelts}`);
    } else if (band >= s.minIelts) {
      facts.push(`IELTS ${band} meets the required ${s.minIelts}`);
    } else if (s.minIelts - band <= 0.5) {
      nearMiss = true;
      facts.push(`IELTS ${band} is just under the required ${s.minIelts}`);
    } else {
      hardFail = true;
      facts.push(`IELTS ${band} is below the required ${s.minIelts}`);
    }
  }

  const gpa = num(profile.result);
  if (s.minGpa != null) {
    if (gpa == null) {
      unknown = true;
      facts.push(`Result not in your profile; this scholarship needs ${s.minGpa}`);
    } else if (gpa >= s.minGpa) {
      facts.push(`Result ${gpa} meets the required ${s.minGpa}`);
    } else if (s.minGpa - gpa <= 0.3) {
      nearMiss = true;
      facts.push(`Result ${gpa} is just under the required ${s.minGpa}`);
    } else {
      hardFail = true;
      facts.push(`Result ${gpa} is below the required ${s.minGpa}`);
    }
  }

  if (s.nationalities.length) {
    const mine = profile.nationality.trim().toLowerCase();
    if (!mine) {
      unknown = true;
      facts.push('Nationality not in your profile');
    } else if (s.nationalities.some((n) => n.trim().toLowerCase() === mine)) {
      facts.push(`Open to ${profile.nationality} students`);
    } else {
      hardFail = true;
      facts.push(`Limited to ${s.nationalities.join(', ')} students`);
    }
  }

  if (s.level) {
    const mine = profile.highestLevel.trim().toLowerCase();
    if (mine && !s.level.toLowerCase().includes(mine) && !mine.includes(s.level.toLowerCase())) {
      nearMiss = true;
      facts.push(`For ${s.level} study; your profile says ${profile.highestLevel}`);
    }
  }

  const verdict: Verdict = hardFail ? 'Not eligible' : nearMiss || unknown ? 'Borderline' : 'Eligible';
  return { verdict, facts };
}

// ── study-destination restrictions (plain rules, not the AI) ────────────────
//
// Several UK universities close their intake to some Bangladeshi applicants -
// sometimes the whole country, more often one region (Sylhet above all), one
// level, one subject stream, one campus or one intake. This is a hard fact,
// so it is matched HERE in code and the answer is handed to the AI already
// decided; it is never left to search-by-meaning, which is good at finding a
// relevant paragraph and bad at being right about a name.
//
// The rules come from NextED's partner information, not a public university
// page. So the wording given to students says the course is not available
// *through NextED for this intake* - never that a named university rejects
// Bangladeshi students, which is a claim we could not source.

export type RestrictionStatus = 'open' | 'closed' | 'check';

export interface RestrictionRule {
  id: string;
  university: string;
  campus: string;
  openCampus: string;
  kind: string;
  levels: string[];
  regions: string[];
  exceptRegions: string[];
  subjects: string[];
  intakes: string[];
  note: string;
  source: string;
  asOf: Date;
}

export interface RestrictionCheck {
  status: RestrictionStatus;
  /** One sentence for the student. Empty when nothing applies. */
  message: string;
  /** The partner line and its date, for a counsellor. */
  detail: string;
  /** True when a human has to look at the real terms. */
  needsCounsellor: boolean;
}

const OPEN: RestrictionCheck = { status: 'open', message: '', detail: '', needsCounsellor: false };

const norm = (v: unknown): string => String(v ?? '').trim().toLowerCase();

/** Loose containment both ways, so "Sylhet" matches "Sylhet Division". */
function hits(list: string[], value: string): boolean {
  const v = norm(value);
  if (!v) return false;
  return list.some((item) => {
    const i = norm(item);
    return i !== '' && (i === v || i.includes(v) || v.includes(i));
  });
}

/** "University of Law" and "The University of Law" are the same institution. */
export function sameUniversity(a: string, b: string): boolean {
  const clean = (v: string) =>
    norm(v)
      .replace(/^the\s+/, '')
      .replace(/\(.*?\)/g, '')
      .replace(/[^a-z0-9 ]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  const x = clean(a);
  const y = clean(b);
  if (!x || !y) return false;
  return x === y || x.includes(y) || y.includes(x);
}

export interface StudentScope {
  /** Home district in Bangladesh; empty means we do not know it yet. */
  homeDistrict: string;
  level: string;
  subject: string;
  intake: string;
}

/**
 * Decides what a set of rules means for one student and one course.
 *
 * Three answers, not two. A rule scoped to a region cannot be applied to a
 * student whose district we do not have, so that case returns `check` rather
 * than guessing either way - the same honesty the eligibility verdict uses.
 */
export function checkRestrictions(
  rules: RestrictionRule[],
  university: string,
  student: StudentScope,
): RestrictionCheck {
  const mine = rules.filter((r) => sameUniversity(r.university, university));
  if (!mine.length) return OPEN;

  let fallback: RestrictionCheck | null = null;

  for (const r of mine) {
    const detail = `${r.note || 'Restricted for Bangladeshi applicants'} (NextED partner information, ${r.asOf
      .toISOString()
      .slice(0, 10)})`;

    // "Only the Belfast campus is open": everything else is closed, and we do
    // not know which campus a course belongs to, so a person has to look.
    if (r.openCampus) {
      fallback ??= {
        status: 'check',
        message: `Only the ${r.openCampus} campus is open to Bangladeshi applicants - a counsellor can confirm which campus this course runs on.`,
        detail,
        needsCounsellor: true,
      };
      continue;
    }

    // A campus-scoped rule has the same problem.
    if (r.campus) {
      fallback ??= {
        status: 'check',
        message: `The ${r.campus} campus is restricted${
          r.regions.length ? ` for ${r.regions.join(', ')} applicants` : ''
        } - a counsellor can confirm which campus this course runs on.`,
        detail,
        needsCounsellor: true,
      };
      continue;
    }

    // Region. An unknown district cannot be ruled in or out.
    let regionApplies = true;
    if (r.regions.length) {
      if (!student.homeDistrict) {
        fallback ??= {
          status: 'check',
          message:
            'This one is restricted for some districts of Bangladesh. Add your home district to your profile and we can tell you.',
          detail,
          needsCounsellor: false,
        };
        continue;
      }
      regionApplies = hits(r.regions, student.homeDistrict);
    } else if (r.exceptRegions.length) {
      if (!student.homeDistrict) {
        fallback ??= {
          status: 'check',
          message:
            'This one is open only to some districts of Bangladesh. Add your home district to your profile and we can tell you.',
          detail,
          needsCounsellor: false,
        };
        continue;
      }
      regionApplies = !hits(r.exceptRegions, student.homeDistrict);
    }
    if (!regionApplies) continue;

    if (r.levels.length && !hits(r.levels, student.level)) continue;
    if (r.subjects.length && !hits(r.subjects, student.subject)) continue;
    if (r.intakes.length && !hits(r.intakes, student.intake)) continue;

    if (r.kind === 'check') {
      fallback ??= { status: 'check', message: `${r.note} - a counsellor can confirm.`, detail, needsCounsellor: true };
      continue;
    }

    return {
      status: 'closed',
      message: 'Not available through NextED for this intake.',
      detail,
      needsCounsellor: true,
    };
  }

  return fallback ?? OPEN;
}

/** The short lines handed to the AI as settled facts. */
export function restrictionFacts(
  rules: RestrictionRule[],
  universities: string[],
  student: StudentScope,
): string[] {
  const out: string[] = [];
  for (const u of universities) {
    const c = checkRestrictions(rules, u, student);
    if (c.status === 'open') continue;
    out.push(`${u}: ${c.status === 'closed' ? 'CLOSED' : 'UNCERTAIN'} - ${c.message}`);
  }
  return out;
}

// ── counsellor: replies that must never be improvised ──────────────────────
//
// The same rules as the nextED AI service (ai/app/core/policy.py), for the
// built-in counsellor that answers while that service is off. Asked how to
// reach a counsellor, a model will happily offer in-app booking, a callback
// or an email address - none of which exist. These answers are fixed text.

/** The NextED office. Override with NEXTED_OFFICE_* in .env if it changes. */
export const OFFICE = {
  name: process.env.NEXTED_OFFICE_NAME || 'nextED',
  address: process.env.NEXTED_OFFICE_ADDRESS || 'Plot 40, 4th Floor, Road 7B, Block H, Banani, Dhaka, Bangladesh',
  phoneDisplay: process.env.NEXTED_OFFICE_PHONE || '01626794269',
  telLink: `tel:${process.env.NEXTED_OFFICE_PHONE_E164 || '+8801626794269'}`,
  mapsUrl:
    process.env.NEXTED_OFFICE_MAPS_URL ||
    'https://www.google.com/maps/place/NextED+Advisors/@23.7898425,90.4059136,17z/data=!3m1!4b1!4m6!3m5!1s0x3755c7fa96085ad5:0x80eacd9ada03657e!8m2!3d23.7898425!4d90.4084885!16s%2Fg%2F11ypcnw83n',
};

export function contactResponse(): string {
  return [
    `You can talk to a ${OFFICE.name} counsellor directly:`,
    '',
    `- Call us on ${OFFICE.phoneDisplay}`,
    `- Visit our office: ${OFFICE.address}`,
    '- The buttons below call the office or open directions',
    '',
    'Bring your questions about countries, universities, scholarships, applications or visas - and your ' +
      'academic documents if you have them handy. Meanwhile, I can help you here with your options, your ' +
      'profile and the next steps.',
  ].join('\n');
}

/** Buttons the app draws under an answer (type -> label). */
export const COUNSELLOR_BUTTONS: Record<string, string> = {
  course_finder: 'Find courses for me',
  scholarship_finder: 'Find scholarships for me',
  complete_profile: 'Complete my profile',
  call_office: 'Call nextED',
  office_location: 'Get directions',
};

const BUTTON_MENTIONS: [string, RegExp][] = [
  ['course_finder', /\b(course[- ]?match(ing|er)?|course[- ]?finder)\b/i],
  ['scholarship_finder', /\bscholarship[- ]?finder\b/i],
  ['complete_profile', /\b(complete|finish|fill in|update)\b.{0,20}\bprofile\b/i],
];

/**
 * The answer as the app shows it: real buttons, never button names in the
 * text. The model sometimes writes "Buttons: - Course matching
 * (course_finder)" instead of asking for them; that block is removed and
 * turned into buttons. An answer that names Course matching, the
 * Scholarship finder or completing the profile gets that button too.
 */
export function finishAnswer<T extends Record<string, unknown>>(answer: T): T {
  let reply = String(answer.reply ?? '');
  const types = new Set<string>();
  for (const a of Array.isArray(answer.actions) ? answer.actions : []) {
    const type = a && typeof a === 'object' ? String((a as Record<string, unknown>).type ?? '') : '';
    if (type in COUNSELLOR_BUTTONS) types.add(type);
  }
  const ids = Object.keys(COUNSELLOR_BUTTONS).join('|');
  const named = new RegExp(`\\b(${ids})\\b`, 'g');
  for (const m of reply.matchAll(named)) types.add(m[1]);
  // A "Buttons:" heading and the bullet list under it.
  reply = reply.replace(
    /(^|\n)[ \t]*(?:\*\*|#+[ \t]*)?(?:suggested |available )?buttons?[ \t]*:?[ \t]*(?:\*\*)?[ \t]*:?[ \t]*(?=\n|$)(?:\n[ \t]*(?:[-*•]|\d+[.)])[^\n]*)*/gi,
    '$1',
  );
  // Any leftover "(course_finder)" or bare id.
  reply = reply.replace(new RegExp(`\\s*[(\\[\`]?\\b(${ids})\\b[)\\]\`]?`, 'g'), '');
  reply = reply.replace(/\n{3,}/g, '\n\n').trim();
  for (const [type, re] of BUTTON_MENTIONS) if (re.test(reply)) types.add(type);
  const order = Object.keys(COUNSELLOR_BUTTONS).filter((t) => types.has(t));
  const actions = order.map((type) => ({ type, label: COUNSELLOR_BUTTONS[type] }));
  const out: Record<string, unknown> = { ...answer, reply };
  if (actions.length) out.actions = actions;
  else delete out.actions;
  // Call / Directions need the office's details.
  if ((types.has('call_office') || types.has('office_location')) && !out.office) out.office = OFFICE;
  return out as T;
}

/** A question about what nextED itself charges: only the office answers it. */
export function feeResponse(): string {
  return (
    `You can get the answer to your query from our office. Please contact us at ${OFFICE.phoneDisplay}, ` +
    'or visit our office in Banani, Dhaka.'
  );
}

const FEE_PATTERNS = [
  /\b(cost|costs|price|pricing|fee|fees|charge|charges|pay|paying|payment|free|money|taka|tk|bdt|package)\b.{0,40}\b(nexted|your (service|services|team|office|company|agency|consultancy|help)|working with (you|nexted)|work with (you|nexted)|using (you|nexted))\b/,
  /\b(nexted|your (service|services|consultancy|agency|company))\b.{0,30}\b(cost|costs|price|pricing|fee|fees|charge|charges|free|package|payment|pay)\b/,
  /\b(is|are) (it|this|your service|your services|nexted|you) (free|paid)\b/,
  /\bdo (i|we) (have|need) to pay (you|nexted|anything)\b/,
  /\bhow much (do|does|will) (you|nexted)\b/,
  /(নেক্সটেড|আপনাদের|আপনার).{0,20}(খরচ|ফি|চার্জ|টাকা)/,
  /(খরচ|ফি|চার্জ|টাকা).{0,20}(নেক্সটেড|আপনাদের)/,
  /\bfile[- ]?open(ing)?\b.{0,20}\b(fee|charge|cost|price|money|taka|tk)\b/,
  /\b(fee|charge|cost|price)\b.{0,25}\bfile\b/,
  /\byour\b.{0,15}\b(service|consultancy|agency)\b.{0,15}\b(fee|charge|cost)\b/,
  /\bhow much\b.{0,30}\b(you|nexted|your office)\b.{0,20}\b(charge|cost|fee)\b/,
  /কত.{0,20}(ফি|চার্জ|টাকা)/,
];

// Tuition, visa, living costs and the like are not nextED's fee - unless the
// message also names nextED's own charge.
const THIRD_PARTY =
  /\b(tuition|university|universities|uni|college|living|accommodation|rent|visa|embassy|ihs|health surcharge|ielts|toefl|pte|duolingo|application fee|deposit|flight|ticket|insurance)\b/;
const NAMES_NEXTED =
  /\b(nexted|file[- ]?open|service charge|service fee|consultancy|your service|your services|your fee|your fees|your charge|working with (you|nexted))\b/;

const CONTACT_PATTERNS = [
  /\b(talk|speak|meet|chat|connect)\b.{0,25}\b(counsel+or|advis[eo]r|consultant|someone|somebody|a person|a human|an agent|nexted|your team|your office|you)\b/,
  /\b(get|be|stay|keep) in touch\b/,
  /\b(call|phone|ring|whatsapp|text|message|e-?mail)\b.{0,6}\bme\b/,
  /\b(contact|reach|call|phone|ring|whatsapp|e-?mail|message)\b.{0,25}\b(you|nexted|counsel+or|office|your team|advis[eo]r|consultant)\b/,
  /\b(counsel+or|consultant|advis[eo]r)\b.{0,30}\b(contact|reach|talk|speak|meet|call|appointment|book|available)\b/,
  /\b(book|schedule|arrange|make|get|fix|set up)\b.{0,20}\b(appointment|consultation|meeting|session)\b/,
  /\b(appointment|consultation)\b/,
  /\b(where|what)\b.{0,20}\b(office|address|located|location)\b/,
  /\b(your|nexted'?s?)\b.{0,12}\b(phone|number|contact|address|e-?mail|whatsapp|office|hotline)\b/,
  /\b(map|directions?)\b.{0,20}\b(office|you|nexted)\b/,
  /\bvisit\b.{0,15}\b(office|you|nexted)\b/,
  /(কাউন্সেলর|কাউন্সিলর|যোগাযোগ|অফিস|ঠিকানা|ফোন নম্বর|নাম্বার)/,
];

const CHANCE_PATTERNS = [
  /\b(chance|chances|odds|probability|likelihood)\b/,
  /\bwill i (get|be) (in|admitted|accepted)\b/,
  /\bcan i get (into|admission|in(?! touch))\b/,
  /\bam i (eligible|qualified)\b/,
];

/** 'fee' | 'contact' | '' - whether a message needs a fixed answer. */
export function fixedIntent(message: string): 'fee' | 'contact' | '' {
  const m = message.toLowerCase();
  // What nextED charges is never the model's to answer.
  if (FEE_PATTERNS.some((p) => p.test(m)) && !(THIRD_PARTY.test(m) && !NAMES_NEXTED.test(m))) return 'fee';
  // A chances question goes to the model (it invites a counsellor itself).
  if (CHANCE_PATTERNS.some((p) => p.test(m))) return '';
  if (CONTACT_PATTERNS.some((p) => p.test(m))) return 'contact';
  return '';
}
