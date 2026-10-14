'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { Icon } from './ui';
import { UpgradeDialog } from './upgrade-dialog';
import p from './plan.module.css';

/** "Get a sharper plan": the quick check (Pro), or the upgrade sheet. */
export function QuickCheckOffer({ pro, modules, back }: { pro: boolean; modules: string[]; back?: string }) {
  const [upgrade, setUpgrade] = useState(false);
  const inner = (
    <>
      <span className={p.circle}>
        <Icon name="quiz" size={22} />
      </span>
      <span style={{ flex: 1 }}>
        <span className={p.cardTitle}>{pro ? 'Get a sharper plan' : 'Get a sharper plan · Pro'}</span>
        <p className={p.cardText}>
          {pro
            ? 'A quick check (about 8 minutes) so your plan starts from what you can do.'
            : 'A quick check that starts your plan from what you can do. Part of Pro.'}
        </p>
      </span>
      <Icon name={pro ? 'arrow_forward' : 'lock'} size={20} color="var(--text-muted)" />
    </>
  );
  if (pro) {
    return (
      <Link href={`/app/plan/quick-check?modules=${encodeURIComponent(modules.join(','))}${back ? `&back=${encodeURIComponent(back)}` : ''}`} className={`${p.card} ${p.cardRow}`}>
        {inner}
      </Link>
    );
  }
  return (
    <>
      <button type="button" className={`${p.card} ${p.cardRow}`} onClick={() => setUpgrade(true)}>
        {inner}
      </button>
      {upgrade && <UpgradeDialog feature="quick_check" onClose={() => setUpgrade(false)} />}
    </>
  );
}

/** Reloads the page once after [ms] (the AI writes the week's note a few seconds after a change). */
export function RefreshSoon({ ms = 12000 }: { ms?: number }) {
  const router = useRouter();
  useEffect(() => {
    const id = setTimeout(() => router.refresh(), ms);
    return () => clearTimeout(id);
  }, [router, ms]);
  return null;
}
