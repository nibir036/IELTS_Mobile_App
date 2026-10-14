import type { Metadata } from 'next';
import Link from 'next/link';
import { BillingControls } from '@/components/billing-actions';
import b from '@/components/billing.module.css';
import h from '@/components/home/home.module.css';
import { HeroCard, Icon, PrimaryButton } from '@/components/ui';
import { billingDate, higherPasses, whatsappLink, type Billing, type Plans } from '@/lib/billing';
import { api, ApiError } from '@/lib/server/api';
import { getMe } from '@/lib/server/me';
import { uiPack } from '@/lib/server/packs';

export const metadata: Metadata = { title: 'Plans & billing' };

const PAID_WITH: Record<string, string> = { bkash: 'bKash', google_play: 'Google Play', admin: 'nextED', manual: 'nextED' };

/** Profile › Plans & billing: your pass, dates, auto-renewal, payment method, upgrade. */
export default async function BillingPage({ searchParams }: { searchParams: Promise<{ paid?: string; error?: string; renew?: string }> }) {
  const [q, ui, me] = await Promise.all([searchParams, uiPack().catch(() => ({}) as Record<string, unknown>), getMe()]);
  // Pro without a pass: demo accounts and Pro given by nextED.
  const proGiven = me.usage.plan === 'pro';
  let billing: Billing | null = null;
  let loadError = '';
  try {
    billing = await api<Billing>('/v1/billing');
  } catch (e) {
    loadError = e instanceof ApiError ? e.message : 'Your plan could not be loaded.';
  }
  const p = (((ui.home ?? {}) as { plans?: Plans }).plans ?? {}) as Plans;
  const passes = p.passes ?? [];
  const cur = billing?.current ?? null;
  const lastEnd = cur ? cur.queued.at(-1)?.endsAt ?? cur.endsAt : null;
  const renewPassId = cur ? cur.queued.at(-1)?.passId || cur.passId : null;
  const renewPass = passes.find((x) => x.id === renewPassId) ?? null;
  const canUpgrade = Boolean(billing?.canUpgrade) && higherPasses(passes, billing?.highestPassId ?? null).length > 0;
  const error = typeof q.error === 'string' ? q.error.slice(0, 300) : '';

  return (
    <div className={h.narrow}>
      <div className={h.top}>
        <Link href="/app/profile" className={h.back} aria-label="Back to Profile">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={h.topText}>
          <h1 className={h.h1} style={{ fontSize: 24, fontWeight: 600 }}>
            Plans &amp; billing
          </h1>
          <p className={h.sub}>{cur ? 'Your Pro pass and payments' : proGiven ? 'You’re on Pro' : 'You’re on the Free plan'}</p>
        </div>
      </div>

      {q.paid && <p className={b.ok}>All set. Your plan details are below.</p>}
      {error && <p className={b.error}>{error}</p>}
      {loadError && <p className={b.error}>{loadError}</p>}

      {cur ? (
        <HeroCard padding={20} radius={28}>
          <span className={h.overline}>Pro · {cur.name} pass</span>
          <div className={b.dates}>
            <div className={b.date}>
              <span>Started</span>
              <b>{billingDate(cur.startedAt)}</b>
            </div>
            <div className={b.date}>
              <span>Ends</span>
              <b>{billingDate(lastEnd!)}</b>
            </div>
          </div>
          <span className={h.heroMuted} style={{ display: 'block', marginTop: 12, fontSize: 13 }}>
            Paid with {PAID_WITH[cur.paidWith] ?? cur.paidWith}
            {cur.queued.length ? ` · ${cur.queued.map((x) => `${x.name} from ${billingDate(x.startsAt)}`).join(', ')}` : ''}
          </span>
        </HeroCard>
      ) : proGiven ? (
        <HeroCard padding={20} radius={28}>
          <span className={h.overline}>Pro</span>
          <p style={{ margin: '8px 0 0', fontSize: 15 }}>
            {me.user.isDemo ? 'This demo account has Pro included. Nothing to pay.' : 'Pro is included with your account. Nothing to pay.'}
          </p>
        </HeroCard>
      ) : (
        !loadError && (
          <HeroCard padding={20} radius={28}>
            <span className={h.overline}>Free plan</span>
            <p style={{ margin: '8px 0 14px', fontSize: 15 }}>Go Pro for every mock test, full AI feedback and the complete study plan.</p>
            <PrimaryButton href="/app/upgrade" trailing="arrow_forward">
              See plans
            </PrimaryButton>
          </HeroCard>
        )
      )}

      {billing && (
        <div className={h.settings}>
          <BillingControls billing={billing} renewPassId={renewPass?.id ?? null} renewPrice={renewPass?.price ?? null} focusRenew={q.renew === '1'} />
          {cur && canUpgrade && (
            <Link href="/app/upgrade?upgrade=1" className={h.setting}>
              <Icon name="upgrade" size={22} className={h.settingIcon} />
              <span className={h.settingText}>
                <span>Upgrade plan</span>
                <span className={h.settingSub}>Get a longer pass; it starts when this one ends</span>
              </span>
              <Icon name="chevron_right" size={20} className={h.settingIcon} />
            </Link>
          )}
        </div>
      )}

      {cur?.autoRenew && <p className={h.note}>bKash asks for your PIN on every payment, so renewal is one tap plus your PIN. We send a reminder by SMS and in the app a day before your pass ends.</p>}

      {!cur && !proGiven && p.supportWhatsapp && (
        <p className={b.support}>
          {p.supportLine ?? 'Facing issues with payment system? Contact our tech support at'}{' '}
          <a href={whatsappLink(p.supportWhatsapp)} target="_blank" rel="noopener noreferrer">
            WhatsApp
          </a>
        </p>
      )}
    </div>
  );
}
