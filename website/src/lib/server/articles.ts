import { uiPack } from './packs';

export interface Article {
  id: string;
  series: string;
  chip: string;
  title: string;
  meta: string;
  tips: Array<{ title: string; body: string }>;
}

export async function articles(): Promise<Article[]> {
  const ui = await uiPack();
  const list = ((ui.resources ?? {}) as { articles?: Article[] }).articles;
  return Array.isArray(list) ? list : [];
}
