// Community rooms / DMs (lib/features/resources/widgets.dart + room_chat_parts.dart):
// kv keys, row helpers and the offline AI-partner reply, shared by the
// Community tab and the room chat. Keys and shapes are the app's own, so the
// app and the website show the same rooms and messages.

/**
 * Mirrors the app's `kCommunityLive` (community_channels_screen.dart): while
 * false, the tab shows its content blurred behind a "Coming soon" wall and a
 * room link lands on the wall. Flip together with the app.
 */
export const COMMUNITY_LIVE = false;
export const SOON_TITLE = 'Community is on its way';
export const SOON_MESSAGE = 'Speaking rooms and chats with other IELTS students are coming in a future update.';

export type Row = Record<string, unknown>;

/** kv keys (ResKeys in widgets.dart). */
export const KEYS = {
  /** Set of room / DM ids the user has opened. */
  readRooms: 'community.readRooms',
  /** DM threads: [{id, letter, name, tone, unread, messages}]. */
  dms: 'community.dms',
  /** Rooms the user created: [{id, name, topic, description, letter, tone, createdAt}]. */
  myRooms: 'community.myRooms',
  /** The user's own sent messages in a room / DM. */
  sent: (roomId: string) => `community.sent.${roomId}`,
} as const;

/** Topics a user-created room can have (kRoomTopics). */
export const ROOM_TOPICS = ['Speaking', 'Writing', 'Reading', 'Listening', 'General'] as const;
const TOPIC_TONE: Record<string, string> = { Speaking: 'pink', Writing: 'lavender', Reading: 'rose', Listening: 'lilac', General: 'periwinkle' };

export const str = (v: unknown): string => (typeof v === 'string' ? v : v == null ? '' : String(v));
export const num = (v: unknown): number => (typeof v === 'number' ? v : Number(v) || 0);
export const rows = (v: unknown): Row[] => (Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Row[]) : []);
export const strs = (v: unknown): string[] => (Array.isArray(v) ? v.map(str).filter(Boolean) : []);

/** The Community tab's content (ui pack → resources.community / speakingRoom). */
export interface CommunityContent {
  roomsCount: number;
  live: { roomId: string; title: string; subtitle: string; avatars: Row[] };
  rooms: Row[];
}
export interface SpeakingRoomContent {
  id: string;
  title: string;
  onlineCount: number;
  dayLabel: string;
  messages: Row[];
  session: Row;
  quickActions: string[];
}

export function readCommunity(ui: Row): { community: CommunityContent; room: SpeakingRoomContent } {
  const res = (ui.resources ?? {}) as Row;
  const c = (res.community ?? {}) as Row;
  const live = (c.live ?? {}) as Row;
  const r = (res.speakingRoom ?? {}) as Row;
  return {
    community: {
      roomsCount: num(c.roomsCount),
      live: { roomId: str(live.roomId), title: str(live.title), subtitle: str(live.subtitle), avatars: rows(live.avatars) },
      rooms: rows(c.rooms),
    },
    room: {
      id: str(r.id),
      title: str(r.title),
      onlineCount: num(r.onlineCount),
      dayLabel: str(r.dayLabel),
      messages: rows(r.messages),
      session: (r.session ?? {}) as Row,
      quickActions: strs(r.quickActions),
    },
  };
}

/** The community kv state as stored ({key: value}). */
export type CommunityState = Record<string, unknown>;

export const myRoomsOf = (st: CommunityState): Row[] => rows(st[KEYS.myRooms]);
export const dmsOf = (st: CommunityState): Row[] => rows(st[KEYS.dms]);
export const sentOf = (st: CommunityState, id: string): Row[] => rows(st[KEYS.sent(id)]);
export const readSetOf = (st: CommunityState): string[] => strs(st[KEYS.readRooms]);

/** Unread count of a row: its seeded unread unless the user opened it. */
export const roomUnread = (read: string[], row: Row): number => (read.includes(str(row.id)) ? 0 : num(row.unread));

/** "Voice message" / "Photo" / text, with "You: " for the user's own. */
export function previewOf(m: Row): string {
  const type = str(m.type);
  const text = type === 'voice' ? 'Voice message' : type === 'image' ? 'Photo' : str(m.text);
  return m.mine === true ? `You: ${text}` : text;
}

/** A user room row: preview = newest message, else its description. */
export function myRoomRow(st: CommunityState, room: Row): Row {
  const sent = sentOf(st, str(room.id));
  let preview = str(room.description) ? str(room.description) : `${str(room.topic)} · created by you`;
  if (sent.length) preview = previewOf(sent[sent.length - 1]);
  return { ...room, preview, mineRoom: true };
}

/** DM rows show the newest message (seeded or sent) as their preview. */
export function dmRow(st: CommunityState, dm: Row): Row {
  const msgs = [...rows(dm.messages), ...sentOf(st, str(dm.id))];
  return { ...dm, preview: msgs.length ? previewOf(msgs[msgs.length - 1]) : str(dm.preview) };
}

/** Store.newId: `<prefix>_<base36 micros><seq>`. */
let seq = 0;
export function newId(prefix: string): string {
  seq++;
  return `${prefix}_${(Date.now() * 1000).toString(36)}${seq}`;
}

export function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return '?';
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return (parts[0].slice(0, 1) + parts[parts.length - 1].slice(0, 1)).toUpperCase();
}

