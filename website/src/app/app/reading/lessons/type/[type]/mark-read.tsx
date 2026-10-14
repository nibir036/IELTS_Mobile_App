'use client';

import { useEffect } from 'react';
import { getState, putState } from '@/lib/lessons/menu';

const KEY = 'reading.typeLessonsRead';

/** Adds this question type to kv `reading.typeLessonsRead` (read-merge-write, like the app). */
export function MarkTypeRead({ type, already }: { type: string; already: boolean }) {
  useEffect(() => {
    if (already || !type) return;
    let cancelled = false;
    void (async () => {
      const cur = await getState<unknown>(KEY);
      if (cancelled) return;
      const list = Array.isArray(cur) ? cur.map(String) : [];
      if (!list.includes(type)) await putState(KEY, [...list, type]);
    })();
    return () => {
      cancelled = true;
    };
  }, [type, already]);
  return null;
}
