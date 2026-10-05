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

  // Writing grading provider: 'gemini' (as on the website) or 'openrouter'.
  // Empty = Gemini when GEMINI_API_KEY is set, otherwise OpenRouter.
  writingProvider: str('WRITING_PROVIDER'),
  geminiApiKey: str('GEMINI_API_KEY'),
  geminiWritingModel: str('GEMINI_WRITING_MODEL', 'gemini-3.6-flash'),
  /** Study plan AI (weekly notes, task reasons): 'all' | 'pro' | 'off'. */
  planAi: str('PLAN_AI', 'all').toLowerCase(),
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

  // Free plan: AI-graded tests allowed before upgrading (same as the website)
  freeWritingTests: num('FREE_WRITING_TESTS', 4),
  freeSpeakingTests: num('FREE_SPEAKING_TESTS', 4),

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