/** A new user room (createMyRoom). */
export function newRoom(name: string, topic: string, description: string): Row {
  const clean = name.trim();
  return {
    id: newId('myroom'),
    name: clean,
    topic,
    description: description.trim(),
    letter: clean ? clean.slice(0, 1).toUpperCase() : '#',
    tone: TOPIC_TONE[topic] ?? 'periwinkle',
    createdAt: new Date().toISOString(),
  };
}

/** "8:12 PM" (the time stamp the app stores on messages). */
export function clockNow(d = new Date()): string {
  const h = d.getHours() % 12 === 0 ? 12 : d.getHours() % 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${d.getHours() < 12 ? 'AM' : 'PM'}`;
}

/** "0:07" from milliseconds. */
export function clockFromMs(ms: number): string {
  const s = Math.round(ms / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export const shortDate = (d: Date) => `${d.getDate()} ${MONTHS[d.getMonth()]}`;

// ── offline AI partner (offlinePartnerReply) ────────────────────────────────

const LINKERS = [
  'because', 'however', 'although', 'therefore', 'moreover', 'whereas', 'for example', 'for instance',
  'on the other hand', 'in addition', 'as a result', 'which means', 'while', 'since', 'unless', 'so that',
];
const UPGRADES: Array<[string, string]> = [
  ['very important', 'crucial'], ['a lot of', 'a great deal of'], ['lots of', 'numerous'], ['very big', 'enormous'],
  ['good', 'beneficial'], ['bad', 'harmful'], ['big', 'significant'], ['important', 'essential'], ['things', 'aspects'],
  ['problem', 'issue'], ['people', 'individuals'], ['think', 'would argue'], ['nowadays', 'these days'],
  ['show', 'demonstrate'], ['help', 'support'], ['get', 'obtain'],
];
const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const hasPhrase = (text: string, phrase: string) => new RegExp(`\\b${esc(phrase)}\\b`).test(text);

/** Word count, linking words, one vocabulary upgrade, then [nextQuestion]. */
export function offlinePartnerReply(answer: string, nextQuestion: string): string {
  const lower = answer.toLowerCase();
  const words = (answer.match(/[A-Za-z']+/g) ?? []).length;
  const parts: string[] = [];
  if (words < 12) {
    parts.push(`That’s quite short (${words} words). In Part 3, aim for 3–5 sentences: your view, a reason and an example.`);
  } else if (words <= 40) {
    parts.push(`Good answer - ${words} words. Add one more supporting detail or an example to develop it.`);
  } else {
    parts.push(`Nicely developed answer (${words} words).`);
  }
  const used = LINKERS.filter((l) => hasPhrase(lower, l)).slice(0, 2);
  parts.push(
    used.length
      ? `You linked ideas with ${used.map((l) => `“${l}”`).join(' and ')}.`
      : 'Try linking ideas with “because”, “however” or “for instance”.',
  );
  let vocab: string | null = null;
  for (const [k, v] of UPGRADES) {
    if (hasPhrase(lower, k)) {
      vocab = `Vocabulary: instead of “${k}”, try “${v}”.`;
      break;
    }
  }
  const extra = ['considerable', 'widespread', 'a growing number of', 'long-term'];
  vocab ??= `Vocabulary: try a less common expression such as “${extra[Math.min(words, 1000) % extra.length]}”.`;
  return `${parts.join(' ')}\n${vocab}\n\nNext question: ${nextQuestion}`;
}

// ── kv access from the browser (read-merge-write, like the app's Store) ─────

export async function readState(prefix: string): Promise<CommunityState | null> {
  try {
    const r = await fetch(`/api/v1/state?prefix=${encodeURIComponent(prefix)}`, { cache: 'no-store' });
    if (!r.ok) return null;
    return ((await r.json()) as { state?: CommunityState }).state ?? {};
  } catch {
    return null;
  }
}

export async function writeState(key: string, value: unknown): Promise<boolean> {
  try {
    const r =
      value === null
        ? await fetch(`/api/v1/state/${encodeURIComponent(key)}`, { method: 'DELETE' })
        : await fetch(`/api/v1/state/${encodeURIComponent(key)}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ value }),
          });
    return r.ok;
  } catch {
    return false;
  }
}

/** Appends [item] to a kv list (re-reading it first: the app may have changed it). */
export async function listAdd(key: string, item: Row): Promise<Row[] | null> {
  const st = await readState(key);
  if (!st) return null;
  const cur = rows(st[key]);
  const next = cur.some((x) => str(x.id) === str(item.id)) ? cur : [...cur, item];
  return (await writeState(key, next)) ? next : null;
}

/** Adds [value] to a kv string set (markRoomRead). */
export async function setAdd(key: string, value: string): Promise<void> {
  const st = await readState(key);
  if (!st) return;
  const cur = strs(st[key]);
  if (cur.includes(value)) return;
  await writeState(key, [...cur, value]);
}

/** Deletes one of the user's rooms and its messages (deleteMyRoom). */
export async function deleteRoom(id: string): Promise<boolean> {
  const st = await readState(KEYS.myRooms);
  if (!st) return false;
  const ok = await writeState(KEYS.myRooms, rows(st[KEYS.myRooms]).filter((r) => str(r.id) !== id));
  await writeState(KEYS.sent(id), null);
  return ok;
}
