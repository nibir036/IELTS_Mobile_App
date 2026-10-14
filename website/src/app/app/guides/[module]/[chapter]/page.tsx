import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { GuideBlock } from '@/components/guide-block';
import { LangSwitch } from '@/components/lang-switch';
import { Icon, PrimaryButton, SoftButton } from '@/components/ui';
import c from '@/components/course.module.css';
import { COURSE_MODULES, MODULE_NAMES } from '@/lib/content/lang';
import { moduleContent } from '@/lib/server/content';

export const metadata: Metadata = { title: 'Guide' };

/** One study-guide chapter, with previous / next. */
export default async function ChapterPage({ params }: { params: Promise<{ module: string; chapter: string }> }) {
  const { module, chapter } = await params;
  if (!(COURSE_MODULES as readonly string[]).includes(module)) notFound();
  const mc = await moduleContent(module, { course: false });
  const chapters = mc.guide.chapters;
  const at = chapters.findIndex((x) => x.id === decodeURIComponent(chapter));
  if (at < 0) notFound();
  const ch = chapters[at];
  const prev = chapters[at - 1];
  const next = chapters[at + 1];
  const href = (id: string) => `/app/guides/${module}/${encodeURIComponent(id)}`;
  return (
    <>
      <div className={c.top}>
        <Link href={`/app/guides/${module}`} className={c.back} aria-label="Contents">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={c.topText}>
          <p className={c.sub} style={{ margin: 0 }}>
            Chapter {at + 1} of {chapters.length}
          </p>
          <h1 className={c.h1} style={{ fontSize: 19 }}>
            {MODULE_NAMES[module]} Guide
          </h1>
        </div>
      </div>
      <LangSwitch current={mc.lang.code} langs={mc.langs} />
      <article className={c.article} dir={mc.lang.rtl ? 'rtl' : undefined}>
        <h2 className={c.articleTitle}>{ch.title}</h2>
        {ch.blocks.map((b, i) => (Array.isArray(b) && b.length ? <GuideBlock key={i} block={b} /> : null))}
      </article>
      <div className={c.foot} style={{ maxWidth: 820 }}>
        {prev && (
          <SoftButton href={href(prev.id)} leading="chevron_left">
            Previous
          </SoftButton>
        )}
        <PrimaryButton href={next ? href(next.id) : `/app/guides/${module}`} trailing={next ? 'chevron_right' : undefined}>
          {next ? 'Next chapter' : 'Contents'}
        </PrimaryButton>
      </div>
    </>
  );
}
