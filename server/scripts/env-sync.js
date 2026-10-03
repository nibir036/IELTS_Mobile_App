// Adds any setting from .env.example that is missing in .env (keeps your
// existing values untouched) and generates AUTH_SECRET if it is empty.
// Usage: node scripts/env-sync.js
const fs = require('node:fs');
const crypto = require('node:crypto');
const path = require('node:path');

const dir = path.join(__dirname, '..');
const envPath = path.join(dir, '.env');
const example = fs.readFileSync(path.join(dir, '.env.example'), 'utf8').split(/\r?\n/);
let current = fs.existsSync(envPath) ? fs.readFileSync(envPath, 'utf8') : '';
const has = (key) => new RegExp(`^\\s*${key}\\s*=`, 'm').test(current);

const added = [];
for (const line of example) {
  const m = /^([A-Z0-9_]+)=/.exec(line);
  if (!m || has(m[1])) continue;
  added.push(line);
}
if (added.length) {
  current = current.replace(/\s*$/, '\n') + '\n# Added by scripts/env-sync.js\n' + added.join('\n') + '\n';
}
const secret = /^\s*AUTH_SECRET\s*=\s*"?([^"\r\n]*)"?/m.exec(current);
if (!secret || secret[1].trim().length < 32) {
  const value = crypto.randomBytes(48).toString('base64url');
  current = secret ? current.replace(/^\s*AUTH_SECRET\s*=.*$/m, `AUTH_SECRET=${value}`) : `${current}AUTH_SECRET=${value}\n`;
  console.log('Generated AUTH_SECRET.');
}
fs.writeFileSync(envPath, current);
console.log(added.length ? `Added to .env: ${added.map((l) => l.split('=')[0]).join(', ')}` : '.env already has every setting.');
