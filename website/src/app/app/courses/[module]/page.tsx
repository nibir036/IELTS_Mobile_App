import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { LangSwitch } from '@/components/lang-switch';
import { HeroCard, Icon, Nexi } from '@/components/ui';
import c from '@/components/course.module.css';
import { COURSE_MODULES, MODULE_NAMES, nexiFor } from '@/lib/content/lang';
import { moduleContent } from '@/lib/server/content';
import { allLessons, doneIn, lessonsDone, lessonsOf, resumeIn, stages, streakDays, xpOf } from '@/lib/server/lessons';

export async function generateMetadata({ params }: { params: Promise<{ module: string }> }): Promise<Metadata> {
  const { module } = await params;
  return { title: `${MODULE_NAMES[module] ?? 'Course'} Course` };
}

/** A module's course map (course_screen.dart): continue card, stages → lessons. */
export default async function CoursePage({ params }: { params: Promise<{ module: string }> }) {
  const { module } = await params;
  if (!(COURSE_MODULES as readonly string[]).includes(module)) notFound();
  const [mc, done] = await Promise.all([moduleContent(module), lessonsDone()]);
  const streak = await streakDays(done);
  const st = stages(mc.course);
  const all = allLessons(mc.course);
  const n = all.filter((l) => done[String(l.id)]).length;
  const resume = resumeIn(module, mc.course, done);
  const current = resume ? String(resume.stage.id) : '';
  const name = MODULE_NAMES[module];
  const dir = mc.lang.rtl ? 'rtl' : undefined;

  return (
    <>
      <div className={c.top}>
        <Link href="/app/courses" className={c.back} aria-label="All courses">
          <Icon name="arrow_back" size={20} />
        </Link>
        <div className={c.topText}>
          <h1 className={c.h1}>{name} Course</h1>
          <p className={c.sub}>
            {st.length} stages · {all.length} lessons
          </p>
        </div>
        <span className={c.xp}>
          <span>
            <Icon name="star" size={16} color="var(--peach)" filled /> {xpOf(done)} XP
          </span>
          <span>
            <Icon name="local_fire_department" size={16} color="var(--alert)" filled /> {streak}
          </span>
        </span>
      </div>

      {st.length === 0 ? (
        <p className={c.sub}>The lessons could not be loaded. Refresh the page to try again.</p>
      ) : (
        <>
          <HeroCard padding={20}>
            <div className={c.continue}>
              <div className={c.continueText}>
                <span className={c.overline}>{!resume ? 'Course complete' : n === 0 ? 'Start here' : 'Continue'}</span>
                <h2 className={c.continueTitle} dir={dir}>
                  {resume ? mc.text(resume.lesson.title) : 'You finished every lesson'}
                </h2>
                <span className={c.heroMuted}>
                  {resume ? `Stage ${resume.stageIndex + 1} · Lesson ${resume.lessonIndex + 1} of ${resume.stageLessons}` : `${all.length} lessons · ${xpOf(done)} XP earned`}
                </span>
                <div className={`${c.bar} ${c.barHero}`}>
                  <span style={{ width: `${all.length ? (n / all.length) * 100 : 0}%` }} />
                </div>
                <span className={c.heroMuted}>
                  {n} of {all.length} lessons done
                </span>
                {resume && (
                  <Link className={c.peachBtn} href={`/app/courses/lesson/${resume.id}`}>
                    {n === 0 ? 'Start' : 'Continue'}
                  </Link>
                )}
              </div>
              <Nexi pose={resume ? nexiFor(module) : 'grad'} height={120} />
            </div>
          </HeroCard>

          <LangSwitch current={mc.lang.code} langs={mc.langs} />

          {st.map((stage, i) => {
            const ls = lessonsOf(stage);
            const d = doneIn(stage, done);
            const complete = ls.length > 0 && d === ls.length;
            const open = String(stage.id) === current || (!resume && i === 0);
            const sub = mc.text(stage.subtitle);
            return (
              <details key={String(stage.id)} className={c.stage} open={open} dir={dir}>
                <summary>
                  <span className={`${c.stageBadge} ${i % 2 ? c.stageBadgeAlt : ''} ${complete ? c.stageBadgeDone : ''}`}>
                    {complete ? <Icon name="check" size={22} /> : i + 1}
                  </span>
                  <span className={c.stageText}>
                    <span className={c.stageMeta}>
                      Stage {i + 1} · {d}/{ls.length}
                    </span>
                    <div className={c.stageTitle}>{mc.text(stage.title)}</div>
                    {sub && <div className={c.stageSub}>{sub}</div>}
                  </span>
                  <Icon name="expand_more" size={20} className={c.chev} />
                </summary>
                <div className={`${c.bar} ${c.stageBar}`}>
                  <span style={{ width: `${ls.length ? (d / ls.length) * 100 : 0}%` }} />
                </div>
                <div className={c.lessons}>
                  {ls.map((l, j) => {
                    const id = String(l.id);
                    const isDone = Boolean(done[id]);
                    const isCurrent = id === resume?.id;
                    const steps = Array.isArray(l.steps) ? l.steps.length : 0;
                    const interactive = !l.auto;
                    return (
                      <Link key={id} href={`/app/courses/lesson/${id}`} className={`${c.lessonRow} ${isCurrent ? c.lessonCurrent : ''}`}>
                        <span className={`${c.lessonNum} ${isDone ? c.lessonNumDone : isCurrent ? c.lessonNumCurrent : ''}`}>
                          {isDone ? <Icon name="check" size={17} /> : j + 1}
                        </span>
                        <span className={c.lessonText}>
                          <div className={c.lessonTitle}>{mc.text(l.title)}</div>
                          <div className={c.lessonMeta}>
                            {Number(l.minutes) || 0} min · {steps} {interactive ? 'steps · interactive' : 'cards'}
                          </div>
                        </span>
                        <Icon name={isCurrent ? 'play_arrow' : 'chevron_right'} size={18} color={isCurrent ? 'var(--text)' : 'var(--text-muted)'} />
                      </Link>
                    );
                  })}
                </div>
              </details>
            );
          })}

          <Link href={`/app/guides/${module}`} className={c.guideLink}>
            <Icon name="article" size={18} /> Read the full {name} guide
          </Link>
        </>
      )}
    </>
  );
}
