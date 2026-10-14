/** Server-only settings (never NEXT_PUBLIC_: nothing here reaches the browser). */
export const env = {
  apiBaseUrl: (process.env.API_BASE_URL || 'http://localhost:4000').replace(/\/+$/, ''),
  appKey: process.env.APP_KEY || '',
  siteUrl: (process.env.SITE_URL || 'http://localhost:3000').replace(/\/+$/, ''),
};
