import type { Metadata } from 'next';
import { TargetBandSetup } from '@/components/home/target-band';
import { profileOf } from '@/lib/home/stats';
import { addDaysKey, todayKey } from '@/lib/home/time';
import { getMe } from '@/lib/server/me';
import { uiPack } from '@/lib/server/packs';

export const metadata: Metadata = { title: 'Set your target band' };

type Raw = Record<string, unknown>;

/** A6 · Target band set-up (lib/features/access/target_band_screen.dart). */
export default async function TargetBandPage() {
  const [me, ui] = await Promise.all([getMe(), uiPack().catch(() => ({}) as Raw)]);
  const data = (((ui.access ?? {}) as Raw).targetBand ?? {}) as Raw;
  const bands = (Array.isArray(data.bandOptions) ? data.bandOptions.map(Number).filter((n) => Number.isFinite(n)) : []) as number[];
  const options = bands.length ? bands : [6, 6.5, 7, 7.5, 8, 8.5, 9];
  const minBand = Number(data.minBand) || 6;
  const maxBand = Number(data.maxBand) > minBand ? Number(data.maxBand) : minBand + 1;
  const prof = profileOf(me.user.profile);
  const today = todayKey();

  // Band: the saved target snapped to an option, or the default.
  let band = Number(data.defaultBand) > 0 ? Number(data.defaultBand) : 7;
  if (prof.targetBand != null) band = options.reduce((best, b) => (Math.abs(b - prof.targetBand!) < Math.abs(best - prof.targetBand!) ? b : best), options[0]);
  // Exam date: the saved one if still ahead, or about 8 weeks out.
  const date = prof.examDate && prof.examDate > today ? prof.examDate : addDaysKey(today, 56);

  return <TargetBandSetup bands={options} minBand={minBand} maxBand={maxBand} band={band} date={date} today={today} />;
}
