// Cloudflare R2 (S3-compatible) for recordings, profile photos and voice
// messages. Objects stay private; the app gets short-lived signed URLs.

import { DeleteObjectsCommand, PutObjectCommand, S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from '../env';
import { HttpError } from './http';

let client: S3Client | null = null;

function s3(): S3Client {
  if (!env.r2Configured) {
    throw new HttpError(503, 'File storage is not configured on the server (R2_* settings).', 'storage_not_configured');
  }
  client ??= new S3Client({
    region: 'auto',
    endpoint: `https://${env.r2AccountId}.r2.cloudflarestorage.com`,
    credentials: { accessKeyId: env.r2AccessKeyId, secretAccessKey: env.r2SecretAccessKey },
  });
  return client;
}

/**
 * Bucket layout (all under env.r2Prefix, "ielts_app_phone_version"):
 *   listening/audio/<file>.mp3          listening recordings (app content)
 *   listening/maps/<file>               map / plan drawings
 *   writing/task1-images/<file>         Task 1 charts, tables, maps, processes
 *   writing/guide-images/<file>         writing guide figures
 *   reading/images/<file>               reading diagrams
 *   speaking/<user id>/<attempt id>/<question>.wav   students' speaking answers
 *   users/<user id>/<kind>/<date>/<uuid>.<ext>       other uploads (photo, voice …)
 */
export const appKey = (key: string) => `${env.r2Prefix}/${key.replace(/^\/+/, '')}`;

/** Content media folders the app may read through /v1/media. */
export const MEDIA_FOLDERS = [
  'listening/audio/',
  'listening/maps/',
  'writing/task1-images/',
  'writing/guide-images/',
  'reading/images/',
];

/** True for keys a user owns (their uploads and speaking recordings). */
export function ownsKey(userId: string, key: string): boolean {
  return (
    key.startsWith(appKey(`users/${userId}/`)) ||
    key.startsWith(appKey(`speaking/${userId}/`)) ||
    key.startsWith(`users/${userId}/`) // before the app folder existed
  );
}

export async function putObject(key: string, body: Buffer, contentType: string): Promise<void> {
  await s3().send(new PutObjectCommand({ Bucket: env.r2Bucket, Key: key, Body: body, ContentType: contentType }));
}

/** Signed GET URL (default 1 hour). [signingDate] fixes the link's start, so
 *  repeated requests in that window get the same (cacheable) URL. */
export async function signedUrl(key: string, seconds = 3600, signingDate?: Date): Promise<string> {
  return getSignedUrl(s3(), new GetObjectCommand({ Bucket: env.r2Bucket, Key: key }), {
    expiresIn: seconds,
    ...(signingDate ? { signingDate } : {}),
  });
}

export async function deleteObjects(keys: string[]): Promise<void> {
  const list = keys.filter(Boolean);
  if (!list.length || !env.r2Configured) return;
  for (let i = 0; i < list.length; i += 1000) {
    await s3().send(
      new DeleteObjectsCommand({
        Bucket: env.r2Bucket,
        Delete: { Objects: list.slice(i, i + 1000).map((Key) => ({ Key })), Quiet: true },
      }),
    );
  }
}

const EXT_TYPES: Record<string, string> = {
  wav: 'audio/wav',
  m4a: 'audio/mp4',
  mp3: 'audio/mpeg',
  webm: 'audio/webm',
  ogg: 'audio/ogg',
  aac: 'audio/aac',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
};

export function contentTypeFor(ext: string): string {
  return EXT_TYPES[ext.toLowerCase()] || 'application/octet-stream';
}

export function isAllowedExt(ext: string, kind: 'audio' | 'image'): boolean {
  const t = EXT_TYPES[ext.toLowerCase()];
  return Boolean(t && t.startsWith(kind === 'audio' ? 'audio/' : 'image/'));
}
