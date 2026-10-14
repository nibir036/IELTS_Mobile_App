import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const site = (process.env.SITE_URL || 'http://localhost:3000').replace(/\/+$/, '');
  return ['', '/signup', '/login', '/terms', '/privacy'].map((p) => ({
    url: `${site}${p}`,
    changeFrequency: p === '' ? 'weekly' : 'monthly',
    priority: p === '' ? 1 : 0.5,
  }));
}
