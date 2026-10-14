'use client';

import { useState } from 'react';
import { Icon, IconCircle, PrimaryButton } from '@/components/ui';
import d from '@/components/dialog.module.css';
import type { CertStatus } from '@/lib/home/certificates';
import h from './home.module.css';
import { Portal } from '@/components/portal';

export interface CertView extends CertStatus {
  iconName: string;
  /** "21 Sep 2026" ('' when unknown). */
  date: string;
  certId: string;
}

/** Progress ring + medal (_Badge). */
function Medal({ c }: { c: CertView }) {
  const r = 28;
  const len = 2 * Math.PI * r;
  return (
    <span className={`${h.medal} ${c.earned ? h.medalOn : ''}`}>
      {!c.earned && (
        <svg viewBox="0 0 62 62" aria-hidden>
          <circle cx={31} cy={31} r={r} fill="none" style={{ stroke: 'var(--track)' }} strokeWidth={3.5} />
          <circle
            cx={31}
            cy={31}
            r={r}
            fill="none"
            style={{ stroke: 'var(--peach)' }}
            strokeWidth={3.5}
            strokeLinecap="round"
            strokeDasharray={`${len * c.progress} ${len}`}
            transform="rotate(-90 31 31)"
          />
        </svg>
      )}
      <span className={h.medalCore}>
        <Icon name={c.iconName} size={c.earned ? 28 : 22} />
      </span>
      {!c.earned && (
        <span className={h.medalLock}>
          <Icon name="lock" size={12} />
        </span>
      )}
    </span>
  );
}

function wrap(ctx: CanvasRenderingContext2D, text: string, maxW: number): string[] {
  const words = text.split(/\s+/);
  const lines: string[] = [];
  let cur = '';
  for (const w of words) {
    const t = cur ? `${cur} ${w}` : w;
    if (ctx.measureText(t).width > maxW && cur) {
      lines.push(cur);
      cur = w;
    } else cur = t;
  }
  if (cur) lines.push(cur);
  return lines;
}

/** Draws the certificate card (same layout as the app's) to a PNG. */
async function certificatePng(c: CertView, name: string): Promise<Blob | null> {
  const W = 1200;
  const H = 820;
  const cv = document.createElement('canvas');
  cv.width = W;
  cv.height = H;
  const x = cv.getContext('2d');
  if (!x) return null;
  try {
    await document.fonts?.ready;
  } catch {}
  const font = getComputedStyle(document.body).fontFamily || 'system-ui, sans-serif';
  // Background + glows.
  const bg = x.createLinearGradient(0, 0, W, H);
  bg.addColorStop(0, '#1c2036');
  bg.addColorStop(1, '#131624');
  x.fillStyle = bg;
  x.beginPath();
  x.roundRect(0, 0, W, H, 56);
  x.fill();
  x.save();
  x.clip();
  for (const [gx, gy, col] of [
    [80, 40, 'rgba(255,156,130,0.30)'],
    [W - 80, H - 40, 'rgba(91,124,240,0.30)'],
  ] as Array<[number, number, string]>) {
    const g = x.createRadialGradient(gx, gy, 0, gx, gy, 520);
    g.addColorStop(0, col);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = g;
    x.fillRect(0, 0, W, H);
  }
  x.restore();
  const P = 72;
  // Mark.
  const pg = x.createLinearGradient(P, 0, P + 72, 0);
  pg.addColorStop(0, '#ffb8a3');
  pg.addColorStop(1, '#ff9c82');
  x.fillStyle = pg;
  x.beginPath();
  x.roundRect(P, P, 72, 72, 22);
  x.fill();
  x.fillStyle = '#151515';
  x.font = `600 30px ${font}`;
  x.textAlign = 'center';
  x.textBaseline = 'middle';
  x.fillText('IA', P + 36, P + 38);
  x.textAlign = 'left';
  x.textBaseline = 'alphabetic';
  x.fillStyle = '#ffffff';
  x.font = `600 30px ${font}`;
  x.fillText('IELTS AI', P + 92, P + 32);
  x.fillStyle = '#b3b7c9';
  x.font = `400 24px ${font}`;
  x.fillText('by nextED', P + 92, P + 64);
  // Body.
  let y = P + 160;
  x.fillStyle = '#ffb4a0';
  x.font = `600 22px ${font}`;
  x.fillText('CERTIFICATE OF ACHIEVEMENT', P, y);
  y += 52;
  x.fillStyle = '#b3b7c9';
  x.font = `400 26px ${font}`;
  x.fillText('This certifies that', P, y);
  y += 66;
  x.fillStyle = '#ffffff';
  x.font = `500 58px ${font}`;
  x.fillText(name, P, y, W - 2 * P);
  y += 54;
  x.fillStyle = '#b3b7c9';
  x.font = `400 26px ${font}`;
  x.fillText('has earned', P, y);
  y += 50;
  x.fillStyle = '#ffffff';
  x.font = `500 40px ${font}`;
  x.fillText(c.title, P, y, W - 2 * P);
  y += 44;
  x.font = `400 26px ${font}`;
  for (const line of wrap(x, c.detail ? `${c.description} ${c.detail}.` : c.description, W - 2 * P).slice(0, 3)) {
    x.fillText(line, P, y);
    y += 36;
  }
  // Fields.
  const fy = H - 120;
  x.fillStyle = 'rgba(255,255,255,0.14)';
  x.fillRect(P, fy - 34, W - 2 * P, 2);
  x.fillStyle = '#b3b7c9';
  x.font = `400 22px ${font}`;
  x.fillText('Date', P, fy);
  x.fillText('Certificate ID', P + 340, fy);
  x.fillStyle = '#ffffff';
  x.font = `500 28px ${font}`;
  x.fillText(c.date, P, fy + 40);
  x.fillText(c.certId, P + 340, fy + 40);
  return new Promise((resolve) => cv.toBlob((b) => resolve(b), 'image/png'));
}

