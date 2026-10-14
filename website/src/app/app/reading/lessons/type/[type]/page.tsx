import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { ReactNode } from 'react';
import { LangSwitch } from '@/components/lang-switch';
import { Icon } from '@/components/ui';
import { rows, str, type Raw } from '@/lib/practice/marking';
import { attempts } from '@/lib/server/attempts';
import { moduleTranslation } from '@/lib/server/content';
import { Exhibit } from '@/lib/lessons/exhibit';
import { typeLesson } from '@/lib/lessons/l10n';
import { bankSetsOf, readingTypeLessons, typeLessonsRead } from '@/lib/lessons/server';
import s from '@/lib/lessons/lessons.module.css';
import { MarkTypeRead } from './mark-read';

export const metadata: Metadata = { title: 'How to attempt' };

const NUMBERED = /^(\d+)\.\s+(.*)$/;

function Paragraph({ line }: { line: string }) {
  const m = NUMBERED.exec(line);
  if (!m) return <p className={s.para}>{line}</p>;
  return (
    <div className={s.numbered}>
      <span className={s.numDot}>{m[1]}</span>
      <p className={s.para}>{m[2]}</p>
    </div>
  );
}

/** A section's paragraphs and exhibits, in its layout order. */
function body(section: Raw): ReactNode[] {
  const paras = str(section.text)
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
  const exhibits = rows(section.exhibits);
  const layout = rows(section.layout);
  if (!layout.length) {
    return [...paras.map((p, i) => <Paragraph key={`p${i}`} line={p} />), ...exhibits.map((e, i) => <Exhibit key={`e${i}`} data={e} />)];
  }
  const out: ReactNode[] = [];
  layout.forEach((l, k) => {
    if ('paragraph' in l) {
      const i = Number(l.paragraph);
      if (i >= 0 && i < paras.length) out.push(<Paragraph key={`l${k}`} line={paras[i]} />);
    } else if ('exhibit' in l) {
      const i = Number(l.exhibit);
      if (i >= 0 && i < exhibits.length) out.push(<Exhibit key={`l${k}`} data={exhibits[i]} />);
    }
  });
  return out;
}

/** "How to attempt …" strategy lesson of one question type (reading_type_lesson_screen.dart). */
export default async function ReadingTypeLesson({ params }: { params: Promise<{ type: string }> }) {
  const { type } = await params;
  const [all, l10n, read, sets, mine] = await Promise.all([
    readingTypeLessons(),
    moduleTranslation('reading'),
    typeLessonsRead(),
    bankSetsOf(type),
    attempts({ skill: 'reading', limit: 500 }).catch(() => []),
  ]);
  const english = all.find((l) => str(l.questionType) === type);
  if (!english) notFound();
  const lesson = typeLesson(english, l10n.tr);
  const sections = rows(lesson.sections);
  const ids = new Set(sets.map((p) => str(p.id)));
  const done = new Set(mine.filter((a) => a.kind !== 'lesson' && ids.has(a.refId)).map((a) => a.refId));
  const start = sets.find((p) => !done.has(str(p.id))) ?? sets[0];
  const dir = l10n.lang.rtl && lesson !== english ? 'rtl' : undefined;

  return (
    <>
      <MarkTypeRead type={type} already={read.includes(type)} />
      <div className={s.head}>
        <Link href={`/app/reading/type/${encodeURIComponent(type)}`} className={s.iconBtn} aria-label={`Back to ${str(english.name)}`}>
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={s.headText}>
          <h1 className={s.h1} dir={dir}>
            {str(lesson.title)}
          </h1>
          <p className={s.sub}>
            {str(english.name)} · {sections.length} parts
          </p>
        </div>
      </div>
      <LangSwitch current={l10n.lang.code} langs={l10n.langs} />
      <div className={s.sections}>
        {sections.map((sec, i) => (
          <section key={i} className={`${s.card} ${s.section}`} dir={dir} aria-labelledby={`part-${i}`}>
            <div className={s.sectionHeadRow}>
              <span className={s.partNum}>{i + 1}</span>
              <h2 id={`part-${i}`} className={s.sectionHeading}>
                {str(sec.heading)}
              </h2>
            </div>
            {body(sec)}
          </section>
        ))}
      </div>
      {start && (
        <div className={s.footer}>
          <Link href={`/app/reading/do/${encodeURIComponent(str(start.id))}`} className={`${s.primaryBtn} ${s.block}`}>
            Start Set {str(start.bankSet)} · {str(start.difficulty)} <Icon name="arrow_forward" size={18} />
          </Link>
        </div>
      )}
    </>
  );
}
