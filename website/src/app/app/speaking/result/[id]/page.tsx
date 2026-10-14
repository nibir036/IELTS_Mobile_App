import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { RecordingPlayer } from '@/components/recording-player';
import { Card, HeroCard, Icon, Nexi, PrimaryButton, SectionTitle } from '@/components/ui';
import { attempt } from '@/lib/server/attempts';
import { buildParagraphs, errorsOf, type Paragraph } from '@/lib/speaking/transcript';
import { formatBand } from '@/lib/writing/analysis';
import r from '../../../writing/result/[id]/result.module.css';
import s from '../../speaking.module.css';

export const metadata: Metadata = { title: 'Speaking evaluation' };

type Row = Record<string, unknown>;
const str = (v: unknown) => (v == null ? '' : String(v));
const list = (v: unknown): string[] => (Array.isArray(v) ? v.map((x) => (typeof x === 'string' ? x : str((x as Row)?.text ?? (x as Row)?.note))).filter(Boolean) : []);

const CRITERIA: Array<[string, string]> = [
  ['FC', 'Fluency & Coherence'],
  ['LR', 'Lexical Resource'],
  ['GRA', 'Grammatical Range & Accuracy'],
  ['P', 'Pronunciation'],
];

/** D6 · Speaking evaluation (speaking_evaluation_screen + transcript). */
export default async function SpeakingResult({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const a = await attempt(decodeURIComponent(id));
  if (!a || a.skill !== 'speaking') notFound();
  const d = a.data;
  const ev = (d.evaluation ?? {}) as Row;
  const status = str(d.status);
  if (!d.source && status && status !== 'completed') {
    return (
      <Card padding={24}>
        <SectionTitle>{status === 'processing' ? 'Still scoring' : 'This session wasn’t scored'}</SectionTitle>
        <p className={r.para}>{status === 'processing' ? 'The examiner is still listening. Refresh this page in a minute.' : str(d.message) || 'Please record your answers again.'}</p>
        <div style={{ marginTop: 12 }}>
          <PrimaryButton href="/app/speaking">Back to Speaking</PrimaryButton>
        </div>
      </Card>
    );
  }
  const crit = ((d.criteria ?? ev.criteria) ?? {}) as Record<string, number>;
  const fb = ((d.criteriaFeedback ?? ev.criteriaFeedback) ?? {}) as Record<string, string>;
  const summary = str(d.summary ?? ev.summary);
  const tips = list(d.feedback ?? ev.feedback).slice(0, 4);
  const perPart = list(d.perPartFeedback ?? ev.perPartFeedback);
  const strengths = (Array.isArray(d.aiStrengths ?? ev.strengths) ? (d.aiStrengths ?? ev.strengths) : []) as Row[];
  const transcript = (d.transcript ?? {}) as { paragraphs?: Paragraph[]; text?: string };
  let paragraphs = transcript.paragraphs ?? [];
  if (!paragraphs.length && Array.isArray(ev.segments)) {
    paragraphs = buildParagraphs((ev.segments as Row[]).map((x) => str(x.transcript)), errorsOf(ev.errors));
  }
  const stats = (d.stats ?? {}) as { fillers?: number; pauses?: number; wpm?: number };
  const audio = (Array.isArray(d.audio) ? d.audio : []) as Array<{ key?: string | null; durationSec?: number }>;
  const questions = (Array.isArray(d.questions) ? d.questions : []) as Array<{ q?: string }>;
  const date = new Date(a.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Dhaka' });

  return (
    <>
      <div className={r.top}>
        <Link href="/app/speaking" className={r.back} aria-label="Back to Speaking">
          <Icon name="arrow_back" size={20} />
        </Link>
        <h1 className={r.h1}>Speaking evaluation</h1>
      </div>

      <HeroCard>
        <div className={r.hero}>
          <div className={r.heroText}>
            <span className={r.heroLabel}>Estimated band</span>
            <span className={r.band}>{formatBand(a.band)}</span>
            <span className={r.heroMeta}>
              {a.title} · {date}
            </span>
          </div>
          <Nexi pose={(a.band ?? 0) >= 7 ? 'thumbs' : 'speaking'} height={120} />
        </div>
      </HeroCard>

      <div className={r.criteria}>
        {CRITERIA.map(([k, name]) => {
          const b = typeof crit[k] === 'number' ? crit[k] : a.band ?? 0;
          return (
            <Card key={k} padding={16}>
              <div className={r.critHead}>
                <span className={r.critName}>{name}</span>
                <span className={r.critBand}>{formatBand(b)}</span>
              </div>
              <div className={r.track}>
                <span style={{ width: `${Math.max(4, (b / 9) * 100)}%` }} />
              </div>
              {fb[k] && <p className={r.critText}>{fb[k]}</p>}
            </Card>
          );
        })}
      </div>

      {(stats.wpm || stats.fillers !== undefined) && (
        <Card padding={16}>
          <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap', fontSize: 14 }}>
            {stats.wpm ? (
              <span>
                <b style={{ fontSize: 20 }}>{stats.wpm}</b> words a minute
              </span>
            ) : null}
            <span>
              <b style={{ fontSize: 20 }}>{stats.fillers ?? 0}</b> fillers
            </span>
            <span>
              <b style={{ fontSize: 20 }}>{stats.pauses ?? 0}</b> long pauses
            </span>
          </div>
        </Card>
      )}

      {summary && (
        <Card padding={18}>
          <SectionTitle>Summary</SectionTitle>
          <p className={r.para}>{summary}</p>
          {perPart.length > 0 && (
            <ul className={r.bullets}>
              {perPart.map((x) => (
                <li key={x}>{x}</li>
              ))}
            </ul>
          )}
        </Card>
      )}

      <div className={r.two}>
        {strengths.length > 0 && (
          <Card padding={18}>
            <SectionTitle>What went well</SectionTitle>
            <ul className={r.bullets}>
              {strengths.slice(0, 6).map((x, i) => (
                <li key={i}>
                  <Icon name="check_circle" size={18} color="var(--success)" />
                  <span>
                    {x.quote ? <i>&ldquo;{str(x.quote)}&rdquo;</i> : null} {str(x.note)}
                  </span>
                </li>
              ))}
            </ul>
          </Card>
        )}
        {tips.length > 0 && (
          <Card padding={18}>
            <SectionTitle>What to work on</SectionTitle>
            <ol className={r.numbers}>
              {tips.map((x) => (
                <li key={x}>{x}</li>
              ))}
            </ol>
          </Card>
        )}
      </div>

      {paragraphs.length > 0 && (
        <Card padding={18}>
          <SectionTitle>Your answers</SectionTitle>
          <p className={r.muted}>Mistakes are marked; fillers and long pauses are shown so you can cut them.</p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            {paragraphs.map((p, i) => (
              <div key={i}>
                {questions[i]?.q && <p className={s.kicker} style={{ margin: '0 0 4px' }}>{questions[i].q}</p>}
                <div className={r.essay}>
                  {p.tokens.map((t, j) =>
                    t.type === 'text' ? (
                      <span key={j}>{t.text}</span>
                    ) : t.type === 'error' ? (
                      <mark key={j} className={r.markGrammar} title={t.note}>
                        {t.text}
                      </mark>
                    ) : (
                      <mark key={j} className={r.markVocab} title={t.note}>
                        {t.text}
                      </mark>
                    ),
                  )}
                </div>
                {audio[i]?.key && (
                  <div style={{ marginTop: 8 }}>
                    <RecordingPlayer storageKey={audio[i].key!} label="Play my answer" />
                  </div>
                )}
              </div>
            ))}
          </div>
          {errorsOf(d.errors ?? ev.errors).length > 0 && (
            <ol className={r.issues}>
              {errorsOf(d.errors ?? ev.errors).map((e, k) => (
                <li key={k}>
                  <p className={r.fix}>
                    <s>{e.original}</s>
                    {e.suggestion && (
                      <>
                        <Icon name="arrow_forward" size={14} /> <b>{e.suggestion}</b>
                      </>
                    )}
                  </p>
                  {e.note && <p className={r.note}>{e.note}</p>}
                </li>
              ))}
            </ol>
          )}
        </Card>
      )}

      <div className={r.actions}>
        <PrimaryButton href="/app/speaking" trailing="arrow_forward">
          Practise again
        </PrimaryButton>
      </div>
    </>
  );
}
