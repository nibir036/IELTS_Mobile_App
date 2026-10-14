import type { Metadata } from 'next';
import { stateValue } from '@/lib/server/attempts';
import { templatePrompts, writingTemplates } from '@/lib/server/templates';
import { TEMPLATE_VALUES_KEY } from '@/lib/writing/templates';
import { Templates } from './templates';

export const metadata: Metadata = { title: 'Writing templates' };

/** C10 · Writing Template (writing_template_screen.dart). */
export default async function TemplatesPage() {
  const [{ types, items }, values] = await Promise.all([writingTemplates(), stateValue<Record<string, string>>(TEMPLATE_VALUES_KEY)]);
  const prompts = await templatePrompts(items);
  return <Templates types={types} items={items} initialValues={values ?? {}} prompts={prompts} />;
}
