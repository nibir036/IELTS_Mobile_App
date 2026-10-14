import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { attempt } from '@/lib/server/attempts';
import { getMe } from '@/lib/server/me';
import { writingPrompt } from '@/lib/server/writing';
import { validIssues } from '@/lib/writing/analysis';
import { Rewriter } from './rewriter';

export const metadata: Metadata = { title: 'Band comparison' };

/** C6 · AI essay rewriter & band comparison (writing_rewriter_screen.dart). */
export default async function RewritePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const a = await attempt(decodeURIComponent(id));
  if (!a || a.skill !== 'writing') notFound();
  const [prompt, me] = await Promise.all([writingPrompt(a.refId).catch(() => null), getMe()]);
  const d = a.data;
  const text = String(d.text ?? '');
  const task = Number(d.task ?? (a.kind === 'task1' ? 1 : 2)) === 1 ? 1 : 2;
  const lim = (me.usage.limits?.rewrite ?? null) as { left?: number } | null;
  const rw = (d.rewrite ?? null) as { text?: string; target?: number; changes?: Array<{ from?: string; to?: string; why?: string }> } | null;
  return (
    <Rewriter
      attempt={{ id: a.id, skill: a.skill, kind: a.kind, title: a.title, refId: a.refId, band: a.band, score: a.score, total: a.total, durationSec: a.durationSec, createdAt: a.createdAt }}
      data={d}
      task={task}
      text={text}
      issues={validIssues(text, d.issues)}
      promptText={String(d.prompt ?? prompt?.prompt ?? '')}
      dataText={task === 1 ? prompt?.dataText ?? '' : ''}
      model={prompt?.modelAnswer ?? ''}
      cached={rw?.text?.trim() ? { text: rw.text.trim(), target: typeof rw.target === 'number' ? rw.target : 8, changes: Array.isArray(rw.changes) ? rw.changes : [] } : null}
      usedUp={me.usage.plan !== 'pro' && !!lim && Number(lim.left ?? 1) <= 0}
    />
  );
}
