// Translations of the Reading strategy lessons, ported from ContentL10n
// (lib/app/data/l10n.dart: skillLesson, typeLesson). [tr] is the reading
// translation pack of the current language (moduleTranslation('reading')).

import { rows, str, type Raw } from '../practice/marking';

const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {});

/** Reading skill lesson (rl_…): translated title, key idea and "uses". */
export function skillLesson(english: Raw, tr: Raw): Raw {
  const t = obj(obj(tr.skillLessons)[str(english.id)]);
  if (!str(t.keyIdea)) return english;
  const en = rows(english.uses);
  const tu = rows(t.uses);
  return {
    ...english,
    ...(str(t.title) ? { title: str(t.title) } : {}),
    keyIdea: str(t.keyIdea),
    ...(tu.length === en.length ? { uses: en.map((u, i) => ({ ...u, ...tu[i] })) } : {}),
  };
}

const paras = (s: string) => s.split('\n').filter((l) => l.trim()).length;

function section(en: Raw, tr: Raw): Raw {
  const out: Raw = { ...en };
  if (str(tr.heading)) out.heading = str(tr.heading);
  const text = str(tr.text);
  if (!text) return out;
  const layout = rows(en.layout);
  if (!str(en.text)) {
    out.text = text;
    if (layout.length) out.layout = [...layout, ...Array.from({ length: paras(text) }, (_, p) => ({ paragraph: p }))];
  } else if (!layout.length || paras(text) === paras(str(en.text))) {
    out.text = text;
  }
  return out;
}

/**
 * Question-type lesson with translated title and section headings / texts;
 * exhibits stay those of the English lesson (they quote the test paper).
 */
export function typeLesson(english: Raw, tr: Raw): Raw {
  const t = obj(obj(tr.typeLessons)[str(english.id)]);
  const ts = rows(t.sections);
  const en = rows(english.sections);
  if (!Object.keys(t).length || ts.length !== en.length) return english;
  return {
    ...english,
    title: str(t.title) || str(english.title),
    sections: en.map((s, i) => section(s, ts[i])),
  };
}
