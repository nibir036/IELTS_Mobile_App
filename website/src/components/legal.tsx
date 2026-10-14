import { Brand, Card } from './ui';
import { uiPack } from '@/lib/server/packs';

type Doc = { title?: string; intro?: string; sections?: Array<{ heading?: string; body?: string[] }> };
type Legal = { draftNote?: string; updated?: string; contactEmail?: string; terms?: Doc; privacy?: Doc };

/** Terms / Privacy, from the same text as the app's legal screen. */
export async function LegalPage({ which }: { which: 'terms' | 'privacy' }) {
  let legal: Legal = {};
  try {
    legal = (((await uiPack()).access ?? {}) as { legal?: Legal }).legal ?? {};
  } catch {
    legal = {};
  }
  const doc = legal[which] ?? {};
  return (
    <main style={{ maxWidth: 760, margin: '0 auto', padding: '20px var(--gutter) 48px', display: 'flex', flexDirection: 'column', gap: 16 }}>
      <Brand />
      <Card padding={24}>
        <h1 style={{ margin: 0, fontSize: 28, fontWeight: 600, letterSpacing: -0.6 }}>{doc.title ?? (which === 'terms' ? 'Terms of Use' : 'Privacy Policy')}</h1>
        {legal.updated && <p style={{ color: 'var(--text-muted)', fontSize: 13 }}>Updated {legal.updated}</p>}
        {legal.draftNote && <p style={{ background: 'var(--accent-soft)', borderRadius: 14, padding: '10px 14px', fontSize: 13.5 }}>{legal.draftNote}</p>}
        {doc.intro && <p style={{ color: 'var(--text-soft)' }}>{doc.intro}</p>}
        {(doc.sections ?? []).map((sec, i) => (
          <section key={i}>
            {sec.heading && <h2 style={{ fontSize: 17, fontWeight: 600, margin: '20px 0 6px' }}>{sec.heading}</h2>}
            {(sec.body ?? []).map((p, j) => (
              <p key={j} style={{ margin: '0 0 10px', color: 'var(--text-soft)', lineHeight: 1.55 }}>
                {p}
              </p>
            ))}
          </section>
        ))}
        {legal.contactEmail && (
          <p style={{ color: 'var(--text-muted)', fontSize: 13.5 }}>
            Questions: <a href={`mailto:${legal.contactEmail}`}>{legal.contactEmail}</a>
          </p>
        )}
      </Card>
    </main>
  );
}
