import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { BookmarkButton, MarkedText, VocabChips } from '@/components/extras/sample-words';
import { practiseHref } from '@/components/extras/word-card';
import { Card, HeroCard, Icon, PrimaryButton, SectionTitle, Tag } from '@/components/ui';
import { findSample, libraryBank, sampleVocabKeys, sampleWordCount, samplesHref, savedKey, vocabEntry, type VocabEntry } from '@/lib/extras/speaking-library';
import { rows, str, strs, type Raw } from '@/lib/practice/marking';
import { stateValue } from '@/lib/server/attempts';
import x from '@/components/extras/extras.module.css';
import r from '@/components/extras/speaking.module.css';

export const metadata: Metadata = { title: 'Speaking sample answers' };

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');

function QuestionCard({ n, q, answer, tag, vocab }: { n: number; q: string; answer: string; tag?: string; vocab: Record<string, VocabEntry> }) {
  return (
    <Card padding="14px 16px 16px" radius={22}>
      <div className={x.cardCol} style={{ gap: 10 }}>
        <div className={r.qHead}>
          <span className={r.num}>{n}</span>
          <h3 className={r.qTitle}>{q}</h3>
        </div>
        {tag && (
          <span>
            <Tag>{tag}</Tag>
          </span>
        )}
        <MarkedText text={answer} vocab={vocab} />
        <p className={x.small}>{sampleWordCount(answer)} words</p>
      </div>
    </Card>
  );
}

