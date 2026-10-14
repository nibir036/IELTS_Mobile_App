import { templatePromptType, type Template } from '../writing/templates';
import { uiPack } from './packs';
import { writingPrompts } from './writing';

type Raw = Record<string, unknown>;

export async function writingTemplates(): Promise<{ types: string[]; items: Template[] }> {
  const ui = await uiPack();
  const t = (((ui.writing ?? {}) as Raw).templates ?? {}) as { types?: string[]; items?: Template[] };
  return { types: Array.isArray(t.types) ? t.types : [], items: Array.isArray(t.items) ? t.items : [] };
}

/** A question of each template's type, to open the template in the editor. */
export async function templatePrompts(items: Template[]): Promise<Record<string, string>> {
  const prompts = await writingPrompts();
  const out: Record<string, string> = {};
  for (const tpl of items) {
    const task = tpl.task === 'task1' ? 1 : 2;
    const type = templatePromptType(tpl.type);
    const p = prompts.find((x) => x.task === task && x.type === type) ?? prompts.find((x) => x.task === task);
    if (p) out[tpl.id] = p.id;
  }
  return out;
}
