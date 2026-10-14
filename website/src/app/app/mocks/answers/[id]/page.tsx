import type { Metadata } from 'next';
import Link from 'next/link';
import { MockAnswers, MockAnswersEmpty, type SpeakingPartView, type WritingTaskView } from '@/components/extras/mock-answers';
import { Icon } from '@/components/ui';
import { clock, weekdayDate, dhakaDay, wordCount } from '@/lib/extras/format';
import { answersOf, objectiveView, withOffsets } from '@/lib/extras/mock-review';
import { mockAttempt, mockComposition } from '@/lib/extras/mock-server';
import { str, strs, type Raw } from '@/lib/practice/marking';
import x from '@/components/extras/extras.module.css';

export const metadata: Metadata = { title: 'Mock answer review' };

const TAB: Record<string, number> = { listening: 0, reading: 1, writing: 2, speaking: 3 };
const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {});
const numOrNull = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const crit = (v: unknown, keys: string[]): Record<string, number | null> => {
  const m = obj(v);
  if (!Object.keys(m).length) return {};
  return Object.fromEntries(keys.map((k) => [k, numOrNull(m[k])]));
};

/** G12 · Mock answer review for one mock attempt (mock_answers_screen.dart). `?tab=listening|reading|writing|speaking`. */
export default async function MockAnswersPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ tab?: string }> }) {
  const [{ id }, { tab }] = await Promise.all([params, searchParams]);
  const a = await mockAttempt(id);
  const back = a ? `/app/mocks/result/${encodeURIComponent(a.id)}` : '/app/mocks';
  const top = (sub: string) => (
    <div className={x.top}>
      <Link href={back} className={x.iconBtn} aria-label="Back to the score report">
        <Icon name="arrow_back" size={20} />
      </Link>
      <div className={x.topText}>
        <h1 className={x.topTitle}>Answer review</h1>
        {sub && <span className={x.topSub}>{sub}</span>}
      </div>
      <span className={x.spacer} />
    </div>
  );
  if (!a) {
    return (
      <div className={x.page}>
        {top('')}
        <MockAnswersEmpty />
      </div>
    );
  }

  const d = a.data;
  const { mock, cue } = await mockComposition(a);
  const sections = obj(d.sections);
  const listening = objectiveView(true, withOffsets(mock?.listening ?? [], true), answersOf(d, 'listening'), d);
  const reading = objectiveView(false, withOffsets(mock?.reading ?? [], false), answersOf(d, 'reading'), d);

  const w = obj(d.writing);
  const tasks: WritingTaskView[] = ([1, 2] as const).map((t) => {
    const p = t === 1 ? mock?.task1 : mock?.task2;
    const essay = str(w[`task${t}`]).trim();
    const tb = numOrNull(w[`task${t}Band`]);
    return {
      task: t,
      title: p?.title ?? '',
      prompt: p?.prompt ?? '',
      band: tb !== null && tb > 0 ? tb : null,
      words: essay ? wordCount(essay) : Number(w[`task${t}Words`]) || 0,
      essay,
      criteria: crit(w[`task${t}Criteria`], ['TA', 'CC', 'LR', 'GRA']),
      summary: str(w[`task${t}Summary`]).trim(),
      modelHref: p && (p.modelAnswer || p.samples.length) ? `/app/writing/samples/${encodeURIComponent(p.id)}` : null,
    };
  });

  const sp = obj(d.speaking);
  const keys = obj(sp.recordingKeys);
  const recs = obj(sp.recordings);
  const tx = obj(sp.transcripts);
  const secs = obj(d.speakingSec);
  let spoken = Number(d.spokenSec) || 0;
  if (!spoken) spoken = Object.values(secs).reduce<number>((s, v) => s + (Number(v) || 0), 0);
  const part = (n: 1 | 2 | 3, title: string, subtitle: string, questions: string[], bullets: string[] = []): SpeakingPartView => {
    const sec = Number(secs[n]) || 0;
    return {
      part: n,
      title,
      sub: [subtitle, sec > 0 ? `spoke ${clock(sec)}` : ''].filter(Boolean).join(' · '),
      questions,
      bullets,
      transcript: str(tx[n]).trim(),
      recordingKey: str(keys[n]),
      onPhone: Boolean(str(obj(recs[n]).path)),
    };
  };
  const parts: SpeakingPartView[] = [
    part(1, 'Part 1 · Introduction', mock?.part1.topic ?? '', mock?.part1.questions ?? []),
    part(2, 'Part 2 · Long turn', str(cue.title) || mock?.cue.title || '', str(cue.prompt) ? [str(cue.prompt)] : [], mock?.cue.bullets ?? strs(cue.bullets)),
    part(3, 'Part 3 · Discussion', str(cue.topic), mock?.cue.part3 ?? strs(cue.part3)),
  ];

  const sub = [a.title, mock?.title, weekdayDate(dhakaDay(a.createdAt))].filter(Boolean).join(' · ');
  return (
    <div className={x.page}>
      {top(sub)}
      <MockAnswers
        initialTab={TAB[tab ?? ''] ?? 0}
        listening={listening}
        reading={reading}
        writing={{ band: numOrNull(sections.writing), criteria: crit(d.writingCriteria, ['TA', 'CC', 'LR', 'GRA']), tasks }}
        speaking={{
          band: numOrNull(sections.speaking),
          criteria: crit(d.speakingCriteria, ['FC', 'LR', 'GRA', 'P']),
          summary: str(d.speakingSummary).trim(),
          spoken: spoken > 0 ? clock(spoken) : '',
          parts,
        }}
      />
    </div>
  );
}
