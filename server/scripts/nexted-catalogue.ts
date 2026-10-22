// A small starter catalogue for the nexted.app module, so course matching and
// the scholarship finder have something real to rank while the full catalogue
// is being built.
//
//   npx tsx --env-file=.env scripts/nexted-catalogue.ts            (npm run nexted:catalogue)
//   npx tsx scripts/nexted-catalogue.ts --if-empty                  (scripts/start.sh, on every deploy)
//
// --if-empty loads the starter rows only into an empty catalogue, so a deploy
// never overwrites courses or scholarships staff have edited or added.
//
// Safe to re-run: every row is upserted by its stable id. Replace these with
// NextED's own catalogue when it is ready - the matcher only ever ranks what
// is in these tables, it never invents a course or a scholarship.

import { prisma } from '../src/db';

const courses = [
  {
    id: 'nc_uk_msc_cs',
    title: 'MSc Computer Science',
    university: 'University of Birmingham',
    country: 'United Kingdom',
    level: 'Master',
    subject: 'Computer Science',
    duration: '1 year',
    intake: 'September 2027',
    tuition: '£27,500 / year',
    minIelts: 6.5,
  },
  {
    id: 'nc_uk_msc_data',
    title: 'MSc Data Science',
    university: 'University of Sheffield',
    country: 'United Kingdom',
    level: 'Master',
    subject: 'Data Science',
    duration: '1 year',
    intake: 'September 2027',
    tuition: '£26,900 / year',
    minIelts: 6.5,
  },
  {
    id: 'nc_uk_msc_business',
    title: 'MSc International Business',
    university: 'Coventry University',
    country: 'United Kingdom',
    level: 'Master',
    subject: 'Business',
    duration: '1 year',
    intake: 'January 2027',
    tuition: '£18,600 / year',
    minIelts: 6.0,
  },
  {
    id: 'nc_ca_msc_cs',
    title: 'MSc Computing Science',
    university: 'University of Alberta',
    country: 'Canada',
    level: 'Master',
    subject: 'Computer Science',
    duration: '2 years',
    intake: 'September 2027',
    tuition: 'CAD 12,000 / year',
    minIelts: 6.5,
  },
  {
    id: 'nc_ca_pg_business',
    title: 'Postgraduate Diploma in Business Analytics',
    university: 'Seneca Polytechnic',
    country: 'Canada',
    level: 'Postgraduate diploma',
    subject: 'Business Analytics',
    duration: '1 year',
    intake: 'May 2027',
    tuition: 'CAD 17,400 / year',
    minIelts: 6.5,
  },
  {
    id: 'nc_au_mit',
    title: 'Master of Information Technology',
    university: 'Deakin University',
    country: 'Australia',
    level: 'Master',
    subject: 'Information Technology',
    duration: '2 years',
    intake: 'July 2027',
    tuition: 'AUD 40,200 / year',
    minIelts: 6.5,
  },
  {
    id: 'nc_de_msc_cs',
    title: 'MSc Computer Science (English taught)',
    university: 'Technical University of Applied Sciences Würzburg',
    country: 'Germany',
    level: 'Master',
    subject: 'Computer Science',
    duration: '1.5 years',
    intake: 'October 2027',
    tuition: 'No tuition fee (semester fee only)',
    minIelts: 6.0,
  },
  {
    id: 'nc_my_bsc_cs',
    title: 'BSc (Hons) Computer Science',
    university: 'Asia Pacific University',
    country: 'Malaysia',
    level: 'Bachelor',
    subject: 'Computer Science',
    duration: '3 years',
    intake: 'March 2027',
    tuition: 'MYR 38,000 total',
    minIelts: 5.5,
  },
];

const scholarships = [
  {
    id: 'ns_chevening',
    title: 'Chevening Scholarship',
    provider: 'UK Government',
    country: 'United Kingdom',
    amount: 'Full tuition, living costs and flights',
    deadline: '2026-11-04',
    level: 'Master',
    minIelts: 6.5,
    minGpa: 3.0,
    nationalities: ['Bangladeshi'],
  },
  {
    id: 'ns_commonwealth',
    title: 'Commonwealth Master’s Scholarship',
    provider: 'Commonwealth Scholarship Commission',
    country: 'United Kingdom',
    amount: 'Full tuition and stipend',
    deadline: '2026-12-15',
    level: 'Master',
    minIelts: 6.5,
    minGpa: 3.2,
    nationalities: ['Bangladeshi', 'Indian', 'Pakistani', 'Sri Lankan'],
  },
  {
    id: 'ns_birmingham_merit',
    title: 'Birmingham International Merit Award',
    provider: 'University of Birmingham',
    country: 'United Kingdom',
    amount: '£3,000 tuition discount',
    deadline: '2027-06-30',
    level: 'Master',
    minIelts: 6.5,
    minGpa: 3.0,
    nationalities: [],
  },
  {
    id: 'ns_daad',
    title: 'DAAD EPOS Scholarship',
    provider: 'DAAD',
    country: 'Germany',
    amount: '€992 / month plus travel',
    deadline: '2026-10-31',
    level: 'Master',
    minIelts: 6.0,
    minGpa: 3.0,
    nationalities: [],
  },
  {
    id: 'ns_deakin_vc',
    title: 'Deakin Vice-Chancellor’s International Scholarship',
    provider: 'Deakin University',
    country: 'Australia',
    amount: '25% tuition reduction',
    deadline: '2027-05-01',
    level: 'Master',
    minIelts: 6.5,
    minGpa: 3.4,
    nationalities: [],
  },
  {
    id: 'ns_seneca_entry',
    title: 'Seneca International Entrance Award',
    provider: 'Seneca Polytechnic',
    country: 'Canada',
    amount: 'CAD 2,000',
    deadline: '2027-03-15',
    level: 'Postgraduate diploma',
    minIelts: 6.5,
    minGpa: 2.8,
    nationalities: [],
  },
];

async function main() {
  if (process.argv.includes('--if-empty')) {
    const [nc, ns] = await Promise.all([prisma.nextedCourse.count(), prisma.nextedScholarship.count()]);
    if (nc > 0 || ns > 0) {
      console.log(`nexted catalogue: already loaded (${nc} courses, ${ns} scholarships), left as is`);
      await prisma.$disconnect();
      return;
    }
  }
  for (const c of courses) {
    await prisma.nextedCourse.upsert({ where: { id: c.id }, create: c, update: c });
  }
  for (const s of scholarships) {
    await prisma.nextedScholarship.upsert({ where: { id: s.id }, create: s, update: s });
  }
  console.log(`nexted catalogue: ${courses.length} courses, ${scholarships.length} scholarships`);
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error(e);
  await prisma.$disconnect();
  process.exit(1);
});
