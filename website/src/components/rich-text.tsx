import { Fragment, type ReactNode } from 'react';

/** "**bold**" spans. */
export function bold(text: string): ReactNode {
  return text.split('**').map((p, i) => (i % 2 ? <b key={i}>{p}</b> : <Fragment key={i}>{p}</Fragment>));
}

/**
 * The app's light article markup: blank-line paragraphs, "• " bullets,
 * a line that is all **bold** is a small heading, **bold** inline.
 */
export function RichText({ text }: { text: string }) {
  const out: ReactNode[] = [];
  let bullets: string[] = [];
  const flush = () => {
    if (!bullets.length) return;
    out.push(
      <ul key={`u${out.length}`} style={{ margin: '6px 0 10px', paddingLeft: 20, display: 'flex', flexDirection: 'column', gap: 6 }}>
        {bullets.map((b, i) => (
          <li key={i}>{bold(b)}</li>
        ))}
      </ul>,
    );
    bullets = [];
  };
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line) {
      flush();
      continue;
    }
    if (line.startsWith('•') || line.startsWith('- ')) {
      bullets.push(line.replace(/^(•|-)\s*/, ''));
      continue;
    }
    flush();
    if (/^\*\*[^*]+\*\*$/.test(line)) {
      out.push(
        <h4 key={`h${out.length}`} style={{ margin: '14px 0 4px', fontSize: 15.5 }}>
          {line.slice(2, -2)}
        </h4>,
      );
    } else {
      out.push(
        <p key={`p${out.length}`} style={{ margin: '0 0 10px', lineHeight: 1.6 }}>
          {bold(line)}
        </p>,
      );
    }
  }
  flush();
  return <div style={{ color: 'var(--text-soft)', fontSize: 15 }}>{out}</div>;
}
