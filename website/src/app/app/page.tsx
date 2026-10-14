import type { Metadata } from 'next';
import Link from 'next/link';
import { Avatar } from '@/components/home/avatar';
import { EditProfileButton, type ProfileBasics } from '@/components/home/edit-profile';
import { MicStep, WordActions } from '@/components/home/home-bits';
import h from '@/components/home/home.module.css';
import { PlanTaskRow } from '@/components/plan-task-row';
import { Card, HeroCard, Icon, IconCircle, Nexi, PrimaryButton, Tag } from '@/components/ui';
import pl from '@/components/plan.module.css';
import { appHref, targetHref } from '@/lib/home/routes';
import { myAttempts, stateValue, unreadCount } from '@/lib/home/server';
import {
  CORE_SKILLS,
  estimatedBand,
  formatBand,
  homeIcon,
  profileOf,
  resultHref,
  skillBand,
  skillLabel,
  skillLetter,
  skillProgress,
  weekMinutes,
} from '@/lib/home/stats';
import { daysBetween, greeting, relativeDay, todayKey, WD, weekdayDate, weekdayIndex } from '@/lib/home/time';
import { skillLanding, type Plan } from '@/lib/plan/plan';
import { firstName, getMe } from '@/lib/server/me';
import { uiPack } from '@/lib/server/packs';
import { currentPlan } from '@/lib/server/plan';
import { resourcesBank } from '@/lib/server/resources';
import s from './pages.module.css';

export const metadata: Metadata = { title: 'Home' };

type Raw = Record<string, unknown>;
const str = (v: unknown) => (v == null ? '' : String(v));

/** "Dive Right In" (lib/features/home/signature_tools.dart). */
const TOOLS = [
  { icon: 'quiz', title: 'Vocab Quiz', sub: 'Quick rounds of IELTS words, scored as you go', href: '/app/resources/vocab-quiz' },
  { icon: 'link', title: 'Writing Booster · Linking', sub: 'Build stronger sentences with the right linking words', href: '/app/writing/sentence-builder' },
  { icon: 'record_voice_over', title: 'Pronunciation Trainer', sub: 'Say a word and see exactly which sounds to fix', href: '/app/speaking/pronunciation' },
];

interface Word {
  id: string;
  word: string;
  partOfSpeech: string;
  definition: string;
  example: string;
}

const POS_SHORT: Record<string, string> = { noun: 'n.', verb: 'v.', adjective: 'adj.', adverb: 'adv.' };

/** A Band 7.5+ bank word that changes daily (ResBank.wordOfTheDay). */
async function wordOfTheDay(fallback: Raw | undefined): Promise<Word | null> {
  const fb: Word | null = fallback?.word
    ? { id: str(fallback.id), word: str(fallback.word), partOfSpeech: str(fallback.partOfSpeech), definition: str(fallback.definition), example: str(fallback.example) }
    : null;
  const bank = await resourcesBank().catch(() => null);
  const pool = (bank?.vocab ?? []).filter((v) => Number(v.band) >= 7.5 && Array.isArray(v.examples) && v.examples.length > 0);
  if (!pool.length) return fb;
  const [y, m, d] = todayKey().split('-').map(Number);
  const day = Math.floor(Date.UTC(y, m - 1, d) / 86_400_000);
  const v = pool[(day * 37) % pool.length];
  const w = str(v.word);
  return {
    id: str(v.id),
    word: w ? w[0].toUpperCase() + w.slice(1) : w,
    partOfSpeech: POS_SHORT[str(v.pos)] ?? str(v.pos),
    definition: str(v.definition),
    example: str((v.examples as unknown[])[0]).replace(/\*\*/g, ''),
  };
}

