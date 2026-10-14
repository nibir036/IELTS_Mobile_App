'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import h from '@/components/home/home.module.css';
import d from '@/components/dialog.module.css';
import { ConfirmDialog } from '@/components/upgrade-dialog';
import { Icon, IconCircle, PrimaryButton, SoftButton } from '@/components/ui';
import { CONTENT_LANGS, LANG_KEY } from '@/lib/content/lang';
import { Portal } from '@/components/portal';

async function errorOf(res: Response | null, fallback: string): Promise<string> {
  if (!res) return 'Can’t reach the IELTS AI server. Please try again.';
  const data = (await res.json().catch(() => ({}))) as { error?: string };
  return data.error ?? fallback;
}

/** One settings row (_SettingRow) as a button. */
function RowButton({ icon, title, subtitle, trail, danger, chevron = true, onClick }: { icon: string; title: string; subtitle?: string; trail?: string; danger?: boolean; chevron?: boolean; onClick: () => void }) {
  return (
    <button type="button" className={`${h.setting} ${danger ? h.danger : ''}`} onClick={onClick}>
      <Icon name={icon} size={22} className={h.settingIcon} />
      <span className={h.settingText}>
        <span>{title}</span>
        {subtitle && <span className={h.settingSub}>{subtitle}</span>}
      </span>
      {trail && <span className={h.settingTrail}>{trail}</span>}
      {chevron && <Icon name="chevron_right" size={20} className={h.settingIcon} />}
    </button>
  );
}

function Sheet({ title, onClose, children, labelId }: { title: ReactNode; onClose: () => void; children: ReactNode; labelId: string }) {
  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby={labelId} onClick={onClose}>
      <div className={`${d.sheet} ${h.dialogScroll}`} onClick={(e) => e.stopPropagation()}>
        <h2 id={labelId} className={d.title}>
          {title}
        </h2>
        {children}
      </div>
    </div></Portal>
  );
}

export function LogoutButton() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <SoftButton
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        await fetch('/api/auth/logout', { method: 'POST' }).catch(() => null);
        router.replace('/login');
        router.refresh();
      }}
    >
      {busy ? 'Logging out…' : 'Log out'}
    </SoftButton>
  );
}

/** Log out (a danger row). */
export function LogoutRow() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  return (
    <RowButton
      icon="logout"
      title={busy ? 'Logging out…' : 'Log out'}
      danger
      chevron={false}
      onClick={async () => {
        if (busy) return;
        setBusy(true);
        await fetch('/api/auth/logout', { method: 'POST' }).catch(() => null);
        router.replace('/login');
        router.refresh();
      }}
    />
  );
}

export function RemoveDeviceButton({ id, name, cooldownDays = 30 }: { id: string; name: string; cooldownDays?: number }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [ask, setAsk] = useState(false);
  const [error, setError] = useState('');
  return (
    <>
      <SoftButton disabled={busy} onClick={() => setAsk(true)}>
        {busy ? 'Removing…' : 'Remove'}
      </SoftButton>
      {ask && (
        <ConfirmDialog
          title="Remove this device?"
          message={`“${name}” will be signed out and its place freed for another device. You can remove a device once every ${cooldownDays} days.`}
          confirm="Remove"
          cancel="Cancel"
          onCancel={() => setAsk(false)}
          onConfirm={async () => {
            setAsk(false);
            setBusy(true);
            const res = await fetch(`/api/v1/me/devices/${encodeURIComponent(id)}`, { method: 'DELETE' }).catch(() => null);
            setBusy(false);
            if (!res?.ok) setError(await errorOf(res, 'The device could not be removed.'));
            router.refresh();
          }}
        />
      )}
      {error && (
        <ConfirmDialog title="Couldn’t remove the device" message={error} confirm="OK" cancel="Close" onConfirm={() => setError('')} onCancel={() => setError('')} />
      )}
    </>
  );
}

type Theme = 'day' | 'night';

