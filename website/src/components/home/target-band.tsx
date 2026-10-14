'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useRef, useState } from 'react';
import { Card, HeroCard, Icon, PrimaryButton } from '@/components/ui';
import { addDaysKey, daysBetween, keyDate, MO, WD, weekdayIndex } from '@/lib/home/time';
import { patchMe } from './edit-profile';
import h from './home.module.css';

/** Five days around [center], never before tomorrow (_windowAround). */
function windowAround(center: string, today: string): string[] {
  const tomorrow = addDaysKey(today, 1);
  let start = addDaysKey(center, -2);
  if (start < tomorrow) start = tomorrow;
  return [0, 1, 2, 3, 4].map((i) => addDaysKey(start, i));
}

const dateLabel = (k: string) => {
  const d = keyDate(k);
  return `${WD[weekdayIndex(k)]}, ${d.getUTCDate()} ${MO[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
};

/** A6 · Target band set-up (target_band_screen.dart): band gauge and exam date. */
export function TargetBandSetup({ bands, minBand, maxBand, band: initialBand, date: initialDate, today }: { bands: number[]; minBand: number; maxBand: number; band: number; date: string; today: string }) {
  const router = useRouter();
  const [band, setBand] = useState(initialBand);
  const [date, setDate] = useState(initialDate);
  const [dates, setDates] = useState(() => windowAround(initialDate, today));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const picker = useRef<HTMLInputElement>(null);
  const f = Math.min(1, Math.max(0, (band - minBand) / (maxBand - minBand)));
  const daysAway = daysBetween(today, date);
  const minDate = addDaysKey(today, 1);
  const maxDate = addDaysKey(today, 730);

  const save = async () => {
    setBusy(true);
    setError('');
    const err = await patchMe({ profile: { targetBand: band, testType: 'Academic', examDate: date } });
    setBusy(false);
    if (err) setError(err);
    else {
      router.push('/app');
      router.refresh();
    }
  };

  return (
    <div className={h.narrow}>
      <div className={h.top}>
        <Link href="/app" className={h.back} aria-label="Back to Home">
          <Icon name="arrow_back" size={18} />
        </Link>
        <div className={h.spacer} />
        <Link href="/app" className={h.linkBtn} style={{ fontSize: 15 }}>
          Skip
        </Link>
      </div>
      <div>
        <h1 className={h.h1} style={{ fontWeight: 500 }}>
          Set your target band
        </h1>
        <p className={h.sub}>We build your daily plan around this goal.</p>
      </div>

      <Card radius={28} padding="22px 18px 18px">
        <div className={h.gaugeWrap}>
          <svg viewBox="0 0 300 180" aria-hidden>
            {Array.from({ length: 13 }, (_, i) => {
              const a = Math.PI - (Math.PI * i) / 12;
              const x1 = 150 + 136 * Math.cos(a);
              const y1 = 150 - 136 * Math.sin(a);
              const x2 = 150 + 144 * Math.cos(a);
              const y2 = 150 - 144 * Math.sin(a);
              return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} style={{ stroke: 'var(--text-faint)' }} strokeWidth={2} strokeLinecap="round" />;
            })}
            <path d="M 30 150 A 120 120 0 0 1 270 150" fill="none" style={{ stroke: 'var(--track)' }} strokeWidth={18} strokeLinecap="round" />
            <path
              d="M 30 150 A 120 120 0 0 1 270 150"
              fill="none"
              style={{ stroke: 'var(--peach)', transition: 'stroke-dasharray 0.9s cubic-bezier(0.65, 0, 0.35, 1)' }}
              strokeWidth={18}
              strokeLinecap="round"
              pathLength={100}
              strokeDasharray={`${f * 100} 100`}
            />
            <g style={{ transform: `rotate(${f * 180}deg)`, transformOrigin: '150px 150px', transition: 'transform 0.9s cubic-bezier(0.65, 0, 0.35, 1)' }}>
              <circle cx={30} cy={150} r={14} style={{ fill: 'var(--text)' }} />
              <circle cx={30} cy={150} r={6} style={{ fill: 'var(--surface)' }} />
            </g>
            <text x={24} y={176} style={{ fill: 'var(--text-muted)', fontSize: 12 }}>
              {minBand.toFixed(1)}
            </text>
            <text x={276} y={176} textAnchor="end" style={{ fill: 'var(--text-muted)', fontSize: 12 }}>
              {maxBand.toFixed(1)}
            </text>
          </svg>
          <div className={h.gaugeNum} aria-live="polite">
            <b>{band.toFixed(1)}</b>
            <span>Target overall band</span>
          </div>
        </div>
        <div className={h.bandRow} role="radiogroup" aria-label="Target band" style={{ gridTemplateColumns: `repeat(${bands.length}, 1fr)`, marginTop: 14 }}>
          {bands.map((b) => (
            <button key={b} type="button" role="radio" aria-checked={Math.abs(b - band) < 0.01} className={`${h.bandChip} ${Math.abs(b - band) < 0.01 ? h.bandChipOn : ''}`} onClick={() => setBand(b)}>
              {b.toFixed(1)}
            </button>
          ))}
        </div>
      </Card>

      <HeroCard radius={28} padding={18}>
        <button
          type="button"
          className={h.identity}
          style={{ gap: 12, width: '100%', border: 0, background: 'transparent', color: 'inherit', textAlign: 'left', cursor: 'pointer', padding: 0 }}
          aria-label={`Exam date ${dateLabel(date)}. Choose another date`}
          onClick={() => {
            const el = picker.current;
            if (!el) return;
            try {
              el.showPicker();
            } catch {
              el.focus();
            }
          }}
        >
          <span className={h.fireBox} style={{ background: 'var(--hero-chip)', color: 'var(--hero-text)' }}>
            <Icon name="calendar_month" size={20} />
          </span>
          <span className={h.rowText}>
            <span className={h.heroMuted} style={{ display: 'block' }}>
              Exam date
            </span>
            <span style={{ fontSize: 17, fontWeight: 500 }}>{dateLabel(date)}</span>
          </span>
          <span className={h.change}>{daysAway} days</span>
        </button>
        <input
          ref={picker}
          type="date"
          className="visually-hidden"
          tabIndex={-1}
          aria-hidden
          value={date}
          min={minDate}
          max={maxDate}
          onChange={(e) => {
            const v = e.target.value;
            if (!/^\d{4}-\d{2}-\d{2}$/.test(v) || v < minDate || v > maxDate) return;
            setDate(v);
            setDates(windowAround(v, today));
          }}
        />
        <div className={h.dateRow} role="radiogroup" aria-label="Exam date" style={{ marginTop: 14 }}>
          {dates.map((k) => (
            <button key={k} type="button" role="radio" aria-checked={k === date} className={`${h.dateChip} ${k === date ? h.dateChipOn : ''}`} onClick={() => setDate(k)} aria-label={dateLabel(k)}>
              <span>{WD[weekdayIndex(k)]}</span>
              <b>{keyDate(k).getUTCDate()}</b>
            </button>
          ))}
        </div>
      </HeroCard>

      {error && <p className={h.error}>{error}</p>}
      <PrimaryButton block trailing="arrow_forward" onClick={save} disabled={busy}>
        {busy ? 'Saving…' : 'Continue'}
      </PrimaryButton>
    </div>
  );
}
