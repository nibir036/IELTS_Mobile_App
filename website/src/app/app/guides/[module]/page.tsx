import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { LangSwitch } from '@/components/lang-switch';
import { Card, Icon } from '@/components/ui';
import c from '@/components/course.module.css';
import { COURSE_MODULES, MODULE_NAMES } from '@/lib/content/lang';
import { moduleContent } from '@/lib/server/content';

export async function generateMetadata({ params }: { params: Promise<{ module: string }> }): Promise<Metadata> {
  const { module } = await params;
  return { title: `${MODULE_NAMES[module] ?? ''} Guide` };
}

/** A study guide's contents page (study_guide_screen.dart). */
export default async function GuidePage({ params }: { params: Promise<{ module: string }> }) {
  const { module } = await params;
  if (!(COURSE_MODULES as readonly string[]).includes(module)) notFound();
  const mc = await moduleContent(module, { course: false });
  const { guide } = mc;
  const dir = mc.lang.rtl ? 'rtl' : undefined;
  return (
    <>
      <div className={c.top}>
        <Link href={`/app/courses/${module}`} className={c.back} aria-label="Back to the course">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={c.topText}>
          <h1 className={c.h1}>{guide.title || `${MODULE_NAMES[module]} Guide`}</h1>
          <p className={c.sub}>{guide.chapters.length} chapters</p>
        </div>
      </div>
      {guide.subtitle && <p className={c.sub} style={{ fontSize: 14, color: 'var(--text-soft)' }}>{guide.subtitle}</p>}
      <LangSwitch current={mc.lang.code} langs={mc.langs} />
      {guide.chapters.length === 0 && <p className={c.sub}>The guide could not be loaded. Refresh the page to try again.</p>}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }} dir={dir}>
        {guide.chapters.map((ch, i) => {
          const m = /^(\d+)\.\s+(.*)$/.exec(ch.title);
          const badge = m ? m[1] : String(i + 1);
          const title = m ? m[2] : ch.title;
          const showGroup = ch.group && ch.group !== guide.chapters[i - 1]?.group;
          return (
            <div key={ch.id} style={{ display: 'contents' }}>
              {showGroup && <h2 className={c.group}>{ch.group}</h2>}
              <Card href={`/app/guides/${module}/${encodeURIComponent(ch.id)}`} padding="12px 14px" radius={20}>
                <div className={c.chapterRow}>
                  <span className={`${c.chapterBadge} ${ch.id.endsWith('_practice') ? c.chapterBadgePractice : ''}`}>{badge}</span>
                  <span style={{ flex: 1, fontSize: 15, fontWeight: 500, lineHeight: 1.3 }}>{title}</span>
                  <Icon name="chevron_right" size={18} color="var(--text-muted)" />
                </div>
              </Card>
            </div>
          );
        })}
      </div>
    </>
  );
}