/** Appearance: Light / Dark (kept in this browser; the app keeps it per device too). */
export function AppearanceToggle() {
  const [theme, setTheme] = useState<Theme | null>(null);
  useEffect(() => {
    const attr = document.documentElement.getAttribute('data-theme');
    setTheme(attr === 'night' || attr === 'day' ? attr : window.matchMedia('(prefers-color-scheme: dark)').matches ? 'night' : 'day');
  }, []);
  const set = (t: Theme) => {
    document.documentElement.setAttribute('data-theme', t);
    try {
      localStorage.setItem('ia_theme', t);
    } catch {}
    setTheme(t);
  };
  return (
    <div className={`${h.seg} ${h.segSmall}`} role="radiogroup" aria-label="Appearance">
      {(
        [
          ['day', 'Light'],
          ['night', 'Dark'],
        ] as Array<[Theme, string]>
      ).map(([t, label]) => (
        <button key={t} type="button" role="radio" aria-checked={theme === t} className={`${h.segBtn} ${theme === t ? h.segOn : ''}`} onClick={() => set(t)}>
          {label}
        </button>
      ))}
    </div>
  );
}

/** Kept for older imports. */
export const ThemeToggle = AppearanceToggle;

const REGIONS: Record<string, string> = { bn: 'Bangladesh, India', ne: 'Nepal', ar: 'UAE, Saudi Arabia, Qatar, Oman, Kuwait', id: 'Indonesia' };

