import { PrismaClient } from '@prisma/client';

/** One Prisma client for the whole process. */
export const prisma = new PrismaClient();