/** Certificate view with Download / Share (_CertificateSheet). */
function CertificateSheet({ c, name, onClose }: { c: CertView; name: string; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  const slug = c.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || c.certId;
  const fileName = `ielts-ai-certificate-${slug}.png`;
  const caption = [
    'Certificate of achievement - IELTS AI by nextED',
    `${name} earned "${c.title}".`,
    c.description,
    c.detail,
    `Awarded ${c.date} · Certificate ID ${c.certId}`,
    'A practice milestone, not an official IELTS result.',
  ]
    .filter(Boolean)
    .join('\n');
  const canShare = typeof navigator !== 'undefined' && typeof navigator.share === 'function';

  const download = async () => {
    setBusy(true);
    const blob = await certificatePng(c, name);
    setBusy(false);
    if (!blob) return;
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  };
  const share = async () => {
    setBusy(true);
    try {
      const blob = await certificatePng(c, name);
      const file = blob ? new File([blob], fileName, { type: 'image/png' }) : null;
      if (file && navigator.canShare?.({ files: [file] })) await navigator.share({ files: [file], text: caption, title: `IELTS AI certificate · ${c.title}` });
      else await navigator.share({ text: caption, title: `IELTS AI certificate · ${c.title}` });
    } catch {}
    setBusy(false);
  };

  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label={`Certificate: ${c.title}`} onClick={onClose}>
      <div className={`${d.sheet} ${h.dialogScroll}`} style={{ maxWidth: 520 }} onClick={(e) => e.stopPropagation()}>
        <div className={h.cert}>
          <div className={h.identity} style={{ gap: 10 }}>
            <span className={h.certMark}>IA</span>
            <span style={{ flex: 1 }}>
              <span style={{ display: 'block', fontSize: 15, fontWeight: 600 }}>IELTS AI</span>
              <span className={h.certSmall} style={{ fontSize: 12 }}>
                by nextED
              </span>
            </span>
            <Icon name={c.iconName} size={28} color="var(--peach)" />
          </div>
          <div className={h.overline} style={{ marginTop: 22, letterSpacing: 1.6 }}>
            Certificate of achievement
          </div>
          <div className={h.certSmall} style={{ marginTop: 10 }}>
            This certifies that
          </div>
          <div className={h.certName}>{name}</div>
          <div className={h.certSmall}>has earned</div>
          <div style={{ fontSize: 20, fontWeight: 500, marginTop: 2 }}>{c.title}</div>
          <div style={{ fontSize: 13, lineHeight: 1.4, marginTop: 4 }}>{c.detail ? `${c.description} ${c.detail}.` : c.description}</div>
          <div className={h.certFields}>
            <div>
              <span>Date</span>
              <b>{c.date || '–'}</b>
            </div>
            <div>
              <span>Certificate ID</span>
              <b>{c.certId}</b>
            </div>
          </div>
        </div>
        <p className={h.note} style={{ textAlign: 'center', margin: '14px 0' }}>
          A practice milestone from IELTS AI by nextED - not an official IELTS result.
        </p>
        <div className={h.form}>
          <PrimaryButton block leading="download" onClick={download} disabled={busy}>
            {busy ? 'Preparing…' : 'Download image'}
          </PrimaryButton>
          {canShare && (
            <button type="button" className={h.outlineBtn} onClick={share} disabled={busy}>
              <Icon name="share" size={18} /> Share
            </button>
          )}
          <button type="button" className={h.outlineBtn} onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div></Portal>
  );
}

/** A locked badge: what it takes, progress, where to earn it (_lockedSheet). */
function LockedSheet({ c, onClose }: { c: CertView; onClose: () => void }) {
  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby="locked-title" onClick={onClose}>
      <div className={d.sheet} onClick={(e) => e.stopPropagation()}>
        <div className={h.form}>
          <div className={h.identity} style={{ gap: 12 }}>
            <IconCircle icon={c.iconName} size={48} fg="var(--text-muted)" />
            <h2 id="locked-title" className={d.title} style={{ margin: 0 }}>
              {c.title}
            </h2>
          </div>
          <p className={d.body} style={{ margin: 0 }}>
            {c.description}
          </p>
          <div className={h.track} style={{ height: 8 }} role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(c.progress * 100)} aria-label="Progress">
            <span style={{ width: `${c.progress * 100}%` }} />
          </div>
          <span className={h.label}>{c.progressLabel}</span>
          {c.practiceHref && (
            <PrimaryButton href={c.practiceHref} block trailing="arrow_forward">
              Work on it
            </PrimaryButton>
          )}
          <button type="button" className={h.outlineBtn} onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div></Portal>
  );
}

export function BadgeGrid({ items, name }: { items: CertView[]; name: string }) {
  const [open, setOpen] = useState<CertView | null>(null);
  return (
    <>
      <div className={h.badgeGrid}>
        {items.map((c) => (
          <button key={c.id} type="button" className={h.medalCard} onClick={() => setOpen(c)} aria-label={`${c.title}: ${c.earned ? `earned${c.date ? ` ${c.date}` : ''}` : c.progressLabel}`}>
            <Medal c={c} />
            <span className={h.medalTitle} style={{ color: c.earned ? 'var(--text)' : 'var(--text-soft)' }}>
              {c.title}
            </span>
            <span className={h.medalSub}>{c.earned ? c.date || 'Earned' : c.progressLabel}</span>
          </button>
        ))}
      </div>
      {open && (open.earned ? <CertificateSheet c={open} name={name} onClose={() => setOpen(null)} /> : <LockedSheet c={open} onClose={() => setOpen(null)} />)}
    </>
  );
}
