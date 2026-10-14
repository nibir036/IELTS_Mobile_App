'use client';

import { useRouter } from 'next/navigation';
import { useState, useTransition } from 'react';
import { CONTENT_LANGS, LANG_KEY } from '@/lib/content/lang';
import { Icon } from './ui';
import c from './course.module.css';

/**
 * Explanation language for lessons and guides (ContentLangSwitch). Saved to
 * the account, so the app follows the same choice (and AI feedback uses it).
 */
export function LangSwitch({ current, langs }: { current: string; langs: string[] }) {
  const router = useRouter();
  const [value, setValue] = useState(current);
  const [pending, start] = useTransition();
  const options = CONTENT_LANGS.filter((l) => langs.includes(l.code));
  if (options.length < 2) return null;
  return (
    <label className={c.lang} title="Explanation language">
      <Icon name="translate" size={18} />
      <span className="visually-hidden">Explanation language</span>
      <select
        value={value}
        disabled={pending}
        onChange={async (e) => {
          const next = e.target.value;
          setValue(next);
          const res = await fetch(`/api/v1/state/${encodeURIComponent(LANG_KEY)}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ value: next }),
          }).catch(() => null);
          if (!res?.ok) {
            setValue(current);
            return;
          }
          start(() => router.refresh());
        }}
      >
        {options.map((l) => (
          <option key={l.code} value={l.code}>
            {l.native}
            {l.code !== 'en' ? ` · ${l.english}` : ''}
          </option>
        ))}
      </select>
      <Icon name={pending ? 'progress_activity' : 'expand_more'} size={18} />
    </label>
  );
}
