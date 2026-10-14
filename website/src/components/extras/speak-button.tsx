'use client';

import { Icon } from '../ui';

/** Reads [text] aloud with the browser's English voice (the app's SpeakButton / Tts). */
export function SpeakButton({ text, label, className, size = 18 }: { text: string; label?: string; className?: string; size?: number }) {
  return (
    <button
      type="button"
      className={className}
      aria-label={label ?? `Listen: ${text}`}
      title={label ?? 'Listen'}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        const synth = typeof window !== 'undefined' ? window.speechSynthesis : undefined;
        if (!synth) return;
        synth.cancel();
        const u = new SpeechSynthesisUtterance(text);
        u.lang = 'en-GB';
        u.rate = 0.9;
        const voice = synth.getVoices().find((v) => v.lang === 'en-GB') ?? synth.getVoices().find((v) => v.lang.startsWith('en'));
        if (voice) u.voice = voice;
        synth.speak(u);
      }}
    >
      <Icon name="volume_up" size={size} />
    </button>
  );
}
