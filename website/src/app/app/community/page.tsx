import type { Metadata } from 'next';
import { CommunityChannels } from '@/components/community/channels';
import { COMMUNITY_LIVE, readCommunity } from '@/components/community/data';
import { communityState } from '@/components/community/server';
import { SoonWall } from '@/components/community/soon-wall';
import { uiPack } from '@/lib/server/packs';

export const metadata: Metadata = { title: 'Community chat' };

/** H3 · Community Channels (community_channels_screen.dart): rooms + direct chats. */
export default async function CommunityPage() {
  const [ui, state] = await Promise.all([uiPack().catch(() => ({}) as Record<string, unknown>), communityState()]);
  const { community } = readCommunity(ui);
  const screen = <CommunityChannels content={community} initial={state} />;
  // Not live in the app yet: the same blurred "Coming soon" wall.
  return COMMUNITY_LIVE ? screen : <SoonWall>{screen}</SoonWall>;
}
