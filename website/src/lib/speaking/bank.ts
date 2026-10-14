// The speaking question bank (pack bank.speaking), as the app reads it
// (lib/features/speaking/bank.dart, speaking_part13_screen.dart).

type Raw = Record<string, unknown>;
const str = (v: unknown) => (v == null ? '' : String(v));
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.map(str).filter(Boolean) : []);
const rows = (v: unknown): Raw[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Raw[]) : []);

export interface SessionQuestion {
  id: string;
  text: string;
  hint: string;
  sample: string;
}

export interface Part1Topic {
  id: string;
  topic: string;
  category: string;
  categoryLabel: string;
  questions: string[];
  samples: Array<{ q: string; answer: string }>;
}

export interface CueCard {
  id: string;
  number: number;
  category: string;
  categoryLabel: string;
  title: string;
  bullets: string[];
  sample: string;
  part3: string[];
  part3Samples: Array<{ q: string; answer: string }>;
}

export interface Part3Topic {
  id: string;
  topic: string;
  description: string;
  category: string;
  categoryLabel: string;
  questions: Array<{ q: string; answer: string; tagLabel: string }>;
}

export interface SpeakingBank {
  part1: Part1Topic[];
  cards: CueCard[];
  part3: Part3Topic[];
}

const qa = (v: unknown) => rows(v).map((x) => ({ q: str(x.q), answer: str(x.answer) }));

export function readBank(raw: Raw): SpeakingBank {
  return {
    part1: rows(raw.part1Topics).map((t) => ({
      id: str(t.id),
      topic: str(t.topic),
      category: str(t.category),
      categoryLabel: str(t.categoryLabel),
      questions: strs(t.questions),
      samples: qa(t.samples),
    })),
    cards: rows(raw.cueCards).map((c) => ({
      id: str(c.id),
      number: Number(c.number) || 0,
      category: str(c.category),
      categoryLabel: str(c.categoryLabel),
      title: str(c.title) || str(c.prompt),
      bullets: strs(c.bullets ?? c.prompts),
      sample: str((c.sample as Raw | undefined)?.answer ?? (typeof c.sample === 'string' ? c.sample : '')),
      part3: strs(c.part3),
      part3Samples: qa(c.part3Samples),
    })),
    part3: rows(raw.part3Topics).map((t) => ({
      id: str(t.id),
      topic: str(t.topic),
      description: str(t.description),
      category: str(t.category),
      categoryLabel: str(t.categoryLabel),
      questions: rows(t.questions).map((q) => ({ q: str(q.q), answer: str(q.answer), tagLabel: str(q.tagLabel) })),
    })),
  };
}

/** Questions with the app's rotating hints and the sample answer for each. */
export function withHints(id: string, questions: string[], hints: string[], samples: Array<{ q: string; answer: string }>): SessionQuestion[] {
  return questions.map((text, i) => ({
    id: `${id}_q${i + 1}`,
    text,
    hint: hints.length ? hints[i % hints.length] : '',
    sample: samples.find((x) => x.q === text)?.answer ?? '',
  }));
}

/** "Describe a person who has influenced you" → "A person who has influenced you". */
export function shortCueTitle(title: string): string {
  const t = title.replace(/^describe\s+/i, '').trim();
  return t ? t[0].toUpperCase() + t.slice(1) : title;
}
