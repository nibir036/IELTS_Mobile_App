'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Brand, Icon } from '@/components/ui';
import s from './shell.module.css';

/** The app's five tabs (lib/features/shell/main_shell.dart). */
export const TABS = [
  { href: '/app', icon: 'home', label: 'Home' },
  { href: '/app/practice', icon: 'auto_stories', label: 'Practice' },
  { href: '/app/mocks', icon: 'fact_check', label: 'Mock tests' },
  { href: '/app/community', icon: 'chat_bubble', label: 'Community chat' },
  { href: '/app/profile', icon: 'person', label: 'Profile' },
] as const;

/** Pages opened from Home (they keep the Home tab lit). */
const HOME_AREA = ['/app/analytics', '/app/schedule', '/app/notifications', '/app/search', '/app/certificates', '/app/onboarding', '/app/plan'];

function isActive(path: string, href: string) {
  if (href === '/app') return path === '/app' || HOME_AREA.some((h) => path === h || path.startsWith(h + '/'));
  return path === href || path.startsWith(href + '/');
}

export function Tabs() {
  const path = usePathname() ?? '';
  return (
    <>
      <nav className={s.side} aria-label="Main">
        <div className={s.sideBrand}>
          <Brand href="/app" />
        </div>
        {TABS.map((t) => {
          const on = isActive(path, t.href);
          return (
            <Link key={t.href} href={t.href} className={`${s.sideTab} ${on ? s.sideActive : ''}`} aria-current={on ? 'page' : undefined}>
              <Icon name={t.icon} size={22} />
              {t.label}
            </Link>
          );
        })}
      </nav>
      <nav className={s.bar} aria-label="Main">
        {TABS.map((t) => {
          const on = isActive(path, t.href);
          return (
            <Link key={t.href} href={t.href} className={`${s.tab} ${on ? s.active : ''}`} aria-current={on ? 'page' : undefined} title={t.label}>
              <Icon name={t.icon} size={22} />
              <span className="visually-hidden">{t.label}</span>
            </Link>
          );
        })}
      </nav>
    </>
  );
}
