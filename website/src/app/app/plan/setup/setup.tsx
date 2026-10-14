'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import { QuickCheckOffer } from '@/components/plan-bits';
import { PlanTaskRow } from '@/components/plan-task-row';
import { HeroCard, Icon, Nexi } from '@/components/ui';
import p from '@/components/plan.module.css';
import { formatHalf, LEVEL_LABELS, moduleLabel, PLAN_MODULES, planDayLabel, WEEKDAYS_SHORT, type PlanInputs, type PlanTask } from '@/lib/plan/plan';

const BANDS = [5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5];
const MINUTES = [15, 20, 30, 45, 60, 90, 120];
const PREVIOUS = [4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5];
const SAVED = 'ia_plan_setup';

type Preview = {
  access?: { plan: string; freeUntil: string | null; ended: boolean };
  estimate: {
    weeks: number;
    weeksMin?: number;
    weeksMax?: number;
    onTrack?: boolean;
    targetBand?: number;
    split?: Record<string, number>;
    focusLabels?: string[];
    phases?: Array<{ label: string; fromWeek: number; toWeek: number }>;
    checkpointWeeks?: number[];
  };
  summary: string;
  week: Array<{ date: string; title: string; skill: string; durationMin: number; reason?: string; checkpoint?: boolean }>;
};

const localToday = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};
const withClock = (inputs: PlanInputs) => ({ ...inputs, startDate: localToday(), tzOffsetMin: -new Date().getTimezoneOffset() });
const minutesLabel = (m: number) => (m < 60 ? `${m} min` : m % 60 === 0 ? `${m / 60} h` : `${Math.floor(m / 60)} h ${m % 60}`);

