'use client';

import { useEffect } from 'react';

/**
 * Stamps `data-hydrated` on <body> once React has taken over the page.
 * End-to-end tests wait on it so they never click a button whose handler is
 * not attached yet.
 */
export function HydrationMarker() {
  useEffect(() => {
    document.body.dataset.hydrated = 'true';
    return () => {
      delete document.body.dataset.hydrated;
    };
  }, []);

  return null;
}
