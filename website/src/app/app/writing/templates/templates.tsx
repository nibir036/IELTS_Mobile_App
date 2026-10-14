'use client';

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';
import { Icon } from '@/components/ui';
import d from '@/components/dialog.module.css';
import { slotValue, TEMPLATE_VALUES_KEY, templatePlain, type Template } from '@/lib/writing/templates';
import r from '../result/[id]/result.module.css';
import s from './templates.module.css';
import { Portal } from '@/components/portal';

/** Fill-in essay structures: tap a dashed slot to fill it; copy or open in the editor. */
export function Templates({
  types,
  items,
  initialValues,
  prompts,
}: {
  types: string[];
  items: Template[];
  initialValues: Record<string, string>;
  prompts: Record<string, string>;
}) {
  const [type, setType] = useState(0);
  const [variant, setVariant] = useState(0);
  const [open, setOpen] = useState<Set<number>>(new Set([0, 1]));
  const [values, setValues] = useState(initialValues);
  const [fill, setFill] = useState<{ key: string; slot: string; value: string } | null>(null);
  const [toast, setToast] = useState('');
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!toast) return;
    const id = setTimeout(() => setToast(''), 2400);
    return () => clearTimeout(id);
  }, [toast]);
  useEffect(() => {
    if (fill) setTimeout(() => input.current?.focus(), 30);
  }, [fill]);

  const versions = items.filter((it) => it.type === types[type]);
  const tpl = versions.length ? versions[Math.min(variant, versions.length - 1)] : null;
  let filled = 0;
  let total = 0;
  tpl?.sections.forEach((sec, si) =>
    sec.segments.forEach((seg, g) => {
      if (seg.slot === undefined) return;
      total++;
      if (slotValue(values, tpl.id, si, g, seg)) filled++;
    }),
  );

  const save = async (key: string, value: string) => {
    const next = { ...values };
    if (value) next[key] = value;
    else delete next[key];
    setValues(next);
    // Merge with what the app may have saved meanwhile.
    const cur = await fetch(`/api/v1/state?prefix=${encodeURIComponent(TEMPLATE_VALUES_KEY)}`).catch(() => null);
    const server = cur?.ok ? ((((await cur.json()) as { state?: Record<string, unknown> }).state?.[TEMPLATE_VALUES_KEY] as Record<string, string>) ?? {}) : {};
    const merged = { ...server };
    if (value) merged[key] = value;
    else delete merged[key];
    void fetch(`/api/v1/state/${encodeURIComponent(TEMPLATE_VALUES_KEY)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ value: merged }),
    }).catch(() => null);
  };

  const copy = async () => {
    if (!tpl) return;
    try {
      await navigator.clipboard.writeText(templatePlain(tpl, values));
      setToast('Template copied');
    } catch {
      setToast('Copy isn’t available in this browser');
    }
  };

  const pick = (fn: () => void) => {
    fn();
    setOpen(new Set([0, 1]));
  };

  return (
    <div className={s.wrap}>
      <div className={r.top}>
        <Link href="/app/writing" className={r.back} aria-label="Back to Writing">
          <Icon name="arrow_back" size={18} />
        </Link>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className={s.overline}>Writing Template</div>
          <div className={s.title}>{tpl ? tpl.title : types[type]}</div>
        </div>
        <button type="button" className={r.back} onClick={copy} title="Copy template" aria-label="Copy template">
          <Icon name="content_copy" size={20} />
        </button>
      </div>

      <div className={s.chips} role="tablist" aria-label="Question type">
        {types.map((t, i) => (
          <button key={t} type="button" role="tab" aria-selected={i === type} className={`${s.chip} ${i === type ? s.chipOn : ''}`} onClick={() => pick(() => (setType(i), setVariant(0)))}>
            {t}
          </button>
        ))}
      </div>
      {versions.length > 1 && (
        <div className={s.chips} aria-label="Version">
          <span className={s.muted}>Version</span>
          {versions.map((v, i) => (
            <button key={v.id} type="button" className={`${s.version} ${i === variant ? s.versionOn : ''}`} onClick={() => pick(() => setVariant(i))}>
              {v.variant || `Version ${i + 1}`}
            </button>
          ))}
        </div>
      )}
      <p className={s.muted} style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <Icon name="auto_awesome" size={14} />
        {tpl ? `Tap a dashed slot to fill it in · ${filled} of ${total} filled` : 'No template for this type - pick another type above'}
      </p>

      {tpl?.sections.map((sec, si) => {
        const isOpen = open.has(si);
        return (
          <section key={si} className={s.section}>
            <button
              type="button"
              className={s.sectionHead}
              aria-expanded={isOpen}
              onClick={() =>
                setOpen((o) => {
                  const n = new Set(o);
                  if (n.has(si)) n.delete(si);
                  else n.add(si);
                  return n;
                })
              }
            >
              <span className={`${s.badge} ${isOpen ? s.badgeOn : ''}`}>{si + 1}</span>
              <span style={{ flex: 1 }}>
                <b>{sec.title}</b>
                <small>{sec.subtitle}</small>
              </span>
              <Icon name={isOpen ? 'expand_less' : 'chevron_right'} size={18} color="var(--text-muted)" />
            </button>
            {isOpen && (
              <p className={s.body}>
                {sec.segments.map((seg, g) => {
                  if (seg.slot === undefined) return <span key={g}>{seg.text}</span>;
                  const key = `${tpl.id}|${si}|${g}`;
                  const v = slotValue(values, tpl.id, si, g, seg);
                  return (
                    <button key={g} type="button" className={v ? s.slotFilled : s.slot} onClick={() => setFill({ key, slot: seg.slot!, value: v })} title={`Fill in: ${seg.slot}`}>
                      {v || seg.slot}
                    </button>
                  );
                })}
              </p>
            )}
          </section>
        );
      })}

      <div className={s.foot}>
        <button type="button" className={s.soft} onClick={copy}>
          <Icon name="content_copy" size={18} /> Copy
        </button>
        {tpl && prompts[tpl.id] ? (
          <Link href={`/app/writing/write/${encodeURIComponent(prompts[tpl.id])}?template=${encodeURIComponent(tpl.id)}`} className={s.primary}>
            Use in editor <Icon name="arrow_forward" size={18} />
          </Link>
        ) : (
          <span className={`${s.primary} ${s.disabled}`}>Use in editor</span>
        )}
      </div>

      {fill && (
        <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label={`Fill in ${fill.slot}`} onClick={() => setFill(null)}>
          <form
            className={d.sheet}
            onClick={(e) => e.stopPropagation()}
            onSubmit={(e) => {
              e.preventDefault();
              void save(fill.key, fill.value.trim());
              setFill(null);
            }}
          >
            <h2 className={d.title}>Fill in: {fill.slot}</h2>
            <input ref={input} className={s.input} value={fill.value} placeholder={fill.slot} onChange={(e) => setFill({ ...fill, value: e.target.value })} />
            <button type="submit" className={s.primary} style={{ width: '100%', marginTop: 14 }}>
              Done
            </button>
          </form>
        </div></Portal>
      )}
      {toast && (
        <div className={s.toast} role="status">
          {toast}
        </div>
      )}
    </div>
  );
}
