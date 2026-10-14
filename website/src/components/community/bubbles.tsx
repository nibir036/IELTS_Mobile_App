// Message bubbles, session card, system line and typing row of the room chat
// (room_chat_bubbles.dart + room_chat_parts.dart). Plain components: the room
// chat (a client component) owns the state.

import { Icon } from '../ui';
import { clockFromMs, num, rows, str, type Row } from './data';
import c from './community.module.css';

export const toneClass = (tone: string) => `${c.tone} ${c[`tone-${tone}`] ?? ''}`;

/** WaveformBars: fixed-shape bars, the part before [progress] in the played colour. */
export function Waveform({ count, height, progress, seed, width }: { count: number; height: number; progress: number; seed: number; width: number }) {
  let x = seed * 9301 + 49297;
  const rnd = () => {
    x = (x * 9301 + 49297) % 233280;
    return x / 233280;
  };
  const hs = Array.from({ length: count }, (_, i) => 0.2 + 0.8 * (0.5 + 0.5 * Math.sin(i * 0.7 + seed)) * (0.6 + 0.4 * rnd()));
  return (
    <span className={c.wave} style={{ width, height }} aria-hidden>
      {hs.map((h, i) => (
        <span key={i} className={i / count < progress ? c.played : undefined} style={{ height: Math.max(3, height * h) }} />
      ))}
    </span>
  );
}

/** AvatarStack: overlapping initials circles. */
export function AvatarStack({ people, size = 34, overlap = 10, fontSize = 12, hero }: { people: Row[]; size?: number; overlap?: number; fontSize?: number; hero?: boolean }) {
  return (
    <span className={`${c.avatars} ${hero ? c.avatarsHero : ''}`} aria-hidden>
      {people.map((p, i) => (
        <span
          key={i}
          className={`${c.avatar} ${toneClass(str(p.tone))}`}
          style={{ width: size, height: size, fontSize, marginLeft: i ? -overlap : 0, color: '#151515' }}
        >
          {str(p.initials)}
        </span>
      ))}
    </span>
  );
}

export function MyTextBubble({ m }: { m: Row }) {
  return (
    <div className={c.mine}>
      <div className={c.bubbleHead}>
        <span>You</span>
        <span>{str(m.time)}</span>
      </div>
      <p className={c.text}>{str(m.text)}</p>
    </div>
  );
}

/** The user's voice note: play/pause, waveform progress, duration; "(expired)" when gone. */
export function MyVoiceBubble({ m, expired, playing, progress, onTap }: { m: Row; expired: boolean; playing: boolean; progress: number; onTap: () => void }) {
  const ms = num(m.durationMs);
  return (
    <div className={c.mine} style={{ padding: '10px 14px 10px 10px', gap: 6 }}>
      <div className={c.bubbleHead} style={{ paddingLeft: 4 }}>
        <span>You · {str(m.time)}</span>
      </div>
      <div className={c.voiceRow} style={{ marginTop: 0 }}>
        <button type="button" className={c.playBtn} onClick={onTap} aria-label={expired ? 'Voice note expired' : playing ? 'Pause voice note' : 'Play voice note'}>
          <Icon name={expired ? 'mic_off' : playing ? 'pause' : 'play_arrow'} size={20} filled />
        </button>
        {expired ? (
          <span style={{ fontSize: 14 }}>Voice note (expired)</span>
        ) : (
          <Waveform count={16} height={24} progress={progress} seed={9} width={100} />
        )}
        <span className={c.duration}>{ms > 0 ? clockFromMs(ms) : str(m.duration)}</span>
      </div>
    </div>
  );
}

/** The user's image message; click opens the full-screen viewer. */
export function MyImageBubble({ m, onOpen }: { m: Row; onOpen: (src: string) => void }) {
  const b64 = str(m.imageBase64);
  const src = b64 ? `data:image/jpeg;base64,${b64}` : '';
  return (
    <div className={c.imgMsg}>
      {src ? (
        <button type="button" className={c.imgBtn} onClick={() => onOpen(src)} aria-label="Open photo">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={src} alt="Photo you sent" />
        </button>
      ) : (
        <div className={c.imgMissing}>
          <Icon name="attach_file" size={22} />
          Image unavailable
        </div>
      )}
      <span className={c.imgMeta}>You · {str(m.time)}</span>
    </div>
  );
}

/** Someone else's text or voice message (voice playback is simulated, as in the app). */
export function OtherBubble({ m, playing, progress, onPlay }: { m: Row; playing: boolean; progress: number; onPlay: () => void }) {
  const voice = str(m.type) === 'voice';
  const tone = str(m.tone);
  return (
    <div className={c.other}>
      <span className={`${c.otherAvatar} ${toneClass(tone)}`} aria-hidden>
        {m.ai === true && !str(m.initials) ? <Icon name="auto_awesome" size={16} /> : str(m.initials)}
      </span>
      <div className={c.otherBubble} style={voice ? { padding: '10px 12px', gap: 6 } : undefined}>
        <div className={c.bubbleHead}>
          <span>{str(m.authorName)}</span>
          <span>{str(m.time)}</span>
        </div>
        {voice ? (
          <div className={c.voiceRow} style={{ marginTop: 0 }}>
            <button type="button" className={c.playBtn} onClick={onPlay} aria-label={playing ? 'Pause voice message' : 'Play voice message'}>
              <Icon name={playing ? 'pause' : 'play_arrow'} size={20} filled />
            </button>
            <Waveform count={18} height={24} progress={progress} seed={4} width={110} />
            <span className={c.duration}>{str(m.duration)}</span>
          </div>
        ) : (
          <p className={c.text}>{str(m.text)}</p>
        )}
      </div>
    </div>
  );
}

/** "Partner practice" card in the content room. */
export function SessionCard({ data, joined, onJoin }: { data: Row; joined: boolean; onJoin: () => void }) {
  const count = num(data.joined) + (joined ? 1 : 0);
  return (
    <div className={c.session}>
      <div className={c.sessionTop}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <p className={c.sessionLabel}>{str(data.label)}</p>
          <p className={c.sessionTitle}>{str(data.title)}</p>
          <p className={c.sessionMeta}>
            Starts {str(data.startsAt)} · {count} joined
          </p>
        </div>
        <AvatarStack people={rows(data.avatars)} size={28} overlap={8} fontSize={10} hero />
      </div>
      <button type="button" className={`${c.joinBtn} ${joined ? c.joined : ''}`} onClick={onJoin} aria-pressed={joined}>
        {joined ? 'Joined' : 'Join room'}
        <Icon name={joined ? 'check' : 'arrow_forward'} size={18} />
      </button>
    </div>
  );
}

export function SystemLine({ text }: { text: string }) {
  return <p className={c.system}>{text}</p>;
}

export function PartnerTyping() {
  return (
    <div className={c.other} role="status">
      <span className={`${c.otherAvatar} ${toneClass('lilac')}`} aria-hidden>
        <Icon name="auto_awesome" size={16} />
      </span>
      <span className={c.typing}>AI partner is typing…</span>
    </div>
  );
}
