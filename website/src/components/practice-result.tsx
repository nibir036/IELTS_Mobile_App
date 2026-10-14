import Link from 'next/link';
import {
  correctLabel,
  listeningItems,
  readingItems,
  rows,
  str,
  type Item,
  type Raw,
} from '@/lib/practice/marking';
import type { Attempt } from '@/lib/server/attempts';
import { formatBand } from '@/lib/writing/analysis';
import { Card, HeroCard, Icon, Nexi, PrimaryButton, SectionTitle, SoftButton } from './ui';
import r from '@/app/app/writing/result/[id]/result.module.css';
import s from './practice.module.css';

function offsetsOf(parts: Raw[], listening: boolean): number[] {
  const out: number[] = [];
  let off = 0;
  for (const p of parts) {
    out.push(off);
    for (const g of rows(p.groups)) {
      for (const q of rows(g.questions)) {
        const pick = Number(g.pick) || 0;
        const nums = q.numbers;
        off += listening ? (pick > 1 ? pick : 1) : Array.isArray(nums) && nums.length > 1 ? nums.length : 1;
      }
    }
  }
  return out;
}

/** Score, band, answer key (+ evidence / transcript) for a Listening or Reading attempt. */
export function PracticeResult({ a, parts, retry, hub }: { a: Attempt; parts: Raw[]; retry: string; hub: string }) {
  const listening = a.skill === 'listening';
  const offs = offsetsOf(parts, listening);
  const items: Item[] = listening ? parts.flatMap((p, i) => listeningItems(p, offs[i], i)) : readingItems(parts.map((p, i) => [p, offs[i]] as [Raw, number]));
  const answers = (a.data.answers ?? {}) as Record<string, string>;
  const correct = new Set(((a.data.correct ?? []) as number[]).map(Number));
  const score = a.score ?? correct.size;
  const total = a.total ?? items.length;
  const date = new Date(a.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Dhaka' });
  const pct = total ? Math.round((score / total) * 100) : 0;

  return (
    <>
      <div className={r.top}>
        <Link href={hub} className={r.back} aria-label="Back">
          <Icon name="arrow_back" size={20} />
        </Link>
        <h1 className={r.h1}>{listening ? 'Listening' : 'Reading'} results</h1>
      </div>

      <HeroCard>
        <div className={r.hero}>
          <div className={r.heroText}>
            <span className={r.heroLabel}>Estimated band</span>
            <span className={r.band}>{formatBand(a.band)}</span>
            <span className={r.heroMeta}>
              {score} / {total} correct ({pct}%) · {a.title} · {date}
            </span>
          </div>
          <Nexi pose={(a.band ?? 0) >= 7 ? 'thumbs' : listening ? 'listening' : 'reading'} height={120} />
        </div>
      </HeroCard>

      {parts.length > 1 && (
        <div className={r.criteria}>
          {parts.map((p, i) => {
            const mine = items.filter((it) => it.part === i);
            const ok = mine.filter((it) => correct.has(it.number)).length;
            return (
              <Card key={i} padding={16}>
                <div className={r.critHead}>
                  <span className={r.critName}>
                    {listening ? `Part ${Number(p.part) || i + 1}` : `Passage ${i + 1}`} · {str(p.title)}
                  </span>
                  <span className={r.critBand}>
                    {ok}/{mine.length}
                  </span>
                </div>
                <div className={r.track}>
                  <span style={{ width: `${Math.max(4, (ok / Math.max(1, mine.length)) * 100)}%` }} />
                </div>
              </Card>
            );
          })}
        </div>
      )}

      <Card padding={18}>
        <SectionTitle>Answer key</SectionTitle>
        <div className={s.keyTable}>
          {items.map((it) => {
            const ok = correct.has(it.number);
            const why = str(it.q.explanation);
            const ev = str(it.q.evidence);
            return (
              <div key={it.number} className={s.keyRow}>
                <span className={`${s.keyNum} ${ok ? s.keyOk : s.keyBad}`}>{it.number}</span>
                <div className={s.grow}>
                  <p className={s.keyQ}>{str(it.q.text) || str(it.q.label) || (it.q.paragraph ? `Paragraph ${str(it.q.paragraph)}` : '')}</p>
                  <p className={s.keyA}>
                    Your answer: <b>{answers[String(it.number)] || '–'}</b>
                    {!ok && (
                      <>
                        {' '}
                        · Correct: <b className={s.keyRight}>{correctLabel(it)}</b>
                      </>
                    )}
                  </p>
                  {!listening && (ev || why) && (
                    <p className={s.keyWhy}>
                      {ev && (
                        <>
                          {it.q.evidenceParagraph ? `Paragraph ${str(it.q.evidenceParagraph)}: ` : ''}&ldquo;{ev}&rdquo;{' '}
                        </>
                      )}
                      {why}
                    </p>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </Card>

      {listening &&
        parts.map((p, i) =>
          rows(p.transcript).length ? (
            <Card key={`t${i}`} padding={18}>
              <SectionTitle>Transcript · {parts.length > 1 ? `Part ${Number(p.part) || i + 1}` : str(p.title)}</SectionTitle>
              <div className={s.transcript}>
                {rows(p.transcript).map((line, j) => (
                  <p key={j}>
                    {line.speaker ? <b>{str(line.speaker)}: </b> : null}
                    {str(line.text)}
                  </p>
                ))}
              </div>
            </Card>
          ) : null,
        )}

      <div className={r.actions}>
        <SoftButton href={hub}>Back to {listening ? 'Listening' : 'Reading'}</SoftButton>
        <PrimaryButton href={retry} leading="replay">
          Try again
        </PrimaryButton>
      </div>
    </>
  );
}
