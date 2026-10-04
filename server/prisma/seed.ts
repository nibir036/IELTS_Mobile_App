/**
 * Loads seed/data/*.json (content + config) into Postgres, then the demo
 * account from assets/demo/parts (skip with SEED_DEMO=0).
 *
 * 01-29  demo content + reading bank          (tool/build_seed_formats.py)
 * 30-35  config
 * 50-71  question banks, full tests, guides,   (tool/build_seed_banks.py, rows
 *        resources and translations             already in table shape)
 *
 *   npx prisma db seed
 *
 * Safe to re-run: every row is upserted by its id, so edited content is
 * updated in place and nothing is duplicated.
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/lib/password';

const prisma = new PrismaClient();

const ROOT = path.resolve(__dirname, '..', '..');
const DATA_DIR = path.join(ROOT, 'seed', 'data');
const DEMO_DIR = path.join(ROOT, 'assets', 'demo', 'parts');

type Row = Record<string, any>;

function readJson(file: string): any {
  return JSON.parse(readFileSync(file, 'utf8'));
}

function items(file: string): Row[] {
  return readJson(path.join(DATA_DIR, file)).items as Row[];
}

/** Drop null / undefined values so optional columns keep their defaults. */
function clean(row: Row): Row {
  const out: Row = {};
  for (const [k, v] of Object.entries(row)) if (v !== null && v !== undefined) out[k] = v;
  return out;
}

function rename(row: Row, from: string, to: string): Row {
  if (!(from in row)) return row;
  const { [from]: value, ...rest } = row;
  return { ...rest, [to]: value };
}

/** "2026-09-29" → Date at 00:00 UTC (for @db.Date columns). */
function day(d: string): Date {
  return new Date(`${d}T00:00:00Z`);
}

async function upsertAll(model: string, rows: Row[], where: (r: Row) => Row = (r) => ({ id: r.id })) {
  const delegate = (prisma as any)[model];
  for (const raw of rows) {
    const data = clean(raw);
    await delegate.upsert({ where: where(data), create: data, update: data });
  }
  console.log(`  ${model.padEnd(24)} ${rows.length}`);
}

async function seedContent() {
  console.log('Content');
  await upsertAll('vocabularyWord', items('13_vocabulary_words.json'));
  await upsertAll(
    'wordOfTheDay',
    items('25_word_of_the_day.json').map((r) => ({ ...r, date: day(r.date) })),
    (r) => ({ date: r.date }),
  );

  // Reading
  await upsertAll('readingTypeLesson', items('28_reading_type_lessons.json'));
  await upsertAll('readingPassage', [
    ...items('01_reading_passages.json').map((r) => ({ ...r, source: 'library' })),
    ...items('27_reading_bank_passages.json').map((r) => ({ ...r, source: 'bank' })),
  ]);
  await upsertAll('readingTest', [
    // The original demo tests are kind "demo"; Academic Reading Tests 1-10 (54) are "full".
    ...items('02_reading_tests.json').map((r) => ({ ...rename(r, 'passages', 'passageIds'), kind: 'demo' })),
    ...items('29_reading_practice_tests.json').map((r) => rename(r, 'passages', 'passageIds')),
  ]);
  await upsertAll(
    'lesson',
    (
      [
        ['reading', '17_reading_lessons.json'],
        ['listening', '18_listening_lessons.json'],
        ['writing', '19_writing_lessons.json'],
      ] as const
    ).flatMap(([skill, file]) =>
      items(file).map(({ id, title, ...rest }, i) => ({ id, skill, sortOrder: i, title, data: rest })),
    ),
  );

  // Listening
  await upsertAll('listeningSet', items('03_listening_sets.json'));
  await upsertAll(
    'listeningTest',
    items('04_listening_tests.json').map((r) => ({ ...rename(r, 'sets', 'setIds'), kind: 'demo' })),
  );

  // Writing
  await upsertAll('writingPrompt', [
    ...items('05_writing_task1_prompts.json').map((r) => ({ ...r, task: 1 })),
    ...items('06_writing_task2_prompts.json').map((r) => ({ ...r, task: 2 })),
  ]);
  await upsertAll('writingSampleAnswer', items('22_writing_sample_answers.json'), (r) => ({ promptId: r.promptId }));
  await upsertAll('writingTemplate', items('21_writing_templates.json'));
  await upsertAll('sentenceDrill', items('20_sentence_drills.json').map((r) => rename(r, 'function', 'purpose')));

  // Speaking
  await upsertAll('speakingPart1Topic', items('07_speaking_part1_topics.json'));
  await upsertAll('speakingCueCard', items('08_speaking_cue_cards.json'));
  await upsertAll(
    'speakingPart3Set',
    items('26_speaking_part3_sets.json').map((r) => ({ ...r, cueCardId: r.cueCardId || null })),
  );
  await upsertAll('pronunciationWord', items('16_pronunciation_words.json').map((r) => rename(r, 'set', 'drillSet')));

  // Mock tests (after the tests and prompts they point to)
  await upsertAll(
    'mockTest',
    items('09_mock_tests.json').map(({ listeningTest, readingTest, task1, task2, ...r }) => ({
      ...r,
      kind: 'demo',
      listeningTestId: listeningTest,
      readingTestId: readingTest,
      task1Id: task1,
      task2Id: task2,
    })),
  );

  // Resources
  await upsertAll('vocabQuiz', items('10_vocab_quizzes.json'));
  await upsertAll('phrase', [
    ...items('11_phrasal_verbs.json').map((r) => ({ ...r, kind: 'phrasal' })),
    ...items('12_idioms.json').map((r) => ({ ...r, kind: 'idiom' })),
  ]);
  await upsertAll('academicWord', items('14_academic_words.json'));
  await upsertAll('irregularVerb', items('15_irregular_verbs.json'));
  await upsertAll('article', items('23_articles.json').map((r, i) => ({ ...r, sortOrder: i })));
  await upsertAll('bandDescriptor', items('24_band_descriptors.json'), (r) => ({ key: r.key }));
}

