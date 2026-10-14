import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, HeroCard, Icon, Nexi } from '@/components/ui';
import { attempts } from '@/lib/server/attempts';
import { speakingBank, speakingCopy } from '@/lib/server/speaking';
import { formatBand } from '@/lib/writing/analysis';
import w from '../writing/writing.module.css';

export const metadata: Metadata = { title: 'Speaking' };

/** D1 · Speaking practice hub (speaking_hub_screen.dart). */
export default async function SpeakingHub() {
  const [copy, bank, mine] = await Promise.all([speakingCopy(), speakingBank(), attempts({ skill: 'speaking', limit: 200 })]);
  const hub = copy.hub ?? {};
  const best = (kind: string) => {
    const b = mine.filter((a) => a.kind === kind && typeof a.band === 'number').map((a) => a.band as number);
    return b.length ? Math.max(...b) : null;
  };
  const rows: Array<[string, string, string, string]> = [
    ['history', 'Speaking history', `${mine.length} sessions · bands and transcripts`, '/app/speaking/history'],
    ['library_books', 'Sample answers & vocabulary', 'Model answers for every question', '/app/speaking/cards'],
    ['menu_book', 'Speaking question bank', 'Every topic and cue card with sample answers, plus key words', '/app/speaking/library'],
    ['graphic_eq', 'My recordings', 'Replay your answers', '/app/speaking/recordings'],
    ['school', 'Speaking Course', 'Bite-sized lessons from the nextED Speaking book', '/app/courses/speaking'],
    ['lightbulb', 'Speaking Tips', 'Fluency, Part 1, Part 2 and Part 3 strategies', '/app/resources/tips/speaking'],
    ['timer', 'Full Speaking Tests', 'Parts 1, 2 and 3 back to back', '/app/speaking/tests'],
    ['record_voice_over', 'Pronunciation Trainer', 'Say a word and see exactly which sounds to fix', '/app/speaking/pronunciation'],
  ];
  return (
    <>
      <div className={w.head}>
        <div>
          <h1 className={w.title}>Speaking Practice</h1>
          <p className={w.sub}>Answer out loud · AI band score in about a minute</p>
        </div>
        <Link href="/app/speaking/history" className={w.iconBox} title="Speaking history" aria-label="Speaking history">
          <Icon name="graphic_eq" size={20} />
        </Link>
      </div>

      <Link href="/app/speaking/part1">
        <HeroCard padding={18}>
          <div className={w.row} style={{ alignItems: 'center' }}>
            <div className={w.grow}>
              <div className={w.taskLabel}>Part 1</div>
              <h2 className={w.taskTitle}>Short Q&amp;A</h2>
              <div className={w.stats} style={{ marginTop: 10 }}>
                <span>
                  <b>{hub.part1?.duration ?? '4–5'}</b> min
                </span>
                <span>
                  <b>{bank.part1.length}</b> topics
                </span>
                {best('part1') !== null && (
                  <span>
                    best <b>{formatBand(best('part1'))}</b>
                  </span>
                )}
              </div>
            </div>
            <Nexi pose="speaking" height={110} />
          </div>
        </HeroCard>
      </Link>

      <div className={w.tasks}>
        {(hub.modes ?? []).map((m) => (
          <Card key={m.id} href={m.id === 'part2' ? '/app/speaking/cards' : '/app/speaking/part3'} padding={18}>
            <div className={w.row}>
              <div className={w.grow}>
                <div className={w.taskLabel} style={{ color: 'var(--text-muted)' }}>
                  {m.label}
                </div>
                <h2 className={w.taskTitle}>{m.title}</h2>
                <p className={w.sub}>
                  {m.duration} · {m.id === 'part2' ? `${bank.cards.length} cue cards` : `${bank.part3.length} discussion topics`}
                  {best(m.id) !== null ? ` · best ${formatBand(best(m.id))}` : ''}
                </p>
              </div>
              <span className={w.arrow}>
                <Icon name="north_east" size={18} />
              </span>
            </div>
          </Card>
        ))}
      </div>

      {hub.mockInterview && (
        <Link href="/app/speaking/tests" className={`${w.wide} ${w.peachCard}`}>
          <span className={w.wideIcon} style={{ background: 'var(--on-peach)', color: '#ffb8a3' }}>
            <Icon name="mic" size={18} />
          </span>
          <span className={w.twoLine}>
            <b>{hub.mockInterview.title}</b>
            <span>{hub.mockInterview.subtitle}</span>
          </span>
          <Icon name="chevron_right" size={20} />
        </Link>
      )}

      <div className={w.moreHead}>More in Speaking</div>
      <div className={w.more}>
        {rows.map(([icon, title, sub, href]) => (
          <Card key={href} href={href} padding="10px 12px 10px 10px" radius={20}>
            <div className={w.moreRow}>
              <span className={w.wideIcon} style={{ width: 42, height: 42, background: 'var(--accent-soft)' }}>
                <Icon name={icon} size={18} />
              </span>
              <span className={w.twoLine}>
                <b>{title}</b>
                <span style={{ color: 'var(--text-muted)', opacity: 1 }}>{sub}</span>
              </span>
              <Icon name="chevron_right" size={16} color="var(--text-muted)" />
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
