'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

export interface Clip {
  blob: Blob;
  format: 'webm' | 'm4a' | 'ogg' | 'wav';
  seconds: number;
}

function pickType(): { mime: string; format: Clip['format'] } {
  const options: Array<[string, Clip['format']]> = [
    ['audio/webm;codecs=opus', 'webm'],
    ['audio/webm', 'webm'],
    ['audio/mp4', 'm4a'],
    ['audio/ogg;codecs=opus', 'ogg'],
  ];
  for (const [mime, format] of options) {
    if (typeof MediaRecorder !== 'undefined' && MediaRecorder.isTypeSupported(mime)) return { mime, format };
  }
  return { mime: '', format: 'webm' };
}

/**
 * Microphone recording in the browser (MediaRecorder), with a live level
 * (0..1) for the meter. One stream is kept while the page is open, so the
 * permission prompt shows once.
 */
export function useRecorder() {
  const [error, setError] = useState<string | null>(null);
  const [recording, setRecording] = useState(false);
  const [level, setLevel] = useState(0);
  const [seconds, setSeconds] = useState(0);
  const stream = useRef<MediaStream | null>(null);
  const rec = useRef<MediaRecorder | null>(null);
  const chunks = useRef<Blob[]>([]);
  const started = useRef(0);
  const raf = useRef<number | null>(null);
  const tick = useRef<ReturnType<typeof setInterval> | null>(null);
  const ctx = useRef<AudioContext | null>(null);

  const supported = typeof window !== 'undefined' && !!navigator.mediaDevices?.getUserMedia && typeof MediaRecorder !== 'undefined';

  const ensureStream = useCallback(async () => {
    if (stream.current) return stream.current;
    try {
      const s = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true } });
      stream.current = s;
      // Level meter.
      const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (AC) {
        const c = new AC();
        ctx.current = c;
        const src = c.createMediaStreamSource(s);
        const an = c.createAnalyser();
        an.fftSize = 512;
        src.connect(an);
        const data = new Uint8Array(an.fftSize);
        const loop = () => {
          an.getByteTimeDomainData(data);
          let sum = 0;
          for (const v of data) sum += ((v - 128) / 128) ** 2;
          setLevel(Math.min(1, Math.sqrt(sum / data.length) * 4));
          raf.current = requestAnimationFrame(loop);
        };
        loop();
      }
      setError(null);
      return s;
    } catch {
      setError('Microphone is off. Allow microphone access in your browser (the lock icon in the address bar), then try again.');
      return null;
    }
  }, []);

  const start = useCallback(async () => {
    const s = await ensureStream();
    if (!s) return false;
    const { mime } = pickType();
    const r = new MediaRecorder(s, mime ? { mimeType: mime } : undefined);
    chunks.current = [];
    r.ondataavailable = (e) => {
      if (e.data.size) chunks.current.push(e.data);
    };
    r.start(250);
    rec.current = r;
    started.current = Date.now();
    setSeconds(0);
    setRecording(true);
    tick.current = setInterval(() => setSeconds(Math.floor((Date.now() - started.current) / 1000)), 250);
    return true;
  }, [ensureStream]);

  const stop = useCallback(async (): Promise<Clip | null> => {
    const r = rec.current;
    if (!r) return null;
    if (tick.current) clearInterval(tick.current);
    const secs = Math.max(1, Math.round((Date.now() - started.current) / 1000));
    const done = new Promise<void>((res) => {
      r.onstop = () => res();
    });
    if (r.state !== 'inactive') r.stop();
    await done;
    rec.current = null;
    setRecording(false);
    const type = r.mimeType || pickType().mime || 'audio/webm';
    const format: Clip['format'] = type.includes('mp4') ? 'm4a' : type.includes('ogg') ? 'ogg' : 'webm';
    const blob = new Blob(chunks.current, { type });
    return blob.size > 0 ? { blob, format, seconds: secs } : null;
  }, []);

  useEffect(
    () => () => {
      if (tick.current) clearInterval(tick.current);
      if (raf.current) cancelAnimationFrame(raf.current);
      rec.current?.state !== 'inactive' && rec.current?.stop();
      stream.current?.getTracks().forEach((t) => t.stop());
      void ctx.current?.close().catch(() => undefined);
    },
    [],
  );

  return { supported, error, recording, level, seconds, start, stop, ensureStream };
}

export async function blobToBase64(blob: Blob): Promise<string> {
  const buf = new Uint8Array(await blob.arrayBuffer());
  let bin = '';
  const step = 0x8000;
  for (let i = 0; i < buf.length; i += step) bin += String.fromCharCode(...buf.subarray(i, i + step));
  return btoa(bin);
}

/** Reads a question aloud with the browser's English voice, if it has one. */
export function speak(text: string) {
  try {
    const synth = window.speechSynthesis;
    if (!synth) return;
    synth.cancel();
    const u = new SpeechSynthesisUtterance(text);
    const v = synth.getVoices().find((x) => /^en-(GB|US)/.test(x.lang));
    if (v) u.voice = v;
    u.lang = v?.lang ?? 'en-GB';
    u.rate = 0.95;
    synth.speak(u);
  } catch {
    // No speech: the question is on screen anyway.
  }
}
