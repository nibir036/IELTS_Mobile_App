// Plans and billing shapes shared by the upgrade and billing pages
// (server: /v1/billing, content: ui pack › home.plans).

export interface Pass {
  id: string;
  name: string;
  label?: string;
  badge?: string;
  days: number;
  price: number;
  priceWas?: number;
  save?: 'percent' | 'amount' | string;
  pitch?: string;
  perDayNote?: string;
  compare?: string;
}

export interface Plans {
  headline?: string;
  subhead?: string;
  passes?: Pass[];
  defaultPass?: string;
  allAccessTitle?: string;
  allAccess?: string[];
  pricingLabel?: string;
  pricingNote?: string;
  ctaNote?: string;
  supportLine?: string;
  supportWhatsapp?: string;
  features?: Array<{ id: string; label: string; free: string; pro: string }>;
}

export interface Billing {
  currency: string;
  current: {
    passId: string;
    name: string;
    days: number;
    startedAt: string;
    endsAt: string;
    paidWith: string;
    autoRenew: boolean;
    queued: Array<{ passId: string; name: string; startsAt: string; endsAt: string }>;
  } | null;
  paymentMethod: { provider: string; label: string } | null;
  highestPassId: string | null;
  canUpgrade: boolean;
  renewalDue: boolean;
  bkash?: boolean;
}

export const taka = (n: number) => `BDT ${Math.round(n).toLocaleString('en-US')}`;

/** "14 Oct 2026" in Dhaka time. */
export const billingDate = (iso: string) =>
  new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Dhaka' });

/** "Save 41%" or "Save BDT 1,270" (the pass's `save` style); '' when there is no saving. */
export function saveLabel(p: Pick<Pass, 'price' | 'priceWas' | 'save'>): string {
  if (!p.priceWas || p.priceWas <= p.price) return '';
  return p.save === 'amount' ? `Save ${taka(p.priceWas - p.price)}` : `Save ${Math.round((1 - p.price / p.priceWas) * 100)}%`;
}

/** https://wa.me/8801626794269 from "+880 1626-794269". */
export const whatsappLink = (num: string) => `https://wa.me/${num.replace(/\D/g, '')}`;

/** Passes ranked above [id] (the longer ones), in content order. */
export function higherPasses(passes: Pass[], id: string | null): Pass[] {
  const i = passes.findIndex((p) => p.id === id);
  return i < 0 ? passes : passes.slice(i + 1);
}
