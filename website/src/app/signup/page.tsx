import type { Metadata } from 'next';
import { AuthFlow } from '@/components/auth-flow';
import { Brand, HeroCard, Nexi } from '@/components/ui';
import s from '../login/login.module.css';

export const metadata: Metadata = { title: 'Create an account', robots: { index: false } };

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
                Create your
                <br />
                account.
              </h1>
              <p className={s.subtitle}>Practise all four skills with AI feedback.</p>
            </div>
            <Nexi pose="point" height={110} priority />
          </div>
        </HeroCard>
        <AuthFlow mode="signup" />
      </div>
    </main>
  );
}
