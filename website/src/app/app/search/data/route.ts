import { NextResponse } from 'next/server';
import { searchIndex } from '@/lib/home/search-index';

/** The search index (built from the content packs) for the search page to filter in the browser. */
export async function GET() {
  try {
    const items = await searchIndex();
    return NextResponse.json({ items }, { headers: { 'Cache-Control': 'private, max-age=600' } });
  } catch {
    return NextResponse.json({ items: [], error: 'Search is not available right now.' }, { status: 503 });
  }
}
