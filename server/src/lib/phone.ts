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
