import type { Metadata } from 'next';
import Link from 'next/link';
import h from '@/components/home/home.module.css';
import { Card, Icon, PrimaryButton } from '@/components/ui';
import { targetHref } from '@/lib/home/routes';
import { homeSection, myAttempts } from '@/lib/home/server';
import { CORE_SKILLS, estimatedBand, formatBand, roundBand, signedBand, skillBand, skillLabel, skillProgress, profileOf, type AttemptLike } from '@/lib/home/stats';
import { addDaysKey, dayKey, keyDate, MO, studyTimeLabel, todayKey, WD, weekdayIndex } from '@/lib/home/time';
import { getMe } from '@/lib/server/me';

export const metadata: Metadata = { title: 'Your progress' };

type Period = 'week' | 'month' | 'year';
const PERIODS: Array<[Period, string]> = [
  ['week', 'Week'],
  ['month', 'Month'],
  ['year', 'Year'],
];
type Bucket = { label: string; from: string; to: string };

const monthKey = (y: number, m: number) => {
  const d = new Date(Date.UTC(y, m, 1));
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-01`;
};

/** Buckets (label, from inclusive, to exclusive) for the period (_buckets). */
function buckets(period: Period): Bucket[] {
  const today = todayKey();
  const t = keyDate(today);
  const y = t.getUTCFullYear();
  const m = t.getUTCMonth();
  const out: Bucket[] = [];
  if (period === 'week') {
    for (let i = 6; i >= 0; i--) {
      const k = addDaysKey(today, -i);
      out.push({ label: WD[weekdayIndex(k)], from: k, to: addDaysKey(k, 1) });
    }
  } else if (period === 'month') {
    for (let i = 4; i >= 0; i--) {
      const from = monthKey(y, m - i);
      out.push({ label: MO[keyDate(from).getUTCMonth()], from, to: monthKey(y, m - i + 1) });
    }
  } else {
    const q = Math.floor(m / 3) * 3;
    for (let i = 4; i >= 0; i--) {
      const from = monthKey(y, q - 3 * i);
      const st = keyDate(from);
      const qn = Math.floor(st.getUTCMonth() / 3) + 1;
      const yy = String(st.getUTCFullYear() % 100).padStart(2, '0');
      out.push({ label: i === 0 ? 'Now' : st.getUTCFullYear() === y ? `Q${qn}` : `Q${qn} '${yy}`, from, to: monthKey(y, q - 3 * i + 3) });
    }
  }
  return out;
}

/** Band points per bucket, carried over empty ones; leading empty buckets dropped. */
function points(all: AttemptLike[], bs: Bucket[]): Array<{ label: string; v: number }> {
  const scored = all.filter((a) => a.band != null && ((CORE_SKILLS as readonly string[]).includes(a.skill) || a.skill === 'mock')).map((a) => ({ k: dayKey(new Date(a.createdAt)), b: a.band as number }));
  const out: Array<{ label: string; v: number }> = [];
  let last: number | null = null;
  for (const b of bs) {
    const inB = scored.filter((x) => x.k >= b.from && x.k < b.to).map((x) => x.b);
    if (inB.length) last = inB.reduce((x, y) => x + y, 0) / inB.length;
    if (last != null) out.push({ label: b.label, v: last });
  }
  return out;
}

/** Newest-3 mean minus the previous-3 mean ('' if unknown). */
function delta(all: AttemptLike[], skill: string): string {
  const bands = all.filter((a) => a.skill === skill && a.kind !== 'session' && a.band != null).map((a) => a.band as number);
  if (bands.length < 2) return '';
  const recent = bands.slice(0, 3);
  const older = bands.slice(recent.length, recent.length + 3);
  if (!older.length) return '';
  const mean = (l: number[]) => l.reduce((x, y) => x + y, 0) / l.length;
  return signedBand(roundBand(mean(recent)) - roundBand(mean(older)));
}

const CRITERIA: Record<string, string> = {
  TA: 'Task Achievement',
  CC: 'Coherence & Cohesion',
  LR: 'Lexical Resource',
  GRA: 'Grammatical Range & Accuracy',
  FC: 'Fluency & Coherence',
  P: 'Pronunciation',
};