async function call<T>(path: string, method: string, body?: unknown): Promise<T> {
  const res = await fetch(`/api/v1/${path}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  }).catch(() => null);
  if (!res) throw new Error('Can’t reach the server. Check your connection.');
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  if (!res.ok) throw new Error(data.error ?? 'Something went wrong. Please try again.');
  return data;
}

/** Set-up steps → preview → start (plan_setup_screen + plan_preview_screen). */
export function PlanSetup({
  defaults,
  edit,
  quickCheckDone,
  pro,
  resume,
}: {
  defaults: PlanInputs;
  edit: boolean;
  quickCheckDone: boolean;
  pro: boolean;
  resume: boolean;
}) {
  const router = useRouter();
  const [inp, setInp] = useState<PlanInputs>(() => ({
    ...defaults,
    modules: [...(defaults.modules ?? PLAN_MODULES)],
    levels: { ...(defaults.levels ?? {}) },
    days: [...(defaults.days ?? [1, 2, 3, 4, 5])],
  }));
  const steps = edit ? [2, 3] : [0, 1, 2, 3, 4];
  const [i, setI] = useState(0);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [showPreview, setShowPreview] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  // Back from the quick check: the answers are kept for this tab.
  useEffect(() => {
    if (!resume) return;
    try {
      const raw = sessionStorage.getItem(SAVED);
      if (raw) setInp(JSON.parse(raw) as PlanInputs);
    } catch {}
    setShowPreview(true);
  }, [resume]);
  useEffect(() => {
    try {
      sessionStorage.setItem(SAVED, JSON.stringify(inp));
    } catch {}
  }, [inp]);

  useEffect(() => {
    if (!showPreview) return;
    let live = true;
    setPreview(null);
    setError('');
    call<Preview>('plan/preview', 'POST', { inputs: withClock(inp) })
      .then((r) => live && setPreview(r))
      .catch((e: Error) => live && setError(e.message));
    return () => {
      live = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [showPreview]);

  const set = (patch: Partial<PlanInputs>) => setInp((x) => ({ ...x, ...patch }));
  const step = steps[i];
  const canNext = step === 0 ? inp.modules.length > 0 : step === 3 ? inp.days.length > 0 : true;
  const last = i + 1 === steps.length;

  const next = async () => {
    if (!last) return setI(i + 1);
    if (!edit) return setShowPreview(true);
    setBusy(true);
    setError('');
    try {
      await call('plan', 'PATCH', {
        action: 'update',
        days: inp.days,
        minutesPerDay: inp.minutesPerDay,
        studyTime: inp.studyTime,
        targetBand: inp.targetBand,
        examDate: inp.examDate,
        tzOffsetMin: -new Date().getTimezoneOffset(),
      });
      router.push('/app/plan');
      router.refresh();
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  };

  const start = async () => {
    setBusy(true);
    setError('');
    try {
      await call('plan', 'POST', { inputs: withClock(inp) });
      try {
        sessionStorage.removeItem(SAVED);
      } catch {}
      router.push('/app/plan');
      router.refresh();
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  };

  const chip = (label: string, on: boolean, onClick: () => void) => (
    <button key={label} type="button" className={`${p.chip} ${on ? p.chipOn : ''}`} aria-pressed={on} onClick={onClick}>
      {label}
    </button>
  );

  // ── preview ──
  if (showPreview) {
    const top = (
      <div className={p.top}>
        <button type="button" className={p.back} onClick={() => setShowPreview(false)} aria-label="Back to the questions">
          <Icon name="arrow_back" size={20} />
        </button>
        <div className={p.topText}>
          <h1 className={p.h1}>Your plan</h1>
          <p className={p.sub}>Check it before you start</p>
        </div>
      </div>
    );
    if (error && !preview) {
      return (
        <>
          {top}
          <div className={p.empty}>
            <Icon name="wifi_off" size={40} color="var(--text-muted)" />
            <h2>Could not make the plan</h2>
            <p>{error}</p>
            <button type="button" className={p.next} style={{ padding: '0 28px' }} onClick={() => setShowPreview(false)}>
              Back
            </button>
          </div>
        </>
      );
    }
    if (!preview) {
      return (
        <>
          {top}
          <div className={p.spinner} />
          <p className={p.note}>Building your plan…</p>
        </>
      );
    }
    const est = preview.estimate;
    const onTrack = est.onTrack !== false;
    const weeksLabel = !onTrack || est.weeksMin === est.weeksMax || !est.weeksMin ? `${est.weeks} weeks` : `${est.weeksMin}-${est.weeksMax} weeks`;
    const free = preview.access ? preview.access.plan === 'free' : !pro;
    const freeEnded = free && Boolean(preview.access?.ended);
    const days = new Map<string, Preview['week']>();
    for (const w of preview.week) days.set(w.date, [...(days.get(w.date) ?? []), w]);
    const split = Object.entries(est.split ?? {});
    const today = localToday();
    return (
      <>
        {top}
        <HeroCard padding={20} radius={30}>
          <div className={p.hero}>
            <div className={p.heroText}>
              <span className={p.overline}>{onTrack ? `Target band ${formatHalf(est.targetBand)}` : 'Your best plan'}</span>
              <h2 className={p.heroBig}>{weeksLabel}</h2>
              <p className={p.heroMuted}>{preview.summary}</p>
            </div>
            <Nexi pose="writing" height={100} />
          </div>
        </HeroCard>
        {free && (
          <p className={p.cardText}>
            {freeEnded
              ? 'Your 3 free study days are used. Pro runs this plan all the way to your exam and adapts it every week.'
              : 'On the free plan you get the first 3 study days of this plan. Pro runs it all the way and adapts it every week.'}
          </p>
        )}
        {!quickCheckDone && (
          <div
            onClickCapture={() => {
              try {
                sessionStorage.setItem(SAVED, JSON.stringify(inp));
              } catch {}
            }}
          >
            <QuickCheckOffer pro={pro} modules={inp.modules} back="/app/plan/setup?preview=1" />
          </div>
        )}
        {(est.phases?.length ?? 0) > 0 && (
          <div className={p.card}>
            <span className={p.cardTitle}>How it goes</span>
            {est.phases!.map((ph) => (
              <div key={ph.label} className={p.phase}>
                <i />
                <span>{ph.label}</span>
                <span>{ph.fromWeek === ph.toWeek ? `Week ${ph.fromWeek}` : `Weeks ${ph.fromWeek}-${ph.toWeek}`}</span>
              </div>
            ))}
            {(est.checkpointWeeks?.length ?? 0) > 0 && <p className={p.cardText}>Checkpoint tests in weeks {est.checkpointWeeks!.join(', ')}.</p>}
          </div>
        )}
        {split.length > 1 && (
          <div className={p.card}>
            <span className={p.cardTitle}>Where your time goes</span>
            {split.map(([k, v]) => (
              <div key={k} className={p.split}>
                <div>
                  <span>{moduleLabel(k)}</span>
                  <span style={{ color: 'var(--text-muted)', fontSize: 12.5 }}>{Math.round(v * 100)}%</span>
                </div>
                <div className={p.bar}>
                  <span style={{ width: `${Math.round(v * 100)}%` }} />
                </div>
              </div>
            ))}
          </div>
        )}
        {(est.focusLabels?.length ?? 0) > 0 && (
          <div className={p.card}>
            <span className={p.cardTitle}>From your results so far</span>
            <div className={p.tags}>
              {est.focusLabels!.map((f) => (
                <span key={f} className={p.tag}>
                  {f}
                </span>
              ))}
            </div>
          </div>
        )}
        {preview.week.length > 0 && (
          <div>
            <h2 style={{ margin: '4px 0 0', fontSize: 18 }}>{free ? 'Your free days' : 'Your first week'}</h2>
            <p className={p.sub}>
              {days.size} {days.size === 1 ? 'day' : 'days'} · {preview.week.length} tasks
            </p>
          </div>
        )}
        {[...days.entries()].map(([d, list]) => (
          <section key={d} className={p.day}>
            <div className={p.dayHead}>
              <span>{planDayLabel(d, today)}</span>
            </div>
            {list.map((w, k) => (
              <PlanTaskRow
                key={k}
                preview
                task={{ id: `${d}:${k}`, title: w.title, skill: w.skill, kind: w.checkpoint ? 'checkpoint' : 'plan', date: d, durationMin: w.durationMin, done: false, target: '', reason: w.reason } as PlanTask}
              />
            ))}
          </section>
        ))}
        {free && (
          <Link href="/app/upgrade" className={`${p.card} ${p.cardRow}`}>
            <span className={`${p.circle} ${p.circleMuted}`}>
              <Icon name="lock" size={20} />
            </span>
            <span style={{ flex: 1 }}>
              <span className={p.cardTitle}>The rest of your plan · Pro</span>
              <p className={p.cardText}>Every day up to your exam, adapted each week to your results.</p>
            </span>
            <Icon name="arrow_forward" size={18} color="var(--text-muted)" />
          </Link>
        )}
        {error && <p className={p.error}>{error}</p>}
        <div className={p.foot}>
          <button type="button" className={p.next} disabled={busy} onClick={start}>
            {busy ? 'Saving…' : 'Start my plan'}
          </button>
        </div>
      </>
    );
  }

  // ── set-up steps ──
  const q = (title: string, sub?: string) => (
    <div>
      <h2 className={p.q}>{title}</h2>
      {sub && <p className={p.qSub}>{sub}</p>}
    </div>
  );
  const mods = PLAN_MODULES.filter((m) => inp.modules.includes(m));
  let body: ReactNode;
  if (step === 0) {
    body = (
      <>
        {q('What do you want to work on?', 'Pick every part of the test you want in your plan.')}
        {PLAN_MODULES.map((m) => {
          const on = inp.modules.includes(m);
          return (
            <button
              key={m}
              type="button"
              className={`${p.option} ${on ? p.optionOn : ''}`}
              aria-pressed={on}
              onClick={() => set({ modules: on ? inp.modules.filter((x) => x !== m) : [...inp.modules, m] })}
            >
              {moduleLabel(m)}
              <Icon name={on ? 'check_circle' : 'radio_button_unchecked'} size={22} color={on ? 'var(--peach)' : 'var(--text-faint)'} filled={on} />
            </button>
          );
        })}
      </>
    );
  } else if (step === 1) {
    body = (
      <>
        {q('Where are you now?', 'Your best guess is fine. The plan corrects itself as you practise.')}
        {mods.map((m) => (
          <div key={m} className={p.card}>
            <span className={p.cardTitle} style={{ fontSize: 15 }}>
              {moduleLabel(m)}
            </span>
            <div className={p.chips}>
              {Object.entries(LEVEL_LABELS).map(([k, label]) =>
                chip(label, (inp.levels[m] ?? 'intermediate') === k, () => set({ levels: { ...inp.levels, [m]: k } })),
              )}
            </div>
          </div>
        ))}
        <p className={p.qSub}>Taken IELTS before? Your overall band</p>
        <div className={p.chips}>
          {chip('Not yet', inp.previousScore == null, () => set({ previousScore: null }))}
          {PREVIOUS.map((b) => chip(formatHalf(b), inp.previousScore === b, () => set({ previousScore: b })))}
        </div>
      </>
    );
  } else if (step === 2) {
    const min = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
    const max = new Date(Date.now() + 730 * 86400000).toISOString().slice(0, 10);
    body = (
      <>
        {q('What band do you need?')}
        <div className={p.chips}>{BANDS.map((b) => chip(formatHalf(b), Number(inp.targetBand) === b, () => set({ targetBand: b })))}</div>
        {q('When is your exam?', 'We fit the plan before it. No date yet is fine too.')}
        <div className={p.chips} style={{ alignItems: 'center' }}>
          <label className={p.input} style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
            <Icon name="calendar_month" size={18} color="var(--text-muted)" />
            <input
              type="date"
              min={min}
              max={max}
              value={inp.examDate ?? ''}
              onChange={(e) => set({ examDate: e.target.value || null })}
              style={{ border: 0, background: 'transparent', font: 'inherit', color: 'inherit' }}
              aria-label="Exam date"
            />
          </label>
          {chip('No date yet', !inp.examDate, () => set({ examDate: null }))}
        </div>
      </>
    );
  } else if (step === 3) {
    body = (
      <>
        {q('Which days can you study?')}
        <div className={p.chips}>
          {WEEKDAYS_SHORT.map((label, k) => {
            const d = k + 1;
            const on = inp.days.includes(d);
            return chip(label, on, () => set({ days: (on ? inp.days.filter((x) => x !== d) : [...inp.days, d]).sort((a, b) => a - b) }));
          })}
        </div>
        {q('How long each day?', 'Be realistic: a plan you can keep beats a big one you skip.')}
        <div className={p.chips}>{MINUTES.map((m) => chip(minutesLabel(m), Number(inp.minutesPerDay) === m, () => set({ minutesPerDay: m })))}</div>
        {q('What time suits you?', 'Your reminder comes at this time.')}
        <label className={p.input} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, alignSelf: 'flex-start' }}>
          <Icon name="schedule" size={18} color="var(--text-muted)" />
          <input
            type="time"
            value={inp.studyTime || '20:00'}
            onChange={(e) => set({ studyTime: e.target.value || '20:00' })}
            style={{ border: 0, background: 'transparent', font: 'inherit', color: 'inherit' }}
            aria-label="Study time"
          />
        </label>
      </>
    );
  } else {
    body = (
      <>
        {q('Which part worries you most?', 'It gets a little more time.')}
        <div className={p.chips}>
          {chip('Not sure', !inp.worry, () => set({ worry: null }))}
          {mods.map((m) => chip(moduleLabel(m), inp.worry === m, () => set({ worry: m })))}
        </div>
        <div className={p.card}>
          <div className={p.cardRow} style={{ gap: 12 }}>
            <Icon name="lightbulb" color="var(--peach)" />
            <p className={p.cardText}>Your plan uses your results in the app and on the web, so it gets sharper the more you practise.</p>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <div className={p.top}>
        <Link href="/app/plan" className={p.back} aria-label="Back">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={p.topText}>
          <h1 className={p.h1}>{edit ? 'Change my plan' : 'Your study plan'}</h1>
          <p className={p.sub}>
            Step {i + 1} of {steps.length}
          </p>
        </div>
      </div>
      <div className={p.progress}>
        <span style={{ width: `${((i + 1) / steps.length) * 100}%` }} />
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14, maxWidth: 640 }}>{body}</div>
      {error && <p className={p.error}>{error}</p>}
      <div className={p.foot} style={{ maxWidth: 640 }}>
        {i > 0 && (
          <button type="button" className={p.outline} onClick={() => setI(i - 1)}>
            Back
          </button>
        )}
        <button type="button" className={p.next} disabled={!canNext || busy} onClick={next}>
          {busy ? 'Saving…' : last ? (edit ? 'Save changes' : 'See my plan') : 'Next'}
          {!last && <Icon name="arrow_forward" size={20} />}
        </button>
      </div>
    </>
  );
}
