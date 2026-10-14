import { NextResponse } from 'next/server';
import { env } from '@/lib/server/env';

/** /media/<key> → the API's media link (which redirects to a signed R2 URL). */
export async function GET(_req: Request, ctx: { params: Promise<{ key: string[] }> }) {
  const { key } = await ctx.params;
  if (!key.length || key.some((k) => k === '..' || k === '')) {
    return NextResponse.json({ error: 'Not found.' }, { status: 404 });
  }
  const res = NextResponse.redirect(`${env.apiBaseUrl}/v1/media/${key.map(encodeURIComponent).join('/')}`, 302);
  res.headers.set('Cache-Control', 'public, max-age=600');
  return res;
}
