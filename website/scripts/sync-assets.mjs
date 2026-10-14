// Copies the app's images and videos into public/ so the website shows the
// very same Nexi poses, logo and module videos as the app.
//
//   npm run sync-assets        (run again after the app's assets change)

import { copyFileSync, existsSync, mkdirSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const app = path.resolve(here, '..', '..', 'assets');
const pub = path.resolve(here, '..', 'public');

const jobs = [
  { from: 'mascot', to: 'mascot', match: (f) => f.endsWith('.png') },
  { from: 'branding', to: 'branding', match: (f) => /^(ielts-ai-|app_icon\.png$)/.test(f) },
  { from: 'videos', to: 'videos', match: (f) => f.endsWith('.mp4') },
];

let copied = 0;
for (const job of jobs) {
  const src = path.join(app, job.from);
  if (!existsSync(src)) {
    console.warn(`skip: ${src} not found`);
    continue;
  }
  const dest = path.join(pub, job.to);
  mkdirSync(dest, { recursive: true });
  for (const f of readdirSync(src)) {
    if (!job.match(f)) continue;
    copyFileSync(path.join(src, f), path.join(dest, f));
    copied++;
  }
}
console.log(`copied ${copied} files into public/`);
