// Loads the app's content files into the content_packs table (only packs
// whose JSON changed are written). Runs on every container start, so a push
// with edited content reaches the app without a new release.
//
//   npx tsx scripts/load-packs.ts        (locally: npx tsx --env-file=.env scripts/load-packs.ts)

import { prisma } from '../src/db';
import { loadPacks } from '../src/lib/packs';

async function main() {
  console.log('Content packs');
  const r = await loadPacks(prisma);
  console.log(`  ${r.written} written, ${r.unchanged} unchanged, ${r.removed} removed`);
  if (r.missing.length) console.warn(`  missing files (old packs kept): ${r.missing.join(', ')}`);
}

main()
  .catch((e) => {
    console.error('[packs] failed:', e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
