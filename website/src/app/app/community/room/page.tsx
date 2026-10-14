import { redirect } from 'next/navigation';
import { readCommunity } from '@/components/community/data';
import { uiPack } from '@/lib/server/packs';

/** /app/community/room without an id opens the content room (Routes.speakingRoomChat with no args). */
export default async function RoomIndex() {
  const { room } = readCommunity(await uiPack().catch(() => ({}) as Record<string, unknown>));
  redirect(room.id ? `/app/community/room/${encodeURIComponent(room.id)}` : '/app/community');
}
