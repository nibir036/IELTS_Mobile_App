'use client';

import { useEffect, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';

/**
 * Renders [children] at the end of <body>. Dialogs and sheets go through
 * this: inside a glass card (backdrop-filter / transform) a `position:
 * fixed` overlay is trapped in that card and the cards after it paint on top.
 */
export function Portal({ children }: { children: ReactNode }) {
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(true), []);
  return ready ? createPortal(children, document.body) : null;
}
