import type { Metadata } from 'next';
import { AuthFlow } from '@/components/auth-flow';
import { Brand, HeroCard, Nexi } from '@/components/ui';
import s from '../login/login.module.css';

export const metadata: Metadata = { title: 'Reset password', robots: { index: false } };

export default function Page() {
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
                Reset your
                <br />
                password.
              </h1>
              <p className={s.subtitle}>We’ll text a code to your phone.</p>
            </div>
            <Nexi pose="thumbs" height={110} priority />
          </div>
        </HeroCard>
        <AuthFlow mode="reset" />
      </div>
    </main>
  );
}
