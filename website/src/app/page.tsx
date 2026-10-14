import Link from 'next/link';
import { Brand, Card, HeroCard, Nexi, PrimaryButton, SoftButton, Tag, type NexiPose } from '@/components/ui';
import { uiPack } from '@/lib/server/packs';
import { saveLabel } from '@/lib/billing';

// Prices come from the same content pack as the app's Plans page.
import s from './landing.module.css';

const SKILLS: Array<{ pose: NexiPose; name: string; text: string }> = [
  { pose: 'writing', name: 'Writing', text: 'Task 1 and Task 2 with a band for each criterion, corrections and a Band 8 rewrite.' },
  { pose: 'speaking', name: 'Speaking', text: 'Answer Parts 1 to 3 out loud and get scored on fluency, vocabulary, grammar and pronunciation.' },
  { pose: 'listening', name: 'Listening', text: 'Real exam-style recordings, practice by question type and full tests marked instantly.' },
  { pose: 'reading', name: 'Reading', text: 'Academic passages, short practice tests and full tests with every answer explained.' },
];

type Pass = { id: string; name: string; badge?: string; days?: number; price: number; priceWas?: number; save?: string; pitch?: string; perDayNote?: string };
type Plans = { passes?: Pass[]; pricingNote?: string; headline?: string; subhead?: string };

const taka = (n: number) => `BDT ${n.toLocaleString('en-US')}`;

export default async function Landing() {
  let plans: Plans = {};
  try {
    plans = (((await uiPack()).home ?? {}) as { plans?: Plans }).plans ?? {};
  } catch {
    plans = {};
  }
  return (
    <div className={s.wrap}>
      <header className={s.nav}>
        <Brand />
        <nav className={s.navLinks}>
          <SoftButton href="/login">Log in</SoftButton>
        </nav>
      </header>

      <main>
        <section className={s.hero}>
          <div>
            <h1 className={s.h1}>Your IELTS band, scored by AI in seconds.</h1>
            <p className={s.lead}>
              Practise all four skills, get a band score and clear feedback on every answer, and follow a study plan built around your exam date.
            </p>
            <div className={s.ctas}>
              <PrimaryButton href="/signup" trailing="arrow_forward">
                Start free
              </PrimaryButton>
              <SoftButton href="/login">I have an account</SoftButton>
            </div>
          </div>
          <div className={s.heroArt}>
            <HeroCard radius={32} padding={28}>
              <Nexi pose="wave" height={260} priority />
            </HeroCard>
          </div>
        </section>

        <section className={s.section}>
          <h2 className={s.h2}>Every part of the test</h2>
          <p className={s.sub}>The same questions, timings and band descriptors as the real exam.</p>
          <div className={s.skills}>
            {SKILLS.map((k) => (
              <Card key={k.name} padding={18}>
                <div className={s.skill}>
                  <Nexi pose={k.pose} height={96} />
                  <h3 className={s.skillName}>{k.name}</h3>
                  <p className={s.skillText}>{k.text}</p>
                </div>
              </Card>
            ))}
          </div>
        </section>

        <section className={s.section}>
          <h2 className={s.h2}>How it works</h2>
          <div className={s.steps}>
            {[
              ['Tell us your target', 'Your target band, exam date and how much time you have each day.'],
              ['Practise with feedback', 'Every essay and spoken answer gets a band and what to fix next.'],
              ['Take full mock tests', 'All four skills under exam timing, with a band report and a plan to improve.'],
            ].map(([title, text], i) => (
              <Card key={title} padding={20}>
                <span className={s.stepNum}>{i + 1}</span>
                <h3 className={s.skillName}>{title}</h3>
                <p className={s.skillText}>{text}</p>
              </Card>
            ))}
          </div>
        </section>

        {plans.passes?.length ? (
          <section className={s.section} id="pricing">
            <h2 className={s.h2}>{plans.headline ?? 'Pricing'}</h2>
            <p className={s.sub}>{plans.subhead ?? 'Full access to every test and AI feedback.'} Start free, no card needed.</p>
            <div className={s.passes}>
              {plans.passes.map((p) => (
                <Card key={p.id} padding={20}>
                  <div className={s.pass}>
                    <div className={s.passTop}>
                      <span className={s.passName}>{p.name}</span>
                      {p.badge && <Tag tone={p.id === 'month' ? 'primary' : 'peach'}>{p.badge}</Tag>}
                    </div>
                    <div className={s.price}>
                      {p.priceWas && p.priceWas > p.price ? <span className={s.priceWas}>{taka(p.priceWas)}</span> : null}
                      <span className={s.priceNow}>{taka(p.price)}</span>
                    </div>
                    {saveLabel(p) && <span style={{ fontSize: 13, color: 'var(--success)', fontWeight: 500 }}>{saveLabel(p)}</span>}
                    {p.days ? <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{p.days} days · about {taka(Math.round(p.price / p.days))} a day</span> : null}
                    {p.pitch && <p className={s.pitch}>{p.pitch}</p>}
                  </div>
                </Card>
              ))}
            </div>
            {plans.pricingNote && <p className={s.note}>{plans.pricingNote}</p>}
          </section>
        ) : null}

        <section className={s.section}>
          <HeroCard radius={32} padding={28}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
              <div style={{ flex: 1, minWidth: 240 }}>
                <h2 className={s.h2} style={{ color: 'var(--hero-text)' }}>
                  Start practising today
                </h2>
                <p style={{ margin: 0, color: 'var(--hero-muted)' }}>Free to start. Your progress follows you between the app and the website.</p>
              </div>
              <PrimaryButton href="/signup" trailing="arrow_forward">
                Create my account
              </PrimaryButton>
            </div>
          </HeroCard>
        </section>
      </main>

      <footer className={s.footer}>
        <span>© {new Date().getFullYear()} IELTS AI by nextED</span>
        <span style={{ display: 'flex', gap: 16 }}>
          <Link href="/terms">Terms</Link>
          <Link href="/privacy">Privacy</Link>
        </span>
      </footer>
    </div>
  );
}
