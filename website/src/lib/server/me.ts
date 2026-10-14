import { redirect } from 'next/navigation';
import { api, ApiError } from './api';

export interface Me {
  user: { id: string; name: string; phone: string; isDemo: boolean; profile: Record<string, unknown> };
  usage: { plan: 'free' | 'pro'; limits: Record<string, unknown> | null } & Record<string, unknown>;
}

/** The signed-in student, or a redirect to /login when the session is gone. */
export async function getMe(): Promise<Me> {
  try {
    return await api<Me>('/v1/me');
  } catch (e) {
    if (e instanceof ApiError && e.status === 401) redirect(`/login?reason=${encodeURIComponent(e.code || 'session_ended')}`);
    throw e;
  }
}

export function firstName(name: string): string {
  return name.trim().split(/\s+/)[0] || 'there';
}
