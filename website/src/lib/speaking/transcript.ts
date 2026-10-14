// Transcript paragraphs in the app's shape (buildTranscriptParagraphs in
// lib/features/speaking/speaking_ai.dart): {faded, tokens: [{type, text, note?}]}.

const FILLERS = new Set(['um', 'umm', 'ummm', 'uh', 'uhh', 'uhm', 'er', 'err', 'erm', 'ah', 'ahh', 'hmm', 'mm']);

export interface Token {
  type: 'text' | 'filler' | 'pause' | 'error';
  text: string;
  note?: string;
}
export interface Paragraph {
  faded: boolean;
  tokens: Token[];
}
export interface SpeakingError {
  original: string;
  suggestion: string;
  type: string;
  note: string;
}

function isFiller(seg: string, start: number, end: number, lower: string): boolean {
  if (FILLERS.has(lower)) return true;
  if (lower !== 'like') return false;
  let i = end;
  while (i < seg.length && seg[i] === ' ') i++;
  if (i < seg.length && seg[i] === ',') return true;
  let j = start - 1;
  while (j >= 0 && seg[j] === ' ') j--;
  return j >= 0 && seg[j] === ',';
}

function plainTokens(text: string, start: number, end: number): Token[] {
  const seg = text.slice(start, end);
  const out: Token[] = [];
  let buf = '';
  const flush = () => {
    if (buf) out.push({ type: 'text', text: buf });
    buf = '';
  };
  const re = /(\.\.\.+|…)|([A-Za-z']+)/g;
  let pos = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(seg))) {
    if (m.index > pos) buf += seg.slice(pos, m.index);
    const word = m[2];
    if (m[1]) {
      flush();
      out.push({ type: 'pause', text: '‖', note: 'Pause - link your ideas instead of stopping.' });
    } else if (word && isFiller(seg, m.index, m.index + m[0].length, word.toLowerCase())) {
      flush();
      out.push({ type: 'filler', text: word, note: 'Filler - try a short silent pause instead.' });
    } else {
      buf += m[0];
    }
    pos = m.index + m[0].length;
  }
  if (pos < seg.length) buf += seg.slice(pos);
  flush();
  return out;
}

export function buildParagraphs(texts: string[], errors: SpeakingError[]): Paragraph[] {
  const used = new Set<number>();
  const out: Paragraph[] = [];
  for (const text of texts) {
    if (!text.trim()) continue;
    const spans: Array<[number, number, SpeakingError]> = [];
    const lower = text.toLowerCase();
    errors.forEach((e, idx) => {
      if (used.has(idx)) return;
      const orig = e.original.trim();
      if (!orig) return;
      let from = 0;
      for (;;) {
        const at = lower.indexOf(orig.toLowerCase(), from);
        if (at < 0) break;
        const end = at + orig.length;
        if (!spans.some(([a, b]) => at < b && end > a)) {
          spans.push([at, end, e]);
          used.add(idx);
          break;
        }
        from = at + 1;
      }
    });
    spans.sort((a, b) => a[0] - b[0]);
    const tokens: Token[] = [];
    let pos = 0;
    for (const [a, b, e] of spans) {
      if (a > pos) tokens.push(...plainTokens(text, pos, a));
      const parts = [e.suggestion ? `Try: “${e.suggestion}”` : '', e.note].filter(Boolean);
      tokens.push({ type: 'error', text: text.slice(a, b), note: parts.join('-') });
      pos = b;
    }
    if (pos < text.length) tokens.push(...plainTokens(text, pos, text.length));
    out.push({ faded: false, tokens });
  }
  return out;
}

/** The examiner's errors, dropping "corrections" that equal the original. */
export function errorsOf(raw: unknown): SpeakingError[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((e) => e && typeof e === 'object')
    .map((e) => {
      const r = e as Record<string, unknown>;
      const original = String(r.original ?? '');
      const sug = String(r.suggestion ?? '');
      return {
        original,
        suggestion: sug.trim().toLowerCase() === original.trim().toLowerCase() ? '' : sug,
        type: String(r.type ?? ''),
        note: String(r.note ?? ''),
      };
    });
}
