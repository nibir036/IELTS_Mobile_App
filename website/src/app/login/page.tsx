import type { Metadata } from 'next';
import { Brand, HeroCard, Nexi } from '@/components/ui';
import { LoginForm } from './login-form';
import s from './login.module.css';

export const metadata: Metadata = { title: 'Log in', robots: { index: false } };

type Search = Promise<{ next?: string; reason?: string }>;

export default async function LoginPage({ searchParams }: { searchParams: Search }) {
  const { next, reason } = await searchParams;
  // Only same-site paths (no open redirect).
  const target = next && next.startsWith('/') && !next.startsWith('//') ? next : '/app';
  return (
    <main className={s.page}>
      <div className={s.column}>
        <header className={s.header}>
          <Brand />
        </header>
        <HeroCard radius={32}>
          <div className={s.heroRow}>
            <div className={s.heroText}>
              <h1 className={s.title}>
                Welcome
                <br />
                back.
              </h1>
              <p className={s.subtitle}>Pick up where you left off.</p>
            </div>
            <Nexi pose="wave" height={110} priority />
          </div>
        </HeroCard>
        <LoginForm next={target} reason={reason ?? null} />
      </div>
    </main>
  );
}
