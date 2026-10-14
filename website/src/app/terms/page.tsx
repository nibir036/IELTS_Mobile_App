import type { Metadata } from 'next';
import { LegalPage } from '@/components/legal';

export const metadata: Metadata = { title: 'Terms of Use' };

export default function Terms() {
  return <LegalPage which="terms" />;
}
