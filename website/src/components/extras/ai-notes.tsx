import { Card, Icon } from '../ui';
import x from './extras.module.css';

type Raw = Record<string, unknown>;
const text = (d: Raw, k: string) => (typeof d[k] === 'string' ? (d[k] as string).trim() : '');

/** True when a section was scored by the app's offline estimator. */
export const scoredOffline = (d: Raw) => {
  const src = d.source;
  return Boolean(src && typeof src === 'object' && Object.values(src as Raw).some((v) => v === 'demo'));
};

/** "AI examiner notes" (MockAiNotes): Writing / Speaking summaries of a mock. */
export function AiNotes({ data }: { data: Raw }) {
  const rows = (
    [
      ['Writing', text(data, 'writingSummary')],
      ['Speaking', text(data, 'speakingSummary')],
    ] as const
  ).filter(([, t]) => t);
  const offline = scoredOffline(data);
  const note = <p className={x.small}>Estimated offline (AI unavailable)</p>;
  if (!rows.length) return offline ? <div style={{ textAlign: 'center' }}>{note}</div> : null;
  return (
    <Card padding={18} radius={28}>
      <div className={x.cardCol} style={{ gap: 10 }}>
        <div className={x.gainHead} style={{ padding: 0 }}>
          <Icon name="auto_awesome" size={16} color="var(--icon-accent)" /> AI examiner notes
        </div>
        {rows.map(([label, t]) => (
          <div key={label}>
            <p className={x.small}>{label}</p>
            <p className={x.para}>{t}</p>
          </div>
        ))}
        {offline && note}
      </div>
    </Card>
  );
}
