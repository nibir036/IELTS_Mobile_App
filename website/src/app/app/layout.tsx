import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { MediaGuard } from '@/components/media-guard';
import { SessionWatch } from '@/components/session-watch';
import s from './shell.module.css';
import { Tabs } from './tabs';

export const metadata: Metadata = { robots: { index: false, follow: false } };

/** Signed-in area (the middleware sends visitors without a session to /login). */
export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <div className={s.layout}>
      <SessionWatch />
      <MediaGuard />
      <Tabs />
      <main className={s.main}>
        <div className={s.inner}>{children}</div>
      </main>
    </div>
  );
}
