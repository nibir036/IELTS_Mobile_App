// Uploads the app's content media to Cloudflare R2 (bucket = R2_BUCKET_NAME,
// top folder = R2_APP_PREFIX, default "ielts_app_phone_version"):
//
//   assets/audio/listening/*   -> listening/audio/
//   assets/listening/maps/*    -> listening/maps/
//   assets/writing/task1/*     -> writing/task1-images/
//   assets/writing/tests/*     -> writing/task1-images/
//   assets/writing/guide/*     -> writing/guide-images/
//   assets/diagrams/app/*      -> reading/images/
//
// The same mapping is in lib/app/services/media.dart (app) and MEDIA_FOLDERS
// in src/lib/r2.ts (server). Files already in R2 with the same size are
// skipped, so it is safe to run again after adding or re-cutting audio.
//
//   cd server
//   npm run media:upload              (upload new / changed files)
//   npm run media:upload -- --dry     (only list what would be uploaded)
//   npm run media:upload -- --force   (upload everything again)

import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

const ROOT = path.resolve(__dirname, '..', '..');
const MAP: Array<[string, string]> = [
  ['assets/audio/listening', 'listening/audio'],
  ['assets/listening/maps', 'listening/maps'],
  ['assets/writing/task1', 'writing/task1-images'],
  ['assets/writing/tests', 'writing/task1-images'],
  ['assets/writing/guide', 'writing/guide-images'],
  ['assets/diagrams/app', 'reading/images'],
];
const TYPES: Record<string, string> = {
  mp3: 'audio/mpeg',
  wav: 'audio/wav',
  m4a: 'audio/mp4',
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  webp: 'image/webp',
  gif: 'image/gif',
  svg: 'image/svg+xml',
};

// Read server/.env ourselves as well (tolerates quotes, spaces around "=",
// a UTF-16 file saved by Notepad/PowerShell, and an empty value in the shell).
(function loadEnv() {
  const file = path.join(__dirname, '..', '.env');
  let raw: Buffer;
  try {
    raw = readFileSync(file);
  } catch {
    console.error(`No .env file at ${file}`);
    return;
  }
  const utf16 = raw[0] === 0xff && raw[1] === 0xfe;
  const text = (utf16 ? raw.toString('utf16le') : raw.toString('utf8')).replace(/^\uFEFF/, '');
  for (const line of text.split(/\r?\n/)) {
    const m = /^\s*(?:export\s+)?([A-Za-z0-9_]+)\s*=\s*(.*)$/.exec(line);
    if (!m) continue;
    let value = m[2].trim();
    if (/^(["']).*\1$/.test(value)) value = value.slice(1, -1);
    else value = value.replace(/\s+#.*$/, '');
    if (value && !process.env[m[1]]?.trim()) process.env[m[1]] = value;
  }
  if (utf16) console.warn('Note: server/.env is saved as UTF-16; save it as UTF-8 so the server can read it too.');
})();

const dry = process.argv.includes('--dry');
const force = process.argv.includes('--force');
const need = (k: string) => {
  const v = process.env[k]?.trim();
  if (!v) {
    const r2 = Object.keys(process.env).filter((x) => x.toUpperCase().includes('R2'));
    console.error(`Missing ${k} in server/.env`);
    console.error(`R2 settings found: ${r2.length ? r2.map((x) => `${x}${process.env[x]?.trim() ? '' : ' (empty)'}`).join(', ') : 'none'}`);
    process.exit(1);
  }
  return v;
};
const bucket = process.env.R2_BUCKET?.trim() && !process.env.R2_BUCKET_NAME?.trim()
  ? process.env.R2_BUCKET.trim()
  : need('R2_BUCKET_NAME');
const prefix = (process.env.R2_APP_PREFIX?.trim() || 'ielts_app_phone_version').replace(/^\/+|\/+$/g, '');
const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${need('R2_ACCOUNT_ID')}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: need('R2_ACCESS_KEY_ID'), secretAccessKey: need('R2_SECRET_ACCESS_KEY') },
});

interface Job {
  file: string;
  key: string;
  size: number;
}

function jobs(): Job[] {
  const out: Job[] = [];
  for (const [dir, folder] of MAP) {
    const abs = path.join(ROOT, dir);
    let names: string[];
    try {
      names = readdirSync(abs);
    } catch {
      console.warn(`  (skipped ${dir}: not found)`);
      continue;
    }
    for (const name of names.sort()) {
      const file = path.join(abs, name);
      const st = statSync(file);
      const ext = name.split('.').pop()?.toLowerCase() ?? '';
      if (!st.isFile() || !TYPES[ext]) continue;
      out.push({ file, key: `${prefix}/${folder}/${name}`, size: st.size });
    }
  }
  return out;
}

async function remoteSize(key: string): Promise<number | null> {
  try {
    const r = await s3.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));
    return r.ContentLength ?? null;
  } catch (e) {
    const status = (e as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode;
    if (status === 404) return null;
    throw e;
  }
}

async function main() {
  const list = jobs();
  const total = list.reduce((a, j) => a + j.size, 0);
  console.log(`${list.length} files, ${(total / 1e6).toFixed(1)} MB -> r2://${bucket}/${prefix}/`);
  let uploaded = 0;
  let skipped = 0;
  let bytes = 0;
  let next = 0;
  const failed: string[] = [];
  async function worker() {
    while (next < list.length) {
      const j = list[next++];
      try {
        if (!force && (await remoteSize(j.key)) === j.size) {
          skipped++;
          continue;
        }
        if (dry) {
          console.log(`  would upload ${j.key} (${(j.size / 1e3).toFixed(0)} KB)`);
          uploaded++;
          continue;
        }
        const ext = j.key.split('.').pop()!.toLowerCase();
        await s3.send(
          new PutObjectCommand({
            Bucket: bucket,
            Key: j.key,
            Body: readFileSync(j.file),
            ContentType: TYPES[ext],
            CacheControl: 'public, max-age=86400',
          }),
        );
        uploaded++;
        bytes += j.size;
        console.log(`  ✓ ${j.key}`);
      } catch (e) {
        failed.push(j.key);
        console.error(`  ✗ ${j.key}: ${(e as Error).message}`);
      }
    }
  }
  await Promise.all(Array.from({ length: 6 }, worker));
  console.log(
    `\n${dry ? 'Would upload' : 'Uploaded'} ${uploaded} (${(bytes / 1e6).toFixed(1)} MB), ` +
      `${skipped} already there, ${failed.length} failed.`,
  );
  if (failed.length) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
