import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, HeroCard, Icon, Nexi } from '@/components/ui';
import c from '@/components/course.module.css';
import { COURSE_MODULES, MODULE_NAMES, moduleIcon } from '@/lib/content/lang';
import { moduleContent } from '@/lib/server/content';
import { allLessons, lessonsDone, resumeIn, stages, streakDays, xpOf } from '@/lib/server/lessons';

export const metadata: Metadata = { title: 'Courses' };

/** Every course with its progress, and where to pick up. */
export default async function CoursesPage() {
  const [done, ...mods] = await Promise.all([lessonsDone(), ...COURSE_MODULES.map((m) => moduleContent(m))]);
  const streak = await streakDays(done);
  const rows = mods.map((mc) => {
    const all = allLessons(mc.course);
    const n = all.filter((l) => done[String(l.id)]).length;
    const resume = resumeIn(mc.module, mc.course, done);
    return { mc, total: all.length, n, stages: stages(mc.course).length, resume };
  });
  // The course touched last: the most recent finished lesson.
  const last = Object.values(done).sort((a, b) => String(b.at).localeCompare(String(a.at)))[0];
  const pick = rows.find((r) => r.mc.module === last?.module && r.resume) ?? rows.find((r) => r.resume);
  const totalDone = Object.keys(done).length;
  return (
    <>
      <div className={c.top}>
        <div className={c.topText}>
          <h1 className={c.h1}>Courses</h1>
          <p className={c.sub}>Bite-sized lessons from the nextED books · {rows.reduce((a, r) => a + r.total, 0)} lessons</p>
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

      {pick?.resume && (
        <HeroCard padding={20}>
          <div className={c.continue}>
            <div className={c.continueText}>
              <span className={c.overline}>{totalDone ? 'Continue' : 'Start here'}</span>
              <h2 className={c.continueTitle}>{pick.mc.text(pick.resume.lesson.title)}</h2>
              <span className={c.heroMuted}>
                {MODULE_NAMES[pick.mc.module]} · Stage {pick.resume.stageIndex + 1} · Lesson {pick.resume.lessonIndex + 1} of {pick.resume.stageLessons}
              </span>
              <Link className={c.peachBtn} href={`/app/courses/lesson/${pick.resume.id}`}>
                {totalDone ? 'Continue' : 'Start'}
              </Link>
            </div>
            <Nexi pose="point" height={120} />
          </div>
        </HeroCard>
      )}

      <div className={c.grid}>
        {rows.map(({ mc, total, n, stages: st }) => (
          <Card key={mc.module} href={`/app/courses/${mc.module}`} padding={16} radius={24}>
            <div className={c.courseCard}>
              <span className={c.courseIcon}>
                <Icon name={moduleIcon(mc.module)} size={24} />
              </span>
              <div className={c.stageText}>
                <div className={c.stageTitle}>{MODULE_NAMES[mc.module]} Course</div>
                <div className={c.stageSub}>
                  {st} stages · {total} lessons · {n} done
                </div>
                <div className={c.bar} style={{ marginTop: 8 }}>
                  <span style={{ width: `${total ? (n / total) * 100 : 0}%` }} />
                </div>
              </div>
              <Icon name="chevron_right" size={20} color="var(--text-muted)" />
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}
