// Content packs: the JSON files the app (and the website) read, stored in the
// database so content can change without a new app release.
//
//   ui                     assets/demo/demo_data.json          (public)
//   bank.<name>            assets/content/<name>_bank.json
//   guide.<module>         assets/content/<module>_guide.json
//   course.<module>        assets/content/lessons/<module>.json
//   l10n.index             assets/content/l10n/index.json       (public)
//   l10n.<lang>.<module>   assets/content/l10n/<lang>/<module>.json
//
// loadPacks() runs on every server start (scripts/load-packs.ts) and in the
// seed: it reads those files, and writes a pack only when its JSON changed.
// The app keeps a copy of each pack and downloads it again only when the
// version (a hash of the JSON) differs. Keep the list in step with the app's
// lib/app/data/content_packs.dart.

import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { gzipSync } from 'node:zlib';
import type { PrismaClient } from '@prisma/client';

/** Repository root (…/server/src/lib → …). */
const ROOT = path.resolve(__dirname, '..', '..', '..');

export interface PackSource {
  key: string;
  /** Path from the repository root. */
  file: string;
  public: boolean;
}

export const BANKS = ['reading', 'listening', 'writing', 'speaking', 'resources', 'tests', 'sentence'] as const;
export const GUIDES = ['reading', 'writing', 'speaking', 'grammar', 'listening', 'vocab'] as const;
export const COURSES = ['writing', 'speaking', 'reading', 'listening', 'grammar', 'vocab'] as const;

/** Every pack and the file it comes from. */
export function packSources(root = ROOT): PackSource[] {
  const out: PackSource[] = [{ key: 'ui', file: 'assets/demo/demo_data.json', public: true }];
  for (const b of BANKS) out.push({ key: `bank.${b}`, file: `assets/content/${b}_bank.json`, public: false });
  for (const g of GUIDES) out.push({ key: `guide.${g}`, file: `assets/content/${g}_guide.json`, public: false });
  for (const c of COURSES) out.push({ key: `course.${c}`, file: `assets/content/lessons/${c}.json`, public: false });
  const indexFile = 'assets/content/l10n/index.json';
  out.push({ key: 'l10n.index', file: indexFile, public: true });
  const indexPath = path.join(root, indexFile);
  if (existsSync(indexPath)) {
    const index = JSON.parse(readFileSync(indexPath, 'utf8')) as Record<string, unknown>;
    for (const [module, langs] of Object.entries(index)) {
      if (!Array.isArray(langs)) continue;
      for (const lang of langs) {
        const l = String(lang);
        if (!/^[a-z]{2,3}$/.test(l) || !/^[a-z]+$/.test(module)) continue;
        out.push({ key: `l10n.${l}.${module}`, file: `assets/content/l10n/${l}/${module}.json`, public: false });
      }
    }
  }
  return out;
}

export interface BuiltPack {
  key: string;
  version: string;
  public: boolean;
  bytes: number;
  gzBytes: number;
  gz: Buffer;
}

/** Reads one pack file: minified JSON, gzipped, versioned by its hash. */
export function buildPack(src: PackSource, root = ROOT): BuiltPack {
  const text = readFileSync(path.join(root, src.file), 'utf8');
  // Minified, so line endings / indentation never change the version.
  const json = Buffer.from(JSON.stringify(JSON.parse(text)), 'utf8');
  const gz = gzipSync(json, { level: 9 });
  return {
    key: src.key,
    version: createHash('sha256').update(json).digest('hex').slice(0, 16),
    public: src.public,
    bytes: json.length,
    gzBytes: gz.length,
    gz,
  };
}

/**
 * Writes changed packs to the database and removes packs whose file is gone.
 * Returns how many were written / unchanged / removed.
 */
export async function loadPacks(
  db: PrismaClient,
  opts: { root?: string; log?: (line: string) => void } = {},
): Promise<{ written: number; unchanged: number; removed: number; missing: string[] }> {
  const root = opts.root ?? ROOT;
  const log = opts.log ?? ((l: string) => console.log(l));
  const existing = new Map(
    ((await db.contentPack.findMany({ select: { key: true, version: true, public: true } })) as Array<{
      key: string;
      version: string;
      public: boolean;
    }>).map((p) => [p.key, p]),
  );
  let written = 0;
  let unchanged = 0;
  const missing: string[] = [];
  const keys = new Set<string>();
  for (const src of packSources(root)) {
    if (!existsSync(path.join(root, src.file))) {
      missing.push(src.file);
      continue;
    }
    keys.add(src.key);
    let pack: BuiltPack;
    try {
      pack = buildPack(src, root);
    } catch (e) {
      log(`  pack ${src.key}: ${src.file} is not valid JSON (${e instanceof Error ? e.message : e}), kept the old one`);
      continue;
    }
    const old = existing.get(pack.key);
    if (old && old.version === pack.version && old.public === pack.public) {
      unchanged++;
      continue;
    }
    await db.contentPack.upsert({ where: { key: pack.key }, create: pack, update: pack });
    written++;
    log(`  pack ${pack.key.padEnd(22)} ${pack.version}  ${(pack.gzBytes / 1024).toFixed(0)} KB gz`);
  }
  // A missing file keeps its pack (a bad checkout must not empty the app);
  // only keys that left the list are removed.
  const listed = new Set(packSources(root).map((s) => s.key));
  const stale = [...existing.keys()].filter((k) => !listed.has(k));
  if (stale.length) await db.contentPack.deleteMany({ where: { key: { in: stale } } });
  return { written, unchanged, removed: stale.length, missing };
}

// ── serving ─────────────────────────────────────────────────────────────────

export interface PackInfo {
  key: string;
  version: string;
  public: boolean;
  bytes: number;
  gzBytes: number;
}

const MANIFEST_TTL_MS = 30_000;
let manifest: { at: number; packs: PackInfo[] } | null = null;
/** Gzipped bodies by key, for the version they were read at. */
const bodies = new Map<string, { version: string; gz: Buffer }>();

/** The pack list (cached for a few seconds). */
export async function packManifest(db: PrismaClient): Promise<PackInfo[]> {
  const now = Date.now();
  if (manifest && now - manifest.at < MANIFEST_TTL_MS) return manifest.packs;
  const packs = (await db.contentPack.findMany({
    select: { key: true, version: true, public: true, bytes: true, gzBytes: true },
    orderBy: { key: 'asc' },
  })) as PackInfo[];
  manifest = { at: now, packs };
  return packs;
}

/** One pack's gzipped JSON (cached in memory per version), or null. */
export async function packBody(db: PrismaClient, key: string): Promise<{ info: PackInfo; gz: Buffer } | null> {
  const info = (await packManifest(db)).find((p) => p.key === key);
  if (!info) return null;
  const hit = bodies.get(key);
  if (hit && hit.version === info.version) return { info, gz: hit.gz };
  const row = (await db.contentPack.findUnique({ where: { key }, select: { version: true, gz: true } })) as {
    version: string;
    gz: Uint8Array;
  } | null;
  if (!row) return null;
  const gz = Buffer.from(row.gz);
  bodies.set(key, { version: row.version, gz });
  return { info: { ...info, version: row.version }, gz };
}

/** Forget cached packs (after loadPacks in the same process). */
export function clearPackCache(): void {
  manifest = null;
  bodies.clear();
}
