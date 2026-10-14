// Study content in the student's explanation language: courses (lessons),
// study guides and their translations, resolved on the server the way the
// app's Lessons / ContentL10n do (lib/app/data/lessons.dart, l10n.dart).

import { contentLang, LANG_KEY, type ContentLang } from '../content/lang';
import { stateValue } from './attempts';
import { getPack } from './packs';

type Raw = Record<string, unknown>;
export type Block = unknown[];

export interface Chapter {
  id: string;
  title: string;
  group?: string;
  blocks: Block[];
}

export interface Guide {
  title: string;
  subtitle: string;
  chapters: Chapter[];
}

/** The saved explanation language. */
export async function currentLang(): Promise<ContentLang> {
  return contentLang(await stateValue<string>(LANG_KEY));
}

/** Languages with [module] content (English first). */
export async function availableLangs(module: string): Promise<string[]> {
  try {
    const idx = await getPack<Record<string, string[]>>('l10n.index');
    return ['en', ...(idx[module] ?? [])];
  } catch {
    return ['en'];
  }
}

async function translation(lang: string, module: string): Promise<Raw> {
  if (lang === 'en') return {};
  if (!(await availableLangs(module)).includes(lang)) return {};
  try {
    return await getPack<Raw>(`l10n.${lang}.${module}`);
  } catch {
    return {};
  }
}

const asList = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);
const s = (v: unknown) => (typeof v === 'string' ? v : v == null ? '' : String(v));

/** Drops the guide's own numbering ("2. …", "২. …"). */
function unnumber(t: string, heading = false): string {
  let out = t.trim().replace(/^[0-9০-৯०-९٠-٩]+(\.[0-9০-৯०-९٠-٩]+)*[.।]\s+/, '');
  if (heading) out = out.replace(/^[0-9০-৯०-९٠-٩]+([.][0-9০-৯०-९٠-٩]+)*[.।]?\s+/, '');
  return out.trim();
}

/** A module's content in one language: text helpers bound to it. */
export interface ModuleContent {
  module: string;
  lang: ContentLang;
  langs: string[];
  guide: Guide;
  course: Raw;
  /** Chapter in the current language (English blocks when the layout differs). */
  chapter(id: string): Chapter | null;
  /** lessonText(): plain string · {en, bn …} · {ref:[chapter, block]} · {chapterTitle}. */
  text(v: unknown): string;
  blocks(chapter: string, from: number, to: number): Block[];
}

export async function moduleContent(module: string, opts: { course?: boolean } = {}): Promise<ModuleContent> {
  const [lang, langs, guideRaw, course] = await Promise.all([
    currentLang(),
    availableLangs(module),
    getPack<Raw>(`guide.${module}`).catch(() => ({}) as Raw),
    opts.course === false ? Promise.resolve({} as Raw) : getPack<Raw>(`course.${module}`).catch(() => ({}) as Raw),
  ]);
  const tr = langs.includes(lang.code) ? await translation(lang.code, module) : {};
  const trGuide = (tr.guide ?? {}) as Record<string, Raw>;
  const chapters: Chapter[] = asList(guideRaw.chapters).map((c) => ({
    id: s(c.id),
    title: s(c.title),
    group: s(c.group) || undefined,
    blocks: Array.isArray(c.blocks) ? (c.blocks as Block[]) : [],
  }));
  const byId = new Map(chapters.map((c) => [c.id, c]));
  const localized = (en: Chapter): Chapter => {
    const t = trGuide[en.id];
    if (!t || !Array.isArray(t.blocks) || t.blocks.length !== en.blocks.length) return en;
    return { ...en, title: s(t.title) || en.title, group: s(t.group) || en.group, blocks: t.blocks as Block[] };
  };
  // Lessons carry their own translations; guide text needs the l10n pack.
  const code = lang.code;
  const text = (v: unknown): string => {
    if (v == null) return '';
    if (typeof v === 'string') return v;
    if (typeof v !== 'object' || Array.isArray(v)) return String(v);
    const m = v as Raw;
    let out = '';
    if (code !== 'en') {
      const direct = m[code];
      if (typeof direct === 'string' && direct) out = direct;
      else if (Array.isArray(m.ref) && m.ref.length === 2) {
        const ch = byId.get(s(m.ref[0]));
        const idx = Number(m.ref[1]);
        if (ch && Number.isFinite(idx)) {
          const b = localized(ch).blocks[idx];
          if (Array.isArray(b) && typeof b[1] === 'string') out = unnumber(b[1], true);
        }
      } else if (typeof m.chapterTitle === 'string') {
        const ch = byId.get(m.chapterTitle);
        if (ch) out = unnumber(localized(ch).title);
      }
    }
    if (!out) out = s(m.en);
    const part = Number(m.part);
    if (part > 1) out = `${out} · Part ${part}`;
    return out;
  };
  return {
    module,
    lang,
    langs,
    guide: { title: s(guideRaw.title), subtitle: s(guideRaw.subtitle), chapters: chapters.map(localized) },
    course,
    chapter: (id) => {
      const c = byId.get(id);
      return c ? localized(c) : null;
    },
    text,
    blocks: (chapter, from, to) => {
      const c = byId.get(chapter);
      if (!c) return [];
      const blocks = localized(c).blocks;
      const end = Math.max(0, Math.min(to, blocks.length));
      const start = Math.max(0, Math.min(from, end));
      return blocks.slice(start, end).filter((b) => Array.isArray(b) && b.length > 0);
    },
  };
}

/**
 * The current explanation language's translation pack of [module] (`{}` for
 * English or when there is none), for content that carries its own l10n
 * shape (reading skill lessons, "How to attempt …" type lessons).
 */
export async function moduleTranslation(module: string): Promise<{ lang: ContentLang; langs: string[]; tr: Raw }> {
  const [lang, langs] = await Promise.all([currentLang(), availableLangs(module)]);
  const tr = langs.includes(lang.code) ? await translation(lang.code, module) : {};
  return { lang, langs, tr };
}
