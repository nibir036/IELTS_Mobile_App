import { normalize, bankPrompts, type Prompt } from '../writing/prompts';
import { getPack, uiPack } from './packs';

type Raw = Record<string, unknown>;

/** The writing question bank (pack bank.writing) as prompts. */
export async function writingPrompts(task?: 1 | 2): Promise<Prompt[]> {
  const all = bankPrompts(await getPack<Raw>('bank.writing'));
  return task ? all.filter((p) => p.task === task) : all;
}

/** The full Writing Tests' own prompts (pack bank.tests → writing.prompts). */
async function testPrompts(): Promise<Prompt[]> {
  const t = await getPack<Raw>('bank.tests').catch(() => ({}) as Raw);
  const list = ((t.writing ?? {}) as Raw).prompts;
  return Array.isArray(list) ? (list as Raw[]).map((p) => normalize(p, Number(p.task) === 1 ? 1 : 2)) : [];
}

/** The original demo prompts (UI pack content.writing): older essays and the ideas library. */
async function legacyRaw(): Promise<Raw[]> {
  const ui = await uiPack().catch(() => ({}) as Raw);
  const w = (((ui.content ?? {}) as Raw).writing ?? {}) as Raw;
  return [...(Array.isArray(w.task1) ? (w.task1 as Raw[]).map((p) => ({ ...p, task: 1 })) : []), ...(Array.isArray(w.task2) ? (w.task2 as Raw[]).map((p) => ({ ...p, task: 2 })) : [])];
}

/** Any prompt by id: the bank, then the full tests, then the demo prompts (Content.writingPrompt). */
export async function writingPrompt(id: string): Promise<Prompt | null> {
  const hit = (await writingPrompts()).find((p) => p.id === id) ?? (await testPrompts()).find((p) => p.id === id);
  if (hit) return hit;
  const raw = (await legacyRaw()).find((p) => String(p.id) === id);
  return raw ? normalize(raw, Number(raw.task) === 1 ? 1 : 2) : null;
}

export interface IdeaPrompt {
  id: string;
  title: string;
  prompt: string;
  topic: string;
  typeName: string;
  hasModel: boolean;
  ideas: { for: string[]; against: string[]; vocabulary: string[] };
}

/** Task 2 prompts that come with ideas (for / against / vocabulary), for the ideas library. */
export async function ideaPrompts(): Promise<IdeaPrompt[]> {
  const [bank, legacy] = await Promise.all([getPack<Raw>('bank.writing').catch(() => ({}) as Raw), legacyRaw()]);
  const raw: Raw[] = [...(Array.isArray(bank.task2) ? (bank.task2 as Raw[]).map((p) => ({ ...p, task: 2 })) : []), ...legacy];
  const list = (v: unknown) => (Array.isArray(v) ? v.map(String) : []);
  return raw
    .filter((p) => Number(p.task) === 2 && p.ideas && typeof p.ideas === 'object' && Object.keys(p.ideas as Raw).length)
    .map((p) => {
      const n = normalize(p, 2);
      const ideas = p.ideas as Raw;
      return {
        id: n.id,
        title: n.title,
        prompt: n.prompt,
        topic: n.topic || String(p.topic ?? ''),
        typeName: n.typeName,
        hasModel: Boolean(n.modelAnswer),
        ideas: { for: list(ideas.for), against: list(ideas.against), vocabulary: list(ideas.vocabulary) },
      };
    });
}

export interface WritingTest {
  id: string;
  number: number;
  title: string;
  task1: Prompt | null;
  task2: Prompt | null;
}

/** Writing Test 1–10 (tests_bank.json). */
export async function writingTests(): Promise<WritingTest[]> {
  const [t, prompts] = await Promise.all([getPack<Raw>('bank.tests').catch(() => ({}) as Raw), testPrompts()]);
  const tests = ((t.writing ?? {}) as Raw).tests;
  const bank = await writingPrompts();
  const find = (id: unknown) => prompts.find((p) => p.id === String(id)) ?? bank.find((p) => p.id === String(id)) ?? null;
  return (Array.isArray(tests) ? (tests as Raw[]) : []).map((x) => ({
    id: String(x.id),
    number: Number(x.number) || 0,
    title: String(x.title ?? ''),
    task1: find(x.task1),
    task2: find(x.task2),
  }));
}
