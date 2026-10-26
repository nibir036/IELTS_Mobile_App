// IELTS AI by nextED - API server for the Flutter app.
//
//   npm run dev     (reloads on change)     npm start
//
// Settings: server/.env (see .env.example). Database: Prisma (prisma/schema.prisma).

import { createServer } from 'node:http';
import { prisma } from './db';
import { assertEnv, env } from './env';
import { assertSessionOpen } from './lib/devices';
import { HttpError, readBody, Router, sendJson, type Ctx } from './lib/http';
import { verifyAccessToken } from './lib/tokens';
import { registerAiRoutes } from './routes/ai';
import { registerAuthRoutes } from './routes/auth';
import { registerBillingRoutes } from './routes/billing';
import { remindRenewals } from './lib/billing/subscriptions';
import { registerContentRoutes } from './routes/content';
import { registerFileRoutes } from './routes/files';
import { registerMeRoutes } from './routes/me';
import { aiHealth, nextedAiEnabled } from './lib/nexted_ai';
import { registerNextedRoutes } from './routes/nexted';
import { registerPlanRoutes } from './routes/plan';
import { registerProgressRoutes } from './routes/progress';
import { registerWebRoutes } from './routes/web';
import { registerBannerRoutes } from './routes/banners';

export function buildRouter(): Router {
  const r = new Router();
  r.get('/health', async () => {
    await prisma.$queryRaw`SELECT 1`;
    // Whether the study-abroad AI service answers (null = off or not running).
    const nextedAi = nextedAiEnabled() ? await aiHealth() : null;
    return { ok: true, time: new Date().toISOString(), nextedAi };
  });
  registerAuthRoutes(r);
  registerMeRoutes(r);
  registerContentRoutes(r);
  registerProgressRoutes(r);
  registerPlanRoutes(r);
  registerAiRoutes(r);
  registerFileRoutes(r);
  registerBillingRoutes(r);
  registerNextedRoutes(r);
  // Privacy, terms and account deletion as web pages (Google Play links).
  registerWebRoutes(r);
  // Ad banners on the home pages, and their admin.
  registerBannerRoutes(r);
  return r;
}

export function createApp(router = buildRouter()) {
  return createServer(async (req, res) => {
    const started = Date.now();
    const url = new URL(req.url || '/', 'http://localhost');
    const method = (req.method || 'GET').toUpperCase();

    // CORS: the app doesn't need it, but it lets you try the API from a browser.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, X-App-Key, X-Device-Id, X-Device-Name, X-Device-Platform, X-Client, X-Admin-Token',
    );
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    if (method === 'OPTIONS') {
      res.writeHead(204).end();
      return;
    }

    let status = 200;
    try {
      const found = router.match(method, url.pathname);
      if (found === null) throw new HttpError(404, 'Not found.', 'not_found');
      if (found === 'method') throw new HttpError(405, 'Method not allowed.', 'method_not_allowed');

      const ctx: Ctx = {
        req,
        res,
        method,
        path: url.pathname,
        query: url.searchParams,
        params: found.params,
        body: {},
        // The proxy (Coolify/Traefik) appends the real client address as the
        // LAST X-Forwarded-For entry; earlier entries are whatever the client sent.
        ip: (String(req.headers['x-forwarded-for'] || '').split(',').map((x) => x.trim()).filter(Boolean).pop() ||
          req.socket.remoteAddress ||
          ''),
      };
      // A signed-in call from a session that has ended (another device signed
      // in, this device was removed, logout) is refused straight away, not
      // only when the access token next expires.
      const auth = /^Bearer\s+(.+)$/i.exec(String(req.headers.authorization || ''));
      if (auth && !url.pathname.startsWith('/v1/auth/')) {
        const claims = verifyAccessToken(auth[1].trim());
        if (claims?.sid) await assertSessionOpen(claims.sid);
      }
      if (method !== 'GET' && method !== 'HEAD') {
        const buf = await readBody(req);
        const type = String(req.headers['content-type'] || '');
        if (type.includes('application/json')) {
          if (buf.length) {
            try {
              const parsed = JSON.parse(buf.toString('utf8'));
              ctx.body = parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
            } catch {
              throw new HttpError(400, 'Body is not valid JSON.', 'bad_json');
            }
          }
        } else if (buf.length) {
          ctx.raw = buf;
        }
      }
      const result = await found.handler(ctx);
      sendJson(res, 200, result ?? { ok: true });
    } catch (e) {
      if (e instanceof HttpError) {
        status = e.status;
        sendJson(res, e.status, { error: e.message, code: e.code ?? 'error', ...(e.extra ?? {}) });
      } else {
        status = 500;
        console.error(`[${method} ${url.pathname}]`, e);
        sendJson(res, 500, { error: 'Something went wrong on the server.', code: 'server_error' });
      }
    } finally {
      // A handler that answers itself (the /v1/media redirect) sets the code.
      if (res.headersSent && res.statusCode) status = res.statusCode;
      if (!env.isProd || status >= 500) {
        console.log(`${method} ${url.pathname} ${status} ${Date.now() - started}ms`);
      }
    }
  });
}

if (require.main === module) {
  assertEnv();
  const server = createApp();
  server.requestTimeout = 5 * 60_000;
  server.listen(env.port, env.host, () => {
    console.log(`IELTS AI API listening on http://${env.host === '0.0.0.0' ? 'localhost' : env.host}:${env.port}`);
    const writing = env.useGeminiForWriting
      ? env.geminiApiKey ? `Gemini (${env.geminiWritingModel})` : 'Gemini - GEMINI_API_KEY missing'
      : env.openrouterApiKey ? 'OpenRouter' : 'not configured';
    console.log(`  SMS: ${env.smsProvider} · R2: ${env.r2Configured ? 'on' : 'off'}`);
    console.log(`  Writing AI: ${writing} · partner chat: ${env.openrouterApiKey ? 'OpenRouter' : 'not configured'}`);
    console.log(`  Speaking: ${env.speakingApiBaseUrl} (${env.speakingApiKey ? 'key set' : 'SPEAKING_API_KEY missing'})`);
    console.log(`  Payments: bKash ${env.bkashAppKey ? 'on' : 'off'} · Google Play ${env.googlePlayServiceAccount ? 'on' : 'off'}`);
  });
  // Website passes ending soon with auto-renewal on: ask to confirm (hourly).
  const renewals = setInterval(() => {
    remindRenewals().catch((e) => console.error('[billing] renewal reminders failed', e));
  }, 60 * 60_000);
  renewals.unref();
  const stop = async () => {
    server.close();
    await prisma.$disconnect();
    process.exit(0);
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}
