// Server-side data for the Community tab and room chat.

import { api } from '@/lib/server/api';
import { getPack } from '@/lib/server/packs';
import { rows, str, strs, type CommunityState, type Row } from './data';

/** Every `community.*` kv value of the signed-in student ({} when offline). */
export async function communityState(): Promise<CommunityState> {
  try {
    return (await api<{ state: CommunityState }>(`/v1/state?prefix=${encodeURIComponent('community.')}`)).state ?? {};
  } catch {
    return {};
  }
}

/** Dart's String.hashCode isn't portable; any stable hash picks the same way. */
function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

const FALLBACK = [
  'Do you think people today have enough free time? Why?',
  'How has technology changed the way people learn?',
  'Should governments spend more on public transport or on roads?',
];

/**
 * Part 3 questions for the AI partner (partnerQuestionsFor): cue-card Part 3
 * questions mentioning the room keyword, else the matching topic's card, else
 * a card picked from the room id and the day. → {topic, questions}.
 */
export async function partnerQuestions(roomId: string, keyword: string, ui: Row): Promise<{ topic: string; questions: string[] }> {
  // Content.cueCards: the speaking bank, or the demo cards without it.
  let cards: Row[] = [];
  try {
    cards = rows((await getPack<Row>('bank.speaking')).cueCards);
  } catch {}
  if (!cards.length) cards = rows(((ui.speaking ?? {}) as Row).cueCards);
  cards = cards.filter((c) => strs(c.part3).length);
  if (!cards.length) return { topic: keyword || 'General', questions: FALLBACK };
  const k = keyword.trim().toLowerCase();
  if (k) {
    const matches: string[] = [];
    for (const c of cards) for (const q of strs(c.part3)) if (q.toLowerCase().includes(k) && !matches.includes(q)) matches.push(q);
    if (matches.length >= 2) return { topic: keyword, questions: matches };
    for (const c of cards) {
      if (str(c.topic).toLowerCase() === k || str(c.title).toLowerCase().includes(k)) return { topic: str(c.topic), questions: strs(c.part3) };
    }
  }
  const pick = cards[(hash(roomId) + new Date().getDate()) % cards.length];
  return { topic: str(pick.topic), questions: strs(pick.part3) };
}
