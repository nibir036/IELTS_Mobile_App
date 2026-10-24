// All settings come from server/.env (loaded with `tsx --env-file=.env`).
// See .env.example for what each one does.

function str(name: string, fallback = ''): string {
  const v = process.env[name];
  return v === undefined || v === '' ? fallback : v;
}

function num(name: string, fallback: number): number {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && process.env[name] !== '' ? v : fallback;
}

function list(name: string, fallback: string): string[] {
  return str(name, fallback)
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

export const env = {
  nodeEnv: str('NODE_ENV', 'development'),
  get isProd() {
    return this.nodeEnv === 'production';
  },
  port: num('PORT', 4000),
  host: str('HOST', '0.0.0.0'),

  /** Signs access tokens, OTP hashes and verification proofs. */
  authSecret: str('AUTH_SECRET'),
  accessTokenMinutes: num('ACCESS_TOKEN_MINUTES', 60),
  refreshTokenDays: num('REFRESH_TOKEN_DAYS', 60),

  // OTP / SMS (Alpha SMS BD, same gateway as the website)
  smsProvider: str('SMS_PROVIDER', 'console'), // 'alpha' | 'console'
  alphaSmsApiKey: str('ALPHA_SMS_API_KEY'),
  smsBrand: str('SMS_BRAND', 'IELTS AI by nextED'),

  // OpenRouter (writing grading, rewrite, speaking partner chat)
  openrouterApiKey: str('OPENROUTER_API_KEY'),
  openrouterBaseUrl: str('OPENROUTER_BASE_URL', 'https://openrouter.ai/api/v1').replace(/\/$/, ''),
  openrouterWritingModel: str('OPENROUTER_WRITING_MODEL', 'openrouter/free'),
  openrouterChatModel: str('OPENROUTER_CHAT_MODEL', 'openrouter/free'),
  openrouterFallbacks: list('OPENROUTER_MODEL_FALLBACKS', 'openrouter/free'),
  openrouterReasoningEffort: str('OPENROUTER_REASONING_EFFORT', 'low'),
  appUrl: str('APP_URL', 'https://ieltsai.nexted.app'),

  // nextED AI service (FastAPI, the `nexted-ai` project): the study-abroad AI
  // Counsellor, Course Finding and Scholarship Finding. Empty = use the
  // built-in Gemini versions. NEXTED_AI_TOKEN = that service's SERVICE_TOKEN.
  nextedAiUrl: str('NEXTED_AI_URL'),
  nextedAiToken: str('NEXTED_AI_TOKEN'),
  nextedAiTimeoutMs: num('NEXTED_AI_TIMEOUT_SECONDS', 150) * 1000,

  // Writing grading provider: 'gemini' (as on the website) or 'openrouter'.
  // Empty = Gemini when GEMINI_API_KEY is set, otherwise OpenRouter.
  writingProvider: str('WRITING_PROVIDER'),
  geminiApiKey: str('GEMINI_API_KEY'),
  geminiWritingModel: str('GEMINI_WRITING_MODEL', 'gemini-3.6-flash'),
  /** Study plan AI (weekly notes, task reasons): 'pro' (Pro accounts only) | 'off'. */
  planAi: str('PLAN_AI', 'pro').toLowerCase(),
  /** Model for the study plan; empty = the writing model. */
  geminiPlanModel: str('GEMINI_PLAN_MODEL'),
  get useGeminiForWriting() {
    const p = this.writingProvider.toLowerCase();
    return p === 'gemini' || (p !== 'openrouter' && Boolean(this.geminiApiKey));
  },

  // Speaking evaluation service (NextED_IELTS_Speaking, FastAPI)
  speakingApiBaseUrl: str('SPEAKING_API_BASE_URL', 'http://localhost:8000').replace(/\/$/, ''),
  speakingApiKey: str('SPEAKING_API_KEY'),

  // Cloudflare R2 (recordings, profile photos, voice messages)
  r2AccountId: str('R2_ACCOUNT_ID'),
  r2AccessKeyId: str('R2_ACCESS_KEY_ID'),
  r2SecretAccessKey: str('R2_SECRET_ACCESS_KEY'),
  r2Bucket: str('R2_BUCKET_NAME') || str('R2_BUCKET'),
  /** Top folder of everything the phone app stores in the bucket. */
  r2Prefix: str('R2_APP_PREFIX', 'ielts_app_phone_version').replace(/^\/+|\/+$/g, ''),
  get r2Configured() {
    return Boolean(this.r2AccountId && this.r2AccessKeyId && this.r2SecretAccessKey && this.r2Bucket);
  },

  // Payments. Website: bKash Tokenized Checkout. App: Google Play one-time passes.
  /** The website's address: bKash returns the student there (callback URLs must start with it). */
  websiteUrl: str('WEBSITE_URL', 'https://ielts.nexted.app').replace(/\/$/, ''),
  /**
   * SMS sent once, right after an account is created. "{site}" becomes the
   * website's address without https:// ; WELCOME_SMS=off sends nothing.
   */
  welcomeSms: str('WELCOME_SMS', 'Welcome to IELTS AI by nextED. Subscribe from our website to avail a 40% discount: {site}'),
  bkashBaseUrl: str('BKASH_BASE_URL', 'https://tokenized.sandbox.bka.sh/v1.2.0-beta').replace(/\/$/, ''),
  bkashAppKey: str('BKASH_APP_KEY'),
  bkashAppSecret: str('BKASH_APP_SECRET'),
  bkashUsername: str('BKASH_USERNAME'),
  bkashPassword: str('BKASH_PASSWORD'),
  googlePlayPackage: str('GOOGLE_PLAY_PACKAGE', 'com.nexted.app'),
  /** Service account JSON key (raw or base64) with access to the Play Console. */
  googlePlayServiceAccount: str('GOOGLE_PLAY_SERVICE_ACCOUNT'),
  /** Shared secret in the Pub/Sub push URL for Play notifications (…/rtdn?token=…). */
  googlePlayRtdnToken: str('GOOGLE_PLAY_RTDN_TOKEN'),
  /** Shared secret for the ad-banner admin (X-Admin-Token header). Empty = admin off. */
  adminToken: str('ADMIN_TOKEN'),
  /** Hours before a website pass ends that the student is asked to confirm the renewal. */
  renewalNoticeHours: num('RENEWAL_NOTICE_HOURS', 24),

  /** Largest JSON body accepted (speaking audio is sent as base64). */
  maxBodyMb: num('MAX_BODY_MB', 40),
};

export function assertEnv(): void {
  const missing: string[] = [];
  if (!process.env.DATABASE_URL) missing.push('DATABASE_URL');
  if (!env.authSecret || env.authSecret.length < 32) missing.push('AUTH_SECRET (32+ random characters)');
  if (missing.length) {
    throw new Error(`Missing settings in server/.env: ${missing.join(', ')}`);
  }
}