export default async function HomePage() {
  const [me, ui, { plan }, mine, unread, resume, saved] = await Promise.all([
    getMe(),
    uiPack().catch(() => ({}) as Raw),
    currentPlan(),
    myAttempts(),
    unreadCount(),
    stateValue<Raw>('resume'),
    stateValue<unknown[]>('resources.savedWords'),
  ]);
  const home = (ui.home ?? {}) as Raw;
  const word = await wordOfTheDay(((home.dashboard ?? {}) as Raw).wordOfTheDay as Raw | undefined);
  const prof = profileOf(me.user.profile);
  const basics: ProfileBasics = { name: me.user.name, targetBand: prof.targetBand, examDate: prof.examDate, photo: prof.photo };
  const pro = me.usage.plan === 'pro';

  const header = (firstTime: boolean) => (
    <header className={h.homeHead}>
      {!firstTime && (
        <Link href="/app/profile" aria-label="Profile and settings">
          <Avatar name={me.user.name} photo={prof.photo} size={48} />
        </Link>
      )}
      <div className={h.topText}>
        <p className={h.greet}>{greeting()}</p>
        {firstTime ? <h1 className={h.bigHi}>Hi, {firstName(me.user.name)}</h1> : <h1 className={h.name}>{me.user.name}</h1>}
      </div>
      <Link href="/app/search" className={h.iconBtn} aria-label="Search" title="Search">
        <Icon name="search" size={22} />
      </Link>
      <Link href="/app/notifications" className={h.iconBtn} aria-label={unread ? `Notifications, ${unread} unread` : 'Notifications'} title="Notifications">
        <Icon name="notifications" size={22} />
        {unread > 0 && <span className={h.dot} />}
      </Link>
    </header>
  );

  const tools = (
    <Card padding="14px 14px 8px">
      <div className={s.toolHead}>
        <Icon name="auto_awesome" size={18} color="var(--peach)" />
        Dive Right In
      </div>
      {TOOLS.map((t) => (
        <Link key={t.href} href={t.href} className={s.tool}>
          <span className={s.toolIcon}>
            <Icon name={t.icon} size={22} />
          </span>
          <span className={s.toolText}>
            <span className={s.toolTitle}>{t.title}</span>
            <span className={s.toolSub}>{t.sub}</span>
          </span>
          <Icon name="arrow_forward" size={18} color="var(--text-muted)" />
        </Link>
      ))}
    </Card>
  );

  // ── B2 · first time (no practice yet) ──────────────────────────────────
  if (mine.length === 0) {
    const ft = (home.firstTime ?? {}) as Raw;
    const checks: Record<string, boolean> = {
      account: true,
      targetBand: prof.targetBand != null,
      examDate: prof.examDate != null,
      mic: prof.micAllowed,
      practice: false,
      plan: Boolean(plan),
      speaking: false,
    };
    let found = false;
    const steps = (Array.isArray(ft.checklist) ? (ft.checklist as Raw[]) : []).map((st) => {
      const done = checks[str(st.check)] ?? false;
      const current = !done && !found;
      if (current) found = true;
      return { id: str(st.id), title: str(st.title), target: str(st.target), done, current };
    });
    const cards = Array.isArray(ft.emptyCards) ? (ft.emptyCards as Raw[]) : [];
    const heroLine = [prof.targetBand == null ? 'Set your target band' : `Target ${formatBand(prof.targetBand)}`, prof.examDate ? `exam ${weekdayDate(prof.examDate)}` : '']
      .filter(Boolean)
      .join(' · ');
    return (
      <>
        {header(true)}
        <HeroCard radius={32} padding={20}>
          <div className={h.heroRow}>
            <div className={h.heroCol}>
              <h2 className={h.heroTitle}>
                Your band score
                <br />
                starts here
              </h2>
              <EditProfileButton initial={basics} className={h.kv} label="Edit target band and exam date">
                <span>{heroLine}</span>
              </EditProfileButton>
            </div>
            <Nexi pose="wave" height={110} priority />
          </div>
          <div className={h.heroActions} style={{ marginTop: 14 }}>
            <PrimaryButton href={plan ? '/app/plan' : '/app/plan/setup'} trailing="arrow_forward" height={52}>
              {plan ? 'See my study plan' : 'Build my study plan'}
            </PrimaryButton>
          </div>
        </HeroCard>

        <div className={h.grid2}>
          <div className={h.stack}>
            <TodayPlan plan={plan} />
            <Card padding="14px 18px" radius={28}>
              <div className={h.cardHead}>
                <h2 className={h.cardTitle}>Getting started</h2>
                <span className={h.label}>
                  {steps.filter((x) => x.done).length} of {steps.length}
                </span>
              </div>
              {steps.map((st) => {
                if (!st.done && st.target === 'micPermission') return <MicStep key={st.id} title={st.title} current={st.current} />;
                const href = st.done ? '' : targetHref(st.target);
                const inner = (
                  <>
                    <span className={h.stepBox}>{st.done && <Icon name="check" size={16} />}</span>
                    <span className={h.stepTitle}>{st.title}</span>
                    {st.current && <Icon name="chevron_right" size={20} color="var(--icon-accent)" />}
                  </>
                );
                const cls = `${h.step} ${st.current ? h.stepCurrent : ''} ${st.done ? h.stepDone : ''}`;
                if (st.target === 'targetBand' && !st.done) {
                  return (
                    <Link key={st.id} href="/app/onboarding/target-band" className={cls}>
                      {inner}
                    </Link>
                  );
                }
                return href ? (
                  <Link key={st.id} href={href} className={cls}>
                    {inner}
                  </Link>
                ) : (
                  <div key={st.id} className={cls}>
                    {inner}
                  </div>
                );
              })}
            </Card>
          </div>
          <div className={h.stack}>
            {tools}
            {cards.length > 0 && (
              <div className={h.emptyCards}>
                {cards.map((c) => (
                  <Link key={str(c.id)} href={targetHref(str(c.target)) || '/app/practice'} className={h.emptyCard}>
                    <span className={h.emptyIcon}>
                      <Icon name={homeIcon(str(c.icon))} size={20} />
                    </span>
                    <span>
                      <span style={{ display: 'block', fontSize: 15 }}>{str(c.title)}</span>
                      <span className={h.rowSub}>{str(c.subtitle)}</span>
                    </span>
                  </Link>
                ))}
              </div>
            )}
          </div>
        </div>
      </>
    );
  }

  // ── B1 · dashboard ─────────────────────────────────────────────────────
  const est = estimatedBand(mine);
  const days = prof.examDate ? daysBetween(todayKey(), prof.examDate) : null;
  const resumeLabel = str(resume?.label);
  const resumeRoute = str(resume?.route);
  const resumeHref = resumeLabel && resumeRoute ? appHref(resumeRoute, resume?.args as Raw | undefined) : '';
  const week = weekMinutes(mine);
  const total = week.reduce((a, b) => a + b, 0);
  const maxDay = Math.max(1, ...week);
  const todayIdx = weekdayIndex(todayKey());
  const scored = mine.filter((a) => a.band != null).slice(0, 5);
  const savedIds = new Set((Array.isArray(saved) ? saved : []).map(String));

  return (
    <>
      {header(false)}

      <HeroCard radius={32} padding={20}>
        <div className={h.heroRow}>
          <div className={h.heroCol}>
            <span className={h.overline}>Est. band</span>
            <span className={h.estBig}>{formatBand(est)}</span>
            <div className={h.heroTrack} role="progressbar" aria-label="Estimated band out of 9" aria-valuemin={0} aria-valuemax={9} aria-valuenow={est ?? 0}>
              <span style={{ width: `${((est ?? 0) / 9) * 100}%` }} />
            </div>
            <EditProfileButton initial={basics} className={h.kv} label="Edit target band">
              <span>Target</span>
              <span>{prof.targetBand == null ? 'Set' : formatBand(prof.targetBand)}</span>
            </EditProfileButton>
            <EditProfileButton initial={basics} className={h.kv} label="Edit exam date">
              <span>Exam in</span>
              <span>{days == null ? 'Set exam date' : days < 0 ? 'Done' : days === 1 ? '1 day' : `${days} days`}</span>
            </EditProfileButton>
          </div>
          <Nexi pose="wave" height={110} priority />
        </div>
        <div className={h.heroActions} style={{ marginTop: 12 }}>
          <PrimaryButton href={resumeHref || '/app/practice'} trailing="arrow_forward" height={46}>
            {resumeHref ? resumeLabel : 'Start practising'}
          </PrimaryButton>
          <Tag tone={pro ? 'primary' : 'peach'}>{pro ? 'Pro' : 'Free plan'}</Tag>
        </div>
      </HeroCard>

      <div className={h.grid2}>
        <div className={h.stack}>
          <TodayPlan plan={plan} />
          <Card href="/app/analytics" radius={30} padding="16px 18px">
            <div className={h.rowBetween}>
              <div>
                <span className={h.label}>Study time this week</span>
                <div className={h.bigTime}>
                  <b>{String(Math.floor(total / 60)).padStart(2, '0')}</b> hr <b>{String(total % 60).padStart(2, '0')}</b> mins
                </div>
              </div>
              <span className={h.pill}>
                This week <Icon name="expand_more" size={16} />
              </span>
            </div>
            <div className={h.bars} role="img" aria-label={`Study minutes this week: ${week.map((m, i) => `${WD[i]} ${m}`).join(', ')}`}>
              {week.map((m, i) => (
                <span key={WD[i]} className={`${h.barCol} ${i === todayIdx ? h.barOn : ''}`}>
                  <i style={{ height: `${Math.max(6, (m / maxDay) * 80)}px` }} />
                  {WD[i]}
                </span>
              ))}
            </div>
          </Card>
        </div>
        <div className={h.stack}>
          {tools}
          {word && (
            <Card radius={26} padding={16}>
              <div className={h.wordTop}>
                <span>
                  <Tag tone="primary">Word of the day</Tag>
                </span>
                <WordActions id={word.id} word={word.word} saved={savedIds.has(word.id)} />
              </div>
              <p className={h.word}>
                {word.word} <small>{word.partOfSpeech}</small>
              </p>
              <p className={h.wordDef}>
                {word.definition} &ldquo;{word.example}&rdquo;
              </p>
            </Card>
          )}
        </div>
      </div>

      <div className={h.skills}>
        {CORE_SKILLS.map((k) => {
          const p = skillProgress(mine, k, prof.targetBand);
          return (
            <Card key={k} href={skillLanding(k)} radius={26} padding={14}>
              <div className={h.skill}>
                <div className={h.skillTop}>
                  <IconCircle icon={homeIcon(k)} size={40} />
                  <span className={h.skillBand}>{formatBand(skillBand(mine, k))}</span>
                </div>
                <span className={h.skillName}>{skillLabel(k)}</span>
                <div className={h.track} role="progressbar" aria-label={`${skillLabel(k)} toward your target`} aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(p * 100)}>
                  <span style={{ width: `${p * 100}%` }} />
                </div>
              </div>
            </Card>
          );
        })}
      </div>

      <Card radius={26} padding="12px 16px 6px">
        <div className={h.cardHead}>
          <h2 className={h.cardTitle}>Recent scores</h2>
          <span className={h.label}>{scored.length ? `Last ${scored.length} · band est.` : 'band est.'}</span>
        </div>
        {scored.length === 0 ? (
          <p className={h.emptyNote}>No band scores yet. Finish a test to see it here.</p>
        ) : (
          scored.map((a) => (
            <Link key={a.id} href={resultHref(a)} className={h.row}>
              <span className={h.letter}>{skillLetter(a.skill)}</span>
              <span className={h.rowText}>
                <span className={h.rowTitle}>{a.title || skillLabel(a.skill)}</span>
                <span className={h.rowSub}>
                  {skillLabel(a.skill)} · {relativeDay(a.createdAt)}
                </span>
              </span>
              <span className={h.bandNum}>{formatBand(a.band)}</span>
            </Link>
          ))
        )}
      </Card>
    </>
  );
}

