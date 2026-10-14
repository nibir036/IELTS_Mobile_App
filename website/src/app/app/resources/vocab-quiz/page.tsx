import type { Metadata } from 'next';
import { str } from '@/lib/practice/marking';
import { resourcesBank } from '@/lib/server/resources';
import { VocabQuiz, type QuizQuestion } from './quiz';

export const metadata: Metadata = { title: 'Vocabulary Quiz' };
export const dynamic = 'force-dynamic';

const LEVELS: Record<string, [number, number, string]> = {
  core: [0, 7, 'Core words · band 6–7'],
  upper: [7.5, 8, 'Upper words · band 7.5–8'],
  top: [8.5, 9, 'Top words · band 8.5–9'],
};

function shuffle<T>(a: T[]): T[] {
  const b = [...a];
  for (let i = b.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [b[i], b[j]] = [b[j], b[i]];
  }
  return b;
}

/** A round of 10: pick the meaning of each word (vocab_quiz_screen.dart). */
export default async function Quiz({ searchParams }: { searchParams: Promise<{ level?: string }> }) {
  const { level = 'core' } = await searchParams;
  const [lo, hi, label] = LEVELS[level] ?? LEVELS.core;
  const { vocab } = await resourcesBank();
  const pool = vocab.filter((v) => {
    const b = Number(v.band) || 0;
    return b >= lo && b <= hi && str(v.definition);
  });
  const picked = shuffle(pool).slice(0, 10);
  const questions: QuizQuestion[] = picked.map((v) => {
    const same = vocab.filter((o) => str(o.pos) === str(v.pos) && o.id !== v.id && str(o.definition));
    const wrong = shuffle(same.length >= 6 ? same : vocab.filter((o) => o.id !== v.id)).slice(0, 3).map((o) => str(o.definition));
    const answer = str(v.definition);
    return {
      id: str(v.id),
      word: str(v.word),
      pos: str(v.pos),
      ipa: str(v.ipa),
      example: (Array.isArray(v.examples) ? str(v.examples[0]) : '').replace(/\*\*/g, ''),
      options: shuffle([answer, ...wrong]),
      answer,
    };
  });
  return <VocabQuiz questions={questions} level={level} label={label} levels={Object.entries(LEVELS).map(([k, v]) => [k, v[2]])} />;
}
