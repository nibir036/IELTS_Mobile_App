// Content media (listening audio, writing / reading images) lives in R2,
// like in the app (lib/app/services/media.dart). The content JSON keeps the
// app's asset paths; this turns them into links served through /media/….

const FOLDERS: Array<[string, string]> = [
  ['assets/audio/listening/', 'listening/audio/'],
  ['assets/listening/maps/', 'listening/maps/'],
  ['assets/writing/task1/', 'writing/task1-images/'],
  ['assets/writing/tests/', 'writing/task1-images/'],
  ['assets/writing/guide/', 'writing/guide-images/'],
  ['assets/diagrams/app/', 'reading/images/'],
];

/** R2 key for an app asset path, or null when it isn't R2 media. */
export function mediaKey(asset: string): string | null {
  for (const [from, to] of FOLDERS) {
    if (asset.startsWith(from)) return to + asset.slice(from.length);
  }
  return null;
}

/** Same-site link for an app asset path ('' when there is none). */
export function mediaUrl(asset: string): string {
  const key = mediaKey(asset);
  return key ? `/media/${key.split('/').map(encodeURIComponent).join('/')}` : '';
}
