'use client';

import { useEffect } from 'react';

/**
 * No "Save image / audio as…", "Open in new tab" or drag-out on content
 * images and audio inside the student area. The media links themselves
 * refuse anything but the page's own <img> / <audio> (app/media route).
 */
export function MediaGuard() {
  useEffect(() => {
    const isMedia = (t: EventTarget | null) => t instanceof HTMLImageElement || t instanceof HTMLMediaElement;
    const stop = (e: Event) => {
      if (isMedia(e.target)) e.preventDefault();
    };
    document.addEventListener('contextmenu', stop);
    document.addEventListener('dragstart', stop);
    return () => {
      document.removeEventListener('contextmenu', stop);
      document.removeEventListener('dragstart', stop);
    };
  }, []);
  return null;
}
