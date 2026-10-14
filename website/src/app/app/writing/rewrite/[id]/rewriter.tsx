'use client';

import Link from 'next/link';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Card, Icon, PrimaryButton } from '@/components/ui';
import {
  applyFixes,
  complexCount,
  formatBand,
  linkerCount,
  linkerMarks,
  locate,
  paragraphs,
  rareWordCount,
  rewriteLabel,
  rewriteTarget,
  type Issue,
  type Mark,
  type Segment,
} from '@/lib/writing/analysis';
import r from '../../result/[id]/result.module.css';
import s from './rewriter.module.css';

type Change = { from?: string; to?: string; why?: string };
type Rewrite = { text: string; target: number; changes: Change[] };
type AttemptHead = {
  id: string;
  skill: string;
  kind: string;
  title: string;
  refId: string;
  band: number | null;
  score: number | null;
  total: number | null;
  durationSec: number;
  createdAt: string;
};

const signed = (n: number) => (n > 0 ? `+${n}` : `${n}`);

function changeMarks(text: string, changes: Change[], key: 'from' | 'to', mark: 'cut' | 'new'): Mark[] {
  const used: Array<[number, number]> = [];
  const out: Mark[] = [];
  for (const c of changes) {
    const phrase = (c[key] ?? '').trim();
    if (!phrase) continue;
    const hit = locate(text, phrase, used);
    if (!hit) continue;
    used.push(hit);
    out.push({ start: hit[0], end: hit[1], mark });
  }
  return out;
}

function Column({ label, band, improved, paras }: { label: string; band: string; improved: boolean; paras: Segment[][] }) {
  return (
    <div className={`${s.col} ${improved ? s.colImproved : ''}`}>
      <div className={s.colHead}>
        <span className={s.colLabel}>{label}</span>
        {band && <span className={s.pill}>{band}</span>}
      </div>
      {paras.map((p, i) => (
        <p key={i} className={s.para}>
          {p.map((seg, j) =>
            seg.mark === 'cut' ? (
              <del key={j} className={s.cut}>
                {seg.text}
              </del>
            ) : seg.mark === 'new' ? (
              <mark key={j} className={s.added}>
                {seg.text}
              </mark>
            ) : (
              <span key={j}>{seg.text}</span>
            ),
          )}
        </p>
      ))}
    </div>
  );
}

