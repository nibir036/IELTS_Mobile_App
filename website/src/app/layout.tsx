import type { Metadata, Viewport } from 'next';
import { Outfit } from 'next/font/google';
import type { ReactNode } from 'react';
import './globals.css';

// The app's typeface (google_fonts: Outfit).
const outfit = Outfit({ subsets: ['latin'], variable: '--font-outfit', display: 'swap' });

const siteUrl = process.env.SITE_URL || 'http://localhost:3000';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'IELTS AI by nextED: practise IELTS with instant AI band scores',
    template: '%s · IELTS AI by nextED',
  },
  description:
    'Practise IELTS Writing, Speaking, Listening and Reading with instant AI band scores, full mock tests and a study plan built around your exam date.',
  applicationName: 'IELTS AI by nextED',
  icons: { icon: '/branding/app_icon.png', apple: '/branding/app_icon.png' },
  openGraph: {
    type: 'website',
    siteName: 'IELTS AI by nextED',
    images: ['/branding/ielts-ai-mascot-full.png'],
  },
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#fbf5f3' },
    { media: '(prefers-color-scheme: dark)', color: '#0d0f1a' },
  ],
};

// Applies a saved Day / Night choice before the first paint (no flash).
const themeScript = `try{var t=localStorage.getItem('ia_theme');if(t==='day'||t==='night')document.documentElement.setAttribute('data-theme',t)}catch(e){}`;

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={outfit.variable} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,400,0..1,0&display=block"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
