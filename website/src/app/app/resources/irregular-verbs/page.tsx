import type { Metadata } from 'next';
import { IrregularVerbs, type Best, type Verb } from '@/components/extras/irregular-verbs';
import { rows, str, type Raw } from '@/lib/practice/marking';
import { stateValue } from '@/lib/server/attempts';
import { uiPack } from '@/lib/server/packs';
import { resourcesBank } from '@/lib/server/resources';
import x from '@/components/extras/extras.module.css';

export const metadata: Metadata = { title: 'Irregular verbs' };

/** H8 · Irregular verbs table and practice (irregular_verbs_screen.dart, irregular_verbs_practice.dart). */
export default async function IrregularVerbsPage() {
  const [bank, ui, best] = await Promise.all([
    resourcesBank().catch(() => null),
    uiPack().catch(() => ({}) as Raw),
    stateValue<Best>('resources.irregularBest'),
  ]);
  const copy = (((ui.resources ?? {}) as Raw).irregularVerbs ?? {}) as Raw;
  // The Resources bank's verbs (with meaning and example), else the UI pack's list.
  const source = bank?.irregularVerbs.length ? bank.irregularVerbs : rows(copy.verbs);
  const verbs: Verb[] = source
    .map((v) => ({ base: str(v.base).trim(), past: str(v.past).trim(), participle: str(v.participle).trim(), meaning: str(v.meaning), example: str(v.example) }))
    .filter((v) => v.base);
  return (
    <div className={x.page}>
      <IrregularVerbs verbs={verbs} defaultLetter={str(copy.defaultLetter) || 'B'} best={best && typeof best === 'object' && typeof best.pct === 'number' ? best : null} />
    </div>
  );
}
