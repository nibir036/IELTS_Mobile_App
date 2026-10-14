import Link from 'next/link';
import type { ReactNode } from 'react';
import { Icon, Tag } from '../ui';
import { SOON_MESSAGE, SOON_TITLE } from './data';
import c from './community.module.css';

/**
 * ComingSoonWall (kit.dart): the screen underneath is shown blurred and inert,
 * with a "Coming soon" card on top. [backHref] adds the back button.
 */
export function SoonWall({ children, backHref }: { children?: ReactNode; backHref?: string }) {
  return (
    <div className={`${c.root} ${c.wall}`}>
      {backHref && (
        <Link href={backHref} className={`${c.iconBtn} ${c.wallBack}`} aria-label="Back">
          <Icon name="arrow_back" size={18} />
        </Link>
      )}
      <div className={c.wallContent} inert aria-hidden>
        {children}
      </div>
      <div className={c.wallOverlay}>
        <section className={c.wallCard} aria-labelledby="community-soon-title">
          <span className={c.wallIcon} aria-hidden>
            <Icon name="chat_bubble" size={24} />
          </span>
          <Tag tone="peach">Coming soon</Tag>
          <h1 id="community-soon-title" className={c.wallTitle}>
            {SOON_TITLE}
          </h1>
          <p className={c.wallMsg}>{SOON_MESSAGE}</p>
        </section>
      </div>
    </div>
  );
}
