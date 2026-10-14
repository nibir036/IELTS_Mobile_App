// G10 · AI Actionable Improvement Plan (improvement_plan_screen.dart): built
// from the weakest sections of a mock attempt and the plan templates of the
// mock UI copy. Pure: the page passes the attempt and copy in.

import { rows, str, strs, type Raw } from '../practice/marking';
import { band, dayOfMonth, isoWeekday, monthShortOf, plusDays, shortDate, weekdayDate } from './format';

export interface PlanGain {
  skill: string;
  letter: string;
  title: string;
  skillName: string;
  score: string;
}

export interface PlanItem {
  id: string;
  skill: string;
  title: string;
  detail: string;
  durationMin: number;
  target: string;
  date: string;
  time: string;
}

export interface PlanWeek {
  label: string;
  dates: string;
  tint: string;
  items: PlanItem[];
}

export interface MockPlan {
  title: string;
  subtitle: string;
  gains: PlanGain[];
  weeks: PlanWeek[];
}

/** Tie-break order when two sections have the same band. */
const PRIORITY = ['writing', 'speaking', 'reading', 'listening'];
const LETTER: Record<string, string> = { listening: 'L', reading: 'R', writing: 'W', speaking: 'S', mock: 'M', vocab: 'V' };

const fill = (tpl: string, v: Record<string, string>) => Object.entries(v).reduce((s, [k, val]) => s.split(`{${k}}`).join(val), tpl);
const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {});

/** "7" from "Full Mock Test 7" (mockNumberLabel). */
export function mockNumberLabel(title: string): string {
  const m = /(\d+)\s*$/.exec(title);
  return m ? m[1] : '';
}

export function sectionBand(data: Raw, skill: string): number | null {
  const v = obj(data.sections)[skill];
  return typeof v === 'number' ? v : null;
}

/**
 * The plan for one mock attempt. [mockCount] = the student's mocks so far
 * (names the next mock when the title has no number); [day] = the mock's
 * calendar day ("2026-10-13").
 */
export function buildPlan(a: { title: string; data: Raw }, day: string, copy: Raw, target: number, mockCount: number): MockPlan {
  const plan = obj(copy.plan);
  const templates = obj(plan.templates);
  const labels = obj(plan.criteriaLabels);
  const data = a.data;
  const skills = [...PRIORITY].sort((x, y) => {
    const c = (sectionBand(data, x) ?? 9) - (sectionBand(data, y) ?? 9);
    return c !== 0 ? c : PRIORITY.indexOf(x) - PRIORITY.indexOf(y);
  });
  const weakest = skills.slice(0, 3);

  let part: Raw = {};
  let ratio = 2;
  for (const p of rows(data.listeningByPart)) {
    const r = (Number(p.correct) || 0) / (Number(p.total) || 1);
    if (r < ratio) {
      ratio = r;
      part = p;
    }
  }
  const partLabel = Object.keys(part).length ? str(part.label) : 'Part 4';

  const gains: PlanGain[] = weakest.map((skill) => {
    const tpl = obj(templates[skill]);
    let focus = str(tpl.focus);
    let score = band(sectionBand(data, skill));
    if (skill === 'listening') {
      focus = fill(focus, { part: partLabel });
      if (Object.keys(part).length) score = `${Number(part.correct) || 0}/${Number(part.total) || 0}`;
    } else if (skill === 'reading') {
      const r = obj(data.readingScore);
      if (Object.keys(r).length) score = `${Number(r.correct) || 0}/${Number(r.total) || 0}`;
    } else {
      const crit = obj(data[skill === 'writing' ? 'writingCriteria' : 'speakingCriteria']);
      let w: [string, number] | null = null;
      for (const [k, v] of Object.entries(crit)) if (typeof v === 'number' && (!w || v < w[1])) w = [k, v];
      if (w) {
        focus = fill(focus, { criterion: str(labels[w[0]]) || w[0] });
        score = band(w[1]);
      } else {
        focus = str(tpl.skillName);
      }
    }
    return { skill, letter: LETTER[skill] ?? '•', title: focus, skillName: str(tpl.skillName), score };
  });

  // Weeks start on the Monday after the mock.
  const monday = plusDays(day, 8 - isoWeekday(day));
  const tints = strs(plan.weekTints);
  const nextMock = obj(plan.nextMock);
  const n = Number(mockNumberLabel(a.title));
  const nextTitle = `Mock Test ${String(Number.isFinite(n) && mockNumberLabel(a.title) ? n + 1 : mockCount + 1).padStart(2, '0')}`;
  const weeks: PlanWeek[] = weakest.map((skill, w) => {
    const start = plusDays(monday, 7 * w);
    const end = plusDays(start, 6);
    const dates = monthShortOf(start) === monthShortOf(end) ? `${dayOfMonth(start)}–${dayOfMonth(end)} ${monthShortOf(end)}` : `${shortDate(start)} – ${shortDate(end)}`;
    const last = w === weakest.length - 1;
    const items: PlanItem[] = rows(obj(templates[skill]).items)
      .slice(0, last ? 1 : undefined)
      .map((it, i) => ({
        id: str(it.id),
        skill,
        title: fill(str(it.title), { part: partLabel }),
        detail: fill(str(it.detail), { part: partLabel }),
        durationMin: Number(it.durationMin) || 0,
        target: str(it.target),
        date: plusDays(start, i * 3),
        time: '19:00',
      }));
    if (last) {
      const sat = plusDays(start, 5);
      items.push({
        id: 'next_mock',
        skill: 'mock',
        title: fill(str(nextMock.title), { mock: nextTitle }),
        detail: fill(str(nextMock.detail), { date: weekdayDate(sat) }),
        durationMin: Number(nextMock.durationMin) || 0,
        target: str(nextMock.target),
        date: sat,
        time: str(nextMock.time),
      });
    }
    return { label: `Week ${w + 1}`, dates, tint: tints[w] ?? 'none', items };
  });

  return {
    title: fill(str(plan.titleTemplate) || 'Your plan to {target}', { target: band(target) }),
    subtitle: fill(str(plan.subtitleTemplate), { mock: a.title }),
    gains,
    weeks,
  };
}
