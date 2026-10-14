import { rows, str, strs, type Raw } from '../practice/marking';
import { normalize, type Prompt } from '../writing/prompts';
import { getPack } from './packs';

export interface MockData {
  id: string;
  number: number;
  title: string;
  listening: Raw[];
  reading: Raw[];
  task1: Prompt | null;
  task2: Prompt | null;
  part1: { id: string; topic: string; questions: string[]; intro: string };
  cue: { id: string; title: string; bullets: string[]; part3: string[] };
}

export async function mockList(): Promise<Raw[]> {
  return rows(((await getPack<Raw>('bank.tests')).mock as Raw | undefined)?.tests);
}

/** Everything one Full Mock Test needs (mock_session.dart). */
export async function mockData(id: string): Promise<MockData | null> {
  const t = await getPack<Raw>('bank.tests');
  const m = rows((t.mock as Raw | undefined)?.tests).find((x) => str(x.id) === id);
  if (!m) return null;
  const L = (t.listening ?? {}) as Raw;
  const R = (t.reading ?? {}) as Raw;
  const W = (t.writing ?? {}) as Raw;
  const S = (t.speaking ?? {}) as Raw;
  const lt = rows(L.tests).find((x) => str(x.id) === str(m.listeningTest));
  const rt = rows(R.tests).find((x) => str(x.id) === str(m.readingTest));
  const listening = strs(lt?.sets).map((sid) => rows(L.sets).find((s) => str(s.id) === sid)).filter((x): x is Raw => Boolean(x));
  const reading = strs(rt?.passages).map((pid) => rows(R.passages).find((p) => str(p.id) === pid)).filter((x): x is Raw => Boolean(x));
  const prompt = (pid: string, task: 1 | 2) => {
    const p = rows(W.prompts).find((x) => str(x.id) === pid);
    return p ? normalize(p, task) : null;
  };
  const sp = (m.speaking ?? {}) as Raw;
  const p1 = rows(S.part1Topics).find((x) => str(x.id) === str(sp.part1)) ?? {};
  const cc = rows(S.cueCards).find((x) => str(x.id) === str(sp.cueCard)) ?? {};
  return {
    id,
    number: Number(m.number) || 0,
    title: str(m.title),
    listening,
    reading,
    task1: prompt(str(m.task1), 1),
    task2: prompt(str(m.task2), 2),
    part1: { id: str(p1.id), topic: str(p1.topic), questions: strs(p1.questions), intro: str(p1.examinerIntro) },
    cue: { id: str(cc.id), title: str(cc.title || cc.prompt), bullets: strs(cc.bullets), part3: strs(cc.part3) },
  };
}

export { overallBand } from '../practice/overall';
