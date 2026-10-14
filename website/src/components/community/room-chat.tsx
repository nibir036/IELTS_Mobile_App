'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { Icon, PrimaryButton, Tag } from '../ui';
import d from '../dialog.module.css';
import { useRecorder } from '../use-recorder';
import { MyImageBubble, MyTextBubble, MyVoiceBubble, OtherBubble, PartnerTyping, SessionCard, SystemLine, Waveform } from './bubbles';
import {
  KEYS,
  clockFromMs,
  clockNow,
  deleteRoom,
  listAdd,
  newId,
  num,
  offlinePartnerReply,
  shortDate,
  str,
  type Row,
  type SpeakingRoomContent,
} from './data';
import c from './community.module.css';
import { Portal } from '@/components/portal';

/** Voice notes recorded on this page visit: a blob URL dies with the page, so older ones show as expired. */
const sessionVoicePaths = new Set<string>();
const voiceNoteExpired = (m: Row) => {
  const p = str(m.path);
  return !p || (p.startsWith('blob:') && !sessionVoicePaths.has(p));
};

const MAX_IMAGE_BYTES = 400 * 1024;

export interface RoomChatProps {
  roomId: string;
  /** Title from the link (?title=), '' for the content room's own title. */
  title: string;
  room: SpeakingRoomContent;
  /** The DM thread when [roomId] is one. */
  dm: Row | null;
  /** The user's own room when [roomId] is one. */
  mine: Row | null;
  sent: Row[];
  me: { name: string; initials: string };
  partner: { topic: string; questions: string[] };
}

type Menu = { m: Row; x: number; y: number } | null;