/** Explanation language (language_sheet.dart), kv `feedbackLanguage`. */
export function LanguageRow({ current, ready }: { current: string; ready: string[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState(current);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const cur = CONTENT_LANGS.find((l) => l.code === value) ?? CONTENT_LANGS[0];
  const pick = async (code: string) => {
    if (code === value || busy) return;
    const prev = value;
    setValue(code);
    setBusy(true);
    setError('');
    const res = await fetch(`/api/v1/state/${encodeURIComponent(LANG_KEY)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ value: code }),
    }).catch(() => null);
    setBusy(false);
    if (!res?.ok) {
      setValue(prev);
      setError(await errorOf(res, 'Could not save your language.'));
      return;
    }
    router.refresh();
  };
  return (
    <>
      <RowButton icon="translate" title="Explanation language" trail={cur.native} onClick={() => setOpen(true)} />
      {open && (
        <Sheet title="Language" labelId="lang-title" onClose={() => setOpen(false)}>
          <div className={h.form}>
            <span className={h.fieldLabel}>App language</span>
            <div className={h.setting} style={{ cursor: 'default' }}>
              <span className={h.settingText}>
                <span>English</span>
                <span className={h.settingSub} style={{ whiteSpace: 'normal' }}>
                  The app is in English, like the IELTS test itself.
                </span>
              </span>
              <Icon name="check" size={20} />
            </div>
            <span className={h.fieldLabel}>Explanations &amp; AI feedback</span>
            <p className={h.note} style={{ margin: 0, color: 'var(--text-soft)' }}>
              Lessons, answer explanations and AI band reports use this language. Passages, questions and your answers are always in English.
            </p>
            <div className={h.settings} role="radiogroup" aria-label="Explanation language">
              {CONTENT_LANGS.map((l) => {
                const on = l.code === value;
                const sub =
                  l.code === 'en' ? '' : `${REGIONS[l.code] ? `${REGIONS[l.code]} · ` : ''}${ready.includes(l.code) ? 'Examples stay in English' : 'AI feedback now · lessons coming soon'}`;
                return (
                  <button key={l.code} type="button" role="radio" aria-checked={on} className={h.setting} onClick={() => pick(l.code)} disabled={busy}>
                    <span className={h.settingText}>
                      <span>{l.code === 'en' ? 'English' : `${l.native} (${l.english})`}</span>
                      {sub && <span className={h.settingSub}>{sub}</span>}
                    </span>
                    <Icon name={on ? 'radio_button_checked' : 'radio_button_unchecked'} size={22} className={h.settingIcon} />
                  </button>
                );
              })}
            </div>
            {error && <p className={h.error}>{error}</p>}
            <PrimaryButton block onClick={() => setOpen(false)}>
              Done
            </PrimaryButton>
          </div>
        </Sheet>
      )}
    </>
  );
}

const strength = (p: string) => {
  let s = 0;
  if (p.length >= 8) s++;
  if (/\d/.test(p)) s++;
  if (/[^A-Za-z0-9]/.test(p)) s++;
  if (/[A-Z]/.test(p) && /[a-z]/.test(p) && p.length >= 10) s++;
  return s;
};
const isStrong = (p: string) => p.length >= 8 && /\d/.test(p) && /[^A-Za-z0-9]/.test(p);

/** Profile › Account › Change password (account_sheets.dart). */
export function ChangePasswordRow({ strengthLabels }: { strengthLabels: string[] }) {
  const [open, setOpen] = useState(false);
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [errs, setErrs] = useState<{ current?: string; next?: string; confirm?: string; form?: string }>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const score = strength(next);
  const strong = isStrong(next);
  const rule = next ? `${strengthLabels[score] ?? ''} · 8+ characters, a number and a symbol` : '8+ characters, a number and a symbol';
  const close = () => {
    setOpen(false);
    setCurrent('');
    setNext('');
    setConfirm('');
    setErrs({});
  };
  const submit = async () => {
    if (!current || !next || !confirm || busy) return;
    if (next !== confirm) return setErrs({ confirm: 'The new passwords don’t match.' });
    if (next === current) return setErrs({ next: 'Choose a password different from your current one.' });
    if (!strong) return setErrs({ next: 'Use 8+ characters with a number and a symbol.' });
    setBusy(true);
    setErrs({});
    const res = await fetch('/api/v1/me/password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ currentPassword: current, newPassword: next }),
    }).catch(() => null);
    setBusy(false);
    if (res?.ok) {
      close();
      setDone(true);
      return;
    }
    const data = res ? ((await res.json().catch(() => ({}))) as { error?: string; code?: string }) : {};
    const msg = data.error ?? 'Your password could not be changed.';
    if (data.code === 'wrong_password') setErrs({ current: msg });
    else if (data.code === 'weak_password') setErrs({ next: msg });
    else setErrs({ form: msg });
  };
  return (
    <>
      <RowButton icon="lock" title="Change password" onClick={() => setOpen(true)} />
      {open && (
        <Sheet title="Change password" labelId="pw-title" onClose={close}>
          <form
            className={h.form}
            onSubmit={(e) => {
              e.preventDefault();
              submit();
            }}
          >
            <p className={h.note} style={{ margin: 0 }}>
              Enter your current password, then choose a new one.
            </p>
            <label className={h.form} style={{ gap: 6 }}>
              <span className={h.fieldLabel}>Current password</span>
              <input className={h.input} type="password" autoComplete="current-password" placeholder="Your current password" value={current} onChange={(e) => (setCurrent(e.target.value), setErrs({}))} />
            </label>
            {errs.current && <p className={h.error}>{errs.current}</p>}
            <Link href="/forgot-password" className={h.linkBtn} style={{ alignSelf: 'flex-start', padding: 0 }}>
              Forgot current password?
            </Link>
            <label className={h.form} style={{ gap: 6 }}>
              <span className={h.fieldLabel}>New password</span>
              <input className={h.input} type="password" autoComplete="new-password" placeholder="Create a new password" value={next} onChange={(e) => (setNext(e.target.value), setErrs({}))} />
            </label>
            {errs.next && <p className={h.error}>{errs.next}</p>}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 4 }} aria-hidden>
              {[0, 1, 2, 3].map((i) => (
                <span key={i} style={{ height: 5, borderRadius: 3, background: i < score ? 'var(--fill)' : 'var(--track)' }} />
              ))}
            </div>
            <p className={h.note} style={{ margin: 0, color: next && !strong ? 'var(--danger)' : undefined }}>
              {rule}
            </p>
            <label className={h.form} style={{ gap: 6 }}>
              <span className={h.fieldLabel}>Confirm new password</span>
              <input className={h.input} type="password" autoComplete="new-password" placeholder="Type it again" value={confirm} onChange={(e) => (setConfirm(e.target.value), setErrs({}))} />
            </label>
            {errs.confirm && <p className={h.error}>{errs.confirm}</p>}
            {errs.form && <p className={h.error}>{errs.form}</p>}
            <PrimaryButton type="submit" block disabled={!current || !next || !confirm || busy}>
              {busy ? 'Updating…' : 'Update password'}
            </PrimaryButton>
            <button type="button" className={h.outlineBtn} onClick={close}>
              Cancel
            </button>
          </form>
        </Sheet>
      )}
      {done && <ConfirmDialog title="Password changed" message="Use your new password next time you sign in." confirm="OK" cancel="Close" onConfirm={() => setDone(false)} onCancel={() => setDone(false)} />}
    </>
  );
}

/** Profile › Delete account: password + typing DELETE (account_sheets.dart). */
export function DeleteAccountRow({ isDemo }: { isDemo: boolean }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [password, setPassword] = useState('');
  const [word, setWord] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const can = password.length > 0 && word.trim().toUpperCase() === 'DELETE';
  const close = () => {
    setOpen(false);
    setPassword('');
    setWord('');
    setError('');
  };
  const submit = async () => {
    if (!can || busy) return;
    setBusy(true);
    setError('');
    const res = await fetch('/api/v1/me', { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ password }) }).catch(() => null);
    if (!res?.ok) {
      setBusy(false);
      setError(await errorOf(res, 'Your account could not be deleted.'));
      return;
    }
    await fetch('/api/auth/logout', { method: 'POST' }).catch(() => null);
    router.replace('/login');
    router.refresh();
  };
  return (
    <>
      <RowButton icon="delete" title="Delete account" subtitle="Permanently remove your account and data" danger onClick={() => setOpen(true)} />
      {open && (
        <Sheet
          labelId="del-title"
          onClose={close}
          title={
            <span style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <IconCircle icon="delete" size={44} bg="var(--danger-soft)" fg="var(--danger)" />
              Delete account?
            </span>
          }
        >
          <form
            className={h.form}
            onSubmit={(e) => {
              e.preventDefault();
              submit();
            }}
          >
            <p className={h.note} style={{ margin: 0, fontSize: 14 }}>
              This permanently deletes your IELTS AI account, including:
            </p>
            <ul className={h.lostList}>
              {['All practice history, scores and bands', 'Your essays and speaking recordings', 'Milestones, study plan and saved items'].map((l) => (
                <li key={l}>
                  <Icon name="close" size={16} color="var(--danger)" />
                  {l}
                </li>
              ))}
            </ul>
            <div className={h.dangerBox}>
              {isDemo ? 'This can’t be undone. As this is the demo account, it will be restored with its demo data the next time the app launches.' : 'This can’t be undone.'}
            </div>
            <label className={h.form} style={{ gap: 6 }}>
              <span className={h.fieldLabel}>Password</span>
              <input className={h.input} type="password" autoComplete="current-password" placeholder="Enter your password" value={password} onChange={(e) => setPassword(e.target.value)} />
            </label>
            <label className={h.form} style={{ gap: 6 }}>
              <span className={h.fieldLabel}>Type DELETE to confirm</span>
              <input className={h.input} placeholder="DELETE" value={word} onChange={(e) => setWord(e.target.value)} autoCapitalize="characters" />
            </label>
            {error && <p className={h.error}>{error}</p>}
            <div className={h.dialogRow}>
              <button type="button" className={h.outlineBtn} onClick={close}>
                Cancel
              </button>
              <PrimaryButton type="submit" disabled={!can || busy} height={50}>
                {busy ? 'Deleting…' : 'Delete'}
              </PrimaryButton>
            </div>
          </form>
        </Sheet>
      )}
    </>
  );
}
