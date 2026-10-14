import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { BandTrend } from '@/components/extras/band-trend';
import { RecordingPlayer } from '@/components/recording-player';
import { Card, HeroCard, Icon, Nexi, PrimaryButton, SectionTitle, SoftButton } from '@/components/ui';
import { mockNumberLabel } from '@/lib/extras/mock-plan';
import { mockAttempts } from '@/lib/extras/mock-server';
import { attempt } from '@/lib/server/attempts';
import { getMe } from '@/lib/server/me';
import { formatBand } from '@/lib/writing/analysis';
import s from '../../../writing/result/[id]/result.module.css';

export const metadata: Metadata = { title: 'Mock test results' };

type Row = Record<string, unknown>;
const str = (v: unknown) => (v == null ? '' : String(v));
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
const list = (v: unknown): string[] => (Array.isArray(v) ? v.map((x) => (typeof x === 'string' ? x : str((x as Row)?.text ?? (x as Row)?.note))).filter(Boolean) : []);

const SKILLS: Array<[string, string, string]> = [
  ['listening', 'Listening', 'headphones'],
  ['reading', 'Reading', 'menu_book'],
  ['writing', 'Writing', 'edit_note'],
  ['speaking', 'Speaking', 'mic'],
];

function Bar({ name, band, text }: { name: string; band: number; text?: string }) {
  return (
    <Card padding={16}>
      <div className={s.critHead}>
        <span className={s.critName}>{name}</span>
        <span className={s.critBand}>{formatBand(band)}</span>
      </div>
      <div className={s.track}>
        <span style={{ width: `${Math.max(0, Math.min(1, band / 9)) * 100}%` }} />
      </div>
      {text && <p className={s.critText}>{text}</p>}
    </Card>
  );
}

