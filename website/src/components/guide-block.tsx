import { mediaUrl } from '@/lib/media';
import { GuideExercise, type ExerciseData } from './guide-exercise';
import { bold } from './rich-text';
import { Icon } from './ui';
import c from './course.module.css';

const s = (b: unknown[], i: number) => (i < b.length && b[i] != null ? String(b[i]) : '');
const strs = (b: unknown[], i: number) => (i < b.length && Array.isArray(b[i]) ? (b[i] as unknown[]).map(String) : []);

/** "✗ …" / "✓ …" line. */
function Mark({ ok, text, strong }: { ok: boolean; text: string; strong?: boolean }) {
  return (
    <div className={c.markRow} dir="ltr">
      <b style={{ color: ok ? 'var(--success)' : 'var(--danger)' }}>{ok ? '✓' : '✗'}</b>
      <span style={strong ? { fontWeight: 500 } : undefined}>{text}</span>
    </div>
  );
}

/**
 * One study-guide block (GuideBlock): ["p", text] · ["h"|"h2", text] ·
 * ["ul"|"ol", items] · ["tip"|"note", text] · ["ex"|"model", text] ·
 * ["table", cols, rows, caption?] · ["img", asset, caption] ·
 * ["pair", wrong, right, why] · ["box", kind, title, text, items] ·
 * ["exercise", {…}]. English examples stay left-to-right in every language.
 */
export function GuideBlock({ block }: { block: unknown[] }) {
  const type = s(block, 0);
  switch (type) {
    case 'h':
      return <h3 className={c.gh}>{bold(s(block, 1))}</h3>;
    case 'h2':
      return <h4 className={c.gh2}>{bold(s(block, 1))}</h4>;
    case 'note':
      return <div className={c.gNote}>{bold(s(block, 1))}</div>;
    case 'model':
      return (
        <div className={c.gModel} dir="ltr">
          {bold(s(block, 1))}
        </div>
      );
    case 'ex':
      return (
        <div className={c.gEx} dir="ltr">
          {bold(s(block, 1))}
        </div>
      );
    case 'tip':
      return (
        <div className={c.gTip}>
          <span className={c.gLabel}>
            <Icon name="lightbulb" size={15} /> Tip
          </span>
          <div>{bold(s(block, 1))}</div>
        </div>
      );
    case 'img': {
      const src = mediaUrl(s(block, 1));
      if (!src) return null;
      return (
        <figure className={c.gImg} dir="ltr">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={src} alt={s(block, 2)} loading="lazy" />
          {s(block, 2) && <figcaption>{s(block, 2)}</figcaption>}
        </figure>
      );
    }
    case 'ul':
    case 'ol': {
      const items = strs(block, 1);
      const Tag = type === 'ol' ? 'ol' : 'ul';
      return (
        <Tag className={c.gList}>
          {items.map((x, i) => (
            <li key={i}>{bold(x)}</li>
          ))}
        </Tag>
      );
    }
    case 'table': {
      const cols = strs(block, 1);
      const rows = Array.isArray(block[2]) ? (block[2] as unknown[]).filter(Array.isArray).map((r) => (r as unknown[]).map(String)) : [];
      const caption = s(block, 3);
      return (
        <div>
          <div className={c.gTableWrap}>
            <table className={c.gTable}>
              <thead>
                <tr>
                  {cols.map((h, i) => (
                    <th key={i}>{bold(h)}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => (
                  <tr key={i}>
                    {cols.map((_, j) => (
                      <td key={j}>{bold(r[j] ?? '')}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {caption && <p className={c.gCaption}>{caption}</p>}
        </div>
      );
    }
    case 'pair':
      return (
        <div className={c.gEx}>
          <Mark ok={false} text={s(block, 1)} />
          <Mark ok text={s(block, 2)} strong />
          {s(block, 3) && <div className={c.gWhy}>{bold(s(block, 3))}</div>}
        </div>
      );
    case 'box': {
      const kind = s(block, 1);
      const [icon, label, cls] =
        kind === 'l1' ? ['translate', 'Bangla speakers', c.gBoxL1] : kind === 'impact' ? ['military_tech', 'IELTS impact', c.gBoxImpact] : ['lightbulb', 'Tip', c.gNote];
      return (
        <div className={`${c.gBox} ${cls}`}>
          <span className={c.gLabel}>
            <Icon name={icon} size={15} /> {label}
          </span>
          {s(block, 2) && <div className={c.gBoxTitle}>{s(block, 2)}</div>}
          {s(block, 3) && <div>{bold(s(block, 3))}</div>}
          {strs(block, 4).map((it, i) => (
            <div key={i} className={c.gBoxItem}>
              {it.split('\n').map((l, j) =>
                l.startsWith('✗ ') || l.startsWith('✓ ') ? (
                  <Mark key={j} ok={l.startsWith('✓')} text={l.slice(2)} />
                ) : (
                  <div key={j}>{bold(l)}</div>
                ),
              )}
            </div>
          ))}
        </div>
      );
    }
    case 'exercise':
      return block[1] && typeof block[1] === 'object' ? <GuideExercise data={block[1] as ExerciseData} /> : null;
    default:
      return <p className={c.gP}>{bold(s(block, 1))}</p>;
  }
}