/** D12 · Sample answers for one Part 1 topic, cue card or Part 3 topic (speaking_samples_screen.dart). */
export default async function SpeakingSamples({ params }: { params: Promise<{ id: string }> }) {
  const { id: raw } = await params;
  const id = decodeURIComponent(raw);
  const bank = await libraryBank();
  const hit = findSample(bank, id);
  if (!hit) notFound();
  const { part, item, list } = hit;
  const saved = await stateValue<unknown[]>(savedKey(part));
  const isSaved = Array.isArray(saved) && saved.map(String).includes(id);
  const pos = list.findIndex((x) => str(x.id) === id);
  const prev = pos > 0 ? str(list[pos - 1].id) : '';
  const next = pos >= 0 && pos < list.length - 1 ? str(list[pos + 1].id) : '';
  const title = part === 2 ? str(item.title) : str(item.topic);
  const bandLabel = str(((bank.meta.bands ?? {}) as Raw)[`part${part}`]);
  const note = str(bank.meta.sampleNote) || 'Use sample answers for ideas, structure and vocabulary, then answer with your own experience.';
  const subtitle = [`Part ${part}`, str(item.categoryLabel), bandLabel].filter(Boolean).join(' · ');

  // Every marked word of the page, in order.
  const texts: string[] =
    part === 1
      ? rows(item.samples).map((s) => str(s.answer))
      : part === 2
        ? [str((item.sample as Raw | undefined)?.answer), ...rows(item.followUps).map((s) => str(s.answer))]
        : rows(item.questions).map((s) => str(s.answer));
  const keys: string[] = [];
  for (const t of texts) for (const k of sampleVocabKeys(t)) if (!keys.includes(k)) keys.push(k);
  const vocab: Record<string, VocabEntry> = {};
  for (const k of keys) {
    const e = vocabEntry(bank.vocab, k);
    if (e) vocab[k] = e;
  }
  const known = keys.filter((k) => vocab[k]);
  const practise = part === 2 ? `/app/speaking/cue/${encodeURIComponent(id)}` : `/app/speaking/session/${part}/${encodeURIComponent(id)}`;

  const sample = (item.sample ?? {}) as Raw;
  const secs = Number(sample.seconds) || 0;
  const links = strs(item.part3Topics)
    .map((pid) => bank.part3.find((t) => str(t.id) === pid) ?? bank.testPart3.find((t) => str(t.id) === pid))
    .filter((t): t is Raw => Boolean(t));

  return (
    <div className={x.page}>
      <div className={x.top}>
        <Link href={`/app/speaking/library?tab=part${part}`} className={x.iconBtn} aria-label="Back to sample answers">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div style={{ flex: 1, minWidth: 0 }}>
          <span className={x.small}>Sample answers</span>
          <span style={{ display: 'block', fontSize: 15, fontWeight: 500 }}>
            {pos + 1} of {list.length}
          </span>
        </div>
        <BookmarkButton kvKey={savedKey(part)} id={id} initial={isSaved} />
        <nav className={r.navBtns} aria-label="Previous and next">
          <Link href={prev ? samplesHref(prev) : '#'} className={cx(x.iconBtn, !prev && r.navOff)} aria-label="Previous" aria-disabled={!prev} tabIndex={prev ? undefined : -1}>
            <Icon name="chevron_left" size={22} />
          </Link>
          <Link href={next ? samplesHref(next) : '#'} className={cx(x.iconBtn, !next && r.navOff)} aria-label="Next" aria-disabled={!next} tabIndex={next ? undefined : -1}>
            <Icon name="chevron_right" size={22} />
          </Link>
        </nav>
      </div>

      <div>
        <h1 className={x.h1} style={{ fontSize: 28 }}>
          {title}
        </h1>
        <p className={x.lead}>{subtitle}</p>
        {part === 3 && str(item.description) && (
          <p className={x.para} style={{ marginTop: 6 }}>
            {str(item.description)}
          </p>
        )}
      </div>

      <div className={r.info}>
        <Icon name="info" size={16} />
        <span>Tap an underlined word for its meaning and pronunciation. {note}</span>
      </div>

      {part === 1 && (
        <div className={x.two}>
          {rows(item.samples).map((s, i) => (
            <QuestionCard key={i} n={i + 1} q={str(s.q)} answer={str(s.answer)} vocab={vocab} />
          ))}
        </div>
      )}

      {part === 3 && (
        <div className={x.two}>
          {rows(item.questions).map((s, i) => (
            <QuestionCard key={i} n={i + 1} q={str(s.q)} answer={str(s.answer)} tag={str(s.tagLabel)} vocab={vocab} />
          ))}
        </div>
      )}

      {part === 2 && (
        <>
          <div className={x.two}>
            <HeroCard padding={18} radius={28}>
              <p className={x.heroLabel} style={{ margin: '0 0 10px' }}>
                You should say:
              </p>
              <ul className={r.bullets}>
                {strs(item.bullets).map((b) => (
                  <li key={b}>{b}</li>
                ))}
              </ul>
            </HeroCard>
            {strs(item.notes).length > 0 && (
              <Card padding="14px 16px 16px" radius={22}>
                <div className={x.cardCol} style={{ gap: 6 }}>
                  <SectionTitle as="h2">1-minute notes</SectionTitle>
                  <p className={x.small}>What fits on the note paper in one minute</p>
                  {strs(item.notes).map((n, i) => (
                    <p key={i} className={x.para} style={{ fontSize: 13.5 }}>
                      {n}
                    </p>
                  ))}
                </div>
              </Card>
            )}
          </div>
          <Card padding="14px 18px 18px" radius={22}>
            <div className={x.cardCol} style={{ gap: 10 }}>
              <div>
                <SectionTitle as="h2">Sample talk</SectionTitle>
                <p className={x.small}>
                  {sampleWordCount(str(sample.answer))} words{secs ? ` · about ${Math.floor(secs / 60)} min ${secs % 60} s` : ''}
                </p>
              </div>
              <MarkedText text={str(sample.answer)} vocab={vocab} />
              {strs(item.phrases).length > 0 && <p className={x.para}>Useful phrases: {strs(item.phrases).join(' · ')}</p>}
            </div>
          </Card>
          {rows(item.followUps).length > 0 && (
            <>
              <div>
                <SectionTitle>Rounding-off questions</SectionTitle>
                <p className={x.small}>The examiner may ask one or two after your talk</p>
              </div>
              <div className={x.two}>
                {rows(item.followUps).map((s, i) => (
                  <QuestionCard key={i} n={i + 1} q={str(s.q)} answer={str(s.answer)} vocab={vocab} />
                ))}
              </div>
            </>
          )}
          {links.length > 0 && (
            <>
              <div>
                <SectionTitle>Part 3 discussion</SectionTitle>
                <p className={x.small}>Topics the examiner may move on to</p>
              </div>
              <div className={r.vocab}>
                {links.map((t) => (
                  <Link key={str(t.id)} href={samplesHref(str(t.id))} className={r.vocabChip} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                    <Icon name="chat" size={16} /> {str(t.topic)}
                  </Link>
                ))}
              </div>
            </>
          )}
        </>
      )}

      {known.length > 0 && (
        <>
          <div className={x.spread} style={{ alignItems: 'flex-end' }}>
            <div>
              <SectionTitle>Key vocabulary</SectionTitle>
              <p className={x.small}>{known.length} words and phrases</p>
            </div>
            <Link href={practiseHref(known, title)} className={x.small} style={{ color: 'var(--text)', fontWeight: 500 }}>
              Practise saying them →
            </Link>
          </div>
          <VocabChips keys={known} vocab={vocab} />
        </>
      )}

      <div className={x.footer}>
        <PrimaryButton href={practise} leading="mic">
          {part === 2 ? 'Practise this cue card' : 'Practise this topic'}
        </PrimaryButton>
      </div>
    </div>
  );
}