/** One bank file (rows already use the table's field names). */
async function bank(model: string, file: string, where?: (r: Row) => Row) {
  await upsertAll(model, items(file), where);
}

/** Question banks, full tests, resources, guides (after the demo content they extend). */
async function seedBanks() {
  console.log('Banks and full tests');
  // Listening
  await bank('listeningSet', '50_listening_bank_sets.json');
  await bank('listeningSet', '51_listening_test_sets.json');
  await bank('listeningTest', '52_listening_full_tests.json');
  // Reading (the reading bank itself is 27-29)
  await bank('readingPassage', '53_reading_test_passages.json');
  await bank('readingTest', '54_reading_full_tests.json');
  // Writing
  await bank('writingPrompt', '55_writing_bank_prompts.json');
  await bank('writingSampleAnswer', '56_writing_bank_samples.json', (r) => ({ promptId: r.promptId }));
  await bank('writingPrompt', '57_writing_test_prompts.json');
  await bank('writingTest', '58_writing_tests.json');
  // Speaking
  await bank('speakingPart1Topic', '59_speaking_bank_part1_topics.json');
  await bank('speakingCueCard', '60_speaking_bank_cue_cards.json');
  await bank('speakingPart3Set', '61_speaking_bank_part3_topics.json');
  await bank('speakingPart1Topic', '62_speaking_test_part1_topics.json');
  await bank('speakingCueCard', '63_speaking_test_cue_cards.json');
  await bank('speakingPart3Set', '64_speaking_test_part3_topics.json');
  await bank('speakingTest', '65_speaking_tests.json');
  // Full Mock Tests 1-4 (after every test they point to)
  await bank('mockTest', '66_full_mock_tests.json');
  // Resources
  await bank('vocabularyWord', '67_resource_vocabulary.json');
  await bank('phrase', '68_resource_phrases.json');
  await bank('academicWord', '69_resource_academic_words.json');
  await bank('irregularVerb', '70_resource_irregular_verbs.json');
  // Guides, bank notes, lists, glossary, translations
  await bank('contentDocument', '71_content_documents.json');
}

async function seedConfig() {
  console.log('Config');
  await upsertAll('plan', items('30_plans.json').map((r, i) => ({ ...r, sortOrder: i })));
  await upsertAll('planFeature', items('31_plan_features.json').map((r, i) => ({ ...r, sortOrder: i })));
  // `group` (Learning / Practice / Streaks / Scores) is only used by the app's
  // Milestones screen; the table has no column for it.
  await upsertAll(
    'certificateDefinition',
    items('32_certificates.json').map(({ group: _group, ...r }, i) => ({ ...r, sortOrder: i })),
  );
  await upsertAll('legalDocument', items('33_legal_documents.json'), (r) => ({
    id_version: { id: r.id, version: r.version },
  }));
  await upsertAll('room', items('34_community_rooms.json'));
  await upsertAll('appConfig', items('35_app_config.json'), (r) => ({ key: r.key }));
}

