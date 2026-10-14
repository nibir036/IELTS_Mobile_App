import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { attempt as getAttempt, stateValue } from '@/lib/server/attempts';
import { applyFixes, validIssues } from '@/lib/writing/analysis';
import { writingTemplates } from '@/lib/server/templates';
import { TEMPLATE_VALUES_KEY, templatePlain } from '@/lib/writing/templates';
import { writingPrompt } from '@/lib/server/writing';
import { mediaUrl } from '@/lib/media';
import { Editor } from './editor';

export const metadata: Metadata = { title: 'Write' };

type Draft = { promptId: string; text: string; elapsedSec?: number };

/** C2 / C3 · Task 1 and Task 2 editor (writing_task1_editor_screen / writing_editor_screen). */
export default async function WritePage({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ from?: string; template?: string }> }) {
  const { id } = await params;
  const { from, template } = await searchParams;
  const prompt = await writingPrompt(decodeURIComponent(id));
  if (!prompt) notFound();
  const draft = await stateValue<Draft>(`writing.draft.task${prompt.task}`);
  const mine = draft && draft.promptId === prompt.id ? draft : null;
  // "Rewrite my essay with these changes": start from the improved version of an earlier essay.
  let start: string | null = null;
  // "Use in editor" from a writing template: the template with the student's filled slots.
  if (template) {
    const [{ items }, values] = await Promise.all([writingTemplates(), stateValue<Record<string, string>>(TEMPLATE_VALUES_KEY)]);
    const tpl = items.find((x) => x.id === template);
    if (tpl) start = templatePlain(tpl, values ?? {});
  }
  if (from) {
    const a = await getAttempt(from);
    if (a && a.skill === 'writing' && a.refId === prompt.id) {
      const text = String(a.data.text ?? '');
      const rw = (a.data.rewrite ?? {}) as { text?: string };
      start = rw.text?.trim() ? rw.text.trim() : applyFixes(text, validIssues(text, a.data.issues))[0];
    }
  }
  return (
    <Editor
      prompt={{
        id: prompt.id,
        task: prompt.task,
        title: prompt.title,
        shortTitle: prompt.shortTitle,
        typeName: prompt.typeName,
        prompt: prompt.prompt,
        minWords: prompt.minWords,
        timeSeconds: prompt.timeSeconds,
        image: prompt.image ? mediaUrl(prompt.image) : '',
        dataText: prompt.dataText,
        hasSamples: prompt.samples.length > 0 || Boolean(prompt.modelAnswer),
      }}
      initialText={start ?? mine?.text ?? ''}
      initialElapsed={start ? 0 : (mine?.elapsedSec ?? 0)}
      otherDraft={Boolean(draft && draft.promptId !== prompt.id && draft.text?.trim())}
    />
  );
}
