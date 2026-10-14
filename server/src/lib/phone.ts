/** Stored phone format: 10 digits without 0 / +880 (1XXXXXXXXX). */
export function normalizePhone(input: string): string {
  let d = input.replace(/\D/g, '');
  if (d.startsWith('880')) d = d.slice(3);
  if (d.startsWith('0')) d = d.slice(1);
  return d;
}

export function isValidPhone(input: string): boolean {
  return /^1[3-9]\d{8}$/.test(normalizePhone(input));
}

/** 8+ characters with at least one number and one symbol (same as the app). */
export function isStrongPassword(p: string): boolean {
  return p.length >= 8 && /\d/.test(p) && /[^A-Za-z0-9]/.test(p);
}

/**
 * Shared Pro demo accounts sign in with "Demo 1" … "Demo 4" instead of a
 * phone number (stored as phone "demo1" … "demo4"; see scripts/demo-accounts.ts).
 * Returns that stored id, or null when [input] is not a demo login.
 */
export function demoLoginId(input: string): string | null {
  const m = /^\s*demo\s*([1-4])\s*$/i.exec(input ?? '');
  return m ? `demo${m[1]}` : null;
}