/** Your essay beside a rewrite two bands up, with what changed (writing_rewriter_screen.dart). */
export function Rewriter({
  attempt,
  data,
  task,
  text,
  issues,
  promptText,
  dataText,
  model,
  cached,
  usedUp,
}: {
  attempt: AttemptHead;
  data: Record<string, unknown>;
  task: 1 | 2;
  text: string;
  issues: Issue[];
  promptText: string;
  dataText: string;
  model: string;
  cached: Rewrite | null;
  usedUp: boolean;
}) {
  const [rw, setRw] = useState<Rewrite | null>(cached);
  const target = rewriteTarget(attempt.band, rw);
  const label = rewriteLabel(target);
  const [loading, setLoading] = useState(!cached && Boolean(text.trim()) && !usedUp);
  const [upgrade, setUpgrade] = useState(!cached && usedUp);
  const [error, setError] = useState('');
  const [mode, setMode] = useState<0 | 1>(0);
  const [copied, setCopied] = useState(false);
  const asked = useRef(false);

  useEffect(() => {
    if (cached || !text.trim() || usedUp || asked.current) return;
    asked.current = true;
    const want = rewriteTarget(attempt.band, null);
    const ctl = new AbortController();
    const timeout = setTimeout(() => ctl.abort(), 95_000);
    (async () => {
      const res = await fetch('/api/v1/writing/rewrite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          task,
          // Task 1: the visual's data, so the rewrite uses the real figures.
          prompt: dataText ? `${promptText}\n\nData shown in the visual:\n${dataText}` : promptText,
          text,
          targetBand: want,
        }),
        signal: ctl.signal,
      }).catch(() => null);
      clearTimeout(timeout);
      const body = (await res?.json().catch(() => ({}))) as { text?: string; changes?: Change[]; error?: string } | undefined;
      if (res?.status === 402) {
        setUpgrade(true);
        setLoading(false);
        return;
      }
      if (!res?.ok || !body?.text?.trim()) {
        setError(body?.error ?? 'The rewrite couldn’t be written right now. Below are the fixes from your report.');
        setLoading(false);
        return;
      }
      const next: Rewrite = { text: body.text.trim(), target: want, changes: Array.isArray(body.changes) ? body.changes : [] };
      setRw(next);
      setLoading(false);
      // Keep it with the essay (the app shows the same rewrite).
      void fetch('/api/v1/attempts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...attempt, data: { ...data, rewrite: next } }),
      }).catch(() => null);
    })();
    return () => {
      clearTimeout(timeout);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const view = useMemo(() => {
    const changes = (rw?.changes ?? []).filter((c) => (c.to ?? '').trim() || (c.from ?? '').trim());
    const [fixed, fixMarks] = applyFixes(text, issues);
    const aiCuts = changeMarks(text, changes, 'from', 'cut');
    const issueMarks: Mark[] = issues.map((i) => ({ start: i.start, end: i.end, mark: 'cut' }));
    const yours = paragraphs(text, aiCuts.length ? aiCuts : issueMarks);
    let improvedText: string;
    let improvedMarks: Mark[];
    let improvedLabel: string;
    let improvedBand: string;
    if (rw) {
      improvedText = rw.text;
      improvedMarks = changeMarks(rw.text, changes, 'to', 'new');
      improvedLabel = label;
      improvedBand = formatBand(target);
    } else if (model) {
      improvedText = model;
      improvedMarks = linkerMarks(model, 'new');
      improvedLabel = 'Band 8 model';
      improvedBand = '8.0';
    } else {
      improvedText = fixed;
      improvedMarks = fixMarks;
      improvedLabel = 'Improved';
      improvedBand = '';
    }
    return {
      changes,
      yours,
      improvedText,
      improved: paragraphs(improvedText, improvedMarks),
      improvedLabel,
      improvedBand,
      stats: [
        { value: signed(rareWordCount(improvedText) - rareWordCount(text)), label: 'less common words' },
        { value: `${linkerCount(text)}→${linkerCount(improvedText)}`, label: 'linking devices' },
        { value: `${complexCount(text)}→${complexCount(improvedText)}`, label: 'complex sentences' },
      ],
    };
  }, [rw, text, issues, model, label, target]);

  const improvedCol = loading ? (
    <div className={`${s.col} ${s.loading}`}>
      <span className={s.spinner} />
      <span>Writing a {label}…</span>
    </div>
  ) : (
    <Column label={view.improvedLabel} band={view.improvedBand} improved paras={view.improved} />
  );

  return (
    <>
      <div className={r.top}>
        <Link href={`/app/writing/result/${attempt.id}`} className={r.back} aria-label="Back to the report">
          <Icon name="arrow_back" size={20} />
        </Link>
        <h1 className={r.h1} style={{ flex: 1 }}>
          Band comparison
        </h1>
        <button
          type="button"
          className={r.back}
          title="Copy improved version"
          aria-label="Copy improved version"
          disabled={loading}
          onClick={async () => {
            try {
              await navigator.clipboard.writeText(view.improvedText);
              setCopied(true);
              setTimeout(() => setCopied(false), 2000);
            } catch {}
          }}
        >
          <Icon name={copied ? 'check' : 'content_copy'} size={20} />
        </button>
      </div>

      {!text.trim() && <p className={r.muted}>This essay has no text to compare.</p>}

      {upgrade && !rw && (
        <Card padding="14px 16px" radius={20}>
          <div className={s.upgrade}>
            <Icon name="military_tech" size={22} />
            <span style={{ flex: 1 }}>Your free Band 8 rewrite is used. Below are the fixes from your report.</span>
            <PrimaryButton href="/app/upgrade" height={40}>
              Pro
            </PrimaryButton>
          </div>
        </Card>
      )}
      {error && <p className={r.muted}>{error}</p>}

      <div className={s.seg} role="tablist" aria-label="View">
        {['Side by side', 'Improved only'].map((l, i) => (
          <button key={l} type="button" role="tab" aria-selected={mode === i} className={mode === i ? s.segOn : ''} onClick={() => setMode(i as 0 | 1)}>
            {l}
          </button>
        ))}
      </div>

      {mode === 0 ? (
        <div className={s.side}>
          <Column label="Yours" band={formatBand(attempt.band)} improved={false} paras={view.yours} />
          {improvedCol}
        </div>
      ) : (
        improvedCol
      )}

      <Card padding="14px 16px" radius={22}>
        <h2 style={{ margin: '0 0 10px', fontSize: 15, fontWeight: 500 }}>What changed</h2>
        {view.changes.length > 0 && !loading ? (
          <div className={s.changes}>
            {view.changes.slice(0, 8).map((c, i) => (
              <div key={i} className={s.change}>
                <div>
                  {c.from?.trim() && <del>{c.from.trim()}</del>}
                  {c.from?.trim() && c.to?.trim() && <span>  →  </span>}
                  {c.to?.trim() && <b>{c.to.trim()}</b>}
                </div>
                {c.why?.trim() && <small>{c.why.trim()}</small>}
              </div>
            ))}
          </div>
        ) : (
          <div className={s.stats}>
            {view.stats.map((x) => (
              <div key={x.label} className={s.stat}>
                <b>{x.value}</b>
                <span>{x.label}</span>
              </div>
            ))}
          </div>
        )}
      </Card>

      <PrimaryButton href={`/app/writing/write/${encodeURIComponent(attempt.refId)}?from=${encodeURIComponent(attempt.id)}`} block height={56} leading="edit">
        Rewrite my essay with these changes
      </PrimaryButton>
    </>
  );
}
