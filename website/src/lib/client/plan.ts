// Ticks study-plan tasks that point at something the student just finished
// (Store.tickPlanTasks): a lesson, a question, a test. Runs in the browser
// through the same-origin API proxy; failures are ignored (the app's sync
// ticks them later too).

type Task = { id: string; kind?: string; ref?: string | null; itemId?: string | null; date?: string; done?: boolean };

const today = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Dhaka' });

export async function tickPlanTasks(ref: string): Promise<number> {
  if (!ref) return 0;
  try {
    const res = await fetch('/api/v1/tasks');
    if (!res.ok) return 0;
    const items = ((await res.json()) as { items?: Task[] }).items ?? [];
    let n = 0;
    for (const t of items) {
      if (t.done || t.ref !== ref || (t.kind !== 'plan' && t.kind !== 'checkpoint')) continue;
      if (t.itemId === 'pron:daily' && String(t.date ?? '').slice(0, 10) !== today()) continue;
      const r = await fetch(`/api/v1/tasks/${encodeURIComponent(t.id)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ done: true }),
      });
      if (r.ok) n++;
      // A repeating task: one tick per attempt.
      if (t.itemId === 'pron:daily') break;
    }
    return n;
  } catch {
    return 0;
  }
}
