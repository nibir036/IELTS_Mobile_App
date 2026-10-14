'use client';

import Link from 'next/link';
import { useState, type ReactNode } from 'react';
import type { Mark, ObjectiveView, ReviewRow, Seg } from '@/lib/extras/mock-review';
import { RecordingPlayer } from '../recording-player';
import { Card, HeroCard, Icon, PrimaryButton, Tag } from '../ui';
import x from './extras.module.css';

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');
const TABS = ['Listening', 'Reading', 'Writing', 'Speaking'] as const;
const fmt = (v: number | null | undefined) => (typeof v === 'number' && Number.isFinite(v) ? v.toFixed(1) : '–');

export interface WritingTaskView {
  task: 1 | 2;
  title: string;
  prompt: string;
  band: number | null;
  words: number;
  essay: string;
  criteria: Record<string, number | null>;
  summary: string;
  modelHref: string | null;
}

export interface SpeakingPartView {
  part: 1 | 2 | 3;
  title: string;
  sub: string;
  questions: string[];
  bullets: string[];
  transcript: string;
  recordingKey: string;
  onPhone: boolean;
}

export interface MockAnswersProps {
  initialTab: number;
  listening: ObjectiveView;
  reading: ObjectiveView;
  writing: { band: number | null; criteria: Record<string, number | null>; tasks: WritingTaskView[] };
  speaking: { band: number | null; criteria: Record<string, number | null>; summary: string; spoken: string; parts: SpeakingPartView[] };
}

function Segs({ segs }: { segs: Seg[] }) {
  return (
    <>
      {segs.map((s, i) =>
        s.hi ? (
          <mark key={i} className={x.hi}>
            {s.text}
          </mark>
        ) : s.bold ? (
          <b key={i}>{s.text}</b>
        ) : (
          <span key={i}>{s.text}</span>
        ),
      )}
    </>
  );
}

function Crits({ keys, values, onHero }: { keys: string[]; values: Record<string, number | null>; onHero?: boolean }) {
  return (
    <div className={x.crits}>
      {keys.map((k) => (
        <div key={k} className={cx(x.crit, onHero && x.critOnHero)}>
          <span className={x.critLabel}>{k}</span>
          <span className={x.critValue}>{typeof values[k] === 'number' && (values[k] as number) > 0 ? fmt(values[k]) : '–'}</span>
        </div>
      ))}
    </div>
  );
}

function Empty({ icon, title, children, action }: { icon: string; title: string; children: ReactNode; action?: ReactNode }) {
  return (
    <Card>
      <div className={x.empty}>
        <Icon name={icon} size={34} color="var(--text-muted)" />
        <h2 className={x.emptyTitle}>{title}</h2>
        <p className={x.emptyText}>{children}</p>
        {action}
      </div>
    </Card>
  );
}

const BADGE: Record<Mark, string> = { correct: x.badgeOk, partial: x.badgeBad, wrong: x.badgeBad, blank: x.badgeBlank, unknown: '' };

