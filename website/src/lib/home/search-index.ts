// Everything search can find (lib/features/home/search_index.dart), built on
// the server from the content packs. Each entry is a compact tuple; the
// browser filters them as the student types.

import { articles } from '../server/articles';
import { currentLang, moduleContent } from '../server/content';
import { getPack, uiPack } from '../server/packs';
import { listeningBankSets } from '../server/practice';
import { resourcesBank } from '../server/resources';
import { speakingBank, speakingTests } from '../server/speaking';
import { writingPrompts, writingTests } from '../server/writing';
import { targetHref } from './routes';

type Raw = Record<string, unknown>;

/** [type, category, title, subtitle, href, extra searchable text] */
export type SearchEntry = [string, string, string, string, string, string];

const str = (v: unknown) => (v == null ? '' : String(v));
const rows = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.map(str).filter(Boolean) : []);
const enc = encodeURIComponent;
const cap = (t: string, n: number) => (t.length > n ? t.slice(0, n) : t);

/** Old demo index categories → the search filters. */
const LEGACY: Record<string, string> = { resources: 'lessons', drills: 'practice', essays: 'mine', vocab: 'vocab' };

const GUIDES: Array<[string, string]> = [
  ['reading', 'Reading Guide'],
  ['writing', 'Writing Guide'],
  ['speaking', 'Speaking Guide'],
  ['grammar', 'Grammar Course'],
  ['listening', 'Listening Guide'],
  ['vocab', 'Vocabulary Lessons'],
];

function blocksText(blocks: unknown): string {
  const out: string[] = [];
  const walk = (x: unknown) => {
    if (typeof x === 'string') out.push(x);
    else if (Array.isArray(x)) x.forEach(walk);
  };
  for (const b of Array.isArray(blocks) ? blocks : []) if (Array.isArray(b) && b.length && b[0] !== 'img') walk(b.slice(1));
  return out.join(' ').replace(/\*\*/g, '');
}

const bandLabel = (b: unknown) => {
  const n = Number(b);
  return n > 0 ? `Band ${Number.isInteger(n) ? n : n}` : '';
};