/** H4 · Speaking Room Chat: text, voice notes, images and an AI speaking partner. */
export function RoomChat({ roomId, title: argTitle, room, dm, mine, sent: initialSent, me, partner }: RoomChatProps) {
  const router = useRouter();
  const key = KEYS.sent(roomId);
  const [sent, setSent] = useState<Row[]>(initialSent);
  const sentRef = useRef(sent);
  sentRef.current = sent;
  const queue = useRef<Promise<unknown>>(Promise.resolve());

  const [input, setInput] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const [toast, setToast] = useState('');
  const [joinedSession, setJoinedSession] = useState(false);

  // Simulated playback of other people's voice messages.
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [playProgress, setPlayProgress] = useState(0);
  const playTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  // The user's own voice notes.
  const rec = useRecorder();
  const recStart = useRef(0);
  const recBusy = useRef(false);
  const audio = useRef<HTMLAudioElement | null>(null);
  const [clip, setClip] = useState<{ id: string; playing: boolean; progress: number } | null>(null);
  const [expired, setExpired] = useState<Set<string>>(new Set());

  // Images.
  const fileRef = useRef<HTMLInputElement>(null);
  const [viewer, setViewer] = useState<string | null>(null);

  // AI speaking partner.
  const [ai, setAi] = useState(false);
  const aiRef = useRef(false);
  const [aiBusy, setAiBusy] = useState(false);
  const aiBusyRef = useRef(false);
  const aiNext = useRef(0);
  const aiStart = useRef(0);

  // Menus and dialogs.
  const [menu, setMenu] = useState<Menu>(null);
  const [roomMenu, setRoomMenu] = useState<{ x: number; y: number } | null>(null);
  const [details, setDetails] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(''), 2600);
    return () => clearTimeout(t);
  }, [toast]);

  useEffect(
    () => () => {
      if (playTimer.current) clearInterval(playTimer.current);
      audio.current?.pause();
    },
    [],
  );

  // ── items (oldest first): content, the user's seeded replies after their afterId, session card, newer messages ──
  const content: Row[] = dm
    ? (Array.isArray(dm.messages) ? (dm.messages as Row[]) : [])
    : mine
      ? [
          {
            id: 'welcome',
            type: 'system',
            text: `Welcome to ${str(mine.name)} · ${str(mine.topic)}. ${str(mine.description) || 'Share a message, a voice note or an image to get started.'}`,
          },
        ]
      : room.messages;
  const ids = new Set(content.map((m) => str(m.id)));
  const items: Row[] = [];
  for (const m of content) {
    items.push(m);
    for (const x of sent) if (str(x.afterId) === str(m.id)) items.push(x);
  }
  if (!dm && !mine) items.push({ id: 'session', type: 'session' });
  for (const x of sent) if (!ids.has(str(x.afterId))) items.push(x);
  if (aiBusy) items.push({ id: 'typing', type: 'typing' });

  // Newest at the bottom.
  useEffect(() => {
    const el = listRef.current;
    if (el) el.scrollTo({ top: el.scrollHeight, behavior: 'smooth' });
  }, [items.length]);

  /** Adds a message locally and saves it to the room's kv list (one write at a time). */
  const persist = useCallback(
    (item: Row) => {
      setSent((prev) => [...prev, item]);
      queue.current = queue.current.then(async () => {
        const saved = await listAdd(key, item);
        if (!saved) {
          setToast('Could not save that message. Check your connection.');
          return;
        }
        const have = new Set(saved.map((x) => str(x.id)));
        setSent((prev) => [...saved, ...prev.filter((x) => !have.has(str(x.id)))]);
      });
    },
    [key],
  );

  /** One of the user's own messages. */
  const post = (fields: Row): Row => {
    const item = { id: newId('msg'), authorName: me.name || 'You', initials: me.initials, mine: true, time: clockNow(), createdAt: new Date().toISOString(), ...fields };
    persist(item);
    return item;
  };

  const send = () => {
    const text = input.trim();
    if (!text) return;
    const item = post({ type: 'text', text });
    setInput('');
    if (aiRef.current) void partnerRespond(text, item);
  };

  // ── voice notes ──
  const stopPlayback = () => {
    if (playTimer.current) clearInterval(playTimer.current);
    audio.current?.pause();
    setPlayingId(null);
    setClip((cl) => (cl ? { ...cl, playing: false } : cl));
  };

  const toggleVoice = async () => {
    if (recBusy.current) return;
    if (rec.recording) return stopAndSendVoice();
    recBusy.current = true;
    const ok = await rec.start();
    recBusy.current = false;
    if (!ok) {
      setToast('Microphone is blocked. Allow microphone access for IELTS AI in your browser or phone settings to send voice notes.');
      return;
    }
    recStart.current = Date.now();
    stopPlayback();
  };

  const stopAndSendVoice = async () => {
    if (recBusy.current) return;
    recBusy.current = true;
    const ms = Date.now() - recStart.current;
    const r = await rec.stop();
    recBusy.current = false;
    if (!r) return setToast('Could not save the voice note. Please try again.');
    if (ms < 700) return setToast('Hold on a little longer - that voice note was too short');
    const path = URL.createObjectURL(r.blob);
    sessionVoicePaths.add(path);
    post({ type: 'voice', path, durationMs: ms, durationSeconds: Math.round(ms / 1000), duration: clockFromMs(ms) });
  };

  const cancelVoice = async () => {
    if (recBusy.current) return;
    recBusy.current = true;
    await rec.stop();
    recBusy.current = false;
    setToast('Voice note discarded');
  };

  const markExpired = (id: string) => setExpired((s) => new Set(s).add(id));

  const toggleMyVoice = (m: Row) => {
    const id = str(m.id);
    if (expired.has(id) || voiceNoteExpired(m)) {
      markExpired(id);
      return setToast('This voice note has expired and can no longer be played');
    }
    if (playTimer.current) clearInterval(playTimer.current);
    setPlayingId(null);
    let a = audio.current;
    if (clip?.id === id && a) {
      if (a.paused) void a.play().catch(() => undefined);
      else a.pause();
      return;
    }
    a?.pause();
    a = new Audio(str(m.path));
    audio.current = a;
    const el = a;
    setClip({ id, playing: false, progress: 0 });
    el.ontimeupdate = () => setClip((cl) => (cl?.id === id ? { ...cl, progress: el.duration ? el.currentTime / el.duration : 0 } : cl));
    el.onplay = () => setClip((cl) => (cl?.id === id ? { ...cl, playing: true } : cl));
    el.onpause = () => setClip((cl) => (cl?.id === id ? { ...cl, playing: false } : cl));
    el.onended = () => setClip((cl) => (cl?.id === id ? { ...cl, playing: false, progress: 0 } : cl));
    el.onerror = () => {
      markExpired(id);
      setClip(null);
      setToast('This voice note has expired and can no longer be played');
    };
    void el.play().catch(() => undefined);
  };

  const togglePlay = (m: Row) => {
    const id = str(m.id);
    if (playTimer.current) clearInterval(playTimer.current);
    audio.current?.pause();
    if (playingId === id) return setPlayingId(null);
    const total = num(m.durationSeconds) <= 0 ? 10 : num(m.durationSeconds);
    setPlayingId(id);
    setPlayProgress(0);
    let p = 0;
    playTimer.current = setInterval(() => {
      p += 0.2 / total;
      if (p >= 1) {
        if (playTimer.current) clearInterval(playTimer.current);
        setPlayingId(null);
        setPlayProgress(0);
      } else setPlayProgress(p);
    }, 200);
  };

  // ── images (resized to 1024px wide, JPEG 70%, under 400 KB, like the app's picker) ──
  const pickImage = async (file: File) => {
    let url = '';
    try {
      url = URL.createObjectURL(file);
      const img = new Image();
      await new Promise<void>((res, rej) => {
        img.onload = () => res();
        img.onerror = () => rej(new Error('decode'));
        img.src = url;
      });
      const scale = Math.min(1, 1024 / (img.naturalWidth || 1));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(img.naturalWidth * scale));
      canvas.height = Math.max(1, Math.round(img.naturalHeight * scale));
      canvas.getContext('2d')?.drawImage(img, 0, 0, canvas.width, canvas.height);
      const b64 = canvas.toDataURL('image/jpeg', 0.7).split(',')[1] ?? '';
      const bytes = Math.floor((b64.length * 3) / 4) - (b64.endsWith('==') ? 2 : b64.endsWith('=') ? 1 : 0);
      if (!b64) throw new Error('encode');
      if (bytes > MAX_IMAGE_BYTES) return setToast(`That image is too large (${Math.round(bytes / 1024)} KB). Please choose one under 400 KB.`);
      post({ type: 'image', imageBase64: b64, bytes });
    } catch {
      setToast('Could not open that image. Please choose another one.');
    } finally {
      if (url) URL.revokeObjectURL(url);
    }
  };

  // ── AI speaking partner ──
  const nextQuestion = () => {
    const qs = partner.questions;
    if (!qs.length) return 'What would you like to talk about next?';
    const q = qs[aiNext.current % qs.length];
    aiNext.current++;
    return q;
  };

  const postPartner = (text: string, offline: boolean) =>
    persist({
      id: newId('msg'),
      type: 'text',
      ai: true,
      mine: false,
      authorName: offline ? 'AI partner (offline demo)' : 'AI partner',
      initials: 'AI',
      tone: 'lilac',
      time: clockNow(),
      createdAt: new Date().toISOString(),
      text,
    });

  const toggleAi = () => {
    if (aiRef.current) {
      aiRef.current = false;
      setAi(false);
      busy(false);
      return setToast('AI speaking partner is off');
    }
    aiRef.current = true;
    setAi(true);
    aiNext.current = 0;
    aiStart.current = sentRef.current.length;
    postPartner(
      `Hi! I’m your AI speaking partner. Answer in 3–5 sentences, as you would in Speaking Part 3, and I’ll give you quick feedback.\n\n${nextQuestion()}`,
      false,
    );
  };

  /** Conversation since the partner was switched on (last 12 turns). */
  const partnerHistory = (latest: Row) => {
    const all = sentRef.current.some((x) => x.id === latest.id) ? sentRef.current : [...sentRef.current, latest];
    const from = Math.max(0, Math.min(aiStart.current, all.length));
    const out = all
      .slice(from)
      .filter((m) => str(m.type) === 'text' && str(m.text))
      .map((m) => ({ role: m.ai === true ? 'partner' : 'student', content: str(m.text) }));
    return out.slice(-12);
  };

  const busy = (v: boolean) => {
    aiBusyRef.current = v;
    setAiBusy(v);
  };

  const partnerRespond = async (answer: string, latest: Row) => {
    if (aiBusyRef.current) return;
    busy(true);
    let res: Row | null = null;
    try {
      const r = await fetch('/api/v1/chat/partner', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ history: partnerHistory(latest), ...(partner.topic ? { topic: partner.topic } : {}), questions: partner.questions }),
      });
      res = r.ok ? ((await r.json()) as Row) : null;
    } catch {
      res = null;
    }
    if (!aiRef.current) return busy(false);
    const fallback = nextQuestion();
    let text = '';
    let offline = true;
    if (res) {
      const feedback = str(res.feedback);
      const suggestion = str(res.suggestion);
      const question = str(res.question) || fallback;
      text = [feedback, suggestion ? `Try: “${suggestion}”.` : '', question].filter(Boolean).join('\n\n');
      offline = false;
    }
    if (!text.trim()) {
      text = offlinePartnerReply(answer, fallback);
      offline = true;
    }
    busy(false);
    postPartner(text, offline);
  };

  // ── menus ──
  const openMenu = (m: Row, e: { preventDefault(): void; currentTarget: EventTarget; type: string; clientX: number; clientY: number }) => {
    e.preventDefault();
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const x = e.type === 'contextmenu' ? e.clientX : r.left;
    const y = e.type === 'contextmenu' ? e.clientY : r.bottom;
    setMenu({ m, x, y });
  };

  const onMessageAction = async (action: 'reply' | 'copy' | 'report', m: Row) => {
    setMenu(null);
    if (action === 'reply') {
      const name = m.mine === true ? 'You' : str(m.authorName).split(' ')[0];
      setInput(`@${name} `);
      inputRef.current?.focus();
    } else if (action === 'copy') {
      const type = str(m.type);
      const text = type === 'voice' ? `Voice message (${str(m.duration)})` : type === 'image' ? 'Photo' : str(m.text);
      try {
        await navigator.clipboard.writeText(text);
        setToast('Copied');
      } catch {
        setToast('Could not copy');
      }
    } else {
      setToast('Reported. A moderator will review this message.');
    }
  };

  const doDelete = async () => {
    setConfirmDelete(false);
    if (!mine) return;
    const ok = await deleteRoom(str(mine.id));
    if (!ok) return setToast('Could not delete the room. Please try again.');
    setToast('Room deleted');
    router.push('/app/community');
    router.refresh();
  };

  // ── render ──
  const title = mine ? str(mine.name) : argTitle || room.title;
  const sub = dm ? 'Direct message' : mine ? `${str(mine.topic)} · your room` : `${room.onlineCount} learners online`;
  const created = mine ? new Date(str(mine.createdAt)) : null;

  const message = (m: Row) => {
    const type = str(m.type);
    if (type === 'session')
      return (
        <SessionCard
          data={room.session}
          joined={joinedSession}
          onJoin={() => {
            setToast(!joinedSession ? `You joined ${str(room.session.title)}` : 'You left the session');
            setJoinedSession(!joinedSession);
          }}
        />
      );
    if (type === 'system') return <SystemLine text={str(m.text)} />;
    if (type === 'typing') return <PartnerTyping />;
    const id = str(m.id);
    const own = m.mine === true;
    let bubble;
    if (own && type === 'voice') {
      bubble = (
        <MyVoiceBubble
          m={m}
          expired={expired.has(id) || voiceNoteExpired(m)}
          playing={clip?.id === id && clip.playing}
          progress={clip?.id === id ? clip.progress : 0}
          onTap={() => toggleMyVoice(m)}
        />
      );
    } else if (own && type === 'image') {
      bubble = <MyImageBubble m={m} onOpen={setViewer} />;
    } else if (own) {
      bubble = <MyTextBubble m={m} />;
    } else {
      bubble = <OtherBubble m={m} playing={playingId === id} progress={playingId === id ? playProgress : 0} onPlay={() => togglePlay(m)} />;
    }
    const more = (
      <button type="button" className={c.msgMore} aria-label="Message options" aria-haspopup="menu" aria-expanded={menu?.m === m} onClick={(e) => openMenu(m, e)}>
        <Icon name="more_horiz" size={18} />
      </button>
    );
    return (
      <div className={`${c.msgWrap} ${own ? c.msgMine : ''}`} onContextMenu={(e) => openMenu(m, e)}>
        {own && more}
        {bubble}
        {!own && more}
      </div>
    );
  };

  const quickActions = room.quickActions.length ? room.quickActions : ['Voice', 'Image', 'AI partner'];

  return (
    <div className={`${c.root} ${c.chat}`}>
      <header className={c.chatHead}>
        <Link href="/app/community" className={c.iconBtn} aria-label="Back">
          <Icon name="arrow_back" size={18} />
        </Link>
        <div className={c.chatTitleBox}>
          <h1 className={c.chatTitle}>{title}</h1>
          <span className={c.chatSub}>
            <span className={c.dot} style={{ width: 7, height: 7, background: 'var(--c-online)' }} />
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{sub}</span>
          </span>
        </div>
        {mine ? (
          <button
            type="button"
            className={c.iconBtn}
            aria-label="Room options"
            aria-haspopup="menu"
            aria-expanded={!!roomMenu}
            onClick={(e) => {
              const r = e.currentTarget.getBoundingClientRect();
              setRoomMenu({ x: r.right - 190, y: r.bottom + 4 });
            }}
          >
            <Icon name="more_vert" size={22} />
          </button>
        ) : (
          <button type="button" className={c.iconBtn} aria-label="Voice room" title="Voice room" onClick={() => setToast('Joining voice room…')}>
            <Icon name="headset_mic" size={22} />
          </button>
        )}
      </header>

      <div className={c.messages} ref={listRef} role="log" aria-live="polite" aria-label="Messages">
        <span className={c.day}>{room.dayLabel}</span>
        {items.map((m) => (
          <div key={str(m.id)}>{message(m)}</div>
        ))}
      </div>

      <div className={c.quickRow}>
        {quickActions.map((a) =>
          a === 'Voice' ? (
            <button key={a} type="button" className={`${c.quick} ${rec.recording ? c.quickOn : ''}`} onClick={() => void toggleVoice()}>
              <Icon name={rec.recording ? 'stop' : 'mic'} size={18} />
              {rec.recording ? 'Stop & send' : 'Voice'}
            </button>
          ) : a === 'Image' ? (
            <button key={a} type="button" className={c.quick} disabled={rec.recording} onClick={() => fileRef.current?.click()}>
              <Icon name="attach_file" size={18} />
              Image
            </button>
          ) : (
            <button key={a} type="button" className={`${c.quick} ${ai ? c.quickOn : ''}`} aria-pressed={ai} onClick={toggleAi}>
              <Icon name="auto_awesome" size={18} />
              {ai ? 'AI partner · on' : a}
            </button>
          ),
        )}
        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          hidden
          onChange={(e) => {
            const f = e.target.files?.[0];
            e.target.value = '';
            if (f) void pickImage(f);
          }}
        />
      </div>

      {rec.recording ? (
        <div className={c.composer}>
          <button type="button" className={`${c.send} ${c.sendGhost}`} aria-label="Cancel voice note" onClick={() => void cancelVoice()}>
            <Icon name="delete" size={22} />
          </button>
          <div className={c.recBar} role="status" aria-label="Recording voice note">
            <span className={c.dot} style={{ width: 9, height: 9, background: 'var(--alert)' }} />
            <span className={c.recTime}>{clockFromMs(rec.seconds * 1000)}</span>
            <span style={{ flex: 1, minWidth: 0, overflow: 'hidden', display: 'flex' }}>
              <Waveform count={22} height={22 + 10 * rec.level} progress={1} seed={3 + Math.round(rec.level * 10)} width={220} />
            </span>
          </div>
          <button type="button" className={c.send} aria-label="Stop and send" onClick={() => void stopAndSendVoice()}>
            <Icon name="send" size={22} />
          </button>
        </div>
      ) : (
        <form
          className={c.composer}
          onSubmit={(e) => {
            e.preventDefault();
            send();
          }}
        >
          <label className={c.visuallyHidden} htmlFor="room-input">
            Message
          </label>
          <input
            id="room-input"
            ref={inputRef}
            className={c.field}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder={ai ? 'Answer the AI partner…' : 'Message the room'}
            enterKeyHint="send"
            autoComplete="off"
          />
          <button type="submit" className={c.send} aria-label="Send">
            <Icon name="send" size={22} />
          </button>
        </form>
      )}

      {menu && (
        <PopMenu
          x={menu.x}
          y={menu.y}
          onClose={() => setMenu(null)}
          items={[
            { icon: 'reply', label: 'Reply', on: () => void onMessageAction('reply', menu.m) },
            { icon: 'content_copy', label: 'Copy text', on: () => void onMessageAction('copy', menu.m) },
            { icon: 'flag', label: 'Report message', danger: true, on: () => void onMessageAction('report', menu.m) },
          ]}
        />
      )}
      {roomMenu && (
        <PopMenu
          x={roomMenu.x}
          y={roomMenu.y}
          onClose={() => setRoomMenu(null)}
          items={[
            { icon: 'info', label: 'Room details', on: () => (setRoomMenu(null), setDetails(true)) },
            { icon: 'delete', label: 'Delete room', danger: true, on: () => (setRoomMenu(null), setConfirmDelete(true)) },
          ]}
        />
      )}

      {details && mine && (
        <Modal label={str(mine.name)} onClose={() => setDetails(false)}>
          <h2 className={d.title} style={{ marginBottom: 0 }}>
            {str(mine.name)}
          </h2>
          <span className={c.detailsTag}>
            <Tag>{str(mine.topic)}</Tag>
          </span>
          <p className={c.detailsBody}>{str(mine.description) || 'No description.'}</p>
          {created && !Number.isNaN(created.getTime()) && <p className={c.detailsMeta}>Created by you · {shortDate(created)}</p>}
          <PrimaryButton block height={48} onClick={() => setDetails(false)}>
            Close
          </PrimaryButton>
        </Modal>
      )}
      {confirmDelete && mine && (
        <Modal label="Delete this room?" onClose={() => setConfirmDelete(false)}>
          <h2 className={d.title} style={{ marginBottom: 0 }}>
            Delete this room?
          </h2>
          <p className={c.detailsBody} style={{ color: 'var(--text-muted)' }}>
            “{str(mine.name)}” and all its messages will be removed. This can’t be undone.
          </p>
          <div className={c.formBtns}>
            <button type="button" className={c.outlineBtn} style={{ height: 48 }} onClick={() => setConfirmDelete(false)}>
              Keep
            </button>
            <button type="button" className={`${c.fillBtn} ${c.dangerBtn}`} style={{ height: 48 }} onClick={() => void doDelete()}>
              Delete
            </button>
          </div>
        </Modal>
      )}

      {viewer && (
        <Viewer src={viewer} onClose={() => setViewer(null)} />
      )}
      {toast && (
        <div className={c.toast} role="status">
          {toast}
        </div>
      )}
    </div>
  );
}

