import { readBank, type SpeakingBank } from '../speaking/bank';
import { getPack, uiPack } from './packs';

export async function speakingBank(): Promise<SpeakingBank> {
  return readBank(await getPack<Record<string, unknown>>('bank.speaking'));
}

type Raw = Record<string, unknown>;

/** The bank plus the full Speaking Tests' own topics and cards, for opening any of them by id. */
export async function speakingBankWithTests(): Promise<SpeakingBank> {
  const [bank, tests] = await Promise.all([speakingBank(), getPack<Raw>('bank.tests').catch(() => ({}) as Raw)]);
  const t = readBank((tests.speaking ?? {}) as Raw);
  return { part1: [...bank.part1, ...t.part1], cards: [...bank.cards, ...t.cards], part3: [...bank.part3, ...t.part3] };
}

export interface SpeakingTest {
  id: string;
  number: number;
  title: string;
  part1: SpeakingBank['part1'][number] | null;
  card: SpeakingBank['cards'][number] | null;
  part3: SpeakingBank['part3'];
}

/** Speaking Test 1–10 (tests_bank.json). */
export async function speakingTests(): Promise<SpeakingTest[]> {
  const [all, tests] = await Promise.all([speakingBankWithTests(), getPack<Raw>('bank.tests').catch(() => ({}) as Raw)]);
  const list = ((tests.speaking ?? {}) as Raw).tests;
  return (Array.isArray(list) ? (list as Raw[]) : []).map((x) => ({
    id: String(x.id),
    number: Number(x.number) || 0,
    title: String(x.title ?? ''),
    part1: all.part1.find((p) => p.id === String(x.part1)) ?? null,
    card: all.cards.find((c) => c.id === String(x.cueCard)) ?? null,
    part3: (Array.isArray(x.part3) ? x.part3 : []).map((id) => all.part3.find((p) => p.id === String(id))).filter((p): p is SpeakingBank['part3'][number] => Boolean(p)),
  }));
}

export interface SpeakingCopy {
  sessionCopy?: Record<'part1' | 'part3', { label: string; aimSeconds: number[]; hints: string[] }>;
  recording?: { prepSeconds?: number; limitSeconds?: number };
  hub?: { part1?: { title: string; duration: string }; modes?: Array<{ id: string; title: string; duration: string; label: string }>; mockInterview?: { title: string; subtitle: string } };
}

export async function speakingCopy(): Promise<SpeakingCopy> {
  return ((await uiPack()).speaking ?? {}) as SpeakingCopy;
}
