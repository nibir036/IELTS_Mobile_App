import type { Metadata } from 'next';
import { COMMUNITY_LIVE, dmsOf, initialsOf, myRoomsOf, readCommunity, sentOf, str } from '@/components/community/data';
import { RoomChat } from '@/components/community/room-chat';
import { communityState, partnerQuestions } from '@/components/community/server';
import { SoonWall } from '@/components/community/soon-wall';
import { getMe } from '@/lib/server/me';
import { uiPack } from '@/lib/server/packs';

export const metadata: Metadata = { title: 'Speaking Room' };

/**
 * H4 · Speaking Room Chat (speaking_room_chat_screen.dart): the content room,
 * one of the student's own rooms or a DM thread, by id. `?title=` names a
 * content room opened from the list.
 */
export default async function RoomPage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ title?: string }> }) {
  // Not live in the app yet (CommunitySoonScreen).
  if (!COMMUNITY_LIVE) return <SoonWall backHref="/app/community" />;

  const [{ id: raw }, q] = await Promise.all([params, searchParams]);
  const [ui, state, me] = await Promise.all([uiPack().catch(() => ({}) as Record<string, unknown>), communityState(), getMe()]);
  const { room } = readCommunity(ui);
  const roomId = decodeURIComponent(raw) || room.id;
  const dm = dmsOf(state).find((x) => str(x.id) === roomId) ?? null;
  const mine = dm ? null : (myRoomsOf(state).find((x) => str(x.id) === roomId) ?? null);
  // Part 3 keyword: the room topic for own rooms ('' for General), else the session topic ("Part 3 · Environment" → "Environment").
  let keyword = '';
  if (mine) keyword = str(mine.topic) === 'General' ? '' : str(mine.topic);
  else {
    const t = str(room.session.title);
    const i = t.lastIndexOf('·');
    keyword = i >= 0 ? t.slice(i + 1).trim() : t;
  }
  const partner = await partnerQuestions(roomId, keyword, ui);
  return (
    <RoomChat
      key={roomId}
      roomId={roomId}
      title={q.title ?? ''}
      room={room}
      dm={dm}
      mine={mine}
      sent={sentOf(state, roomId)}
      me={{ name: me.user.name, initials: initialsOf(me.user.name) }}
      partner={partner}
    />
  );
}