/** Lowest criterion of the newest attempt of [skill] that has criteria. */
function weakCriterion(all: AttemptLike[], skill: string): [string, number] | null {
  for (const a of all) {
    if (a.skill !== skill || a.kind === 'session') continue;
    const nested = (a.data?.criteria ?? null) as Record<string, unknown> | null;
    let low: [string, number] | null = null;
    for (const [k, label] of Object.entries(CRITERIA)) {
      let v = a.data?.[k];
      if (typeof v !== 'number' && nested && typeof nested === 'object') v = nested[k];
      if (typeof v === 'number' && (low == null || v < low[1])) low = [label, v];
    }
    if (low) return low;
  }
  return null;
}

/** Line chart (_LineChartPainter) as SVG. */
function LineChart({ values }: { values: number[] }) {
  const W = 400;
  const H = 150;
  const y = (gy: number) => (gy / 130) * H;
  const grid = [20, 55, 90].map((g) => y(g));
  if (!values.length) {
    return (
      <svg viewBox={`0 0 ${W} ${H}`} aria-hidden>
        {grid.map((g) => (
          <line key={g} x1={0} x2={W} y1={g} y2={g} style={{ stroke: 'var(--border)' }} strokeWidth={1} />
        ))}
      </svg>
    );
  }
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min;
  const left = 10;
  const right = W - 10;
  const pts = values.map((v, i) => {
    const x = values.length === 1 ? right : left + ((right - left) * i) / (values.length - 1);
    const norm = range === 0 ? 0.5 : (v - min) / range;
    return [x, y(104 - norm * 70)] as const;
  });
  const line = pts.map(([px, py], i) => `${i ? 'L' : 'M'}${px.toFixed(1)},${py.toFixed(1)}`).join(' ');
  const base = y(120);
  const area = `${line} L${pts[pts.length - 1][0].toFixed(1)},${base} L${pts[0][0].toFixed(1)},${base} Z`;
  return (
    <svg viewBox={`0 0 ${W} ${H}`} aria-hidden>
      {grid.map((g) => (
        <line key={g} x1={0} x2={W} y1={g} y2={g} style={{ stroke: 'var(--border)' }} strokeWidth={1} />
      ))}
      <path d={area} style={{ fill: 'var(--fill)' }} fillOpacity={0.08} />
      <path d={line} fill="none" style={{ stroke: 'var(--fill)' }} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
      {pts.slice(0, -1).map(([px, py], i) => (
        <circle key={i} cx={px} cy={py} r={4} style={{ fill: 'var(--surface)', stroke: 'var(--fill)' }} strokeWidth={2} />
      ))}
      <circle cx={pts[pts.length - 1][0]} cy={pts[pts.length - 1][1]} r={6} style={{ fill: 'var(--fill)' }} />
    </svg>
  );
}

