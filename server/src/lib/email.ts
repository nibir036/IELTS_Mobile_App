// Email through Brevo's transactional API (https://api.brevo.com/v3/smtp/email).
// EMAIL_PROVIDER=console (the default outside production) prints the message
// in the server log instead of sending it, like SMS_PROVIDER=console.
//
//   POST https://api.brevo.com/v3/smtp/email
//   headers: api-key: <BREVO_API_KEY>
//   body: {sender:{name,email}, to:[{email}], subject, textContent, htmlContent}
//   success: 201 {"messageId": "..."}

import { env } from '../env';
import { HttpError } from './http';

const SEND_URL = 'https://api.brevo.com/v3/smtp/email';

/** Lower-case, trimmed; '' when it is not a plausible address. */
export function normalizeEmail(input: unknown): string {
  const e = String(input ?? '').trim().toLowerCase();
  return isValidEmail(e) ? e : '';
}

export function isValidEmail(e: string): boolean {
  return e.length <= 200 && /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e);
}

const escapeHtml = (t: string) =>
  t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export async function sendEmail(to: string, subject: string, text: string, html?: string): Promise<void> {
  if (env.emailProvider !== 'brevo') {
    console.log(`[email:console] to ${to}: ${subject}\n${text}`);
    return;
  }
  if (!env.brevoApiKey || !env.emailFrom) {
    throw new HttpError(500, 'Email is not configured on the server.', 'email_not_configured');
  }
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 15_000);
  try {
    const res = await fetch(SEND_URL, {
      method: 'POST',
      headers: { 'api-key': env.brevoApiKey, 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        sender: { name: env.emailFromName, email: env.emailFrom },
        to: [{ email: to }],
        subject,
        textContent: text,
        htmlContent: html ?? `<p>${escapeHtml(text).replace(/\n/g, '<br>')}</p>`,
      }),
      signal: ctrl.signal,
    });
    if (!res.ok) {
      const data = await res.json().catch(() => null);
      console.error('[email] Brevo failed:', res.status, data);
      throw new HttpError(502, 'Could not send the email right now. Please try again shortly.', 'email_failed');
    }
  } catch (e) {
    if (e instanceof HttpError) throw e;
    console.error('[email] Brevo failed:', e);
    throw new HttpError(502, 'Could not send the email right now. Please try again shortly.', 'email_failed');
  } finally {
    clearTimeout(timer);
  }
}

/** The 6-digit verification code, as a short branded email. */
export async function sendCodeEmail(to: string, code: string, purpose: 'signup' | 'reset'): Promise<void> {
  const brand = env.emailFromName;
  const what = purpose === 'reset' ? 'reset your password' : 'finish creating your account';
  const subject = `${code} is your ${brand} verification code`;
  const text =
    `Your ${brand} verification code is ${code}.\n\n` +
    `Enter it in the app to ${what}. It expires in 5 minutes.\n\n` +
    `If you did not ask for this code, you can ignore this email.`;
  const html =
    `<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#151515">` +
    `<p style="font-size:15px;margin:0 0 16px">Your ${escapeHtml(brand)} verification code is</p>` +
    `<p style="font-size:32px;font-weight:700;letter-spacing:6px;margin:0 0 16px">${code}</p>` +
    `<p style="font-size:14px;margin:0 0 8px">Enter it in the app to ${what}. It expires in 5 minutes.</p>` +
    `<p style="font-size:12px;color:#666;margin:16px 0 0">If you did not ask for this code, you can ignore this email.</p>` +
    `</div>`;
  await sendEmail(to, subject, text, html);
}
