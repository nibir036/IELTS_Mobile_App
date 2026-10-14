'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import b from '@/components/billing.module.css';
import h from '@/components/home/home.module.css';
import { Icon, PrimaryButton, Tag } from '@/components/ui';
import { saveLabel, taka, type Billing, type Pass } from '@/lib/billing';

const callbackURL = () => `${window.location.origin}/api/billing/bkash/callback`;

async function post(path: string, body: unknown, method = 'POST'): Promise<{ ok: boolean; data: Record<string, unknown> }> {
  try {
    const res = await fetch(`/api/v1/${path}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    return { ok: res.ok, data };
  } catch {
    return { ok: false, data: { error: 'Can’t reach the IELTS AI server. Please try again.' } };
  }
}

/** Sends the browser to bKash for [passId]; returns an error message on failure. */
async function payWithBkash(passId: string, autoRenew: boolean): Promise<string> {
  const r = await post('billing/bkash/start', { passId, autoRenew, callbackURL: callbackURL() });
  const url = String(r.data.bkashURL ?? '');
  if (r.ok && url) {
    window.location.href = url;
    return '';
  }
  return String(r.data.error ?? 'bKash could not be opened. Please try again.');
}

/** Pick a pass, keep auto-renewal on (default) and pay with bKash. */
export function PassPicker({
  passes,
  defaultPass,
  wallet,
  ready,
  stackNote,
  ctaNote,
}: {
  passes: Pass[];
  defaultPass?: string;
  /** Saved wallet label ("bKash 017•••••678"), if any. */
  wallet: string | null;
  /** bKash payments are set up on the server. */
  ready: boolean;
  /** Pro: "Starts after your current pass ends on …". */
  stackNote?: string;
  ctaNote?: string;
}) {
  const [sel, setSel] = useState(() => (passes.some((p) => p.id === defaultPass) ? defaultPass! : passes[0]?.id ?? ''));
  const [autoRenew, setAutoRenew] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const pass = passes.find((p) => p.id === sel);

  const pay = async () => {
    if (!pass || busy) return;
    setBusy(true);
    setError('');
    const err = await payWithBkash(pass.id, autoRenew);
    if (err) {
      setError(err);
      setBusy(false);
    }
  };

  return (
    <>
      <div className={b.passes} role="radiogroup" aria-label="Choose a pass">
        {passes.map((x) => {
          const on = x.id === sel;
          const save = saveLabel(x);
          return (
            <button key={x.id} type="button" role="radio" aria-checked={on} className={`${b.pass} ${on ? b.passOn : ''}`} onClick={() => setSel(x.id)}>
              <div className={b.passHead}>
                <span className={b.passName}>{x.name}</span>
                <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                  {(x.badge || x.label) && <Tag tone={x.badge ? 'primary' : 'peach'}>{x.badge ?? x.label}</Tag>}
                  <span className={b.radio} aria-hidden />
                </span>
              </div>
              <div className={b.price}>
                {x.priceWas && x.priceWas > x.price ? <span className={b.was}>{taka(x.priceWas)}</span> : null}
                <span className={b.priceNow}>{taka(x.price)}</span>
              </div>
              {save && <span className={b.save}>{save}</span>}
              <span className={b.perDay}>
                {x.days} days · about {taka(x.price / x.days)} a day{x.perDayNote ? `, ${x.perDayNote}` : ''}
              </span>
              {x.pitch && <p className={b.pitch}>{x.pitch}</p>}
            </button>
          );
        })}
      </div>

      <div className={b.checkout}>
        <label className={b.check}>
          <input type="checkbox" checked={autoRenew} onChange={(e) => setAutoRenew(e.target.checked)} />
          <span>
            Auto-renew with bKash
            <span className={b.checkSub}>
              {wallet ? `Uses your saved wallet (${wallet}). ` : 'Your bKash wallet is saved for renewals. '}
              We remind you a day before the pass ends; renewing then takes one tap and your bKash PIN. Turn it off any time in Plans &amp; billing.
            </span>
          </span>
        </label>
        {stackNote && <p className={b.muted}>{stackNote}</p>}
        {error && <p className={b.error}>{error}</p>}
        <div className={b.payRow}>
          <PrimaryButton onClick={pay} disabled={!pass || busy || !ready} trailing={busy ? undefined : 'arrow_forward'}>
            {busy ? 'Opening bKash…' : pass ? `Pay ${taka(pass.price)} with bKash` : 'Choose a pass'}
          </PrimaryButton>
          {!ready && <span className={b.muted}>Payments open soon.</span>}
        </div>
        {ctaNote && <p className={b.muted}>{ctaNote}</p>}
      </div>
    </>
  );
}

/** Plans & billing: auto-renew switch, renew now, remove wallet, add wallet. */
export function BillingControls({ billing, renewPassId, renewPrice, focusRenew }: { billing: Billing; renewPassId: string | null; renewPrice: number | null; focusRenew?: boolean }) {
  const router = useRouter();
  const [auto, setAuto] = useState(billing.current?.autoRenew ?? false);
  const [busy, setBusy] = useState<'' | 'toggle' | 'renew' | 'remove' | 'save'>('');
  const [error, setError] = useState('');
  const wallet = billing.paymentMethod;

  const toggle = async () => {
    if (busy) return;
    const next = !auto;
    if (next && !wallet) {
      // Turning it on needs a saved wallet: bKash saves it, then comes back here.
      setBusy('save');
      setError('');
      const r = await post('billing/bkash/save-method', { callbackURL: callbackURL() });
      const url = String(r.data.bkashURL ?? '');
      if (r.ok && url) {
        window.location.href = url;
        return;
      }
      setError(String(r.data.error ?? 'bKash could not be opened. Please try again.'));
      setBusy('');
      return;
    }
    setBusy('toggle');
    setError('');
    setAuto(next);
    const r = await post('billing', { autoRenew: next }, 'PATCH');
    if (!r.ok) {
      setAuto(!next);
      setError(String(r.data.error ?? 'Auto-renewal could not be changed.'));
    }
    setBusy('');
    router.refresh();
  };

  const renew = async () => {
    if (!renewPassId || busy) return;
    setBusy('renew');
    setError('');
    const err = await payWithBkash(renewPassId, true);
    if (err) {
      setError(err);
      setBusy('');
    }
  };

  const remove = async () => {
    if (busy) return;
    setBusy('remove');
    setError('');
    const r = await post('billing/payment-method', undefined, 'DELETE');
    if (!r.ok) setError(String(r.data.error ?? 'The wallet could not be removed.'));
    else setAuto(false);
    setBusy('');
    router.refresh();
  };

  return (
    <>
      {billing.current && (
        <div className={h.setting}>
          <Icon name="autorenew" size={22} className={h.settingIcon} />
          <span className={h.settingText}>
            <span>Auto-renewal</span>
            <span className={h.settingSub}>
              {auto ? 'On · we remind you a day before your pass ends, then you renew in one tap' : 'Off · your Pro access stops when the pass ends'}
            </span>
          </span>
          <button
            type="button"
            role="switch"
            aria-checked={auto}
            aria-label="Auto-renewal"
            className={`${h.switch} ${auto ? h.switchOn : ''}`}
            onClick={toggle}
            disabled={busy !== ''}
          />
        </div>
      )}

      <div className={h.setting}>
        <Icon name="account_balance_wallet" size={22} className={h.settingIcon} />
        <span className={h.settingText}>
          <span>Payment method</span>
          <span className={h.settingSub}>{wallet ? wallet.label : 'No wallet saved'}</span>
        </span>
        {wallet ? (
          <button type="button" className={b.linkDanger} onClick={remove} disabled={busy !== ''}>
            {busy === 'remove' ? 'Removing…' : 'Remove'}
          </button>
        ) : null}
      </div>

      {(billing.renewalDue || focusRenew) && renewPassId && renewPrice != null && billing.current && (
        <PrimaryButton block onClick={renew} disabled={busy !== ''} leading="autorenew">
          {busy === 'renew' ? 'Opening bKash…' : `Renew now · ${taka(renewPrice)}`}
        </PrimaryButton>
      )}
      {busy === 'save' && <p className={b.muted}>Opening bKash to save your wallet…</p>}
      {error && <p className={b.error}>{error}</p>}
    </>
  );
}
