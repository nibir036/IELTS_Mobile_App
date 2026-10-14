// Pro passes (7 / 45 / 100 days) and their prices, read from the same content
// the app and website show (ui pack → home.plans.passes), so a price change
// is one edit to assets/demo/demo_data.json. The website (bKash) charges
// `price`; the app (Google Play) sells `playProductId`, priced in Play Console
// at `app.price`.

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { gunzipSync } from 'node:zlib';
import { prisma } from '../../db';
import { packBody } from '../packs';

export interface Pass {
  id: string;
  name: string;
  days: number;
  /** Website price (BDT). */
  webPrice: number;
  /** App price (BDT), as set in Play Console. */
  appPrice: number;
  playProductId: string;
}

type Raw = Record<string, unknown>;
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : Number(v) || 0);

function parse(ui: Raw): Pass[] {
  const plans = (((ui.home ?? {}) as Raw).plans ?? {}) as Raw;
  const list = Array.isArray(plans.passes) ? (plans.passes as Raw[]) : [];
  return list
    .map((p) => {
      const app = (p.app ?? {}) as Raw;
      return {
        id: String(p.id ?? ''),
        name: String(p.name ?? ''),
        days: num(p.days),
        webPrice: num(p.price),
        appPrice: num(app.price ?? p.price),
        playProductId: String(p.playProductId ?? ''),
      };
    })
    .filter((p) => p.id && p.days > 0)
    .sort((a, b) => a.days - b.days);
}

let cache: { version: string; passes: Pass[] } | null = null;

/** The passes, shortest first (from the database's ui pack; the repo file as a fallback). */
export async function passes(): Promise<Pass[]> {
  try {
    const body = await packBody(prisma, 'ui');
    if (body) {
      if (cache?.version === body.info.version) return cache.passes;
      const list = parse(JSON.parse(gunzipSync(body.gz).toString('utf8')) as Raw);
      if (list.length) {
        cache = { version: body.info.version, passes: list };
        return list;
      }
    }
  } catch {
    // fall through to the file
  }
  const file = path.resolve(__dirname, '..', '..', '..', '..', 'assets', 'demo', 'demo_data.json');
  return existsSync(file) ? parse(JSON.parse(readFileSync(file, 'utf8')) as Raw) : [];
}

export async function passById(id: string): Promise<Pass | null> {
  return (await passes()).find((p) => p.id === id) ?? null;
}

export async function passByProduct(productId: string): Promise<Pass | null> {
  return (await passes()).find((p) => p.playProductId === productId) ?? null;
}
