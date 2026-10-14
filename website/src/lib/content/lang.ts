// Explanation language for lessons, guides and AI feedback (the app's
// ContentL10n, lib/app/data/l10n.dart). The choice is the account's kv state
// `feedbackLanguage`, so app and web always show the same language.

export interface ContentLang {
  code: string;
  native: string;
  english: string;
  rtl?: boolean;
}

export const CONTENT_LANGS: ContentLang[] = [
  { code: 'en', native: 'English', english: 'English' },
  { code: 'bn', native: 'বাংলা', english: 'Bangla' },
  { code: 'ne', native: 'नेपाली', english: 'Nepali' },
  { code: 'ar', native: 'العربية', english: 'Arabic', rtl: true },
  { code: 'id', native: 'Bahasa Indonesia', english: 'Indonesian' },
];

export const LANG_KEY = 'feedbackLanguage';

export function contentLang(code: string | null | undefined): ContentLang {
  return CONTENT_LANGS.find((l) => l.code === code) ?? CONTENT_LANGS[0];
}

export const MODULE_NAMES: Record<string, string> = {
  writing: 'Writing',
  speaking: 'Speaking',
  reading: 'Reading',
  listening: 'Listening',
  grammar: 'Grammar',
  vocab: 'Vocabulary',
};

export const COURSE_MODULES = ['writing', 'speaking', 'reading', 'listening', 'grammar', 'vocab'] as const;

export type NexiPoseName = 'wave' | 'point' | 'thumbs' | 'grad' | 'listening' | 'reading' | 'speaking' | 'writing';

export function nexiFor(module: string): NexiPoseName {
  switch (module) {
    case 'writing':
      return 'writing';
    case 'speaking':
      return 'speaking';
    case 'listening':
      return 'listening';
    case 'reading':
    case 'grammar':
    case 'vocab':
      return 'reading';
    default:
      return 'wave';
  }
}

export function moduleIcon(module: string): string {
  switch (module) {
    case 'writing':
      return 'edit';
    case 'speaking':
      return 'mic';
    case 'reading':
      return 'menu_book';
    case 'listening':
      return 'headset_mic';
    case 'vocab':
      return 'translate';
    default:
      return 'school';
  }
}

/** Material Symbols name for a concept card's icon key (lessonIcon). */
export function lessonIcon(key: string): string {
  const m: Record<string, string> = {
    target: 'my_location',
    link: 'link',
    book: 'menu_book',
    settings: 'settings',
    check: 'check',
    layers: 'layers',
    swap: 'swap_horiz',
    play: 'play_arrow',
    add: 'add',
    list: 'list',
    doc: 'description',
    chat: 'chat',
    forward: 'arrow_forward',
    clock: 'schedule',
    flag: 'flag',
  };
  return m[key] ?? 'auto_awesome';
}
