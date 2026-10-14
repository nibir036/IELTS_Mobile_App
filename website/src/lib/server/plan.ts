import type { Plan } from '../plan/plan';
import { api, ApiError } from './api';

/**
 * The student's current study plan (null when there is none). Loading it
 * also lets the server tick tasks finished anywhere, roll the plan into a
 * new week and end a pause (ensurePlan).
 */
export async function currentPlan(): Promise<{ plan: Plan | null; error: string | null }> {
  try {
    const r = await api<{ plan: Plan | null }>('/v1/plan');
    return { plan: r.plan, error: null };
  } catch (e) {
    return { plan: null, error: e instanceof ApiError ? e.message : 'Could not load your plan.' };
  }
}
