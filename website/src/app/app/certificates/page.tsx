import type { Metadata } from 'next';
import Link from 'next/link';
import { BadgeGrid, type CertView } from '@/components/home/certificates-grid';
import h from '@/components/home/home.module.css';
import { HeroCard, Icon, Nexi, SectionTitle } from '@/components/ui';
import { CERT_GROUPS, certIcon, certificateId } from '@/lib/home/certificates';
import { certificates, myAttempts } from '@/lib/home/server';
import { profileOf, streakDays } from '@/lib/home/stats';
import { dayKey, longDate } from '@/lib/home/time';
import { lessonsDone, xpOf } from '@/lib/server/lessons';
import { getMe } from '@/lib/server/me';

export const metadata: Metadata = { title: 'Milestones' };

/** Profile › Learning › Milestones (certificates_screen.dart). */
export default async function CertificatesPage() {
  const [me, mine, done] = await Promise.all([getMe(), myAttempts(), lessonsDone()]);
  const { items, intro } = await certificates({ attempts: mine, done, target: profileOf(me.user.profile).targetBand });
  const earned = items.filter((c) => c.earned).length;
  const views: CertView[] = items.map((c) => ({
    ...c,
    iconName: certIcon(c.icon),
    date: c.earnedAt ? longDate(dayKey(new Date(c.earnedAt))) : '',
    certId: certificateId(me.user.id, c),
  }));
  const groups = new Map<string, CertView[]>();
  for (const c of views) groups.set(c.group, [...(groups.get(c.group) ?? []), c]);
  const order = [...CERT_GROUPS.filter((g) => groups.has(g)), ...[...groups.keys()].filter((g) => !CERT_GROUPS.includes(g))];
  const streak = streakDays(mine, done);

  return (
    <>
      <div className={h.top}>
        <Link href="/app/profile" className={h.back} aria-label="Back to Profile">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={h.topText}>
          <h1 className={h.h1} style={{ fontSize: 24, fontWeight: 600 }}>
            Milestones
          </h1>
          <p className={h.sub}>
            {earned} of {items.length} badges earned
          </p>
        </div>
      </div>

      <HeroCard padding={20}>
        <div className={h.heroRow}>
          <div className={h.heroCol}>
            <div>
              <span style={{ fontSize: 44, fontWeight: 600, lineHeight: 1 }}>{earned}</span>{' '}
              <span className={h.heroMuted} style={{ fontSize: 14 }}>
                / {items.length} badges
              </span>
            </div>
            <div className={h.heroTrack}>
              <span style={{ width: `${items.length ? (earned / items.length) * 100 : 0}%` }} />
            </div>
            {intro && (
              <p className={h.heroMuted} style={{ margin: 0, fontSize: 12.5, lineHeight: 1.4, maxWidth: 520 }}>
                {intro}
              </p>
            )}
            <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', fontSize: 12.5, fontWeight: 600 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                <Icon name="star" size={16} color="var(--peach)" /> {xpOf(done)} XP
              </span>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                <Icon name="local_fire_department" size={16} color="var(--peach)" /> {streak}-day streak
              </span>
            </div>
          </div>
          <Nexi pose="grad" height={112} />
        </div>
      </HeroCard>

      {order.map((g) => (
        <section key={g} className={h.stack} style={{ gap: 10 }}>
          <SectionTitle>{g}</SectionTitle>
          <BadgeGrid items={groups.get(g) ?? []} name={me.user.name} />
        </section>
      ))}
    </>
  );
}
