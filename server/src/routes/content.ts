// Practice content (same for every student), returned in the same shape as
// seed/data and the app's JSON so screens can read it unchanged. Rows loaded
// from the app's banks / full tests (seed 50-71) keep the app record in
// `data`; those are returned as that record.
//
//   GET /v1/content                         manifest: every collection + count + version
//   GET /v1/content/:collection             list (filters below, ?limit=&offset=)
//   GET /v1/content/:collection/:id         one item
//   GET /v1/content/bundle?collections=a,b  several collections in one call
//   GET /v1/word-of-the-day                 today's word (Asia/Dhaka)

import { prisma } from '../db';
import { badRequest, int, notFound, Router, s } from '../lib/http';

type Row = Record<string, unknown>;

/** Drops timestamps and nulls; renames DB-only columns back to seed names. */
function clean(row: Row, rename: Record<string, string> = {}, drop: string[] = []): Row {
  const out: Row = {};
  for (const [k, v] of Object.entries(row)) {
    if (v === null || k === 'createdAt' || k === 'updatedAt' || drop.includes(k)) continue;
    out[rename[k] ?? k] = v;
  }
  return out;
}

const speakingFilters: Record<string, (v: string) => Row> = {
  source: (v) => ({ source: v }), // demo | bank | test
  category: (v) => ({ category: v }),
  test: (v) => ({ testId: v }),
};

interface Collection {
  model: string;
  /** Primary key column used by /:collection/:id. */
  key?: string;
  orderBy: Row | Row[];
  filters?: Record<string, (v: string) => Row>;
  map?: (row: Row) => Row;
}

const COLLECTIONS: Record<string, Collection> = {
  'reading-passages': {
    model: 'readingPassage',
    orderBy: [{ source: 'desc' }, { questionType: 'asc' }, { bankSet: 'asc' }, { id: 'asc' }],
    filters: {
      source: (v) => ({ source: v }), // library | bank | test
      test: (v) => ({ testId: v }),
      type: (v) => ({ questionType: v }),
      part: (v) => ({ part: int(v, 0) }),
      difficulty: (v) => ({ difficulty: v }),
    },
  },
  'reading-tests': {
    model: 'readingTest',
    orderBy: [{ kind: 'asc' }, { number: 'asc' }],
    filters: { kind: (v) => ({ kind: v }) }, // full | short | demo
    map: (r) => clean(r, { passageIds: 'passages' }),
  },
  'reading-type-lessons': { model: 'readingTypeLesson', orderBy: { id: 'asc' } },
  'listening-sets': {
    model: 'listeningSet',
    orderBy: [{ source: 'asc' }, { part: 'asc' }, { id: 'asc' }],
    filters: {
      part: (v) => ({ part: int(v, 0) }),
      source: (v) => ({ source: v }), // demo | bank | test
      test: (v) => ({ testId: v }),
    },
  },
  'listening-tests': {
    model: 'listeningTest',
    orderBy: [{ kind: 'asc' }, { number: 'asc' }],
    filters: { kind: (v) => ({ kind: v }) }, // full | demo
    map: (r) => clean(r, { setIds: 'sets' }),
  },
  'writing-prompts': {
    model: 'writingPrompt',
    orderBy: [{ task: 'asc' }, { id: 'asc' }],
    filters: {
      task: (v) => ({ task: int(v, 0) }),
      type: (v) => ({ type: v }),
      source: (v) => ({ source: v }), // demo | bank | test
      test: (v) => ({ testId: v }),
    },
  },
  'writing-tests': {
    model: 'writingTest',
    orderBy: { number: 'asc' },
    map: (r) => clean(r, { task1Id: 'task1', task2Id: 'task2' }),
  },
  'writing-sample-answers': { model: 'writingSampleAnswer', key: 'promptId', orderBy: { promptId: 'asc' } },
  'writing-templates': { model: 'writingTemplate', orderBy: { id: 'asc' } },
  'sentence-drills': {
    model: 'sentenceDrill',
    orderBy: { id: 'asc' },
    map: (r) => clean(r, { purpose: 'function' }),
  },
  'speaking-part1-topics': { model: 'speakingPart1Topic', orderBy: { id: 'asc' }, filters: speakingFilters },
  'speaking-cue-cards': { model: 'speakingCueCard', orderBy: { id: 'asc' }, filters: speakingFilters },
  'speaking-part3-sets': { model: 'speakingPart3Set', orderBy: { id: 'asc' }, filters: speakingFilters },
  'speaking-tests': {
    model: 'speakingTest',
    orderBy: { number: 'asc' },
    map: (r) => clean(r, { part1Id: 'part1', cueCardId: 'cueCard', part3Ids: 'part3' }),
  },
  'pronunciation-words': {
    model: 'pronunciationWord',
    orderBy: { id: 'asc' },
    map: (r) => clean(r, { drillSet: 'set' }),
  },
  'mock-tests': {
    model: 'mockTest',
    orderBy: [{ kind: 'asc' }, { number: 'asc' }, { letter: 'asc' }],
    filters: { kind: (v) => ({ kind: v }) }, // full | demo
    map: (r) =>
      clean(r, {
        listeningTestId: 'listeningTest',
        readingTestId: 'readingTest',
        task1Id: 'task1',
        task2Id: 'task2',
      }),
  },
  lessons: {
    model: 'lesson',
    orderBy: [{ skill: 'asc' }, { sortOrder: 'asc' }],
    filters: { skill: (v) => ({ skill: v }) },
    map: (r) => {
      const data = (r.data ?? {}) as Row;
      return { id: r.id, skill: r.skill, title: r.title, ...data };
    },
  },
  'vocab-quizzes': { model: 'vocabQuiz', orderBy: { id: 'asc' } },
  phrases: {
    model: 'phrase',
    orderBy: [{ kind: 'asc' }, { phrase: 'asc' }],
    filters: { kind: (v) => ({ kind: v }) }, // phrasal | idiom
  },
  vocabulary: {
    model: 'vocabularyWord',
    orderBy: { word: 'asc' },
    filters: { category: (v) => ({ category: v }) },
  },
  'academic-words': {
    model: 'academicWord',
    orderBy: [{ day: 'asc' }, { word: 'asc' }],
    filters: { day: (v) => ({ day: int(v, 0) }) },
  },
  'irregular-verbs': { model: 'irregularVerb', orderBy: { base: 'asc' } },
  articles: {
    model: 'article',
    orderBy: [{ series: 'asc' }, { sortOrder: 'asc' }],
    filters: { series: (v) => ({ series: v }) },
    map: (r) => clean(r, {}, ['sortOrder']),
  },
  'band-descriptors': { model: 'bandDescriptor', key: 'key', orderBy: { key: 'asc' } },
  // Guides (guide.listening …), bank notes (meta.*), lists (list.*), the speaking
  // glossary and translations (l10n.<lang>.<module>): one JSON document each.
  documents: {
    model: 'contentDocument',
    orderBy: [{ kind: 'asc' }, { sortOrder: 'asc' }],
    filters: { kind: (v) => ({ kind: v }) }, // guide | meta | list | glossary | l10n
    map: (r) => ({ id: r.id, kind: r.kind, title: r.title, data: r.data }),
  },
};

