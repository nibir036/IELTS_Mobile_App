import type { Metadata } from 'next';
import Link from 'next/link';
import { Card, Icon, SectionTitle, Tag } from '@/components/ui';
import { rows, str, strs } from '@/lib/practice/marking';
import { uiPack } from '@/lib/server/packs';
import w from '../../writing/writing.module.css';

export const metadata: Metadata = { title: 'Scoring criteria' };

type Raw = Record<string, unknown>;

/** Scoring Criteria (scoring_criteria_screen.dart): how each skill is marked, band 9 down to 4. */
export default async function Scoring({ searchParams }: { searchParams: Promise<{ skill?: string }> }) {
  const { skill } = await searchParams;
  const ui = await uiPack();
  const skills = rows(((ui.resources ?? {}) as Raw).scoring && ((ui.resources as Raw).scoring as Raw).skills);
  const cur = skills.find((x) => str(x.key) === skill) ?? skills[0];
  if (!cur) return <Card padding={20}>Scoring criteria are not available.</Card>;
  return (
    <>
      <div className={w.head}>
        <div>
          <Link href="/app/resources" className={w.sub} style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="arrow_back" size={16} /> Resources
          </Link>
          <h1 className={w.title}>Scoring criteria</h1>
        </div>
      </div>
      <nav className={w.chips}>
        {skills.map((x) => (
          <Link key={str(x.key)} href={`/app/resources/scoring?skill=${str(x.key)}`} className={`${w.chip} ${x === cur ? w.chipOn : ''}`}>
            {str(x.name)}
          </Link>
        ))}
      </nav>
      <Card padding={18}>
        <p style={{ margin: 0, color: 'var(--text-soft)', lineHeight: 1.6 }}>{str(cur.intro)}</p>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 12 }}>
          {rows(cur.facts).map((f) => (
            <Tag key={str(f.label)}>
              {str(f.label)}: {str(f.value)}
            </Tag>
          ))}
        </div>
      </Card>
      {rows(cur.blocks).map((b, i) => (
        <Card key={i} padding={18}>
          {b.title ? <SectionTitle>{str(b.title)}</SectionTitle> : null}
          {b.subtitle ? <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: 13.5 }}>{str(b.subtitle)}</p> : null}
          <div style={{ marginTop: 10 }}>
            {str(b.type) === 'table' ? (
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 14 }}>
                <thead>
                  <tr>
                    {strs(b.columns).map((c) => (
                      <th key={c} style={{ textAlign: 'left', padding: '6px 8px', borderBottom: '1px solid var(--border)', color: 'var(--text-muted)', fontWeight: 500 }}>
                        {c}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {(Array.isArray(b.rows) ? (b.rows as unknown[][]) : []).map((r, j) => (
                    <tr key={j}>
                      {r.map((c, k) => (
                        <td key={k} style={{ padding: '6px 8px', borderBottom: '1px solid var(--divider)' }}>
                          {str(c)}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : str(b.type) === 'chips' ? (
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {strs(b.items).map((x) => (
                  <Tag key={x}>{x}</Tag>
                ))}
              </div>
            ) : str(b.type) === 'parts' || str(b.type) === 'bands' ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {rows(b.items).map((x, j) => (
                  <p key={j} style={{ margin: 0 }}>
                    <b>{str(x.label || x.band)}</b> {str(x.title || x.name)} <span style={{ color: 'var(--text-soft)' }}>· {str(x.text)}</span>
                  </p>
                ))}
              </div>
            ) : str(b.type) === 'criteria' ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                {rows(b.criteria).map((c) => (
                  <details key={str(c.name)} style={{ border: '1px solid var(--border)', borderRadius: 14, padding: '10px 14px', background: 'var(--surface)' }}>
                    <summary style={{ cursor: 'pointer', fontWeight: 600 }}>{str(c.name)}</summary>
                    <ul style={{ margin: '8px 0', paddingLeft: 20, color: 'var(--text-soft)', fontSize: 14 }}>
                      {strs(c.focus).map((f) => (
                        <li key={f}>{f}</li>
                      ))}
                    </ul>
                    {rows(c.levels).map((l) => (
                      <p key={str(l.band)} style={{ margin: '6px 0', fontSize: 14 }}>
                        <b>Band {str(l.band)}</b> <span style={{ color: 'var(--text-soft)' }}>{str(l.text)}</span>
                      </p>
                    ))}
                  </details>
                ))}
              </div>
            ) : (
              <ul style={{ margin: 0, paddingLeft: 20, display: 'flex', flexDirection: 'column', gap: 6, color: 'var(--text-soft)', fontSize: 14.5 }}>
                {strs(b.items).map((x) => (
                  <li key={x}>{x}</li>
                ))}
              </ul>
            )}
            {b.note ? <p style={{ margin: '10px 0 0', color: 'var(--text-muted)', fontSize: 13 }}>{str(b.note)}</p> : null}
          </div>
        </Card>
      ))}
    </>
  );
}