/** Mock results (mock_results_screen.dart): overall band and every section. */
export default async function MockResult({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const a = await attempt(decodeURIComponent(id));
  if (!a || a.skill !== 'mock') notFound();
  const d = a.data;
  const sections = (d.sections ?? {}) as Record<string, number>;
  const ls = (d.listeningScore ?? {}) as Row;
  const rs = (d.readingScore ?? {}) as Row;
  const byPart = Array.isArray(d.listeningByPart) ? (d.listeningByPart as Row[]) : [];
  const wr = (d.writing ?? {}) as Row;
  const wc = (d.writingCriteria ?? {}) as Record<string, number>;
  const sc = (d.speakingCriteria ?? {}) as Record<string, number>;
  const spk = (d.speaking ?? {}) as Row;
  const transcripts = (spk.transcripts ?? {}) as Record<string, string>;
  const keys = (spk.recordingKeys ?? {}) as Record<string, string>;
  const overall = num(d.overall ?? a.band);
  const date = new Date(a.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Dhaka' });
  const detail: Record<string, string> = {
    listening: `${num(ls.correct)} / ${num(ls.total) || 40} correct`,
    reading: `${num(rs.correct)} / ${num(rs.total) || 40} correct`,
    writing: `Task 1 ${formatBand(num(wr.task1Band))} · Task 2 ${formatBand(num(wr.task2Band))}`,
    speaking: `${Math.round(num(d.spokenSec) / 60)} min spoken`,
  };
  // Band trend (mock_results_screen.dart): up to 4 older mocks and this one.
  const [allMocks, me] = await Promise.all([mockAttempts(), getMe().catch(() => null)]);
  const goal = Number(me?.user.profile?.targetBand) || 7;
  const older = allMocks.filter((m) => m.createdAt < a.createdAt).slice(0, 4).reverse();
  const trend = [...older, a].map((m) => ({ label: `M${mockNumberLabel(m.title) || '–'}`, band: num(m.band ?? m.data.overall) }));
  const weakest = SKILLS.map(([k, n]) => [n, num(sections[k])] as const).sort((x, y) => x[1] - y[1])[0];

  return (
    <>
      <div className={s.top}>
        <Link href="/app/mocks" className={s.back} aria-label="Back to Mock tests">
          <Icon name="arrow_back" size={20} />
        </Link>
        <h1 className={s.h1}>Band report</h1>
      </div>

      <HeroCard>
        <div className={s.hero}>
          <div className={s.heroText}>
            <span className={s.heroLabel}>Overall band</span>
            <span className={s.band}>{formatBand(overall)}</span>
            <span className={s.heroMeta}>
              {str(d.mockTitle) || a.title} · {date}
            </span>
          </div>
          <Nexi pose={overall >= 7 ? 'thumbs' : 'grad'} height={120} />
        </div>
      </HeroCard>

      <div className={s.criteria}>
        {SKILLS.map(([k, name]) => (
          <Bar key={k} name={name} band={num(sections[k])} text={detail[k]} />
        ))}
      </div>

      <div className={s.actions}>
        <PrimaryButton href={`/app/mocks/plan/${encodeURIComponent(a.id)}`} leading="auto_awesome">
          See my improvement plan
        </PrimaryButton>
        <SoftButton href={`/app/mocks/answers/${encodeURIComponent(a.id)}`} leading="checklist">
          Review every answer
        </SoftButton>
      </div>

      {trend.length > 1 && (
        <Card padding={18}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8, marginBottom: 8 }}>
            <SectionTitle>Band trend</SectionTitle>
            <span style={{ fontSize: 12.5, color: 'var(--text-muted)' }}>Next goal · {formatBand(goal)}</span>
          </div>
          <BandTrend points={trend} goal={goal} />
        </Card>
      )}

      {weakest && (
        <Card padding={18}>
          <SectionTitle>Where to focus next</SectionTitle>
          <p className={s.para}>
            {weakest[0]} is your lowest section at band {formatBand(weakest[1])}. Raising it by half a band lifts your overall score the most.
          </p>
        </Card>
      )}

      {byPart.length > 0 && (
        <Card padding={18}>
          <SectionTitle>Listening by part</SectionTitle>
          <ul className={s.bullets}>
            {byPart.map((p) => (
              <li key={str(p.label)} style={{ justifyContent: 'space-between' }}>
                <span>{str(p.label)}</span>
                <b>
                  {num(p.correct)} / {num(p.total)}
                </b>
              </li>
            ))}
          </ul>
        </Card>
      )}

      <SectionTitle>Writing</SectionTitle>
      <div className={s.criteria}>
        <Bar name="Task Achievement / Response" band={num(wc.TA)} />
        <Bar name="Coherence & Cohesion" band={num(wc.CC)} />
        <Bar name="Lexical Resource" band={num(wc.LR)} />
        <Bar name="Grammatical Range & Accuracy" band={num(wc.GRA)} />
      </div>
      {str(d.writingSummary) && (
        <Card padding={18}>
          <p className={s.para} style={{ marginTop: 0 }}>
            {str(d.writingSummary)}
          </p>
        </Card>
      )}
      <div className={s.two}>
        {list(wr.strengths).length > 0 && (
          <Card padding={18}>
            <SectionTitle as="h3">What went well</SectionTitle>
            <ul className={s.bullets}>
              {list(wr.strengths).slice(0, 4).map((t) => (
                <li key={t}>
                  <Icon name="check_circle" size={18} color="var(--success)" /> {t}
                </li>
              ))}
            </ul>
          </Card>
        )}
        {list(wr.feedback).length > 0 && (
          <Card padding={18}>
            <SectionTitle as="h3">To improve</SectionTitle>
            <ul className={s.bullets}>
              {list(wr.feedback).slice(0, 4).map((t) => (
                <li key={t}>
                  <Icon name="arrow_upward" size={18} color="var(--peach)" /> {t}
                </li>
              ))}
            </ul>
          </Card>
        )}
      </div>
      {[1, 2].map((n) =>
        str(wr[`task${n}`]).trim() ? (
          <Card key={n} padding={18}>
            <SectionTitle as="h3">
              Task {n} · {num(wr[`task${n}Words`])} words · band {formatBand(num(wr[`task${n}Band`]))}
            </SectionTitle>
            <p className={s.para}>{str(wr[`task${n}`])}</p>
          </Card>
        ) : null,
      )}

      <SectionTitle>Speaking</SectionTitle>
      <div className={s.criteria}>
        <Bar name="Fluency & Coherence" band={num(sc.FC)} />
        <Bar name="Lexical Resource" band={num(sc.LR)} />
        <Bar name="Grammatical Range & Accuracy" band={num(sc.GRA)} />
        <Bar name="Pronunciation" band={num(sc.P)} />
      </div>
      {(str(d.speakingSummary) || list(spk.feedback).length > 0) && (
        <Card padding={18}>
          {str(d.speakingSummary) && (
            <p className={s.para} style={{ marginTop: 0 }}>
              {str(d.speakingSummary)}
            </p>
          )}
          {list(spk.feedback).length > 0 && (
            <ul className={s.bullets}>
              {list(spk.feedback).slice(0, 4).map((t) => (
                <li key={t}>
                  <Icon name="arrow_upward" size={18} color="var(--peach)" /> {t}
                </li>
              ))}
            </ul>
          )}
        </Card>
      )}
      {['1', '2', '3'].map((n) =>
        transcripts[n] || keys[n] ? (
          <Card key={n} padding={18}>
            <SectionTitle as="h3">Part {n}</SectionTitle>
            {keys[n] && <RecordingPlayer storageKey={keys[n]} label="Play my answer" />}
            {transcripts[n] && <p className={s.para}>{transcripts[n]}</p>}
          </Card>
        ) : null,
      )}

      <div className={s.actions}>
        <PrimaryButton href={`/app/mocks/${str(d.mockId) || a.refId}`} leading="refresh">
          Take this test again
        </PrimaryButton>
        <SoftButton href="/app/mocks">All mock tests</SoftButton>
      </div>
    </>
  );
}
