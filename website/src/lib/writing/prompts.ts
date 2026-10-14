// Writing prompts from the writing question bank pack (bank.writing), shaped
// like the app's WritingContent._normalize (lib/features/writing/writing_data.dart).

export const TASK1_TYPES: Record<string, string> = {
  line: 'Line graph',
  bar: 'Bar chart',
  pie: 'Pie chart',
  table: 'Table',
  process: 'Process diagram',
  map: 'Map / plan',
  mixed: 'Combination',
};
export const TASK2_TYPES: Record<string, string> = {
  opinion: 'Opinion',
  discussion: 'Discussion',
  advantages: 'Advantages & disadvantages',
  problem: 'Problem–solution',
  'two-part': 'Two-part question',
  'positive-negative': 'Positive / negative development',
};

export function typeName(task: 1 | 2, type: string): string {
  const n = (task === 1 ? TASK1_TYPES : TASK2_TYPES)[type];
  if (n) return n;
  if (!type) return task === 1 ? 'Report' : 'Essay';
  return type[0].toUpperCase() + type.slice(1);
}

export interface Sample {
  band: number;
  label?: string;
  words?: number;
  text?: string;
  why?: string | string[];
}

export interface Prompt {
  id: string;
  task: 1 | 2;
  number: number;
  type: string;
  typeName: string;
  title: string;
  shortTitle: string;
  topic: string;
  difficulty: string;
  prompt: string;
  statement: string;
  minWords: number;
  timeSeconds: number;
  image: string;
  dataText: string;
  samples: Sample[];
  modelAnswer: string;
  modelBand: number;
}

type Raw = Record<string, unknown>;
const str = (v: unknown) => (v == null ? '' : String(v));
const num = (v: unknown) => (typeof v === 'number' ? v : Number(v) || 0);

export function normalize(raw: Raw, task: 1 | 2): Prompt {
  const type = str(raw.type);
  const name = typeName(task, type);
  const title = str(raw.title) || name;
  const minWords = num(raw.minWords) > 0 ? num(raw.minWords) : task === 1 ? 150 : 250;
  const model = raw.modelAnswer;
  let modelAnswer = '';
  let modelBand = 0;
  if (model && typeof model === 'object') {
    modelAnswer = str((model as Raw).text);
    modelBand = num((model as Raw).band);
  } else if (typeof model === 'string') {
    modelAnswer = model;
  }
  if (modelAnswer.trim() && modelBand <= 0) modelBand = 8;
  return {
    id: str(raw.id),
    task,
    number: num(raw.number),
    type,
    typeName: name,
    title,
    shortTitle: task === 1 ? `${title}, ${name.toLowerCase()}` : title,
    topic: str(raw.topic),
    difficulty: str(raw.difficulty),
    prompt: str(raw.prompt),
    statement: str(raw.statement) || str(raw.question),
    minWords,
    timeSeconds: task === 1 ? 1200 : 2400,
    image: str(raw.image),
    dataText: str(raw.dataText),
    samples: Array.isArray(raw.samples) ? (raw.samples as Sample[]) : [],
    modelAnswer: modelAnswer.trim(),
    modelBand,
  };
}

/** All practice prompts of the bank, in bank order. */
export function bankPrompts(bank: Raw): Prompt[] {
  const t1 = Array.isArray(bank.task1) ? (bank.task1 as Raw[]) : [];
  const t2 = Array.isArray(bank.task2) ? (bank.task2 as Raw[]) : [];
  return [
    ...t1.filter((p) => str(p.id)).map((p) => normalize(p, 1)),
    ...t2.filter((p) => str(p.id)).map((p) => normalize(p, 2)),
  ];
}
