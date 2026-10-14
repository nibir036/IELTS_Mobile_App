// Writing templates (C10, writing_template_screen.dart): fill-in essay
// structures from the UI pack (writing.templates). Filled slots are the
// student's kv state `writing.template.values` {"tplId|section|segment": value}.

export const TEMPLATE_VALUES_KEY = 'writing.template.values';

export type Segment = { text?: string; slot?: string; value?: string };
export interface Template {
  id: string;
  type: string;
  variant: string;
  title: string;
  task: 'task1' | 'task2';
  sections: Array<{ title: string; subtitle: string; segments: Segment[] }>;
}

export function slotValue(values: Record<string, string>, tplId: string, s: number, g: number, seg: Segment): string {
  const v = values[`${tplId}|${s}|${g}`];
  return typeof v === 'string' ? v : seg.value ?? '';
}

/** The template as plain text: filled slots, else "[slot]". */
export function templatePlain(tpl: Template, values: Record<string, string>): string {
  return tpl.sections
    .map((sec, s) =>
      sec.segments
        .map((seg, g) => {
          if (seg.slot === undefined) return seg.text ?? '';
          const v = slotValue(values, tpl.id, s, g, seg);
          return v || `[${seg.slot}]`;
        })
        .join(''),
    )
    .join('\n\n')
    .trim();
}

/** The question type a template is written for (the bank's `type`). */
export function templatePromptType(tplType: string): string {
  const t = tplType.toLowerCase();
  if (t.startsWith('task 1')) {
    const k = t.replace('task 1', '').trim();
    return k === 'chart' ? 'line' : k;
  }
  if (t.startsWith('problem')) return 'problem';
  if (t.startsWith('two')) return 'two-part';
  return t;
}