async function build(): Promise<SearchEntry[]> {
  const out: SearchEntry[] = [];
  const add = (type: string, category: string, title: string, subtitle: string, href: string, body = '') => {
    if (!title.trim() || !href) return;
    out.push([type, category, title, subtitle, href, body.replace(/\s+/g, ' ').trim()]);
  };
  const safe = <T>(p: Promise<T>, fb: T) => p.catch(() => fb);

  const [ui, tests, reading, listening, prompts, wTests, sBank, sTests, res, arts] = await Promise.all([
    safe(uiPack(), {} as Raw),
    safe(getPack<Raw>('bank.tests'), {} as Raw),
    safe(getPack<Raw>('bank.reading'), {} as Raw),
    safe(listeningBankSets(), [] as Raw[]),
    safe(writingPrompts(), []),
    safe(writingTests(), []),
    safe(speakingBank(), { part1: [], cards: [], part3: [] }),
    safe(speakingTests(), []),
    safe(resourcesBank(), null),
    safe(articles(), []),
  ]);

  // Hand-made entries (drills, vault, guides) from the home JSON.
  for (const it of rows((((ui.home ?? {}) as Raw).search as Raw | undefined)?.index)) {
    const cat = str(it.category);
    add(str(it.type), LEGACY[cat] ?? cat, str(it.title), str(it.subtitle), targetHref(str(it.target)), str(it.keywords));
  }

  // Reading
  for (const t of rows(((tests.reading ?? {}) as Raw).tests)) {
    add('Reading', 'practice', str(t.title), 'Reading · full test · 3 passages · 60 min', `/app/reading/do/${enc(str(t.id))}`, 'reading full test');
  }
  for (const t of wTests) {
    add('Writing', 'practice', t.title, 'Writing · full test · Task 1 + Task 2 · 60 min', '/app/writing/tests', `writing full test ${t.task1?.title ?? ''} ${t.task2?.title ?? ''} ${cap(t.task2?.prompt ?? '', 300)}`);
  }
  for (const t of sTests) {
    add('Speaking', 'practice', t.title, 'Speaking · full test · Parts 1–3', '/app/speaking/tests', `speaking full test ${t.part1?.topic ?? ''} ${t.card?.title ?? ''}`);
  }
  for (const t of rows(reading.tests)) {
    add('Reading', 'practice', str(t.title), `Reading · short practice test · ${str(t.questionCount)} questions`, `/app/reading/do/${enc(str(t.id))}`, `reading practice test ${strs(t.questionTypes).join(' ')}`);
  }
  for (const p of rows(reading.passages)) {
    add(
      'Reading',
      'practice',
      str(p.title),
      `Reading · ${str(p.questionTypeName)} · Set ${str(p.bankSet)} · ${str(p.difficulty)}`,
      `/app/reading/do/${enc(str(p.id))}`,
      `reading ${str(p.topic)} ${str((p.lesson as Raw | undefined)?.title)}`,
    );
  }
  for (const l of rows(reading.lessons)) {
    add(
      'Lesson',
      'lessons',
      str(l.title),
      `Reading · ${str(l.name)} lesson`,
      `/app/reading/type/${enc(str(l.questionType) || str(l.id).replace(/^rtl_/, ''))}`,
      cap(rows(l.sections).map((s) => `${str(s.heading)} ${str(s.text)}`).join(' '), 600),
    );
  }

  // Listening
  for (const st of listening) {
    const fmt = str(st.formatLabel);
    add('Listening', 'practice', str(st.title), `Listening · Part ${str(st.part)}${fmt ? ` · ${fmt}` : ''}`, `/app/listening/set/${enc(str(st.id))}`, `listening ${str(st.listeningContext ?? st.context)} ${cap(str(st.scenario), 200)}`);
  }

  // Writing
  for (const w of prompts) {
    const task = w.task;
    add(
      'Writing',
      'practice',
      w.title,
      `Writing Task ${task} · ${w.typeName || w.type}${task === 2 && w.topic ? ` · ${w.topic}` : ''}`,
      `/app/writing/write/${enc(w.id)}`,
      `writing task ${task} ${task === 1 ? 'chart' : 'essay'} ${cap(w.prompt, 300)}`,
    );
    if (w.samples.length) {
      add('Sample', 'lessons', `${w.title} - sample answers`, `Writing Task ${task} · Band 6, 7 and 8 ${task === 1 ? 'answers' : 'essays'}`, `/app/writing/samples/${enc(w.id)}`, `model answer ${cap(w.prompt, 200)}`);
    }
  }

  // Speaking
  for (const c of sBank.cards) {
    add('Speaking', 'practice', c.title, `Speaking Part 2 · cue card · ${c.categoryLabel}`, `/app/speaking/cue/${enc(c.id)}`, `speaking part 2 cue card ${c.bullets.join(' ')}`);
  }
  for (const t of sBank.part1) {
    add('Speaking', 'practice', t.topic, `Speaking Part 1 · ${t.questions.length} questions`, `/app/speaking/session/1/${enc(t.id)}`, `speaking part 1 ${cap(t.questions.join(' '), 400)}`);
  }
  for (const t of sBank.part3) {
    add('Speaking', 'practice', t.topic, 'Speaking Part 3 · discussion', `/app/speaking/session/3/${enc(t.id)}`, `speaking part 3 discussion ${t.description} ${cap(t.questions.map((q) => q.q).join(' '), 400)}`);
  }

  // Resources bank words (open on the words page).
  if (res) {
    const word = (tab: string, w: string) => `/app/resources/words?tab=${tab}&q=${enc(w)}`;
    const seen = new Set<string>();
    for (const v of res.vocab) {
      const head = str(v.word);
      if (seen.has(head.toLowerCase())) continue;
      seen.add(head.toLowerCase());
      const band = bandLabel(v.band);
      add('Vocab', 'vocab', head, `${str(v.pos)}${band ? ` · ${band}` : ''} · ${str(v.definition)}`, word('vocab', head), strs(v.synonyms).join(' '));
    }
    for (const p of res.phrasalVerbs) add('Phrasal verb', 'vocab', str(p.phrase), `phrasal verb · ${str(p.meaning)}`, word('phrasal', str(p.phrase)));
    for (const p of res.idioms) add('Idiom', 'vocab', str(p.phrase), `idiom · ${str(p.meaning)}`, word('idioms', str(p.phrase)));
    for (const g of res.connectors) {
      for (const c of rows(g.items)) add('Linking word', 'vocab', str(c.word), `linking word · ${str(c.use)}`, word('connectors', str(c.word)), str(g.title));
    }
    for (const a of res.academicWords) add('Academic word', 'vocab', str(a.word), `${str(a.pos)} · ${str(a.definition)}`, word('academic', str(a.word)), strs(a.family).join(' '));
    for (const tp of res.topics) {
      for (const x of rows(tp.items)) add('Topic vocab', 'vocab', str(x.term), `topic term · ${str(x.meaning)}`, word('topics', str(x.term)), str(tp.title));
    }
    for (const v of res.irregularVerbs) {
      add('Irregular verb', 'vocab', `${str(v.base)} – ${str(v.past)} – ${str(v.participle)}`, str(v.meaning), word('irregular', str(v.base)), 'irregular verb');
    }
  }

  // Guides (in the explanation language) and tips.
  const guides = await Promise.all(GUIDES.map(([m]) => moduleContent(m, { course: false }).catch(() => null)));
  GUIDES.forEach(([m, name], gi) => {
    const mc = guides[gi];
    if (!mc) return;
    mc.guide.chapters.forEach((ch, i) => {
      const en = mc.chapter(ch.id);
      add('Guide', 'lessons', ch.title, `${name} · chapter ${i + 1}`, `/app/guides/${m}/${enc(ch.id)}`, cap(`${en?.title ?? ''} ${blocksText(ch.blocks)}`, 1500));
    });
  });
  for (const a of arts) {
    const series = a.series ? `${a.series[0].toUpperCase()}${a.series.slice(1)} ` : '';
    add('Tips', 'lessons', a.title, `${series}tips · ${a.chip}`, `/app/resources/article/${enc(a.id)}`, cap(a.tips.map((t) => `${t.title} ${t.body}`).join(' '), 1200));
  }
  return out;
}

const cache = new Map<string, { at: number; items: SearchEntry[] }>();
const TTL = 10 * 60_000;

/** The search index for the student's explanation language (cached 10 min). */
export async function searchIndex(): Promise<SearchEntry[]> {
  const lang = (await currentLang()).code;
  const hit = cache.get(lang);
  if (hit && Date.now() - hit.at < TTL) return hit.items;
  const items = await build();
  cache.set(lang, { at: Date.now(), items });
  return items;
}
