'use client';

import { useEffect } from 'react';

const ENDED = new Set(['signed_in_elsewhere', 'device_removed', 'session_ended']);
const EVERY_MS = 30_000;

/**
 * One screen at a time: when the account signs in somewhere else (the app,
 * another browser), the server ends this session. This notices within
 * ~30 seconds, or as soon as the tab comes back into view, and goes to the
 * sign-in page with the reason ("You were signed in on another device").
 */
export function SessionWatch() {
  useEffect(() => {
    let busy = false;
    let gone = false;
    const check = async () => {
      if (busy || gone || document.visibilityState !== 'visible') return;
      busy = true;
      try {
        const res = await fetch('/api/v1/me/usage', { cache: 'no-store' });
        if (res.status === 401) {
          const data = (await res.json().catch(() => ({}))) as { code?: string };
          const code = ENDED.has(String(data.code)) ? String(data.code) : 'session_ended';
          gone = true;
          const next = window.location.pathname + window.location.search;
          window.location.replace(`/login?reason=${encodeURIComponent(code)}&next=${encodeURIComponent(next)}`);
        }
      } catch {
        // Offline: try again later.
      } finally {
        busy = false;
      }
    };
    const id = window.setInterval(check, EVERY_MS);
    const onShow = () => void check();
    document.addEventListener('visibilitychange', onShow);
    window.addEventListener('focus', onShow);
    return () => {
      window.clearInterval(id);
      document.removeEventListener('visibilitychange', onShow);
      window.removeEventListener('focus', onShow);
    };
  }, []);
  return null;
}