/** One reviewed question (MockAnswerRow). */
function AnswerRow({ row, open, onToggle }: { row: ReviewRow; open: boolean; onToggle: () => void }) {
  const wrongish = row.mark === 'wrong' || row.mark === 'partial';
  const showKey = !(row.mark === 'correct' && row.given.toLowerCase() === row.correct.toLowerCase());
  const id = `d-${row.key}`;
  return (
    <div className={x.row}>
      <span className={cx(x.badge, BADGE[row.mark])} aria-label={`Question ${row.number}`}>
        {row.number}
      </span>
      <div className={x.rowBody}>
        <div className={x.rowTop}>
          <p className={x.rowQ}>{row.question || `Question ${row.number}`}</p>
          {row.mark === 'correct' && (
            <span className={cx(x.mTag, x.mOk)}>
              <Icon name="check" size={14} /> Correct
            </span>
          )}
          {row.mark === 'partial' && <span className={cx(x.mTag, x.mBad)}>{row.marks} correct</span>}
          {row.mark === 'wrong' && (
            <span className={cx(x.mTag, x.mBad)}>
              <Icon name="close" size={14} /> Wrong
            </span>
          )}
          {row.mark === 'blank' && <span className={cx(x.mTag, x.mBlank)}>Blank</span>}
        </div>
        {row.mark === 'unknown' ? (
          <p className={cx(x.small, x.italic)}>Your answer not recorded</p>
        ) : (
          <p className={x.line}>
            <span className={x.lbl}>Your answer</span>
            <span className={cx(!row.given ? x.gNone : wrongish ? x.gBad : x.gOk, row.mark === 'wrong' && x.strike)}>{row.given || '(no answer)'}</span>
          </p>
        )}
        {showKey && (
          <p className={x.line}>
            <span className={x.lbl}>Correct answer</span>
            <span className={x.keyText}>{row.correct}</span>
          </p>
        )}
        {row.also && <p className={x.small}>Also accepted: {row.also}</p>}
        {row.details && (
          <button type="button" className={x.toggle} onClick={onToggle} aria-expanded={open} aria-controls={id}>
            {open ? `Hide ${row.details.label}` : `Show ${row.details.label}`}
            <Icon name={open ? 'expand_less' : 'expand_more'} size={16} />
          </button>
        )}
        {open && row.details && (
          <div id={id} className={x.cardCol} style={{ gap: 8 }}>
            {row.details.explanation.length > 0 && (
              <p className={x.boxText}>
                <Segs segs={row.details.explanation} />
              </p>
            )}
            {row.details.boxes.map((b) => (
              <div key={b.title} className={x.box}>
                <span className={x.boxTitle}>{b.title}</span>
                {b.lines.map((l, i) => (
                  <p key={i} className={x.boxText}>
                    {l.head && <b style={{ fontSize: 12, color: 'var(--text-muted)' }}>{l.head}</b>}
                    <Segs segs={l.segs} />
                  </p>
                ))}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function ObjectiveTab({ o, filter, setFilter, toggled, toggle }: { o: ObjectiveView; filter: number; setFilter: (n: number) => void; toggled: Set<string>; toggle: (k: string) => void }) {
  if (!o.groups.length) {
    return (
      <Empty icon={o.name === 'Listening' ? 'headphones' : 'menu_book'} title="Questions unavailable">
        The {o.name} test of this mock is not in the content bank any more.
      </Empty>
    );
  }
  const f = o.recorded ? filter : 0;
  const passes = (m: Mark) => (f === 1 ? m === 'wrong' || m === 'partial' : f === 2 ? m === 'blank' : true);
  const ratio = o.correct === null || !o.total ? 0 : Math.max(0, Math.min(1, o.correct / o.total));
  let heading = '';
  let shown = 0;
  const blocks: ReactNode[] = [];
  o.groups.forEach((g, gi) => {
    const rows = g.rows.filter((r) => passes(r.mark));
    if (!rows.length) return;
    if (g.heading !== heading) {
      heading = g.heading;
      blocks.push(
        <div key={`h${gi}`} className={x.unitHead}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <h2 className={x.unitTitle}>{g.heading}</h2>
            {g.unitTitle && <span className={x.unitSub}>{g.unitTitle}</span>}
          </div>
        </div>,
      );
    }
    shown += rows.length;
    blocks.push(
      <Card key={`g${gi}`} padding="14px 16px 12px" radius={24}>
        <p className={x.groupMeta}>{g.meta}</p>
        {g.title && <p className={x.groupTitle}>{g.title}</p>}
        <div className={x.rows}>
          {rows.map((r) => {
            const def = r.mark === 'wrong' || r.mark === 'partial' || r.mark === 'blank';
            return <AnswerRow key={r.key} row={r} open={def !== toggled.has(r.key)} onToggle={() => toggle(r.key)} />;
          })}
        </div>
      </Card>,
    );
  });

  return (
    <>
      <HeroCard padding={20} radius={28}>
        <div className={x.heroRow}>
          <div className={x.heroCol}>
            <span className={x.heroLabel}>{o.name} score</span>
            <span className={x.heroBig}>
              {o.correct === null ? '–' : o.correct} / {o.total}
            </span>
          </div>
          <span className={x.bandPill}>Band {fmt(o.band)}</span>
        </div>
        <div className={x.heroTrack} role="progressbar" aria-valuemin={0} aria-valuemax={o.total} aria-valuenow={o.correct ?? 0} aria-label={`${o.name} score`}>
          <span style={{ width: `${ratio * 100}%` }} />
        </div>
        {o.recorded && (
          <p className={x.heroNote} style={{ margin: '10px 0 0' }}>
            {o.correct} correct · {o.wrong} wrong · {o.blank} blank
          </p>
        )}
      </HeroCard>
      {o.recorded ? (
        <div className={x.chips} role="group" aria-label="Show">
          {(
            [
              [0, 'All', o.total],
              [1, 'Wrong', o.wrong],
              [2, 'Blank', o.blank],
            ] as const
          ).map(([i, label, n]) => (
            <button key={i} type="button" className={cx(x.chip, f === i && x.chipOn)} aria-pressed={f === i} onClick={() => setFilter(i)}>
              {label} <span className={x.chipCount}>{n}</span>
            </button>
          ))}
        </div>
      ) : (
        <Card padding="12px 14px" radius={20}>
          <div className={x.note}>
            <Icon name="info" size={18} />
            <span>Your answers were not recorded for this mock, so this is the answer key only.</span>
          </div>
        </Card>
      )}
      {blocks}
      {shown === 0 && (
        <Empty icon="check_circle" title={f === 1 ? 'No wrong answers' : 'No blank answers'}>
          {f === 1 ? `Every answered question in ${o.name} was correct.` : `You answered every ${o.name} question.`}
        </Empty>
      )}
    </>
  );
}

/** G12 · Mock answer review (mock_answers_screen.dart): Listening / Reading against the key, both essays and the Speaking parts. */
export function MockAnswers({ initialTab, listening, reading, writing, speaking }: MockAnswersProps) {
  const [tab, setTab] = useState(Math.max(0, Math.min(3, initialTab)));
  const [filters, setFilters] = useState<[number, number]>([0, 0]);
  const [toggled, setToggled] = useState<Set<string>>(new Set());
  const toggle = (k: string) =>
    setToggled((s) => {
      const n = new Set(s);
      if (!n.delete(k)) n.add(k);
      return n;
    });

  return (
    <>
      <div className={x.seg} role="tablist" aria-label="Section">
        {TABS.map((t, i) => (
          <button key={t} type="button" role="tab" aria-selected={tab === i} className={cx(x.segBtn, tab === i && x.segOn)} onClick={() => setTab(i)}>
            {t}
          </button>
        ))}
      </div>

      <div className={x.page} role="tabpanel" aria-label={TABS[tab]}>
        {tab < 2 && (
          <ObjectiveTab
            o={tab === 0 ? listening : reading}
            filter={filters[tab]}
            setFilter={(n) => setFilters((f) => (tab === 0 ? [n, f[1]] : [f[0], n]))}
            toggled={toggled}
            toggle={toggle}
          />
        )}

        {tab === 2 && (
          <>
            <HeroCard padding={20} radius={28}>
              <div className={x.heroRow}>
                <div className={x.heroCol}>
                  <span className={x.heroLabel}>Writing band</span>
                  <span className={x.heroBig}>{fmt(writing.band)}</span>
                </div>
                <span className={x.heroNote}>Task 2 counts double</span>
              </div>
              {Object.keys(writing.criteria).length > 0 && <Crits keys={['TA', 'CC', 'LR', 'GRA']} values={writing.criteria} onHero />}
            </HeroCard>
            <div className={x.two}>
              {writing.tasks.map((t) => (
                <Card key={t.task} padding="16px 18px 18px" radius={26}>
                  <div className={x.cardCol}>
                    <div className={x.cardHead}>
                      <Tag>Task {t.task}</Tag>
                      <h3 className={x.cardTitle}>{t.title || `Writing Task ${t.task}`}</h3>
                      {t.band !== null && t.band > 0 && <Tag tone="primary">Band {fmt(t.band)}</Tag>}
                    </div>
                    <p className={x.muted}>{t.prompt || 'Prompt not found in the content bank.'}</p>
                    <hr className={x.hair} />
                    <div className={x.spread}>
                      <b style={{ fontSize: 14, fontWeight: 500 }}>Your answer</b>
                      {t.words > 0 && <span className={x.small}>{t.words} words</span>}
                    </div>
                    {t.essay ? (
                      <div className={x.box}>
                        <p className={x.para}>{t.essay}</p>
                      </div>
                    ) : (
                      <p className={cx(x.muted, x.italic)}>Essay not recorded for this mock.</p>
                    )}
                    {Object.keys(t.criteria).length > 0 && <Crits keys={['TA', 'CC', 'LR', 'GRA']} values={t.criteria} />}
                    {t.summary && <p className={x.para}>{t.summary}</p>}
                    {t.modelHref && (
                      <Link href={t.modelHref} className={x.outline}>
                        <Icon name="article" size={18} /> See the model answer
                      </Link>
                    )}
                  </div>
                </Card>
              ))}
            </div>
          </>
        )}

        {tab === 3 && (
          <>
            <HeroCard padding={20} radius={28}>
              <div className={x.heroRow}>
                <div className={x.heroCol}>
                  <span className={x.heroLabel}>Speaking band</span>
                  <span className={x.heroBig}>{fmt(speaking.band)}</span>
                </div>
                {speaking.spoken && <span className={x.heroNote}>Spoke {speaking.spoken} min</span>}
              </div>
              {Object.keys(speaking.criteria).length > 0 && <Crits keys={['FC', 'LR', 'GRA', 'P']} values={speaking.criteria} onHero />}
              {speaking.summary && <p className={x.heroText}>{speaking.summary}</p>}
            </HeroCard>
            {speaking.parts.map((p) => (
              <Card key={p.part} padding="16px 18px 18px" radius={26}>
                <div className={x.cardCol} style={{ gap: 10 }}>
                  <div className={x.cardHead}>
                    <span className={x.letter}>P{p.part}</span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <h3 className={x.cardTitle} style={{ display: 'block' }}>
                        {p.title}
                      </h3>
                      {p.sub && <span className={x.cardSub}>{p.sub}</span>}
                    </div>
                  </div>
                  {p.recordingKey && <RecordingPlayer storageKey={p.recordingKey} label="Play my answer" />}
                  {!p.questions.length && <p className={x.muted}>Questions not found in the content bank.</p>}
                  {p.questions.map((q, i) => (
                    <div key={i} className={x.qline}>
                      <b>{i + 1}</b>
                      <span>{q}</span>
                    </div>
                  ))}
                  {p.bullets.length > 0 && (
                    <div className={x.box}>
                      <span className={x.boxTitle}>You should say</span>
                      {p.bullets.map((b) => (
                        <p key={b} className={x.boxText}>
                          •&nbsp; {b}
                        </p>
                      ))}
                    </div>
                  )}
                  {p.transcript ? (
                    <div className={x.box}>
                      <span className={x.boxTitle}>Your answer (transcript)</span>
                      <p className={x.para}>{p.transcript}</p>
                    </div>
                  ) : (
                    <p className={cx(x.small, x.italic)}>
                      {p.recordingKey
                        ? 'Transcript not recorded · play your recording above.'
                        : p.onPhone
                          ? 'Transcript not recorded · the recording is kept on the phone you took this mock on.'
                          : 'Transcript and recording not recorded for this part.'}
                    </p>
                  )}
                </div>
              </Card>
            ))}
          </>
        )}
      </div>
    </>
  );
}

export function MockAnswersEmpty() {
  return (
    <Empty icon="checklist" title="No mock answers yet" action={<PrimaryButton href="/app/mocks">Start a mock test</PrimaryButton>}>
      Finish a full mock test to review every answer against the key.
    </Empty>
  );
}
