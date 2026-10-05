// Checks the study plan engine on sample students (no database).
//
//   npx tsx scripts/plan-check.ts            # summary per sample
//   npx tsx scripts/plan-check.ts --verbose  # also prints week 1 tasks

import {
  addDays,
  buildProfile,
  estimate,
  generateDays,
  loadCatalog,
  normaliseInputs,
  summary,
  type Evidence,
  type PlanState,
} from '../src/lib/plan';

const verbose = process.argv.includes('--verbose');
const catalog = loadCatalog();
const ids = new Set(catalog.items.map((i) => i.id));
let failures = 0;

function check(cond: boolean, msg: string) {
  if (!cond) {
    failures++;
    console.log(`  FAIL ${msg}`);
  }
}

const base = {
  targetBand: 7,
  testType: 'academic',
  days: [1, 2, 3, 4, 6, 7],
  minutesPerDay: 40,
  studyTime: '20:00',
  startDate: '2026-10-12',
  tzOffsetMin: 360,
};

const samples: { name: string; raw: Record<string, unknown>; ev?: Evidence }[] = [
  { name: 'all modules, intermediate', raw: { ...base, modules: ['listening', 'reading', 'writing', 'speaking'], levels: { listening: 'intermediate', reading: 'intermediate', writing: 'intermediate', speaking: 'intermediate' } } },
  { name: 'writing only, beginner, 20 min', raw: { ...base, modules: ['writing'], levels: { writing: 'beginner' }, minutesPerDay: 20, days: [1, 3, 5] } },
  { name: 'reading + listening, advanced, GT', raw: { ...base, testType: 'gt', modules: ['reading', 'listening'], levels: { reading: 'advanced', listening: 'advanced' }, targetBand: 8 } },
  { name: 'speaking + writing, exam in 5 weeks', raw: { ...base, modules: ['speaking', 'writing'], levels: { speaking: 'amateur', writing: 'amateur' }, examDate: '2026-11-16', worry: 'writing' } },
  { name: 'already at target', raw: { ...base, modules: ['reading'], levels: { reading: 'advanced' }, targetBand: 6, previousScore: 7 } },
  { name: '90 min a day, 7 days', raw: { ...base, modules: ['listening', 'reading', 'writing', 'speaking'], levels: { listening: 'amateur', reading: 'amateur', writing: 'amateur', speaking: 'amateur' }, minutesPerDay: 90, days: [1, 2, 3, 4, 5, 6, 7] } },
];

// Two students with identical set-up answers but different first-week results.
const twins = { ...base, modules: ['writing', 'reading'], levels: { writing: 'intermediate', reading: 'intermediate' } };
const now = new Date('2026-10-20T10:00:00Z');
const evA: Evidence = {
  lessonsDone: [],
  attempts: [
    { skill: 'reading', kind: 'test', refId: 'rb_headings_01', band: null, score: 2, total: 8, data: null, createdAt: now },
    { skill: 'writing', kind: 'task2', refId: 'wb2_opinion_01', band: 5.5, score: null, total: null, data: { criteria: { TA: 6, CC: 5, LR: 6, GRA: 6 } }, createdAt: now },
  ],
};
const evB: Evidence = {
  lessonsDone: [],
  attempts: [
    { skill: 'reading', kind: 'test', refId: 'rb_headings_01', band: null, score: 8, total: 8, data: null, createdAt: now },
    { skill: 'writing', kind: 'task2', refId: 'wb2_opinion_01', band: 5.5, score: null, total: null, data: { criteria: { TA: 6, CC: 6.5, LR: 6, GRA: 4.5 } }, createdAt: now },
  ],
};
samples.push({ name: 'twin A (weak headings, weak coherence)', raw: twins, ev: evA });
samples.push({ name: 'twin B (weak grammar)', raw: twins, ev: evB });

const firstWeeks: Record<string, string[]> = {};

for (const s of samples) {
  const inputs = normaliseInputs(s.raw);
  const ev = s.ev ?? { attempts: [], lessonsDone: [] };
  const profile = buildProfile(inputs, ev, catalog, now);
  const est = estimate(inputs, profile);
  const state: PlanState = { scheduled: new Set(), doneRefs: new Set(ev.attempts.map((a) => a.refId ?? '')) };
  const tasks = generateDays(inputs, est, profile, catalog, state, inputs.startDate, addDays(inputs.startDate, 13), 'user-' + s.name);
  console.log(`\n${s.name}: ${est.weeks} weeks (${est.weeksMin}-${est.weeksMax}), start ${est.startBand} → ${est.targetBand}, onTrack=${est.onTrack}, realistic ${est.realisticBand}, focus ${est.focus} [${est.focusTags.join(', ')}]`);
  console.log(`  phases ${est.phases.map((p) => `${p.id} ${p.fromWeek}-${p.toWeek}`).join(' · ')} · checkpoints ${est.checkpointWeeks.join(',')}`);
  console.log(`  ${summary(inputs, est)}`);
  // checks
  const byDay = new Map<string, number>();
  for (const t of tasks) byDay.set(t.date, (byDay.get(t.date) ?? 0) + t.minutes);
  const studyDays = [...byDay.keys()];
  check(tasks.length > 0, 'no tasks');
  check(tasks.every((t) => ids.has(t.itemId)), 'unknown item id');
  check(tasks.every((t) => inputs.days.includes(((new Date(t.date + 'T00:00:00Z').getUTCDay() + 6) % 7) + 1)), 'task on a non-study day');
  const once = tasks.filter((t) => t.itemId !== 'pron:daily').map((t) => t.itemId);
  check(new Set(once).size === once.length, 'item scheduled twice');
  for (const [d, m] of byDay) {
    const cp = tasks.some((t) => t.date === d && t.checkpoint);
    if (!cp) check(m <= inputs.minutesPerDay + 10, `day ${d} has ${m} min (budget ${inputs.minutesPerDay})`);
  }
  if (inputs.testType === 'gt') check(!tasks.some((t) => t.itemId.startsWith('w1:')), 'GT student got an Academic Task 1');
  check(studyDays.length >= Math.min(inputs.days.length * 2 - 1, inputs.days.length), 'too few study days filled');
  const minutes = [...byDay.values()];
  console.log(`  ${tasks.length} tasks on ${studyDays.length} days, minutes/day ${Math.min(...minutes)}-${Math.max(...minutes)}`);
  firstWeeks[s.name] = tasks.filter((t) => t.date < addDays(inputs.startDate, 7)).map((t) => t.itemId);
  if (verbose) for (const t of tasks.slice(0, 14)) console.log(`    ${t.date} ${String(t.minutes).padStart(3)}m ${t.title}  ← ${t.reason}`);
}

// Twins must differ.
const a = new Set(firstWeeks['twin A (weak headings, weak coherence)']);
const b = firstWeeks['twin B (weak grammar)'];
const overlap = b.filter((x) => a.has(x)).length / Math.max(1, b.length);
console.log(`\ntwins: ${Math.round(overlap * 100)}% of week-1 tasks shared`);
check(overlap < 0.6, 'twins got near-identical plans');

console.log(failures ? `\n${failures} check(s) failed` : '\nall checks passed');
process.exit(failures ? 1 : 0);
