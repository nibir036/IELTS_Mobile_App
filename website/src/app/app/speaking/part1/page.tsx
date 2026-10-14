import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon, PrimaryButton, Tag } from '@/components/ui';
import { speakingBank } from '@/lib/server/speaking';
import w from '../../writing/writing.module.css';

export const metadata: Metadata = { title: 'Part 1 topics' };

export default async function Part1({ searchParams }: { searchParams: Promise<{ c?: string }> }) {
  const { c } = await searchParams;
  const bank = await speakingBank();
  const cats = [...new Map(bank.part1.map((t) => [t.category, t.categoryLabel])).entries()];
  const list = c ? bank.part1.filter((t) => t.category === c) : bank.part1;
  const pick = list[Math.floor(Math.random() * Math.max(1, list.length))];
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/speaking" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Speaking
          </Link>
          <h1 className={w.title}>Part 1 · Short Q&amp;A</h1>
          <p className={w.sub}>{list.length} topics · answer each question in 20–30 seconds</p>
        </div>
        {pick && (
          <PrimaryButton href={`/app/speaking/session/1/${pick.id}`} leading="shuffle">
            Random topic
          </PrimaryButton>
        )}
      </div>
      <nav className={w.chips}>
        <Link href="/app/speaking/part1" className={`${w.chip} ${!c ? w.chipOn : ''}`}>
          All
        </Link>
        {cats.map(([id, label]) => (
          <Link key={id} href={`/app/speaking/part1?c=${id}`} className={`${w.chip} ${c === id ? w.chipOn : ''}`}>
            {label}
          </Link>
        ))}
      </nav>
      <div className={w.qList}>
        {list.map((t) => (
          <Card key={t.id} href={`/app/speaking/session/1/${t.id}`} padding={14} radius={22}>
            <div className={w.q}>
              <div className={w.grow}>
                <p className={w.qTitle}>{t.topic}</p>
                <p className={w.qText}>{t.questions.slice(0, 2).join(' · ')}</p>
                <div className={w.qMeta}>
                  <Tag>{t.questions.length} questions</Tag>
                  <Tag>{t.categoryLabel}</Tag>
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
