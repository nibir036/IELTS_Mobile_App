'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { Card, HeroCard, Icon, PrimaryButton, SoftButton, Tag } from '../ui';
import d from '../dialog.module.css';
import { AvatarStack, toneClass } from './bubbles';
import {
  KEYS,
  ROOM_TOPICS,
  dmRow,
  dmsOf,
  listAdd,
  myRoomRow,
  myRoomsOf,
  newRoom,
  readSetOf,
  roomUnread,
  setAdd,
  str,
  type CommunityContent,
  type CommunityState,
  type Row,
} from './data';
import c from './community.module.css';
import { Portal } from '@/components/portal';

/** /app/community/room/<id>?title=… (Routes.speakingRoomChat with {roomId, title}). */
export const roomHref = (id: string, title: string) => `/app/community/room/${encodeURIComponent(id)}${title ? `?title=${encodeURIComponent(title)}` : ''}`;

/** H3 · Community Channels: rooms + direct chats (community_channels_screen.dart). */
export function CommunityChannels({ content, initial }: { content: CommunityContent; initial: CommunityState }) {
  const router = useRouter();
  const [tab, setTab] = useState(0);
  const [st, setSt] = useState<CommunityState>(initial);
  const [sheet, setSheet] = useState(false);
  const [toast, setToast] = useState('');

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(''), 2600);
    return () => clearTimeout(t);
  }, [toast]);

  const read = readSetOf(st);
  const dms = dmsOf(st).map((x) => dmRow(st, x));
  const mine = [...myRoomsOf(st)].reverse().map((r) => myRoomRow(st, r));
  const list = tab === 0 ? [...mine, ...content.rooms] : dms;
  const directCount = dms.reduce((n, x) => n + roomUnread(read, x), 0);

  /** markRoomRead, then the room opens (the write finishes in the background). */
  const markRead = (id: string) => {
    if (!id || read.includes(id)) return;
    setSt((s) => ({ ...s, [KEYS.readRooms]: [...readSetOf(s), id] }));
    void setAdd(KEYS.readRooms, id);
  };

  return (
    <div className={c.root}>
      <div className={c.head}>
        <h1 className={c.title}>Community</h1>
        <button type="button" className={c.iconBtn} aria-label="New room" title="New room" onClick={() => setSheet(true)}>
          <Icon name="add" size={22} />
        </button>
      </div>

      <div className={c.segs} role="tablist" aria-label="Community">
        {['Rooms', directCount > 0 ? `Direct · ${directCount}` : 'Direct'].map((label, i) => (
          <button key={i} type="button" role="tab" aria-selected={tab === i} className={`${c.segBtn} ${tab === i ? c.segOn : ''}`} onClick={() => setTab(i)}>
            {label}
          </button>
        ))}
      </div>

      <HeroCard radius={24} padding={16}>
        <div className={c.liveRow}>
          <AvatarStack people={content.live.avatars} hero />
          <div className={c.liveText}>
            <p className={c.liveTitle}>{content.live.title}</p>
            <p className={c.liveSub}>{content.live.subtitle}</p>
          </div>
          <PrimaryButton
            height={40}
            onClick={() => {
              markRead(content.live.roomId);
              router.push(roomHref(content.live.roomId, ''));
            }}
          >
            Join
          </PrimaryButton>
        </div>
      </HeroCard>

      <Card radius={24} padding="12px 16px 4px">
        <div className={c.listHead}>
          <span>{tab === 0 ? 'Your rooms' : 'Direct messages'}</span>
          <span>{tab === 0 ? content.roomsCount + mine.length : list.length}</span>
        </div>
        {tab === 1 && !list.length && (
          <div className={c.empty}>
            <Icon name="chat" size={28} color="var(--text-muted)" />
            <p className={c.emptyTitle}>No direct messages yet</p>
            <p className={c.emptyMsg}>Join a room and practise with a partner - your chats will appear here.</p>
            <SoftButton onClick={() => setTab(0)}>Browse rooms</SoftButton>
          </div>
        )}
        <div className={c.list} role="tabpanel">
          {list.map((r) => (
            <RoomRow key={str(r.id)} data={r} unread={roomUnread(read, r)} onOpen={() => markRead(str(r.id))} />
          ))}
        </div>
      </Card>

      {sheet && (
        <NewRoomSheet
          taken={[...content.rooms, ...myRoomsOf(st)].map((r) => str(r.name).toLowerCase())}
          onClose={() => setSheet(false)}
          onCreated={(room, rooms) => {
            setSheet(false);
            setTab(0);
            setSt((s) => ({ ...s, [KEYS.myRooms]: rooms }));
            setToast(`Room “${str(room.name)}” created`);
            markRead(str(room.id));
            router.push(roomHref(str(room.id), str(room.name)));
          }}
        />
      )}
      {toast && (
        <div className={c.toast} role="status">
          {toast}
        </div>
      )}
    </div>
  );
}

