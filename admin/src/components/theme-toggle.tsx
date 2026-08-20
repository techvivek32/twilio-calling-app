'use client';

import { useEffect, useSyncExternalStore } from 'react';

import { IconMonitor, IconMoon, IconSun } from './icons';

export type ThemeChoice = 'light' | 'dark' | 'system';

export const THEME_STORAGE_KEY = 'bc-theme';

/**
 * Runs before paint so the saved theme is applied without a flash of the
 * wrong palette. Kept as a string because it is injected into <head>.
 */
export const themeBootstrapScript = `
(function () {
  try {
    var stored = localStorage.getItem('${THEME_STORAGE_KEY}');
    var dark = stored === 'dark' ||
      ((!stored || stored === 'system') &&
        window.matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.classList.toggle('dark', dark);
  } catch (e) {}
})();
`;

/* The stored choice is browser state, so it is read through an external store
 * rather than mirrored into React state inside an effect. */
const listeners = new Set<() => void>();

function subscribe(onChange: () => void) {
  listeners.add(onChange);
  window.addEventListener('storage', onChange);
  return () => {
    listeners.delete(onChange);
    window.removeEventListener('storage', onChange);
  };
}

function getSnapshot(): ThemeChoice {
  const stored = localStorage.getItem(THEME_STORAGE_KEY);
  return stored === 'light' || stored === 'dark' ? stored : 'system';
}

/** The server cannot know the preference; hydration corrects it immediately. */
function getServerSnapshot(): ThemeChoice {
  return 'system';
}

function applyToDocument(choice: ThemeChoice) {
  const dark =
    choice === 'dark' ||
    (choice === 'system' &&
      window.matchMedia('(prefers-color-scheme: dark)').matches);
  document.documentElement.classList.toggle('dark', dark);
}

/**
 * Re-applies the stored theme once React has hydrated. The inline bootstrap
 * script sets the class before paint, but hydration reconciles <html> and can
 * drop it again, so this pins it back.
 */
export function ThemeSync() {
  useEffect(() => {
    applyToDocument(getSnapshot());
  }, []);

  return null;
}

const OPTIONS: { value: ThemeChoice; label: string; Icon: typeof IconSun }[] = [
  { value: 'light', label: 'Light', Icon: IconSun },
  { value: 'dark', label: 'Dark', Icon: IconMoon },
  { value: 'system', label: 'System', Icon: IconMonitor },
];

/** Segmented Light / Dark / System control. */
export function ThemeToggle() {
  const choice = useSyncExternalStore(
    subscribe,
    getSnapshot,
    getServerSnapshot,
  );

  // While on "system", follow the OS as it changes.
  useEffect(() => {
    if (choice !== 'system') return;
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = () => applyToDocument('system');
    media.addEventListener('change', onChange);
    return () => media.removeEventListener('change', onChange);
  }, [choice]);

  function select(value: ThemeChoice) {
    localStorage.setItem(THEME_STORAGE_KEY, value);
    applyToDocument(value);
    listeners.forEach((listener) => listener());
  }

  return (
    <div
      role="radiogroup"
      aria-label="Colour theme"
      className="flex items-center gap-0.5 rounded-lg border border-line bg-sunken p-0.5"
    >
      {OPTIONS.map(({ value, label, Icon }) => {
        const active = choice === value;
        return (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={active}
            aria-label={label}
            title={label}
            onClick={() => select(value)}
            className={`flex flex-1 items-center justify-center rounded-md py-1.5 transition-colors ${
              active
                ? 'bg-surface text-ink shadow-card'
                : 'text-ink-muted hover:text-ink'
            }`}
          >
            <Icon size={16} />
          </button>
        );
      })}
    </div>
  );
}
