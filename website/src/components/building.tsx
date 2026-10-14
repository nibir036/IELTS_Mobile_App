import { Card, Nexi, PrimaryButton } from './ui';

/** A screen that is in the app but not on the website yet (said plainly). */
export function BuildingScreen({ title, note }: { title: string; note?: string }) {
  return (
    <Card padding={24}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
        <Nexi pose="point" height={110} />
        <div style={{ flex: 1, minWidth: 220, display: 'flex', flexDirection: 'column', gap: 8 }}>
          <h1 style={{ margin: 0, fontSize: 24, fontWeight: 600, letterSpacing: -0.4 }}>{title}</h1>
          <p style={{ margin: 0, color: 'var(--text-soft)' }}>
            {note ?? 'This screen is coming to the website soon. It already works in the IELTS AI app, with the same account and progress.'}
          </p>
          <div style={{ marginTop: 6 }}>
            <PrimaryButton href="/app" leading="arrow_back">
              Back to Home
            </PrimaryButton>
          </div>
        </div>
      </div>
    </Card>
  );
}
