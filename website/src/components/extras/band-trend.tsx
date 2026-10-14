import x from './extras.module.css';

/**
 * Band trend of the last mocks (mock_results_screen.dart · _TrendPainter):
 * a line through each mock's overall band, with the target as a dashed guide.
 * Server-rendered SVG in percentages, so it fills any card width undistorted.
 */
export function BandTrend({ points, goal }: { points: Array<{ label: string; band: number }>; goal: number }) {
  const H = 64;
  const per = 26; // px per band
  const y = (v: number) => Math.max(5, Math.min(H - 5, 7 + (goal - v) * per));
  const n = points.length;
  const px = (i: number) => `${n === 1 ? 50 : 3 + (94 * i) / (n - 1)}%`;
  const desc = points.map((p) => `${p.label} ${p.band.toFixed(1)}`).join(', ');
  return (
    <div className={x.trendWrap}>
      <svg width="100%" height={H} role="img" aria-label={`Overall band by mock: ${desc}. Target ${goal.toFixed(1)}.`} style={{ display: 'block', overflow: 'visible' }}>
        <line x1="0%" x2="100%" y1={y(goal)} y2={y(goal)} stroke="var(--border)" strokeWidth={1} strokeDasharray="3 4" />
        {points.slice(1).map((p, i) => (
          <line key={`l${i}`} x1={px(i)} x2={px(i + 1)} y1={y(points[i].band)} y2={y(p.band)} stroke="var(--fill)" strokeWidth={2} strokeLinecap="round" />
        ))}
        {points.map((p, i) => {
          const last = i === n - 1;
          return (
            <circle key={i} cx={px(i)} cy={y(p.band)} r={last ? 5 : 3.5} fill={last ? 'var(--fill)' : 'var(--surface)'} stroke="var(--fill)" strokeWidth={2}>
              <title>{`${p.label}: ${p.band.toFixed(1)}`}</title>
            </circle>
          );
        })}
      </svg>
      <div className={x.trendLabels} aria-hidden>
        {points.map((p, i) => (
          <span key={i}>{p.label}</span>
        ))}
      </div>
    </div>
  );
}
