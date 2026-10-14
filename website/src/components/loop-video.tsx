/** A short, silent, looping module video (the app's LoopVideo). */
export function LoopVideo({ src, label }: { src: string; label: string }) {
  return (
    <video
      src={src}
      aria-label={label}
      autoPlay
      muted
      loop
      playsInline
      preload="metadata"
      style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', pointerEvents: 'none' }}
    />
  );
}
