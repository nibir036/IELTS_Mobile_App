// Loads the UK restriction list into nexted_restrictions.
//
//   npx tsx --env-file=.env scripts/nexted-restrictions.ts
//
// Safe to run again: every row has a stable id and is upserted, so re-running
// after the list is revised updates it in place rather than duplicating it.
//
// WHY THIS IS A TABLE AND NOT A DOCUMENT
// The counsellor must never *retrieve* these as text. A semantic search that
// confuses "Oxford Brookes" with "Oxford International Education Group" - both
// on this list, with different rules - would cost a student a year and a
// deposit. The match happens in code (lib/nexted.ts), and the AI is handed the
// result already decided.
//
// WHERE IT COMES FROM
// NextED's partner information, not a public university page, so nothing here
// can be shown with a university link. The app says "not available through
// NextED for this intake"; it never says a named university rejects
// Bangladeshi students, which is a claim we could not source.
//
// KEEPING IT HONEST
// This list moves every cycle. AS_OF below is the day it was handed over; the
// app shows it, so a student can see how fresh it is. When the list is
// revised, edit this file, change AS_OF, and run it again.

import { prisma } from '../src/db';

/** The day this list was given to us. Change it with the list. */
const AS_OF = new Date('2026-10-18T00:00:00Z');

const SOURCE = 'NextED partner information (UK), October 2026';

interface Rule {
  /** Stable id: never reuse one for a different rule. */
  id: string;
  university: string;
  campus?: string;
  openCampus?: string;
  kind?: 'full' | 'partial' | 'check';
  levels?: string[];
  regions?: string[];
  exceptRegions?: string[];
  subjects?: string[];
  intakes?: string[];
  note: string;
}

/** A university closed to every Bangladeshi applicant. */
const full = (id: string, university: string): Rule => ({
  id: `uk-${id}`,
  university,
  kind: 'full',
  note: 'Full restrictions for Bangladesh',
});

