import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Card, HeroCard, Icon, Nexi, PrimaryButton, SectionTitle, SoftButton } from '@/components/ui';
import { attempt } from '@/lib/server/attempts';
import { formatBand, rewriteLabel, rewriteTarget, wordCount, type Issue } from '@/lib/writing/analysis';
import s from './result.module.css';

export const metadata: Metadata = { title: 'Essay feedback' };

type Row = Record<string, unknown>;
const str = (v: unknown) => (v == null ? '' : String(v));
const list = (v: unknown): string[] => (Array.isArray(v) ? v.map((x) => (typeof x === 'string' ? x : str((x as Row)?.text ?? (x as Row)?.note))).filter(Boolean) : []);

/** C5 · Essay feedback (writing_band_report_screen.dart + line review). */
export default async function Result({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const a = await attempt(decodeURIComponent(id));
  if (!a || a.skill !== 'writing') notFound();
  // The app's shape, or the server's (data.evaluation) for an attempt the app hasn't adopted.
  const ev = (a.data.evaluation ?? {}) as Row;
  const d = a.data;
  const task = Number(d.task ?? ev.task ?? (a.kind.endsWith('1') ? 1 : 2)) === 1 ? 1 : 2;
  const crit = ((d.criteria ?? ev.criteria) ?? {}) as Record<string, number>;
  const critFb = ((d.criteriaFeedback ?? ev.criteriaFeedback) ?? {}) as Record<string, string>;
  const text = str(d.text);
  const summary = str(d.summary ?? ev.summary);
  const strengths = list(d.aiStrengths ?? ev.strengths);
  const suggestions = list(d.feedback ?? ev.feedback).slice(0, 3);
  const snippet = str(d.enhancedSnippet ?? ev.enhancedSnippet);
  const issues = (Array.isArray(d.issues) ? (d.issues as Issue[]) : []).filter((i) => typeof i.start === 'number' && text.slice(i.start, i.end) === i.original);
  const words = Number(d.words ?? ev.words) || wordCount(text);
  const criteria: Array<[string, string]> = [
    ['TA', task === 1 ? 'Task Achievement' : 'Task Response'],
    ['CC', 'Coherence & Cohesion'],
    ['LR', 'Lexical Resource'],
    ['GRA', 'Grammatical Range & Accuracy'],
  ];

  // The essay split into plain text and marked issues.
  const parts: Array<{ t: string; issue?: Issue; n?: number }> = [];
  let pos = 0;
  issues
    .slice()
    .sort((x, y) => x.start - y.start)
    .forEach((i, k) => {
      if (i.start < pos) return;
      if (i.start > pos) parts.push({ t: text.slice(pos, i.start) });
      parts.push({ t: text.slice(i.start, i.end), issue: i, n: k + 1 });
      pos = i.end;
    });
  if (pos < text.length) parts.push({ t: text.slice(pos) });

  const date = new Date(a.createdAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Dhaka' });

  return (
    <>
      <div className={s.top}>
        <Link href="/app/writing" className={s.back} aria-label="Back to Writing">
          <Icon name="arrow_back" size={20} />
        </Link>
        <h1 className={s.h1}>Essay feedback</h1>
      </div>

      <HeroCard>
        <div className={s.hero}>
          <div className={s.heroText}>
            <span className={s.heroLabel}>Estimated band</span>
            <span className={s.band}>{formatBand(a.band)}</span>
            <span className={s.heroMeta}>
              Task {task} · {a.title} · {words} words · {date}
            </span>
          </div>
          <Nexi pose={(a.band ?? 0) >= 7 ? 'thumbs' : 'writing'} height={120} />
        </div>
      </HeroCard>

      <div className={s.criteria}>
        {criteria.map(([k, name]) => {
          const b = typeof crit[k] === 'number' ? crit[k] : a.band ?? 0;
          return (
            <Card key={k} padding={16}>
              <div className={s.critHead}>
                <span className={s.critName}>{name}</span>
                <span className={s.critBand}>{formatBand(b)}</span>
              </div>
              <div className={s.track}>
                <span style={{ width: `${Math.max(4, (b / 9) * 100)}%` }} />
              </div>
              {critFb[k] && <p className={s.critText}>{critFb[k]}</p>}
            </Card>
          );
        })}
      </div>

      {summary && (
        <Card padding={18}>
          <SectionTitle>Summary</SectionTitle>
          <p className={s.para}>{summary}</p>
        </Card>
      )}

      <div className={s.two}>
        {strengths.length > 0 && (
          <Card padding={18}>
            <SectionTitle>What you did well</SectionTitle>
            <ul className={s.bullets}>
              {strengths.map((x) => (
                <li key={x}>
                  <Icon name="check_circle" size={18} color="var(--success)" />
                  <span>{x}</span>
                </li>
              ))}
            </ul>
          </Card>
        )}
        {suggestions.length > 0 && (
          <Card padding={18}>
            <SectionTitle>Top suggestions</SectionTitle>
            <ol className={s.numbers}>
              {suggestions.map((x) => (
                <li key={x}>{x}</li>
              ))}
            </ol>
          </Card>
        )}
      </div>

      {text && (
        <Card padding={18}>
          <SectionTitle>Line by line</SectionTitle>
          <p className={s.muted}>
            {issues.length ? `${issues.length} point${issues.length === 1 ? '' : 's'} to fix, marked in your ${task === 1 ? 'report' : 'essay'}.` : 'No line-level issues were marked.'}
          </p>
          <div className={s.essay}>
            {parts.map((p, i) =>
              p.issue ? (
                <mark key={i} className={p.issue.type === 'vocab' ? s.markVocab : s.markGrammar} title={`${p.issue.title}: ${p.issue.suggestion}`}>
                  {p.t}
                  <sup>{p.n}</sup>
                </mark>
              ) : (
                <span key={i}>{p.t}</span>
              ),
            )}
          </div>
          {issues.length > 0 && (
            <ol className={s.issues}>
              {issues.map((i, k) => (
                <li key={i.id ?? k}>
                  <span className={i.type === 'vocab' ? s.tagVocab : s.tagGrammar}>{i.title}</span>
                  <p className={s.fix}>
                    <s>{i.original}</s> <Icon name="arrow_forward" size={14} /> <b>{i.suggestion}</b>
                  </p>
                  {i.note && <p className={s.note}>{i.note}</p>}
                </li>
              ))}
            </ol>
          )}
        </Card>
      )}

      {snippet && (
        <Card padding={18}>
          <SectionTitle>A stronger version of one part</SectionTitle>
          <p className={s.para}>{snippet}</p>
        </Card>
      )}

      {text.trim() && (
        <Card href={`/app/writing/rewrite/${a.id}`} padding="14px 16px" radius={22}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <Icon name="auto_fix_high" size={22} color="var(--peach)" />
            <span style={{ flex: 1 }}>
              <b style={{ display: 'block', fontSize: 15 }}>{rewriteLabel(rewriteTarget(a.band, (d.rewrite ?? null) as { text?: string; target?: number } | null))}</b>
              <span className={s.muted} style={{ margin: 0 }}>
                Your essay side by side with a stronger rewrite, and what changed
              </span>
            </span>
            <Icon name="arrow_forward" size={18} color="var(--text-muted)" />
          </div>
        </Card>
      )}

      <div className={s.actions}>
        <SoftButton href={`/app/writing/samples/${str(d.promptId ?? a.refId)}`} leading="article">
          Sample answers
        </SoftButton>
        <PrimaryButton href={`/app/writing/questions/${task}`} trailing="arrow_forward">
          Write another
        </PrimaryButton>
      </div>
    </>
  );
}