// ── Demo account (same data the app's demo login shows) ──────────────────

const DHAKA_MS = 6 * 60 * 60 * 1000; // Asia/Dhaka = UTC+6, no DST

/** Today's date in Dhaka as [year, monthIndex, day]. */
function dhakaToday(): [number, number, number] {
  const d = new Date(Date.now() + DHAKA_MS);
  return [d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()];
}

/** Dhaka local date (today + offsetDays) at `hour`:00, as a UTC instant. */
function dhakaAt(offsetDays: number, hour = 0): Date {
  const [y, m, d] = dhakaToday();
  return new Date(Date.UTC(y, m, d + offsetDays, hour) - DHAKA_MS);
}

/** Dhaka calendar date (today + offsetDays) for @db.Date columns. */
function dhakaDate(offsetDays: number): Date {
  const [y, m, d] = dhakaToday();
  return new Date(Date.UTC(y, m, d + offsetDays));
}

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

async function seedDemo() {
  console.log('Demo account');
  const [entry] = readJson(path.join(DEMO_DIR, 'accounts.json')) as Row[];
  const acc = entry.account as Row;
  const { examDaysFromNow, ...profile } = acc.profile as Row;
  if (typeof examDaysFromNow === 'number') profile.examDate = isoDate(dhakaDate(examDaysFromNow));

  // accounts.json times have no zone: read them as Dhaka time.
  const created = new Date(/[zZ]|[+-]\d\d:\d\d$/.test(acc.createdAt) ? acc.createdAt : `${acc.createdAt}+06:00`);
  const user = {
    id: acc.id,
    name: acc.name,
    phone: acc.phone,
    passwordHash: hashPassword(acc.password),
    isDemo: true,
    profile,
    phoneVerifiedAt: created,
    createdAt: created,
  };
  // Keep the existing password hash on re-runs (a new salt each run is pointless churn).
  const { passwordHash, ...userUpdate } = user;
  await prisma.user.upsert({ where: { id: user.id }, create: user, update: userUpdate });
  console.log(`  ${'user'.padEnd(24)} 1  (phone ${acc.phone}, password ${acc.password})`);

  const files = ['home', 'listening', 'mock', 'reading', 'resources', 'speaking', 'writing'].map((s) =>
    readJson(path.join(DEMO_DIR, `seed_${s}.json`)),
  );
  const now = Date.now();

  const attempts = files.flatMap((f) => (f.attempts ?? []) as Row[]).map(({ daysAgo, hour, refId, ...a }) => {
    let createdAt = typeof daysAgo === 'number' ? dhakaAt(-daysAgo, hour ?? 18) : new Date(a.createdAt ?? now);
    if (createdAt.getTime() > now) createdAt = new Date(now - 5 * 60 * 1000);
    return { ...a, refId: refId || null, userId: user.id, createdAt };
  });
  await upsertAll('attempt', attempts);

  const notifications = files
    .flatMap((f) => (f.notifications ?? []) as Row[])
    .map(({ daysAgo, minutesAgo, ...n }) => ({
      ...n,
      userId: user.id,
      createdAt: new Date(now - ((daysAgo ?? 0) * 1440 + (minutesAgo ?? 0)) * 60 * 1000),
    }));
  await upsertAll('notification', notifications);

  const tasks = files
    .flatMap((f) => (f.tasks ?? []) as Row[])
    .map(({ dayOffset, ...t }) => ({ ...t, userId: user.id, date: dhakaDate(dayOffset ?? 0) }));
  await upsertAll('studyTask', tasks);

  const state = files.flatMap((f) =>
    Object.entries((f.kv ?? {}) as Row).map(([key, value]) => ({ userId: user.id, key, value })),
  );
  await upsertAll('userState', state, (r) => ({ userId_key: { userId: r.userId, key: r.key } }));
}

async function main() {
  await seedContent();
  await seedBanks();
  await seedConfig();
  if (process.env.SEED_DEMO !== '0') await seedDemo();
  console.log('Seed finished.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
