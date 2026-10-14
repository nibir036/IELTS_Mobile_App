import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Card, Icon, PrimaryButton, SectionTitle, Tag } from '@/components/ui';
import { writingPrompt } from '@/lib/server/writing';
import { mediaUrl } from '@/lib/media';
import s from '../../writing.module.css';
import r from '../../result/[id]/result.module.css';

export const metadata: Metadata = { title: 'Sample answers' };

/** Band 6, 7 and 8 answers for one question (writing_sample_answer_screen.dart). */
export default async function Samples({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const p = await writingPrompt(decodeURIComponent(id));
  if (!p) notFound();
  const samples = [...p.samples].sort((a, b) => Number(a.band) - Number(b.band));
  if (!samples.length && p.modelAnswer) samples.push({ band: p.modelBand || 8, label: `Band ${p.modelBand || 8}`, text: p.modelAnswer });
  return (
    <>
      <div className={s.head}>
        <div>
          <Link href="/app/writing/samples" className={s.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Sample answers
          </Link>
          <h1 className={s.title}>{p.title}</h1>
          <p className={s.sub}>
            Task {p.task} · {p.typeName}
          </p>
        </div>
        <PrimaryButton href={`/app/writing/write/${p.id}`} leading="edit">
          Write this one
        </PrimaryButton>
      </div>
      <Card padding={18}>
        <SectionTitle>Question</SectionTitle>
        <p className={r.para}>{p.prompt}</p>
        {p.image && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={mediaUrl(p.image)} alt={p.title} style={{ width: '100%', maxWidth: 640, borderRadius: 14, marginTop: 10, background: '#fff' }} />
        )}
      </Card>
      {samples.map((x) => (
        <Card key={String(x.band)} padding={18}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
            <SectionTitle>{x.label || `Band ${x.band}`}</SectionTitle>
            {x.words ? <Tag>{x.words} words</Tag> : null}
          </div>
          {x.why && (
            <p className={r.muted} style={{ marginTop: 6 }}>
              {Array.isArray(x.why) ? x.why.join(' · ') : x.why}
            </p>
          )}
          <p className={r.para}>{x.text}</p>
        </Card>
      ))}
    </>
  );
}
