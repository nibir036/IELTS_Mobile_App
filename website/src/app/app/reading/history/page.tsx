import type { Metadata } from 'next';
import { HistoryList } from '@/components/history-list';
import { attempts } from '@/lib/server/attempts';

export const metadata: Metadata = { title: 'Reading history' };

export default async function ReadingHistory() {
  const list = (await attempts({ skill: 'reading', limit: 300 })).filter((a) => a.kind !== 'lesson');
  return <HistoryList title="Reading history" back="/app/reading" backLabel="Reading" items={list} base="/app/reading/result" />;
}
