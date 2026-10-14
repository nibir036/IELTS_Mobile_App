'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, type FormEvent } from 'react';
import { Icon, Notice, PrimaryButton, uiStyles as u } from '@/components/ui';
import s from './login.module.css';

const ENDED: Record<string, { title: string; body: string }> = {
  signed_in_elsewhere: {
    title: 'Signed out on this device',
    body: 'Your account was opened on your other device. Only one screen can be signed in at a time. Log in to use it here.',
  },
  device_removed: {
    title: 'This device was removed',
    body: 'It was removed from your account on your other device. Log in to add it again.',
  },
  session_ended: {
    title: 'Please log in again',
    body: 'Your session has ended.',
  },
};

export function LoginForm({ next, reason }: { next: string; reason: string | null }) {
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [show, setShow] = useState(false);
  const [keep, setKeep] = useState(true);
  const [busy, setBusy] = useState(false);
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);
  const [locked, setLocked] = useState<string | null>(null);
  const [ended, setEnded] = useState(reason ? ENDED[reason] ?? null : null);

  const canSubmit = !busy && phone.trim() !== '' && password !== '';

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    setBusy(true);
    setPhoneError(null);
    setPasswordError(null);
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: phone.trim(), password, keep }),
      });
      const data = (await res.json().catch(() => ({}))) as { error?: string; code?: string };
      if (res.ok) {
        router.replace(next);
        router.refresh();
        return;
      }
      setEnded(null);
      if (data.code === 'device_locked') {
        setLocked(data.error ?? 'This device is locked.');
      } else if (data.code === 'wrong_password') {
        setLocked(null);
        setPasswordError(data.error ?? 'Wrong password.');
      } else {
        setLocked(null);
        setPhoneError(data.error ?? 'Couldn’t log in. Please try again.');
      }
    } catch {
      setPhoneError('Can’t reach the server. Check your connection.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className={s.form} onSubmit={submit} noValidate>
      {locked ? (
        <Notice icon="lock" title="This device is locked">
          {locked}
        </Notice>
      ) : ended ? (
        <Notice icon="devices" title={ended.title}>
          {ended.body}
        </Notice>
      ) : null}

      <div className={u.field}>
        <label className={u.fieldLabel} htmlFor="phone">
          Phone number
        </label>
        <div className={u.inputWrap}>
          <span className={u.prefix}>+880</span>
          <input
            id="phone"
            className={u.input}
            type="text"
            autoComplete="username"
            placeholder="1XXX XXXXXX"
            value={phone}
            onChange={(e) => {
              setPhone(e.target.value);
              setPhoneError(null);
            }}
          />
        </div>
        {phoneError && <span className={u.fieldError}>{phoneError}</span>}
      </div>

      <div className={u.field}>
        <label className={u.fieldLabel} htmlFor="password">
          Password
        </label>
        <div className={u.inputWrap}>
          <input
            id="password"
            className={u.input}
            type={show ? 'text' : 'password'}
            autoComplete="current-password"
            placeholder="Your password"
            value={password}
            onChange={(e) => {
              setPassword(e.target.value);
              setPasswordError(null);
            }}
          />
          <button type="button" className={u.eye} onClick={() => setShow(!show)} aria-label={show ? 'Hide password' : 'Show password'}>
            <Icon name={show ? 'visibility_off' : 'visibility'} size={20} />
          </button>
        </div>
        {passwordError && <span className={u.fieldError}>{passwordError}</span>}
      </div>

      <div className={s.row}>
        <label className={s.check}>
          <input type="checkbox" checked={keep} onChange={(e) => setKeep(e.target.checked)} />
          Keep me signed in
        </label>
        <Link href="/forgot-password" className={s.link}>
          Forgot password?
        </Link>
      </div>

      <PrimaryButton type="submit" block disabled={!canSubmit}>
        {busy ? 'Logging in…' : 'Log in'}
      </PrimaryButton>

      <p className={s.footer}>
        New to IELTS AI? <Link href="/signup">Create an account</Link>
      </p>
      <p className={s.legal}>
        By continuing you agree to our <Link href="/terms">Terms</Link> and <Link href="/privacy">Privacy Policy</Link>.
      </p>
    </form>
  );
}
