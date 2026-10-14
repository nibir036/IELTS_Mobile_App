import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon } from '@/components/ui';
import { uiPack } from '@/lib/server/packs';
import w from '../writing/writing.module.css';

export const metadata: Metadata = { title: 'Resources' };

type Row = { id: string; title: string; subtitle: string; count?: string; icon: string; tone: string; target: string };
type Wod = { word: string; partOfSpeech?: string; phonetic?: string; definition: string; example?: string };

const HREF: Record<string, string> = {
  vocabQuiz: '/app/resources/vocab-quiz',
  vocabVault: '/app/resources/words',
  academicWords: '/app/resources/words?tab=academic',
  phrasalVerbs: '/app/resources/words?tab=phrasal',
  idioms: '/app/resources/words?tab=idioms',
  topicVocab: '/app/resources/words?tab=topics',
  irregularVerbs: '/app/resources/words?tab=irregular',
  scoringCriteria: '/app/resources/scoring',
  grammarCourse: '/app/courses/grammar',
  vocabCourse: '/app/courses/vocab',
  writingSampleAnswer: '/app/writing/samples',
  articleTips: '/app/resources/tips',
};
const ICON: Record<string, string> = {
  quiz: 'quiz', school: 'school', translate: 'translate', checklist: 'checklist', doc: 'description', bulb: 'lightbulb',
  calendar: 'calendar_month', article: 'article', abc: 'abc', book: 'menu_book', verb: 'swap_horiz',
};
const TONE: Record<string, string> = { pink: '#ffe2d8', lavender: '#dce6ff', rose: '#ffd2c4', plain: 'var(--surface-alt)', mist: 'var(--surface-alt2)' };

/** G1 · Resources hub (resources_hub_screen.dart). */
export default async function ResourcesHub() {
  const ui = await uiPack();
  const hub = (((ui.resources ?? {}) as { hub?: { lists?: Row[]; tiles?: Row[]; wordOfTheDay?: Wod } }).hub ?? {}) as { lists?: Row[]; tiles?: Row[]; wordOfTheDay?: Wod };
  const word = hub.wordOfTheDay;
  return (
    <>
      <div className={w.head}>
        <div>
          <h1 className={w.title}>Resources</h1>
          <p className={w.sub}>Vocabulary, grammar, tips and the band descriptors</p>
        </div>
      </div>

      {word && (
        <Card padding={20}>
          <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>Word of the day</span>
          <p style={{ margin: '4px 0 0', fontSize: 28, fontWeight: 600, letterSpacing: -0.4 }}>
            {word.word} <span style={{ fontSize: 14, fontWeight: 400, color: 'var(--text-muted)' }}>{word.phonetic} · {word.partOfSpeech}</span>
          </p>
          <p style={{ margin: '6px 0 0', color: 'var(--text-soft)' }}>{word.definition}</p>
          {word.example && <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontStyle: 'italic' }}>&ldquo;{word.example}&rdquo;</p>}
        </Card>
      )}

      <div className={w.tasks} style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))' }}>
        {(hub.tiles ?? []).map((t) => (
          <Card key={t.id} href={t.id === 'exam_day' ? '/app/resources/tips/all' : HREF[t.target] ?? '/app/resources'} padding={16} radius={22}>
            <span className={w.wideIcon} style={{ background: TONE[t.tone] ?? TONE.plain, color: '#151515', marginBottom: 10 }}>
              <Icon name={ICON[t.icon] ?? 'article'} size={20} />
            </span>
            <p className={w.qTitle}>{t.title}</p>
            <p className={w.qText}>{t.subtitle}</p>
          </Card>
        ))}
      </div>

      <div className={w.more}>
        {(hub.lists ?? []).map((row) => (
          <Card key={row.id} href={HREF[row.target] ?? '/app/resources'} padding="10px 12px 10px 10px" radius={20}>
            <div className={w.moreRow}>
              <span className={w.wideIcon} style={{ width: 42, height: 42, background: TONE[row.tone] ?? TONE.pink, color: '#151515' }}>
                <Icon name={ICON[row.icon] ?? 'translate'} size={18} />
              </span>
              <span className={w.twoLine}>
                <b>{row.title}</b>
                <span style={{ color: 'var(--text-muted)', opacity: 1 }}>{row.subtitle}</span>
              </span>
              {row.count && <span className={w.moreMeta}>{row.count}</span>}
              <Icon name="chevron_right" size={16} color="var(--text-muted)" />
            </div>
          </Card>
        ))}
      </div>
      <p className={w.sub}>
        Looking for practice? <Link href="/app/practice">Go to the Practice tab</Link>.
      </p>
    </>
  );
}
