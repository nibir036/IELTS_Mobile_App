// Alpha SMS BD (api.sms.net.bd) -- same gateway and number rules as the
// website. SMS_PROVIDER=console (default in development) prints the message
// in the server log instead of sending it.
//
//   POST https://api.sms.net.bd/sendsms  (form: api_key, msg, to)
//   success: {"error": 0, "msg": "...", "data": {"request_id": N}}
//   failure: {"error": <non-zero>, "msg": "..."}  (421 = recharge needed)

import { env } from '../env';
import { HttpError } from './http';

const SEND_URL = 'https://api.sms.net.bd/sendsms';

/** "+880 01712-345678" / "01712345678" / "1712345678" -> "8801712345678". */
export function toAlphaSmsNumber(rawPhone: string): string {
  let digits = rawPhone.replace(/[^\d]/g, '');
  if (digits.startsWith('880')) digits = digits.slice(3);
  digits = digits.replace(/^0+/, '');
  return `880${digits}`;
}

export async function sendSms(phone: string, message: string): Promise<void> {
  const to = toAlphaSmsNumber(phone);
  if (!/^8801\d{9}$/.test(to)) {
    throw new HttpError(400, 'Please use a Bangladeshi mobile number (+880).', 'invalid_phone');
  }
  if (env.smsProvider !== 'alpha') {
    console.log(`[sms:console] to ${to}: ${message}`);
    return;
  }
  if (!env.alphaSmsApiKey) throw new HttpError(500, 'SMS is not configured on the server.', 'sms_not_configured');

  const res = await fetch(SEND_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ api_key: env.alphaSmsApiKey, msg: message, to }),
  });
  const data = (await res.json().catch(() => null)) as { error: number; msg: string } | null;
  if (!data || data.error !== 0) {
    console.error('[sms] Alpha SMS failed:', res.status, data);
    throw new HttpError(502, 'Could not send the SMS right now. Please try again shortly.', 'sms_failed', {
      provider: data?.msg,
    });
  }
}
