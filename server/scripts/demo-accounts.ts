// The shared Pro demo accounts: "Demo 1" … "Demo 4", all with the same
// password (DEMO_PASSWORD, default Demo@Nexted123). For store reviewers,
// sales demos and the team. They sign in with "Demo N" instead of a phone
// number, are Pro without a payment, have no device limit, and their password
// can't be changed nor the account deleted from the app or website.
//
// Runs on every container start (scripts/start.sh): creates missing accounts,
// puts back Pro, the name and the password if someone changed them. Their
// progress is kept.
//
//   npx tsx --env-file=.env scripts/demo-accounts.ts      (locally)
//   DEMO_ACCOUNTS=0 turns it off.

import { prisma } from '../src/db';
import { hashPassword, verifyPassword } from '../src/lib/password';

const COUNT = 4;

async function main() {
  if (process.env.DEMO_ACCOUNTS === '0') return;
  const password = process.env.DEMO_PASSWORD || 'Demo@Nexted123';
  console.log('Demo accounts');
  for (let n = 1; n <= COUNT; n++) {
    const phone = `demo${n}`;
    const name = `Demo ${n}`;
    const found = (await prisma.user.findUnique({
      where: { phone },
      select: { id: true, passwordHash: true, profile: true },
    })) as { id: string; passwordHash: string; profile: Record<string, unknown> | null } | null;
    if (!found) {
      await prisma.user.create({
        data: {
          name,
          phone,
          passwordHash: hashPassword(password),
          passwordChangedAt: new Date(),
          phoneVerifiedAt: new Date(),
          isDemo: true,
          profile: { plan: 'Pro', testType: 'Academic' },
        },
      });
      console.log(`  ${name}: created`);
      continue;
    }
    const profile = { ...(found.profile ?? {}), plan: 'Pro' };
    await prisma.user.update({
      where: { id: found.id },
      data: {
        name,
        isDemo: true,
        profile,
        // A new hash only when the password differs (a new salt each start is churn).
        ...(verifyPassword(password, found.passwordHash) ? {} : { passwordHash: hashPassword(password), passwordChangedAt: new Date() }),
      },
    });
    console.log(`  ${name}: ok`);
  }
}

main()
  .catch((e) => {
    console.error('[demo-accounts] failed:', e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
