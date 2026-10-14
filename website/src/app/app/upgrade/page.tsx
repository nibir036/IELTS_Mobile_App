import type { Metadata } from 'next';
import Link from 'next/link';
import { PassPicker } from '@/components/billing-actions';
import b from '@/components/billing.module.css';
import { Card, HeroCard, Icon, Nexi, SectionTitle } from '@/components/ui';
import { billingDate, higherPasses, whatsappLink, type Billing, type Plans } from '@/lib/billing';
import { api } from '@/lib/server/api';
import { getMe } from '@/lib/server/me';
import { uiPack } from '@/lib/server/packs';
import s from '../pages.module.css';

export const metadata: Metadata = { title: 'Pro plans' };

/** Plans page (lib/features/home/plans_screen.dart): web prices, paid with bKash. */
export default async function Upgrade({ searchParams }: { searchParams: Promise<{ upgrade?: string }> }) {
  const [me, ui, billing, q] = await Promise.all([
    getMe(),
    uiPack(),
    api<Billing>('/v1/billing').catch(() => null),
    searchParams,
  ]);
  const p = (((ui.home ?? {}) as { plans?: Plans }).plans ?? {}) as Plans;
  const all = p.passes ?? [];
  const current = billing?.current ?? null;
  const pro = Boolean(current) || me.usage.plan === 'pro';
  // Upgrading: only the passes longer than the one you hold.
  const passes = q.upgrade && billing?.highestPassId ? higherPasses(all, billing.highestPassId) : all;
  const list = passes.length ? passes : all;
  const lastEnd = current ? current.queued.at(-1)?.endsAt ?? current.endsAt : null;

  return (
    <>
      <HeroCard>
        <div className={s.heroRow}>
          <div className={s.heroText}>
            {pro && <span className={s.heroChip}>You’re on Pro</span>}
            <h1 className={s.heroTitle}>{q.upgrade ? 'Upgrade your plan' : p.headline ?? 'Go Pro'}</h1>
            <p className={s.heroSub}>{p.subhead}</p>
          </div>
          <Nexi pose="grad" height={110} />
        </div>
      </HeroCard>

      {current && (
        <Card padding={16}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            <Icon name="workspace_premium" size={22} />
            <span style={{ flex: 1, fontSize: 14 }}>
              {current.name} pass · until {billingDate(lastEnd!)}
            </span>
            <Link href="/app/profile/billing" style={{ fontSize: 14, fontWeight: 500 }}>
              Plans &amp; billing
            </Link>
          </div>
        </Card>
      )}

      <PassPicker
        passes={list}
        defaultPass={q.upgrade ? list[0]?.id : p.defaultPass}
        wallet={billing?.paymentMethod?.label ?? null}
        ready={billing?.bkash !== false}
        stackNote={lastEnd ? `Your new pass starts when your current access ends on ${billingDate(lastEnd)}, so you don’t lose any days.` : undefined}
        ctaNote={p.ctaNote}
      />

      <div className={s.grid2}>
        <Card padding={18}>
          <SectionTitle>{p.allAccessTitle ?? 'Everything is unlocked'}</SectionTitle>
          <ul style={{ listStyle: 'none', padding: 0, margin: '10px 0 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
            {(p.allAccess ?? []).map((x) => (
              <li key={x} style={{ display: 'flex', gap: 8, fontSize: 14 }}>
                <Icon name="check_circle" size={18} color="var(--success)" />
                {x}
              </li>
            ))}
          </ul>
        </Card>
        <Card padding={18}>
          <SectionTitle>Free vs Pro</SectionTitle>
          <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: 10, fontSize: 13.5 }}>
            <thead>
              <tr style={{ color: 'var(--text-muted)', textAlign: 'left' }}>
                <th style={{ padding: '6px 0', fontWeight: 500 }}>Feature</th>
                <th style={{ padding: '6px 8px', fontWeight: 500 }}>Free</th>
                <th style={{ padding: '6px 0', fontWeight: 500 }}>Pro</th>
              </tr>
            </thead>
            <tbody>
              {(p.features ?? []).map((f) => (
                <tr key={f.id} style={{ borderTop: '1px solid var(--divider)' }}>
                  <td style={{ padding: '8px 0' }}>{f.label}</td>
                  <td style={{ padding: '8px', color: 'var(--text-soft)' }}>{f.free === 'yes' ? '✓' : f.free === 'no' ? '–' : f.free}</td>
                  <td style={{ padding: '8px 0', fontWeight: 500 }}>{f.pro === 'yes' ? '✓' : f.pro}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>
      {p.pricingNote && <p className={s.muted}>{p.pricingNote}</p>}
      {!pro && p.supportWhatsapp && (
        <p className={b.support}>
          {p.supportLine ?? 'Facing issues with payment system? Contact our tech support at'}{' '}
          <a href={whatsappLink(p.supportWhatsapp)} target="_blank" rel="noopener noreferrer">
            WhatsApp
          </a>
        </p>
      )}
    </>
  );
}
