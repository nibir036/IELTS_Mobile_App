import type { Metadata } from 'next';
import { LegalPage } from '@/components/legal';

export const metadata: Metadata = { title: 'Privacy Policy' };

export default function Privacy() {
  return <LegalPage which="privacy" />;
}
