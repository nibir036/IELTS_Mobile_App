// Google Play: one-time Pro passes (in-app products). The server checks every
// purchase token with the Google Play Developer API using a service account,
// then consumes it (so the pass can be bought again later). Consuming also
// acknowledges it; an unacknowledged purchase is refunded by Google after 3 days.
//
//   GOOGLE_PLAY_PACKAGE            com.nexted.ieltsai
//   GOOGLE_PLAY_SERVICE_ACCOUNT    the service account's JSON key (raw or base64)

import { createSign } from 'node:crypto';
import { env } from '../../env';
import { HttpError } from '../http';

const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
}

function account(): ServiceAccount {
  const raw = env.googlePlayServiceAccount.trim();
  if (!raw) throw new HttpError(503, 'Google Play purchases are not set up on the server yet.', 'billing_not_configured');
  const text = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
  const sa = JSON.parse(text) as ServiceAccount;
  if (!sa.client_email || !sa.private_key) throw new HttpError(503, 'The Google Play service account key is incomplete.', 'billing_not_configured');
  return sa;
}

const b64url = (b: Buffer | string) => Buffer.from(b).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

let token: { value: string; until: number } | null = null;

/** OAuth access token for the service account (JWT bearer grant), cached. */
async function accessToken(): Promise<string> {
  if (token && Date.now() < token.until) return token.value;
  const sa = account();
  const now = Math.floor(Date.now() / 1000);
  const aud = sa.token_uri || 'https://oauth2.googleapis.com/token';
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({ iss: sa.client_email, scope: SCOPE, aud, iat: now, exp: now + 3600 }));
  const sig = createSign('RSA-SHA256').update(`${head}.${claims}`).sign(sa.private_key);
  const res = await fetch(aud, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${head}.${claims}.${b64url(sig)}` }),
  });
  const data = (await res.json().catch(() => ({}))) as { access_token?: string; expires_in?: number };
  if (!res.ok || !data.access_token) throw new HttpError(502, 'Could not reach Google Play to check the purchase.', 'play_auth_failed');
  token = { value: data.access_token, until: Date.now() + Math.max(60, (data.expires_in ?? 3600) - 120) * 1000 };
  return token.value;
}

export interface ProductPurchase {
  /** 0 purchased · 1 cancelled · 2 pending */
  purchaseState?: number;
  /** 0 yet to be consumed · 1 consumed */
  consumptionState?: number;
  /** 0 yet to be acknowledged · 1 acknowledged */
  acknowledgementState?: number;
  orderId?: string;
  purchaseTimeMillis?: string;
  obfuscatedExternalAccountId?: string;
  regionCode?: string;
}

const url = (productId: string, purchaseToken: string, action = '') =>
  `${API}/${encodeURIComponent(env.googlePlayPackage)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}${action}`;

/** The purchase as Google sees it (null when the token is unknown). */
export async function getProductPurchase(productId: string, purchaseToken: string): Promise<ProductPurchase | null> {
  const res = await fetch(url(productId, purchaseToken), { headers: { Authorization: `Bearer ${await accessToken()}` } });
  if (res.status === 404 || res.status === 400 || res.status === 410) return null;
  if (!res.ok) throw new HttpError(502, 'Google Play could not check this purchase right now. Please try again.', 'play_check_failed');
  return (await res.json()) as ProductPurchase;
}

/** Consumes (and so acknowledges) the purchase. */
export async function consumePurchase(productId: string, purchaseToken: string): Promise<void> {
  const res = await fetch(url(productId, purchaseToken, ':consume'), {
    method: 'POST',
    headers: { Authorization: `Bearer ${await accessToken()}` },
  });
  if (!res.ok && res.status !== 204) {
    console.error('[billing] consume failed', res.status, await res.text().catch(() => ''));
  }
}
