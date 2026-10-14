import type { Metadata } from 'next';
import { RecordingsList, type RecordingRow } from '@/components/extras/recordings-list';
import { band, dhakaDay, plusDays, weekdayDate } from '@/lib/extras/format';
import { attempts } from '@/lib/server/attempts';
import { uiPack } from '@/lib/server/packs';
import x from '@/components/extras/extras.module.css';

export const metadata: Metadata = { title: 'My recordings' };

type Raw = Record<string, unknown>;

/** D10 · My recordings (my_recordings_screen.dart): every speaking answer with playback of its uploaded audio. */
export default async function MyRecordings() {
  const [ui, list] = await Promise.all([uiPack().catch(() => ({}) as Raw), attempts({ skill: 'speaking', limit: 300 }).catch(() => [])]);
  const copy = ((ui.speaking as Raw | undefined)?.recordings ?? {}) as Raw;
  const filters = (Array.isArray(copy.filters) ? (copy.filters as Raw[]) : []).map((f) => ({ id: String(f.id ?? ''), label: String(f.label ?? '') })).filter((f) => f.id);
  const groups = Array.isArray(copy.groups) ? copy.groups.map(String) : ['This week', 'Earlier'];
  const weekAgo = plusDays(dhakaDay(new Date()), -6);

  const items: RecordingRow[] = list
    .filter((a) => a.kind !== 'pronunciation')
    .sort((p, q) => q.createdAt.localeCompare(p.createdAt))
    .map((a) => {
      const d = a.data;
      const isTest = d.test === true;
      const answers = Array.isArray(d.questions) ? d.questions.length : 0;
      const detail = isTest
        ? a.band != null
          ? `Parts 1–3 · band ${band(a.band)}`
          : 'Parts 1–3'
        : a.kind === 'part2' || answers === 0
          ? `band ${band(a.band)}`
          : `${answers} answer${answers === 1 ? '' : 's'}`;
      const spoken = Number(d.spokenSec) > 0 ? Number(d.spokenSec) : a.durationSec;
      const day = dhakaDay(a.createdAt);
      const clips = (Array.isArray(d.audio) ? (d.audio as Raw[]) : [])
        .map((c) => ({ key: String(c?.key ?? ''), sec: Number(c?.durationSec) || 0 }))
        .filter((c) => c.key);
      return {
        id: a.id,
        part: isTest ? 'test' : a.kind,
        group: day >= weekAgo ? (groups[0] ?? 'This week') : (groups[1] ?? 'Earlier'),
        title: a.title,
        meta: `${weekdayDate(day)} · ${detail}`,
        seconds: spoken,
        clips,
      };
    });

  return (
    <div className={x.page}>
      <RecordingsList items={items} filters={filters.length ? filters : [{ id: 'all', label: 'All' }]} groups={groups} />
    </div>
  );
}
