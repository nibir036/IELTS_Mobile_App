// Cloudflare R2 (S3-compatible) for recordings, profile photos and voice
// messages. Objects stay private; the app gets short-lived signed URLs.

import { CopyObjectCommand, DeleteObjectsCommand, PutObjectCommand, S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
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
 *   archive/users/<user id>/...         a student's data, written on profile
 *                                       completion and on account deletion (lib/archive.ts)
 *   training/speaking/<sample id>/...   speaking audio kept for model training
 *                                       after an account is deleted, not linked to anyone
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

/** True for "that object does not exist" (a key in the database whose file
 *  was never uploaded, or was already removed). */
function isMissing(e: unknown): boolean {
  const err = e as { name?: string; Code?: string; $metadata?: { httpStatusCode?: number } };
  return err?.name === 'NoSuchKey' || err?.Code === 'NoSuchKey' || err?.$metadata?.httpStatusCode === 404;
}

/** The object's bytes, or null when it does not exist. */
export async function getObjectBytes(key: string): Promise<Buffer | null> {
  try {
    const res = await s3().send(new GetObjectCommand({ Bucket: env.r2Bucket, Key: key }));
    const body = res.Body as { transformToByteArray?: () => Promise<Uint8Array> } | undefined;
    if (!body?.transformToByteArray) return null;
    return Buffer.from(await body.transformToByteArray());
  } catch (e) {
    if (isMissing(e)) return null;
    throw e;
  }
}

/**
 * Copy inside the bucket. Tries R2's server-side copy first; if that is
 * refused (some R2 tokens and key names trip it), downloads and re-uploads.
 * Returns false when the source does not exist - nothing to copy.
 */
export async function copyObject(from: string, to: string): Promise<boolean> {
  try {
    const source = `${env.r2Bucket}/${from.split('/').map(encodeURIComponent).join('/')}`;
    await s3().send(new CopyObjectCommand({ Bucket: env.r2Bucket, CopySource: source, Key: to }));
    return true;
  } catch (e) {
    if (isMissing(e)) return false;
    console.warn('[r2] server-side copy refused, copying by download:', e instanceof Error ? e.message : e);
    const bytes = await getObjectBytes(from);
    if (!bytes) return false;
    const ext = (from.match(/\.([a-z0-9]{2,5})$/i)?.[1] ?? '').toLowerCase();
    await putObject(to, bytes, contentTypeFor(ext));
    return true;
  }
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
  pdf: 'application/pdf',
};

export function contentTypeFor(ext: string): string {
  return EXT_TYPES[ext.toLowerCase()] || 'application/octet-stream';
}

/** Study-abroad documents: PDF, JPEG and PNG only. */
export const DOCUMENT_EXTS = new Set(['pdf', 'jpg', 'jpeg', 'png']);

export function isAllowedExt(ext: string, kind: 'audio' | 'image'): boolean {
  const t = EXT_TYPES[ext.toLowerCase()];
  return Boolean(t && t.startsWith(kind === 'audio' ? 'audio/' : 'image/'));
}
