// The app's building blocks (lib/app/widgets/kit.dart) for the web, so pages
// look the same as their app screens.

import Image from 'next/image';
import Link from 'next/link';
import type { CSSProperties, ReactNode } from 'react';
import s from './ui.module.css';

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');

/** A Material Symbols icon by name ('home', 'lock' …), like the app's AppIcons. */
export function Icon({ name, size = 22, filled, color, className }: { name: string; size?: number; filled?: boolean; color?: string; className?: string }) {
  return (
    <span aria-hidden className={cx('icon', filled && 'filled', className)} style={{ fontSize: size, color }}>
      {name}
    </span>
  );
}

/** Frosted glass card (AppCard). Pass [href] to make the whole card a link. */
export function Card({
  children,
  href,
  padding,
  radius,
  style,
  className,
}: {
  children: ReactNode;
  href?: string;
  padding?: number | string;
  radius?: number;
  style?: CSSProperties;
  className?: string;
}) {
  const st: CSSProperties = { ...(padding !== undefined ? { padding } : {}), ...(radius ? { borderRadius: radius } : {}), ...style };
  if (href) {
    return (
      <Link href={href} className={cx(s.card, s.cardLink, className)} style={st}>
        {children}
      </Link>
    );
  }
  return (
    <div className={cx(s.card, className)} style={st}>
      {children}
    </div>
  );
}

/** Dark navy card with the peach / blue glow (HeroCard). */
export function HeroCard({ children, padding, radius, className }: { children: ReactNode; padding?: number; radius?: number; className?: string }) {
  return (
    <div className={cx(s.hero, className)} style={{ ...(padding !== undefined ? { padding } : {}), ...(radius ? { borderRadius: radius } : {}) }}>
      {children}
    </div>
  );
}

type ButtonProps = {
  children: ReactNode;
  href?: string;
  onClick?: () => void;
  type?: 'button' | 'submit';
  disabled?: boolean;
  block?: boolean;
  dark?: boolean;
  leading?: string;
  trailing?: string;
  height?: number;
};

/** Peach pill button (PrimaryButton); [dark] = the black / peach-on-night one. */
export function PrimaryButton({ children, href, onClick, type = 'button', disabled, block, dark, leading, trailing, height }: ButtonProps) {
  const className = cx(s.primary, block && s.block, dark && s.dark);
  const inner = (
    <>
      {leading && <Icon name={leading} size={18} />}
      <span>{children}</span>
      {trailing && <Icon name={trailing} size={18} />}
    </>
  );
  const style = height ? { height } : undefined;
  if (href && !disabled) {
    return (
      <Link href={href} className={className} style={style}>
        {inner}
      </Link>
    );
  }
  return (
    <button type={type} className={className} onClick={onClick} disabled={disabled} style={style}>
      {inner}
    </button>
  );
}

export function SoftButton({ children, href, onClick, disabled, leading }: ButtonProps) {
  const inner = (
    <>
      {leading && <Icon name={leading} size={18} />}
      {children}
    </>
  );
  if (href) {
    return (
      <Link href={href} className={s.soft}>
        {inner}
      </Link>
    );
  }
  return (
    <button type="button" className={s.soft} onClick={onClick} disabled={disabled}>
      {inner}
    </button>
  );
}

export function IconCircle({ icon, size = 40, bg, fg }: { icon: string; size?: number; bg?: string; fg?: string }) {
  return (
    <span className={s.iconCircle} style={{ width: size, height: size, background: bg, color: fg }}>
      <Icon name={icon} size={Math.round(size * 0.48)} />
    </span>
  );
}

export function Tag({ children, tone }: { children: ReactNode; tone?: 'primary' | 'peach' }) {
  return <span className={cx(s.tag, tone === 'primary' && s.tagPrimary, tone === 'peach' && s.tagPeach)}>{children}</span>;
}

export function SectionTitle({ children, as: As = 'h2' }: { children: ReactNode; as?: 'h1' | 'h2' | 'h3' }) {
  return <As className={s.sectionTitle}>{children}</As>;
}

export function Notice({ icon, title, children, action }: { icon: string; title: string; children: ReactNode; action?: ReactNode }) {
  return (
    <div className={s.notice} role="status">
      <IconCircle icon={icon} size={38} bg="var(--surface)" />
      <div style={{ flex: 1, minWidth: 0 }}>
        <p className={s.noticeTitle}>{title}</p>
        <p className={s.noticeBody}>{children}</p>
        {action && <div style={{ marginTop: 10 }}>{action}</div>}
      </div>
    </div>
  );
}

export type NexiPose = 'wave' | 'point' | 'thumbs' | 'grad' | 'listening' | 'reading' | 'speaking' | 'writing';

/** Nexi, the mascot (same images as the app). */
export function Nexi({ pose, height, priority }: { pose: NexiPose; height: number; priority?: boolean }) {
  return (
    <Image
      src={`/mascot/nexi_${pose}.png`}
      alt=""
      width={Math.round(height * 0.8)}
      height={height}
      priority={priority}
      style={{ height, width: 'auto', objectFit: 'contain', flex: 'none' }}
    />
  );
}

/** App icon + "IELTS AI" (the login screen's header). */
export function Brand({ size = 36, href = '/' }: { size?: number; href?: string }) {
  return (
    <Link href={href} className={s.brand} aria-label="IELTS AI by nextED, home">
      <Image src="/branding/app_icon.png" alt="" width={size} height={size} className={s.brandMark} />
      <span>IELTS AI</span>
    </Link>
  );
}

export const uiStyles = s;