function RoomRow({ data, unread, onOpen }: { data: Row; unread: number; onOpen: () => void }) {
  let trailing = null;
  if (data.live === true) {
    trailing = (
      <span className={c.livePill}>
        <span className={c.dot} style={{ width: 6, height: 6, background: 'var(--c-live-dot)' }} />
        Live
      </span>
    );
  } else if (data.mineRoom === true) {
    trailing = <Tag>Yours</Tag>;
  } else if (unread > 0) {
    trailing = (
      <span className={c.badge} aria-label={`${unread} unread`}>
        {unread}
      </span>
    );
  }
  return (
    <Link href={roomHref(str(data.id), str(data.name))} className={c.row} onClick={onOpen}>
      <span className={`${c.letter} ${toneClass(str(data.tone))}`} aria-hidden>
        {str(data.letter)}
      </span>
      <span className={c.rowText}>
        <span className={c.rowName}>{str(data.name)}</span>
        <span className={c.rowSub}>{str(data.preview)}</span>
      </span>
      {trailing}
    </Link>
  );
}

const MAX_NAME = 40;
const MAX_DESC = 140;

/** "New room" sheet: name, topic chips, short description, validation. */
function NewRoomSheet({ taken, onClose, onCreated }: { taken: string[]; onClose: () => void; onCreated: (room: Row, rooms: Row[]) => void }) {
  const [name, setName] = useState('');
  const [desc, setDesc] = useState('');
  const [topic, setTopic] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const first = useRef<HTMLInputElement>(null);

  const close = useRef(onClose);
  close.current = onClose;
  useEffect(() => {
    first.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && close.current();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const validate = (): string | null => {
    const n = name.trim();
    if (n.length < 3) return 'Give the room a name (at least 3 characters).';
    if (n.length > MAX_NAME) return `Keep the name under ${MAX_NAME} characters.`;
    if (taken.includes(n.toLowerCase())) return 'A room with this name already exists.';
    if (!topic) return 'Pick a topic for the room.';
    if (desc.trim().length > MAX_DESC) return `Keep the description under ${MAX_DESC} characters.`;
    return null;
  };

  const create = async () => {
    const err = validate();
    if (err) return setError(err);
    setBusy(true);
    const room = newRoom(name, topic!, desc);
    const rooms = await listAdd(KEYS.myRooms, room);
    setBusy(false);
    if (!rooms) return setError('Could not create the room. Check your connection and try again.');
    onCreated(room, rooms);
  };

  const len = desc.trim().length;
  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-labelledby="new-room-title" onClick={onClose}>
      <form
        className={`${d.sheet} ${c.form}`}
        onClick={(e) => e.stopPropagation()}
        onSubmit={(e) => {
          e.preventDefault();
          void create();
        }}
      >
        <h2 id="new-room-title" className={d.title} style={{ marginBottom: 0 }}>
          New room
        </h2>
        <p className={c.formSub}>Start a study room for your group. Only you can delete it.</p>
        <label className={c.label}>
          Room name
          <input
            ref={first}
            className={c.input}
            value={name}
            placeholder="e.g. Task 2 essay swap"
            onChange={(e) => {
              setName(e.target.value);
              setError(null);
            }}
          />
        </label>
        <span className={c.label} id="room-topic-label">
          Topic
        </span>
        <div className={c.chips} role="radiogroup" aria-labelledby="room-topic-label">
          {ROOM_TOPICS.map((t) => (
            <button
              key={t}
              type="button"
              role="radio"
              aria-checked={topic === t}
              className={`${c.chip} ${topic === t ? c.chipOn : ''}`}
              onClick={() => {
                setTopic(t);
                setError(null);
              }}
            >
              {t}
            </button>
          ))}
        </div>
        <label className={c.label}>
          Short description (optional)
          <textarea
            className={c.input}
            rows={3}
            value={desc}
            placeholder="What will you practise here?"
            onChange={(e) => {
              setDesc(e.target.value);
              setError(null);
            }}
          />
        </label>
        <span className={`${c.counter} ${len > MAX_DESC ? c.counterOver : ''}`}>
          {len}/{MAX_DESC}
        </span>
        {error && (
          <p className={c.error} role="alert">
            {error}
          </p>
        )}
        <div className={c.formBtns}>
          <button type="button" className={c.outlineBtn} onClick={onClose}>
            Cancel
          </button>
          <button type="submit" className={c.fillBtn} disabled={busy}>
            Create room
          </button>
        </div>
      </form>
    </div></Portal>
  );
}
