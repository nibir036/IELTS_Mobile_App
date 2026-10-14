import { Brand, Card, Nexi, PrimaryButton } from '@/components/ui';

export default function NotFound() {
  return (
    <main style={{ maxWidth: 560, margin: '0 auto', padding: '20px var(--gutter)', display: 'flex', flexDirection: 'column', gap: 16 }}>
      <Brand />
      <Card padding={24}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
          <Nexi pose="point" height={100} />
          <div style={{ flex: 1, minWidth: 200 }}>
            <h1 style={{ margin: '0 0 6px', fontSize: 24 }}>Page not found</h1>
            <p style={{ margin: '0 0 12px', color: 'var(--text-soft)' }}>This page doesn&rsquo;t exist or has moved.</p>
            <PrimaryButton href="/">Go to the home page</PrimaryButton>
          </div>
        </div>
      </Card>
    </main>
  );
}
