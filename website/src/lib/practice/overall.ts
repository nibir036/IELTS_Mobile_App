/** IELTS overall: the average rounded to the nearest half band (.25 and .75 round up). */
export function overallBand(bands: number[]): number {
  if (!bands.length) return 0;
  const avg = bands.reduce((a, b) => a + b, 0) / bands.length;
  const floor = Math.floor(avg);
  const frac = avg - floor;
  return frac < 0.25 ? floor : frac < 0.75 ? floor + 0.5 : floor + 1;
}

export const roundHalf = (v: number) => Math.min(9, Math.max(0, Math.round(v * 2) / 2));
