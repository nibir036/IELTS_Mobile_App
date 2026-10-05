// IELTS AI by nextED - API server for the Flutter app.
//
//   npm run dev     (reloads on change)     npm start
//
// Settings: server/.env (see .env.example). Database: Prisma (prisma/schema.prisma).

import { createServer } from 'node:http';
import { prisma } from './db';
import { assertEnv, env } from './env';
import { HttpError, readBody, Router, sendJson, type Ctx } from './lib/http';
import { registerAiRoutes } from './routes/ai';
import { registerAuthRoutes } from './routes/auth';
import { registerContentRoutes } from './routes/content';
import { registerFileRoutes } from './routes/files';
import { registerMeRoutes } from './routes/me';
import { registerPlanRoutes } from './routes/plan';
import { registerProgressRoutes } from './routes/progress';

export function buildRouter(): Router {
  const r = new Router();
  r.get('/health', async () => {
    await prisma.$queryRaw`SELECT 1`;
    return { ok: true, time: new Date().toISOString() };
  });
  registerAuthRoutes(r);
  registerMeRoutes(r);
  registerContentRoutes(r);
  registerProgressRoutes(r);
  registerPlanRoutes(r);
  registerAiRoutes(r);
  registerFileRoutes(r);
  return r;
}

export function createApp(router = buildRouter()) {
  return createServer(async (req, res) => {
    const started = Date.now();
    const url = new URL(req.url || '/', 'http://localhost');
    const method = (req.method || 'GET').toUpperCase();

    // CORS: the app doesn't need it, but it lets you try the API from a browser.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
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
        ip: String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim(),
      };
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
  });
  const stop = async () => {
    server.close();
    await prisma.$disconnect();
    process.exit(0);
  };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}