/** B4 · Study analytics (analytics_screen.dart). */
export default async function AnalyticsPage({ searchParams }: { searchParams: Promise<{ period?: string }> }) {
  const sp = await searchParams;
  const period: Period = sp.period === 'week' || sp.period === 'year' ? sp.period : 'month';
  const [me, all, home] = await Promise.all([getMe(), myAttempts(), homeSection()]);
  const target = profileOf(me.user.profile).targetBand;

  const header = (
    <div className={h.top}>
      <Link href="/app" className={h.back} aria-label="Back to Home">
        <Icon name="arrow_back" size={20} />
      </Link>
      <div className={h.spacer} />
      <nav className={h.seg} aria-label="Period">
        {PERIODS.map(([id, label]) => (
          <Link key={id} href={`/app/analytics?period=${id}`} className={`${h.segBtn} ${id === period ? h.segOn : ''}`} aria-current={id === period ? 'page' : undefined} replace scroll={false}>
            {label}
          </Link>
        ))}
      </nav>
    </div>
  );

  const bs = buckets(period);
  const pts = points(all, bs);
  const studied = all.filter((a) => {
    const k = dayKey(new Date(a.createdAt));
    return k >= bs[0].from && k < bs[bs.length - 1].to;
  }).reduce((s, a) => s + Math.round((a.durationSec || 0) / 60), 0);
  const phrase = period === 'week' ? 'in the last 7 days' : period === 'month' ? 'in the last 5 months' : 'in the last 15 months';

  const title = (
    <div>
      <h1 className={h.h1}>Your progress</h1>
      <p className={h.sub}>Band estimates from practice and mock tests</p>
      {all.length > 0 && (
        <p className={h.sub} style={{ fontSize: 13 }}>
          {studyTimeLabel(studied)} studied {phrase}
        </p>
      )}
    </div>
  );

  if (!all.length) {
    return (
      <>
        {header}
        {title}
        <Card>
          <div className={h.emptyState}>
            <Icon name="insights" size={44} color="var(--text-muted)" />
            <h2>Analytics appear after your first practice</h2>
            <p>Finish a test, essay or speaking answer and your band trend, skill breakdown and study time show up here.</p>
            <PrimaryButton href="/app/practice">Start practising</PrimaryButton>
          </div>
        </Card>
      </>
    );
  }

  let change = 'No change yet';
  if (pts.length >= 2) {
    const d = roundBand(pts[pts.length - 1].v) - roundBand(pts[0].v);
    change = period === 'week' ? `${signedBand(d)} this week` : `${signedBand(d)} since ${pts[0].label}`;
  }
  const bands = Object.fromEntries(CORE_SKILLS.map((k) => [k, skillBand(all, k)])) as Record<string, number | null>;
  let weakest: string | null = null;
  for (const k of CORE_SKILLS) {
    const b = bands[k];
    if (b == null) continue;
    if (weakest == null || b < (bands[weakest] as number)) weakest = k;
  }
  const crit = weakest ? weakCriterion(all, weakest) : null;
  const weakTitle = weakest ? (crit ? `${skillLabel(weakest)} · ${crit[0]} ${formatBand(crit[1])}` : `${skillLabel(weakest)} · Band ${formatBand(bands[weakest])}`) : '';
  const weakTargets = ((home.analytics ?? {}) as Record<string, unknown>).weakestTargets as Record<string, string> | undefined;
  const weakHref = weakest ? targetHref(weakTargets?.[weakest] ?? '') || `/app/${weakest}` : '';

  return (
    <>
      {header}
      {title}
      <div className={h.grid2}>
        <Card radius={30} padding="16px 18px">
          <div className={h.rowBetween} style={{ alignItems: 'flex-end' }}>
            <div>
              <span className={h.label}>Overall band</span>
              <div className={h.overall}>{formatBand(estimatedBand(all))}</div>
            </div>
            <span className={h.change}>{change}</span>
          </div>
          <div className={h.chart} style={{ height: 'auto' }} role="img" aria-label={pts.length ? `Band trend: ${pts.map((p) => `${p.label} ${formatBand(roundBand(p.v))}`).join(', ')}` : 'No band scores in this period'}>
            <LineChart values={pts.map((p) => p.v)} />
            {pts.length > 0 && <span className={h.chartTag}>{formatBand(roundBand(pts[pts.length - 1].v))}</span>}
            {pts.length === 0 && <span className={h.chartEmpty}>No band scores in this period</span>}
          </div>
          <div className={h.chartLabels}>
            {pts.map((p, i) => (
              <span key={`${p.label}${i}`}>{p.label}</span>
            ))}
          </div>
        </Card>

        <div className={h.stack}>
          <Card radius={30} padding="16px 18px">
            <h2 className={h.cardTitle} style={{ fontSize: 15, fontWeight: 400 }}>
              Skill breakdown
            </h2>
            {CORE_SKILLS.map((k) => {
              const p = skillProgress(all, k, target);
              const d = delta(all, k);
              return (
                <div key={k} className={h.skillBar}>
                  <div className={h.skillBarHead}>
                    <span>{skillLabel(k)}</span>
                    <span>
                      {d && <small>{d}</small>}
                      {formatBand(bands[k])}
                    </span>
                  </div>
                  <div className={h.fatTrack} role="progressbar" aria-label={`${skillLabel(k)} toward your target`} aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(p * 100)}>
                    <span className={k === weakest ? h.striped : undefined} style={{ width: `${p * 100}%` }} />
                  </div>
                </div>
              );
            })}
          </Card>

          {weakest && (
            <Link href={weakHref} className={h.weak}>
              <span className={h.rowText}>
                <span className={h.weakLabel}>Weakest area</span>
                <span className={h.weakTitle} style={{ display: 'block' }}>
                  {weakTitle}
                </span>
              </span>
              <span className={h.weakGo}>
                <Icon name="arrow_forward" size={20} />
              </span>
            </Link>
          )}
        </div>
      </div>
    </>
  );
}
