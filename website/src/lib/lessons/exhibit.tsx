// Lesson exhibits of the "How to attempt …" lessons (reading/exhibits.dart →
// ReadingExhibit with plain gaps): summary, notes, table, flow-chart and a
// picture-less diagram. They quote the English test paper, so always LTR.

import { Fragment, type ReactNode } from 'react';
import { Icon } from '@/components/ui';
import { rows, str, strs, type Raw } from '../practice/marking';
import s from './lessons.module.css';

const GAP = /\((\d+)\)\s*_{2,}/g;

/** Text with its "(n) ______" gaps drawn as numbered slots (GapText). */
export function GapText({ text }: { text: string }): ReactNode {
  const out: ReactNode[] = [];
  let pos = 0;
  for (const m of text.matchAll(GAP)) {
    const at = m.index ?? 0;
    if (at > pos) out.push(<Fragment key={`t${pos}`}>{text.slice(pos, at)}</Fragment>);
    out.push(
      <span key={`g${at}`} className={s.gap}>
        ({m[1]}) ______
      </span>,
    );
    pos = at + m[0].length;
  }
  if (pos < text.length) out.push(<Fragment key={`t${pos}`}>{text.slice(pos)}</Fragment>);
  return <>{out}</>;
}

function Panel({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className={s.exhibit} dir="ltr">
      {title && <p className={s.exhibitTitle}>{title}</p>}
      {children}
    </div>
  );
}

export function Exhibit({ data }: { data: Raw }) {
  const kind = str(data.kind);
  const title = str(data.title);
  switch (kind) {
    case 'summary':
      return (
        <Panel title={title}>
          <p className={s.exText}>
            <GapText text={str(data.text)} />
          </p>
        </Panel>
      );
    case 'notes':
      return (
        <Panel title={title}>
          <div className={s.notes}>
            {rows(data.lines).map((l, i) =>
              Number(l.level) === 0 ? (
                <p key={i} className={s.noteHead}>
                  <GapText text={str(l.text)} />
                </p>
              ) : (
                <p key={i} className={s.noteLine} style={{ paddingInlineStart: 10 * (Number(l.level) || 1) }}>
                  <span aria-hidden>•</span>
                  <span>
                    <GapText text={str(l.text)} />
                  </span>
                </p>
              ),
            )}
          </div>
        </Panel>
      );
    case 'table': {
      const columns = strs(data.columns);
      const body = (Array.isArray(data.rows) ? data.rows : []).filter(Array.isArray).map((r) => (r as unknown[]).map(str));
      const width = Math.max(columns.length, ...body.map((r) => r.length), 0);
      if (!width) return null;
      const cells = Array.from({ length: width }, (_, j) => j);
      return (
        <Panel title={title}>
          <div className={s.tableWrap}>
            <table className={s.table}>
              {columns.length > 0 && (
                <thead>
                  <tr>
                    {cells.map((j) => (
                      <th key={j} scope="col">
                        {columns[j] ?? ''}
                      </th>
                    ))}
                  </tr>
                </thead>
              )}
              <tbody>
                {body.map((r, i) => (
                  <tr key={i}>
                    {cells.map((j) => (
                      <td key={j}>
                        <GapText text={r[j] ?? ''} />
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Panel>
      );
    }
    case 'flowchart': {
      const steps = Array.isArray(data.steps) ? data.steps : [];
      const arrow = (k: string) => (
        <span key={k} className={s.flowArrow} aria-hidden>
          <Icon name="keyboard_arrow_down" size={18} />
        </span>
      );
      const box = (t: string, k: string) => (
        <div key={k} className={s.flowBox}>
          <GapText text={t} />
        </div>
      );
      const out: ReactNode[] = [];
      steps.forEach((st, i) => {
        if (st && typeof st === 'object' && !Array.isArray(st)) {
          const branches = (Array.isArray((st as Raw).branches) ? ((st as Raw).branches as unknown[]) : []).filter(Array.isArray).map((b) => (b as unknown[]).map(str));
          if (!branches.length) return;
          out.push(
            <div key={`b${i}`} className={s.flowFork}>
              {branches.map((b, j) => (
                <div key={j} className={s.flowCol}>
                  {b.flatMap((t, k) => (k < b.length - 1 ? [box(t, `x${k}`), arrow(`a${k}`)] : [box(t, `x${k}`)]))}
                </div>
              ))}
            </div>,
          );
        } else {
          out.push(box(str(st), `s${i}`));
        }
        if (i < steps.length - 1) out.push(arrow(`a${i}`));
      });
      return (
        <Panel title={title}>
          <div className={s.flowCol}>
            {out}
          </div>
        </Panel>
      );
    }
    case 'diagram': {
      const labels = rows(data.labels);
      const side = (x: string) => labels.filter((l) => str(l.side) === x).sort((a, b) => Number(a.order) - Number(b.order));
      const caption = str(data.caption);
      return (
        <Panel title={title}>
          <div className={s.diagram}>
            <div className={s.diagramSide} style={{ textAlign: 'right' }}>
              {side('left').map((l, i) => (
                <span key={i}>
                  <GapText text={str(l.text)} />
                </span>
              ))}
            </div>
            <div className={s.diagramBox}>{caption || 'diagram'}</div>
            <div className={s.diagramSide}>
              {side('right').map((l, i) => (
                <span key={i}>
                  <GapText text={str(l.text)} />
                </span>
              ))}
            </div>
          </div>
        </Panel>
      );
    }
    default:
      return null;
  }
}
