import Link from 'next/link';
import type { VocabEntry } from '@/lib/extras/speaking-library';
import { Icon, Tag } from '../ui';
import { SpeakButton } from './speak-button';
import r from './speaking.module.css';
import x from './extras.module.css';

const cx = (...c: Array<string | false | null | undefined>) => c.filter(Boolean).join(' ');

export const practiseHref = (keys: string[], title?: string) =>
  `/app/speaking/pronunciation?vocab=${encodeURIComponent(keys.slice(0, 12).join(','))}${title ? `&title=${encodeURIComponent(title)}` : ''}`;

/** A speaking vocabulary entry (showSpeakingWord): headword, IPA, stress, meaning, example, synonyms. */
export function WordCard({ e, headingId, hideHead }: { e: VocabEntry; headingId?: string; hideHead?: boolean }) {
  return (
    <div className={r.sheetCol}>
      {!hideHead && (
        <div className={r.wordHead}>
          <h2 id={headingId} className={r.headword}>
            {e.headword}
          </h2>
          {e.level && <Tag tone="peach">{e.level}</Tag>}
          <SpeakButton text={e.headword} className={x.iconBtn} />
        </div>
      )}
      {(e.ipa || e.pos) && (
        <p style={{ margin: 0 }}>
          <span className={r.ipa}>{e.ipa}</span>
          {e.pos && <span className={r.pos}>{e.pos}</span>}
        </p>
      )}
      {e.syllables.length > 1 && (
        <div className={r.syls} aria-label="Syllables, stressed one highlighted">
          {e.syllables.map((s, i) => (
            <span key={i} className={cx(r.syl, s.stress && r.sylStress)}>
              {s.stress ? s.text.toUpperCase() : s.text}
            </span>
          ))}
        </div>
      )}
      {e.meaning && <p className={r.meaning}>{e.meaning}</p>}
      {e.example && (
        <p className={r.example}>
          <Icon name="format_quote" size={16} color="var(--text-muted)" />
          <span>{e.example}</span>
        </p>
      )}
      {e.synonyms.length > 0 && (
        <div className={r.syn}>
          Similar:
          {e.synonyms.map((s) => (
            <span key={s} className={r.synTag}>
              {s}
            </span>
          ))}
        </div>
      )}
      <Link href={practiseHref([e.key], e.headword)} className={x.outline} style={{ height: 42 }}>
        <Icon name="mic" size={18} /> Practise saying it
      </Link>
    </div>
  );
}
