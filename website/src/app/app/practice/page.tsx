import type { Metadata } from 'next';
import Link from 'next/link';
import { LoopVideo } from '@/components/loop-video';
import { Icon } from '@/components/ui';
import { getMe } from '@/lib/server/me';
import { uiPack } from '@/lib/server/packs';
import s from '../pages.module.css';

export const metadata: Metadata = { title: 'Practice' };

type Module = { id: string; title: string; video?: string; skill?: string };

const ROUTE: Record<string, string> = {
  vocab: '/app/resources',
  writing: '/app/writing',
  speaking: '/app/speaking',
  listening: '/app/listening',
  reading: '/app/reading',
};

/** Practice tab (lib/features/home/module_hub_screen.dart): Resources across the top, then the four skills. */
export default async function PracticePage() {
  const [me, ui] = await Promise.all([getMe(), uiPack().catch(() => ({}) as Record<string, unknown>)]);
  const modules = (((ui.home ?? {}) as { modules?: Module[] }).modules ?? []).filter((m) => m.skill && ROUTE[m.skill]);
  const initials = me.user.name
    .split(/\s+/)
    .map((p) => p[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
  return (
    <>
      <div className={s.header}>
        <div>
          <h1 className={s.pageTitle}>Practice</h1>
          <p className={s.muted}>Pick a skill and start.</p>
        </div>
        <Link href="/app/profile" className={s.avatar} aria-label="Profile">
          {initials}
        </Link>
      </div>
      <div className={s.modules}>
        {modules.map((m, i) => (
          <Link key={m.id} href={ROUTE[m.skill!]} className={`${s.module} ${i === 0 ? s.moduleWide : ''}`}>
            <div className={s.moduleMedia}>
              {m.video && <LoopVideo src={`/videos/${m.video.split('/').pop()}`} label={m.title} />}
            </div>
            <div className={s.moduleName}>
              <span>{m.title}</span>
              <Icon name="arrow_forward" size={18} color="var(--text-muted)" />
            </div>
          </Link>
        ))}
      </div>
      <Link href="/app/courses" className={s.coursesCard}>
        <span className={s.coursesIcon}>
          <Icon name="school" size={24} />
        </span>
        <span style={{ flex: 1 }}>
          <b>Courses</b>
          <span className={s.muted} style={{ display: 'block', fontSize: 13 }}>
            Writing, Speaking, Reading, Listening, Grammar and Vocabulary · bite-sized lessons
          </span>
        </span>
        <Icon name="arrow_forward" size={18} color="var(--text-muted)" />
      </Link>
    </>
  );
}