function useEscape(onClose: () => void) {
  const cb = useRef(onClose);
  cb.current = onClose;
  useEffect(() => {
    const k = (e: KeyboardEvent) => e.key === 'Escape' && cb.current();
    window.addEventListener('keydown', k);
    return () => window.removeEventListener('keydown', k);
  }, []);
}

function PopMenu({ x, y, items, onClose }: { x: number; y: number; items: Array<{ icon: string; label: string; danger?: boolean; on: () => void }>; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const cb = useRef(onClose);
  cb.current = onClose;
  useEscape(onClose);
  useEffect(() => {
    ref.current?.querySelector('button')?.focus();
    const down = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) cb.current();
    };
    window.addEventListener('mousedown', down);
    return () => window.removeEventListener('mousedown', down);
  }, []);
  const left = Math.max(8, Math.min(x, (typeof window !== 'undefined' ? window.innerWidth : 400) - 206));
  const top = Math.max(8, Math.min(y, (typeof window !== 'undefined' ? window.innerHeight : 600) - 48 * items.length - 24));
  return (
    <div
      ref={ref}
      className={c.menu}
      role="menu"
      style={{ position: 'fixed', left, top }}
      onKeyDown={(e) => {
        if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
        e.preventDefault();
        const bs = Array.from(ref.current?.querySelectorAll('button') ?? []);
        const i = bs.indexOf(document.activeElement as HTMLButtonElement);
        bs[(i + (e.key === 'ArrowDown' ? 1 : bs.length - 1)) % bs.length]?.focus();
      }}
    >
      {items.map((it, i) => (
        <div key={it.label} style={{ display: 'contents' }}>
          {it.danger && i > 0 && <span className={c.menuSep} role="separator" />}
          <button type="button" role="menuitem" className={`${c.menuItem} ${it.danger ? c.menuDanger : ''}`} onClick={it.on}>
            <Icon name={it.icon} size={18} />
            {it.label}
          </button>
        </div>
      ))}
    </div>
  );
}

function Modal({ label, onClose, children }: { label: string; onClose: () => void; children: ReactNode }) {
  useEscape(onClose);
  return (
    <Portal><div className={d.backdrop} role="dialog" aria-modal="true" aria-label={label} onClick={onClose}>
      <div className={`${d.sheet} ${c.form}`} onClick={(e) => e.stopPropagation()}>
        {children}
      </div>
    </div></Portal>
  );
}

function Viewer({ src, onClose }: { src: string; onClose: () => void }) {
  useEscape(onClose);
  const close = useRef<HTMLButtonElement>(null);
  useEffect(() => close.current?.focus(), []);
  return (
    <div className={c.viewer} role="dialog" aria-modal="true" aria-label="Photo" onClick={onClose}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt="Photo you sent" onClick={(e) => e.stopPropagation()} />
      <button ref={close} type="button" className={`${c.iconBtn} ${c.viewerClose}`} aria-label="Close" onClick={onClose}>
        <Icon name="close" size={22} />
      </button>
    </div>
  );
}
