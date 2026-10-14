'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState, type FormEvent, type ReactNode } from 'react';
import { Icon, PrimaryButton, uiStyles as u } from './ui';

type Mode = 'signup' | 'reset';

/** The server's rule (server/src/routes/auth.ts), checked before a code is sent. */
const PASSWORD_RULE = 'Use 8+ characters with at least one number and one symbol.';
const strong = (p: string) => p.length >= 8 && /\d/.test(p) && /[^A-Za-z0-9]/.test(p);
type Step = 'details' | 'code' | 'password';

async function post(action: string, body: Record<string, unknown>) {
  const res = await fetch(`/api/auth/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  if (!res.ok) throw new Error(String(data.error ?? 'Something went wrong. Please try again.'));
  return data;
}

function Field({
  id,
  label,
  error,
  children,
}: {
  id: string;
  label: string;
  error?: string | null;
  children: ReactNode;
}) {
  return (
    <div className={u.field}>
      <label className={u.fieldLabel} htmlFor={id}>
        {label}
      </label>
      <div className={u.inputWrap}>{children}</div>
      {error && <span className={u.fieldError}>{error}</span>}
    </div>
  );
}

/** Sign-up (name, phone, password → SMS code) and Forgot password (phone → code → new password). */
export function AuthFlow({ mode }: { mode: Mode }) {
  const router = useRouter();
  const [step, setStep] = useState<Step>('details');
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [code, setCode] = useState('');
  const [proof, setProof] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [wait, setWait] = useState(0);
  const [devCode, setDevCode] = useState<string | null>(null);

  useEffect(() => {
    if (wait <= 0) return;
    const t = setTimeout(() => setWait(wait - 1), 1000);
    return () => clearTimeout(t);
  }, [wait]);

  const purpose = mode === 'signup' ? 'signup' : 'reset';

  async function sendCode() {
    const r = await post('otp-send', { phone: phone.trim(), purpose });
    setWait(Number(r.resendAfterSec ?? 45));
    setDevCode(typeof r.devCode === 'string' ? r.devCode : null);
  }

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong. Please try again.');
    } finally {
      setBusy(false);
    }
  }

  async function finish(withProof: string) {
    if (mode === 'signup') {
      await post('register', { name: name.trim(), phone: phone.trim(), password, proof: withProof });
    } else {
      await post('reset', { phone: phone.trim(), password, proof: withProof });
    }
    router.replace('/app');
    router.refresh();
  }

  function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    if (step === 'details') {
      if (mode === 'signup' && (!name.trim() || !strong(password))) {
        setError(!name.trim() ? 'Enter your name.' : PASSWORD_RULE);
        return;
      }
      void run(async () => {
        await sendCode();
        setStep('code');
      });
    } else if (step === 'code') {
      void run(async () => {
        const r = await post('otp-verify', { phone: phone.trim(), purpose, code: code.trim() });
        const p = String(r.proof ?? '');
        setProof(p);
        if (mode === 'signup') await finish(p);
        else setStep('password');
      });
    } else {
      if (!strong(password)) {
        setError(PASSWORD_RULE);
        return;
      }
      void run(() => finish(proof));
    }
  }

  const phoneField = (
    <Field id="phone" label="Phone number">
      <span className={u.prefix}>+880</span>
      <input
        id="phone"
        className={u.input}
        type="tel"
        inputMode="tel"
        autoComplete="tel-national"
        placeholder="1XXX XXXXXX"
        value={phone}
        onChange={(e) => setPhone(e.target.value)}
        required
      />
    </Field>
  );
  const passwordField = (label: string) => (
    <Field id="password" label={label}>
      <input
        id="password"
        className={u.input}
        type={show ? 'text' : 'password'}
        autoComplete="new-password"
        placeholder="8+ characters, a number and a symbol"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        required
      />
      <button type="button" className={u.eye} onClick={() => setShow(!show)} aria-label={show ? 'Hide password' : 'Show password'}>
        <Icon name={show ? 'visibility_off' : 'visibility'} size={20} />
      </button>
    </Field>
  );

  return (
    <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }} noValidate>
      {step === 'details' && (
        <>
          {mode === 'signup' && (
            <Field id="name" label="Your name">
              <input
                id="name"
                className={u.input}
                autoComplete="name"
                placeholder="Full name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
              />
            </Field>
          )}
          {phoneField}
          {mode === 'signup' && passwordField('Password')}
        </>
      )}

      {step === 'code' && (
        <>
          <p style={{ margin: 0, color: 'var(--text-soft)' }}>
            We sent a 6-digit code to <b>+880 {phone.replace(/^0/, '')}</b>.{' '}
            <button type="button" onClick={() => setStep('details')} style={{ border: 0, background: 'none', padding: 0, textDecoration: 'underline', cursor: 'pointer' }}>
              Change number
            </button>
          </p>
          <Field id="code" label="Code">
            <input
              id="code"
              className={u.input}
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              placeholder="6-digit code"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
              style={{ letterSpacing: 6, fontSize: 20 }}
              required
            />
          </Field>
          {devCode && <p style={{ margin: 0, fontSize: 13, color: 'var(--text-muted)' }}>Test server code: {devCode}</p>}
          <button
            type="button"
            disabled={wait > 0 || busy}
            onClick={() => void run(sendCode)}
            style={{ alignSelf: 'flex-start', border: 0, background: 'none', padding: 0, color: wait > 0 ? 'var(--text-muted)' : 'var(--text)', textDecoration: 'underline', cursor: wait > 0 ? 'default' : 'pointer' }}
          >
            {wait > 0 ? `Resend code in ${wait}s` : 'Resend code'}
          </button>
        </>
      )}

      {step === 'password' && passwordField('New password')}

      {error && <span className={u.fieldError}>{error}</span>}

      <PrimaryButton type="submit" block disabled={busy}>
        {busy
          ? 'Please wait…'
          : step === 'details'
            ? 'Send code'
            : step === 'code'
              ? mode === 'signup'
                ? 'Create account'
                : 'Verify'
              : 'Save new password'}
      </PrimaryButton>

      <p style={{ textAlign: 'center', fontSize: 14, color: 'var(--text-muted)', margin: 0 }}>
        {mode === 'signup' ? 'Already have an account?' : 'Remembered it?'}{' '}
        <Link href="/login" style={{ color: 'var(--text)', fontWeight: 600 }}>
          Log in
        </Link>
      </p>
    </form>
  );
}