function delegate(model: string) {
  return (prisma as unknown as Record<string, Record<string, (args: unknown) => Promise<unknown>>>)[model];
}

function collectionOf(name: string): Collection {
  const c = COLLECTIONS[name];
  if (!c) throw notFound(`Unknown content collection "${name}".`);
  return c;
}

function mapRow(c: Collection, row: Row): Row {
  // Bank / full-test rows: the app's own record.
  if (c.model !== 'contentDocument' && row.data && typeof row.data === 'object' && !Array.isArray(row.data)) {
    return { id: row.id, ...(row.data as Row) };
  }
  return c.map ? c.map(row) : clean(row);
}

async function list(name: string, query: URLSearchParams, paged = true) {
  const c = collectionOf(name);
  const where: Row = {};
  for (const [key, build] of Object.entries(c.filters ?? {})) {
    const v = s(query.get(key), 100);
    if (v) Object.assign(where, build(v));
  }
  const take = paged ? int(query.get('limit'), 500, 1, 1000) : undefined;
  const skip = paged ? int(query.get('offset'), 0, 0) : undefined;
  const d = delegate(c.model);
  const [rows, total] = await Promise.all([
    d.findMany({ where, orderBy: c.orderBy, take, skip }) as Promise<Row[]>,
    d.count({ where }) as Promise<number>,
  ]);
  return { items: rows.map((r) => mapRow(c, r)), total };
}

/** Today's date in Dhaka as a UTC-midnight Date (for @db.Date columns). */
function dhakaToday(): Date {
  const d = new Date(Date.now() + 6 * 3600_000);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

export function registerContentRoutes(r: Router): void {
  r.get('/v1/content', async () => {
    const out: Array<{ name: string; count: number; version: string | null }> = [];
    for (const [name, c] of Object.entries(COLLECTIONS)) {
      const d = delegate(c.model);
      const count = (await d.count({})) as number;
      let version: string | null = null;
      try {
        const agg = (await d.aggregate({ _max: { updatedAt: true } })) as { _max?: { updatedAt?: Date | null } };
        version = agg._max?.updatedAt ? agg._max.updatedAt.toISOString() : null;
      } catch {
        version = null;
      }
      out.push({ name, count, version });
    }
    return { collections: out };
  });

  r.get('/v1/content/bundle', async (ctx) => {
    const names = s(ctx.query.get('collections'), 1000)
      .split(',')
      .map((x) => x.trim())
      .filter(Boolean);
    if (!names.length) throw badRequest('Pass ?collections=reading-passages,reading-tests,…');
    const out: Record<string, Row[]> = {};
    for (const name of names) out[name] = (await list(name, new URLSearchParams(), false)).items;
    return out;
  });

  r.get('/v1/content/:collection', async (ctx) => list(ctx.params.collection, ctx.query));

  r.get('/v1/content/:collection/:id', async (ctx) => {
    const c = collectionOf(ctx.params.collection);
    const row = (await delegate(c.model).findUnique({ where: { [c.key ?? 'id']: ctx.params.id } })) as Row | null;
    if (!row) throw notFound('Content not found.');
    return { item: mapRow(c, row) };
  });

  r.get('/v1/word-of-the-day', async () => {
    const today = dhakaToday();
    let pick = await prisma.wordOfTheDay.findFirst({
      where: { date: { lte: today } },
      orderBy: { date: 'desc' },
      include: { word: true },
    });
    if (!pick) pick = await prisma.wordOfTheDay.findFirst({ orderBy: { date: 'asc' }, include: { word: true } });
    if (pick) return { date: pick.date.toISOString().slice(0, 10), word: clean(pick.word as unknown as Row) };
    // No schedule yet: rotate through the vocabulary by day number.
    const count = await prisma.vocabularyWord.count();
    if (!count) throw notFound('No vocabulary yet.');
    const word = await prisma.vocabularyWord.findFirst({
      orderBy: { id: 'asc' },
      skip: Math.floor(today.getTime() / 86400_000) % count,
    });
    return { date: today.toISOString().slice(0, 10), word: word ? clean(word as unknown as Row) : null };
  });
}
