import type { Metadata } from 'next';
import { HistoryList } from '@/components/history-list';
import { attempts } from '@/lib/server/attempts';

export const metadata: Metadata = { title: 'Listening history' };

export default async function ListeningHistory() {
  const list = (await attempts({ skill: 'listening', limit: 300 })).filter((a) => a.kind !== 'lesson');
  return <HistoryList title="Listening history" back="/app/listening" backLabel="Listening" items={list} base="/app/listening/result" />;
}