const RULES: Rule[] = [
  // ── closed to the whole country ──────────────────────────────────────────
  full('roehampton', 'University of Roehampton'),
  full('kingston', 'Kingston University'),
  full('keele', 'Keele University'),
  full('ravensbourne', 'Ravensbourne University London'),
  full('de-montfort', 'De Montfort University'),
  full('sunderland', 'University of Sunderland'),
  full('uwtsd', 'University of Wales Trinity Saint David'),
  full('coventry', 'Coventry University'),
  full('uclan', 'University of Central Lancashire'),
  full('middlesex', 'Middlesex University'),
  full('anglia-ruskin', 'Anglia Ruskin University'),
  full('oncampus-ceg', 'OnCampus CEG Foundation'),
  full('derby', 'University of Derby'),
  full('uel', 'University of East London'),
  full('bradford', 'University of Bradford'),
  full('ucb', 'University College Birmingham'),

  // ── only one campus stays open ───────────────────────────────────────────
  {
    id: 'uk-ulster-campus',
    university: 'Ulster University',
    openCampus: 'Belfast',
    kind: 'check',
    note: 'Only the main Belfast campus is open; QA-run campuses are restricted',
  },
  {
    id: 'uk-northumbria-campus',
    university: 'Northumbria University',
    openCampus: 'Newcastle',
    kind: 'check',
    note: 'Only the main Newcastle campus is open; QA-run campuses are restricted',
  },
  {
    id: 'uk-aston-london',
    university: 'Aston University',
    campus: 'London',
    regions: ['Sylhet'],
    note: 'London campus restricted for Sylhet; the Birmingham campus is open',
  },
  {
    id: 'uk-hull-london',
    university: 'University of Hull',
    campus: 'London',
    regions: ['Sylhet'],
    note: 'London campus restricted for Sylhet; the main campus is open',
  },

  // ── closed by level ──────────────────────────────────────────────────────
  {
    id: 'uk-oxford-brookes-ug',
    university: 'Oxford Brookes University',
    levels: ['Undergraduate'],
    note: 'Undergraduate restricted for Bangladesh',
  },
  {
    id: 'uk-oxford-brookes-sylhet',
    university: 'Oxford Brookes University',
    regions: ['Sylhet'],
    note: 'Sylhet restricted',
  },
  {
    id: 'uk-bcu-levels',
    university: 'Birmingham City University',
    levels: ['Undergraduate', 'MRes'],
    note: 'Undergraduate and MRes restricted for Bangladesh',
  },
  {
    id: 'uk-bolton-levels',
    university: 'University of Greater Manchester, Bolton',
    levels: ['MRes', 'PhD'],
    note: 'MRes and PhD restricted for Bangladesh',
  },

  // ── closed by level and by region ────────────────────────────────────────
  {
    id: 'uk-bucks-new-ug',
    university: 'Buckinghamshire New University',
    levels: ['Undergraduate'],
    note:
      'Undergraduate restricted. Only students from five named universities may apply from Bangladesh, with a full deposit',
  },
  {
    id: 'uk-bucks-new-sylhet',
    university: 'Buckinghamshire New University',
    regions: ['Sylhet'],
    note: 'Sylhet restricted',
  },
  {
    id: 'uk-cardiff-met-ug',
    university: 'Cardiff Metropolitan University',
    levels: ['Undergraduate'],
    note: 'Undergraduate restricted for Bangladesh',
  },
  {
    id: 'uk-cardiff-met-sylhet',
    university: 'Cardiff Metropolitan University',
    regions: ['Sylhet'],
    note: 'The full Sylhet region is restricted',
  },
  {
    id: 'uk-lsbu',
    university: 'London South Bank University',
    levels: ['Undergraduate'],
    note: 'Undergraduate restricted for Bangladesh',
  },
  {
    id: 'uk-lsbu-regions',
    university: 'London South Bank University',
    regions: ['Dhaka', 'Sylhet'],
    note: 'Dhaka and Sylhet restricted',
  },
  {
    id: 'uk-regent-london-ug',
    university: 'Regent College London',
    levels: ['Undergraduate'],
    note: 'Undergraduate restricted for Bangladesh',
  },
  {
    id: 'uk-regent-london-sylhet',
    university: 'Regent College London',
    regions: ['Sylhet'],
    note: 'Sylhet restricted',
  },
  {
    id: 'uk-hertfordshire-ug',
    university: 'University of Hertfordshire',
    levels: ['Undergraduate'],
    note: 'Undergraduate restricted for Bangladesh',
  },
  {
    id: 'uk-hertfordshire-sylhet',
    university: 'University of Hertfordshire',
    regions: ['Sylhet'],
    note: 'Sylhet restricted',
  },
  {
    id: 'uk-hertfordshire-management',
    university: 'University of Hertfordshire',
    subjects: ['Management', 'Business'],
    note: 'Management stream courses restricted for Bangladesh',
  },

  // ── closed by region only ────────────────────────────────────────────────
  { id: 'uk-south-wales', university: 'University of South Wales', regions: ['Sylhet'], note: 'Sylhet restricted' },
  { id: 'uk-aberystwyth', university: 'Aberystwyth University', regions: ['Sylhet'], note: 'Sylhet restricted' },
  {
    id: 'uk-oxford-intl',
    university: 'Oxford International Education Group',
    regions: ['Sylhet'],
    note: 'Sylhet restricted',
  },
  {
    id: 'uk-canterbury',
    university: 'Canterbury Christ Church University',
    regions: ['Sylhet'],
    note: 'Sylhet restricted',
  },
  { id: 'uk-brighton', university: 'University of Brighton', regions: ['Sylhet'], note: 'Sylhet restricted' },
  {
    id: 'uk-bedfordshire',
    university: 'University of Bedfordshire',
    exceptRegions: ['Dhaka'],
    note: 'Restricted for Bangladeshi applicants except Dhaka',
  },

  // ── closed by region, subject or intake ──────────────────────────────────
  { id: 'uk-chester-sylhet', university: 'University of Chester', regions: ['Sylhet'], note: 'Sylhet restricted' },
  {
    id: 'uk-chester-intakes',
    university: 'University of Chester',
    kind: 'full',
    intakes: ['January 2027', 'May 2027'],
    note: 'Full Bangladeshi restriction for the January and May 2027 intakes',
  },
  { id: 'uk-law-sylhet', university: 'University of Law', regions: ['Sylhet'], note: 'Sylhet restricted' },
  {
    id: 'uk-law-business',
    university: 'University of Law',
    subjects: ['Business'],
    note: 'Business courses restricted for Bangladesh',
  },
  {
    id: 'uk-wolverhampton-sylhet',
    university: 'University of Wolverhampton',
    regions: ['Sylhet'],
    note: 'Sylhet restricted',
  },
  {
    id: 'uk-wolverhampton-business',
    university: 'University of Wolverhampton',
    subjects: ['Business'],
    note: 'Business courses restricted for Bangladesh',
  },
  {
    id: 'uk-wolverhampton-mres',
    university: 'University of Wolverhampton',
    levels: ['MRes'],
    note: 'MRes courses restricted for Bangladesh',
  },
  {
    id: 'uk-portsmouth',
    university: 'University of Portsmouth',
    regions: ['Sylhet'],
    kind: 'check',
    note: 'Sylhet restricted; selected courses remain available for other regions',
  },
];

async function main(): Promise<void> {
  let written = 0;
  for (const r of RULES) {
    const data = {
      university: r.university,
      campus: r.campus ?? '',
      openCampus: r.openCampus ?? '',
      kind: r.kind ?? 'partial',
      levels: r.levels ?? [],
      regions: r.regions ?? [],
      exceptRegions: r.exceptRegions ?? [],
      subjects: r.subjects ?? [],
      intakes: r.intakes ?? [],
      note: r.note,
      source: SOURCE,
      asOf: AS_OF,
      active: true,
    };
    await prisma.nextedRestriction.upsert({ where: { id: r.id }, create: { id: r.id, ...data }, update: data });
    written++;
  }

  // Anything in the table that is no longer on the list is retired rather
  // than deleted, so a counsellor can still see what it used to say.
  const ids = RULES.map((r) => r.id);
  const retired = await prisma.nextedRestriction.updateMany({
    where: { id: { notIn: ids }, active: true },
    data: { active: false },
  });

  const universities = new Set(RULES.map((r) => r.university)).size;
  console.log('Study-destination restrictions');
  console.log(`  rules written      ${written}`);
  console.log(`  universities       ${universities}`);
  console.log(`  rules retired      ${retired.count}`);
  console.log(`  as of              ${AS_OF.toISOString().slice(0, 10)}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
