// Uploads (R2), recordings, community rooms, public config.

import { randomUUID } from 'node:crypto';
import { prisma } from '../db';
import { badRequest, forbidden, HttpError, int, notFound, rateLimit, Router, s, type Ctx } from '../lib/http';
import { appKey, contentTypeFor, deleteObjects, isAllowedExt, MEDIA_FOLDERS, ownsKey, putObject, signedUrl } from '../lib/r2';
import { requireUser } from '../lib/users';

const MAX_UPLOAD_BYTES = 25 * 1024 * 1024;
const KINDS: Record<string, 'audio' | 'image'> = { recording: 'audio', voice: 'audio', photo: 'image' };

export function registerFileRoutes(r: Router): void {
  /**
   * Upload a file. Raw bytes (PUT, Content-Type = the file type) or JSON
   * {base64}. Query: ?kind=recording|voice|photo&ext=wav[&attemptId=&durationMs=]
   * -> {key, url (signed, 1 h), recordingId?}
   */
  const upload = async (ctx: Ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`upload:${userId}`, 120, 3600);
    const kind = s(ctx.query.get('kind'), 20) || 'recording';
    const type = KINDS[kind];
    if (!type) throw badRequest('kind must be recording, voice or photo.');
    const ext = (s(ctx.query.get('ext'), 5) || (type === 'audio' ? 'wav' : 'jpg')).toLowerCase();
    if (!isAllowedExt(ext, type)) throw badRequest(`.${ext} is not allowed for ${kind}.`);
    const bytes = ctx.raw && ctx.raw.length ? ctx.raw : Buffer.from(s(ctx.body.base64, 40_000_000), 'base64');
    if (!bytes.length) throw badRequest('Empty upload.');
    if (bytes.length > MAX_UPLOAD_BYTES) throw new HttpError(413, 'File is larger than 25 MB.', 'too_large');

    const key = appKey(`users/${userId}/${kind}/${new Date().toISOString().slice(0, 10)}/${randomUUID()}.${ext}`);
    await putObject(key, bytes, contentTypeFor(ext));
    let recordingId: string | undefined;
    if (kind === 'recording') {
      const attemptId = s(ctx.query.get('attemptId'), 80);
      const owned = attemptId
        ? await prisma.attempt.findFirst({ where: { id: attemptId, userId }, select: { id: true } })
        : null;
      const rec = await prisma.recording.create({
        data: {
          userId,
          attemptId: owned?.id ?? null,
          r2Key: key,
          format: ext,
          durationMs: int(ctx.query.get('durationMs'), 0, 0, 3_600_000),
          bytes: bytes.length,
        },
        select: { id: true },
      });
      recordingId = rec.id;
    }
    if (kind === 'photo') {
      const user = await prisma.user.findUnique({ where: { id: userId }, select: { profile: true } });
      const profile = { ...((user?.profile ?? {}) as Record<string, unknown>) };
      const old = typeof profile.photo === 'string' ? profile.photo : '';
      profile.photo = key;
      await prisma.user.update({ where: { id: userId }, data: { profile: profile as object } });
      if (ownsKey(userId, old) && old.includes('/photo/')) await deleteObjects([old]).catch(() => undefined);
    }
    return { key, url: await signedUrl(key), ...(recordingId ? { recordingId } : {}) };
  };
  r.put('/v1/uploads', upload);

  /**
   * App content media (listening audio, maps, writing / reading images) in
   * R2 under <prefix>/<folder>/<file>. Public, like the bundled assets were:
   * redirects to a signed R2 link, so the bucket itself stays private.
   * e.g. GET /v1/media/listening/audio/P1-FN.mp3
   */
  r.get('/v1/media/*', async (ctx) => {
    const key = ctx.params['*'];
    if (key.includes('..') || !MEDIA_FOLDERS.some((f) => key.startsWith(f) && key.length > f.length)) {
      throw notFound('No such media file.');
    }
    rateLimit(`media:${ctx.ip}`, 3000, 3600);
    // Signed from the start of the hour for 2 h: the same link all hour (so
    // phones and the browser can cache it), always valid for 1 h or more.
    const hour = 3600 * 1000;
    const start = new Date(Math.floor(Date.now() / hour) * hour);
    const url = await signedUrl(appKey(key), 7200, start);
    const fresh = Math.max(60, Math.floor((start.getTime() + hour - Date.now()) / 1000));
    ctx.res.writeHead(302, { Location: url, 'Cache-Control': `public, max-age=${fresh}` });
    ctx.res.end();
    return undefined;
  });
  r.post('/v1/uploads', upload);

  // Signed URL for one of your own files (valid 1 hour).
  r.get('/v1/uploads/*', async (ctx) => {
    const userId = requireUser(ctx);
    const key = ctx.params['*'];
    if (!ownsKey(userId, key)) {
      // Voice messages in community rooms are readable by every signed-in student.
      const msg = await prisma.roomMessage.findFirst({ where: { r2Key: key }, select: { id: true } });
      if (!msg) throw forbidden('Not your file.');
    }
    return { url: await signedUrl(key) };
  });

  r.get('/v1/recordings', async (ctx) => {
    const userId = requireUser(ctx);
    const rows = await prisma.recording.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: int(ctx.query.get('limit'), 50, 1, 200),
      include: { attempt: { select: { id: true, title: true, kind: true, band: true } } },
    });
    return {
      items: await Promise.all(
        rows.map(async (x) => ({
          id: x.id,
          key: x.r2Key,
          url: await signedUrl(x.r2Key).catch(() => null),
          format: x.format,
          durationMs: x.durationMs,
          bytes: x.bytes,
          createdAt: x.createdAt.toISOString(),
          attempt: x.attempt,
        })),
      ),
    };
  });

  r.delete('/v1/recordings/:id', async (ctx) => {
    const userId = requireUser(ctx);
    const rec = await prisma.recording.findUnique({ where: { id: ctx.params.id } });
    if (!rec || rec.userId !== userId) throw notFound('Recording not found.');
    await prisma.recording.delete({ where: { id: rec.id } });
    await deleteObjects([rec.r2Key]).catch((e) => console.error('[recordings] R2 delete failed', e));
    return { deleted: true };
  });

  // ── community ─────────────────────────────────────────────────────────────

  r.get('/v1/rooms', async (ctx) => {
    requireUser(ctx);
    const rooms = await prisma.room.findMany({ orderBy: [{ official: 'desc' }, { createdAt: 'asc' }] });
    const out: Record<string, unknown>[] = [];
    for (const room of rooms) {
      const last = await prisma.roomMessage.findFirst({
        where: { roomId: room.id },
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { id: true, name: true } } },
      });
      out.push({
        id: room.id,
        letter: room.letter,
        name: room.name,
        tone: room.tone,
        topic: room.topic,
        official: room.official,
        last: last
          ? { type: last.type, text: last.text ?? '', from: last.user?.name ?? 'AI partner', createdAt: last.createdAt.toISOString() }
          : null,
      });
    }
    return { items: out };
  });

  r.get('/v1/rooms/:id/messages', async (ctx) => {
    requireUser(ctx);
    const room = await prisma.room.findUnique({ where: { id: ctx.params.id }, select: { id: true } });
    if (!room) throw notFound('Room not found.');
    const after = ctx.query.get('after');
    const afterDate = after ? new Date(after) : null;
    const rows = await prisma.roomMessage.findMany({
      where: { roomId: room.id, ...(afterDate && !Number.isNaN(afterDate.getTime()) ? { createdAt: { gt: afterDate } } : {}) },
      orderBy: { createdAt: 'desc' },
      take: int(ctx.query.get('limit'), 50, 1, 200),
      include: { user: { select: { id: true, name: true } } },
    });
    return {
      items: rows.reverse().map((m) => ({
        id: m.id,
        type: m.type,
        text: m.text ?? '',
        key: m.r2Key ?? '',
        durationMs: m.durationMs ?? 0,
        user: m.user ? { id: m.user.id, name: m.user.name } : null,
        createdAt: m.createdAt.toISOString(),
      })),
    };
  });

  // {type: text|voice|image, text?, key? (from /v1/uploads), durationMs?}
  r.post('/v1/rooms/:id/messages', async (ctx) => {
    const userId = requireUser(ctx);
    rateLimit(`room:${userId}`, 30, 60);
    const room = await prisma.room.findUnique({ where: { id: ctx.params.id }, select: { id: true } });
    if (!room) throw notFound('Room not found.');
    const type = s(ctx.body.type, 10) || 'text';
    if (!['text', 'voice', 'image'].includes(type)) throw badRequest('type must be text, voice or image.');
    const text = s(ctx.body.text, 2000);
    const key = s(ctx.body.key, 300);
    if (type === 'text' && !text) throw badRequest('Message is empty.');
    if (type !== 'text' && !ownsKey(userId, key)) throw badRequest('Upload the file first (/v1/uploads).');
    const m = await prisma.roomMessage.create({
      data: {
        roomId: room.id,
        userId,
        type,
        text: text || null,
        r2Key: key || null,
        durationMs: type === 'voice' ? int(ctx.body.durationMs, 0, 0, 600_000) : null,
      },
      include: { user: { select: { id: true, name: true } } },
    });
    return {
      item: {
        id: m.id,
        type: m.type,
        text: m.text ?? '',
        key: m.r2Key ?? '',
        durationMs: m.durationMs ?? 0,
        user: m.user ? { id: m.user.id, name: m.user.name } : null,
        createdAt: m.createdAt.toISOString(),
      },
    };
  });

  // ── public config ─────────────────────────────────────────────────────────

  r.get('/v1/config', async () => {
    const [plans, planFeatures, certificates, appConfig, legal] = await Promise.all([
      prisma.plan.findMany({ orderBy: { sortOrder: 'asc' } }),
      prisma.planFeature.findMany({ orderBy: { sortOrder: 'asc' } }),
      prisma.certificateDefinition.findMany({ orderBy: { sortOrder: 'asc' } }),
      prisma.appConfig.findMany(),
      prisma.legalDocument.findMany({ orderBy: { version: 'desc' }, select: { id: true, version: true, title: true } }),
    ]);
    const latestLegal: Record<string, { version: string; title: string }> = {};
    for (const d of legal) latestLegal[d.id] ??= { version: d.version, title: d.title };
    const strip = <T extends Record<string, unknown>>(x: T) => {
      const { createdAt: _c, updatedAt: _u, sortOrder: _s, ...rest } = x as Record<string, unknown>;
      return Object.fromEntries(Object.entries(rest).filter(([, v]) => v !== null));
    };
    return {
      plans: plans.map((p) => strip(p as unknown as Record<string, unknown>)),
      planFeatures: planFeatures.map((p) => strip(p as unknown as Record<string, unknown>)),
      certificates: certificates.map((p) => strip(p as unknown as Record<string, unknown>)),
      config: Object.fromEntries(appConfig.map((c) => [c.key, c.value])),
      legal: latestLegal,
    };
  });

  r.get('/v1/legal/:id', async (ctx) => {
    const doc = await prisma.legalDocument.findFirst({ where: { id: ctx.params.id }, orderBy: { version: 'desc' } });
    if (!doc) throw notFound('Document not found.');
    return { id: doc.id, version: doc.version, title: doc.title, intro: doc.intro ?? '', sections: doc.sections };
  });
}