/** Today's plan (TodayPlanCard), or the "get your study plan" card. */
function TodayPlan({ plan }: { plan: Plan | null }) {
  if (!plan) {
    return (
      <Card href="/app/plan/setup" padding="16px 14px 16px 18px" radius={28}>
        <div className={pl.cardRow}>
          <span className={pl.circle} style={{ width: 46, height: 46 }}>
            <Icon name="calendar_month" size={22} />
          </span>
          <span style={{ flex: 1 }}>
            <span className={pl.cardTitle} style={{ fontSize: 16 }}>
              Get your study plan
            </span>
            <p className={pl.cardText}>Daily tasks matched to your level, time and exam date.</p>
          </span>
          <Icon name="arrow_forward" size={20} color="var(--text-muted)" />
        </div>
      </Card>
    );
  }
  const todays = plan.tasks.filter((t) => t.date === plan.today && (t.kind === 'plan' || t.kind === 'checkpoint'));
  const doneToday = todays.filter((t) => t.done).length;
  const openToday = todays.filter((t) => !t.done);
  return (
    <section className={pl.card} aria-label="Today's plan">
      <div className={pl.cardRow}>
        <div style={{ flex: 1 }}>
          <p className={pl.cardText}>Today&apos;s plan</p>
          <span style={{ fontSize: 18, fontWeight: 600 }}>
            {todays.length === 0 ? 'Rest day' : openToday.length === 0 ? 'All done for today' : `${doneToday} of ${todays.length} done`}
          </span>
        </div>
        <Link href="/app/plan" className={s.seePlan}>
          See plan
        </Link>
      </div>
      {todays.length > 0 ? (
        <div className={pl.bar}>
          <span style={{ width: `${(doneToday / todays.length) * 100}%` }} />
        </div>
      ) : (
        <p className={pl.cardText}>No tasks today. Rest well, or get ahead from your plan.</p>
      )}
      {(openToday.length ? openToday : todays).slice(0, 3).map((t) => (
        <PlanTaskRow key={t.id} task={t} showReason={false} />
      ))}
    </section>
  );
}
