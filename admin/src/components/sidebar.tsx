'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';

const LINKS = [
  { href: '/dashboard', label: 'Dashboard', icon: '▦' },
  { href: '/users', label: 'Users', icon: '👤' },
  { href: '/numbers', label: 'Phone Numbers', icon: '☎' },
  { href: '/calls', label: 'Calls', icon: '📞' },
  { href: '/messages', label: 'Messages', icon: '💬' },
  { href: '/settings', label: 'Twilio Settings', icon: '⚙' },
] as const;

export function Sidebar({
  adminName,
  adminEmail,
}: {
  adminName: string;
  adminEmail: string;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  const nav = (
    <nav className="flex flex-col gap-1">
      {LINKS.map((link) => {
        const active =
          pathname === link.href || pathname.startsWith(`${link.href}/`);
        return (
          <Link
            key={link.href}
            href={link.href}
            onClick={() => setOpen(false)}
            className={`flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-semibold transition-colors ${
              active
                ? 'bg-brand-500 text-white'
                : 'text-ink-soft hover:bg-surface-muted hover:text-ink'
            }`}
          >
            <span aria-hidden className="w-5 text-center text-base">
              {link.icon}
            </span>
            {link.label}
          </Link>
        );
      })}
    </nav>
  );

  return (
    <>
      {/* Mobile bar */}
      <div className="flex items-center justify-between border-b border-line bg-surface px-4 py-3 lg:hidden">
        <span className="font-extrabold text-brand-500">Business Connect</span>
        <button
          type="button"
          className="btn-secondary px-3 py-1.5"
          onClick={() => setOpen((value) => !value)}
          aria-expanded={open}
        >
          {open ? 'Close' : 'Menu'}
        </button>
      </div>

      {open ? (
        <div className="border-b border-line bg-surface px-4 py-3 lg:hidden">
          {nav}
          <form action="/api/auth/logout" method="post" className="mt-3">
            <button type="submit" className="btn-secondary w-full">
              Sign out
            </button>
          </form>
        </div>
      ) : null}

      {/* Desktop rail */}
      <aside aria-label="Main navigation" className="hidden w-64 shrink-0 flex-col border-r border-line bg-surface p-4 lg:flex">
        <div className="mb-6 px-2">
          <p className="text-lg font-extrabold tracking-tight text-brand-500">
            Business Connect
          </p>
          <p className="text-xs font-semibold uppercase tracking-wider text-ink-muted">
            Admin panel
          </p>
        </div>

        {nav}

        <div className="mt-auto border-t border-line pt-4">
          <p className="truncate px-2 text-sm font-semibold text-ink">
            {adminName}
          </p>
          <p className="truncate px-2 text-xs text-ink-soft">{adminEmail}</p>
          <form action="/api/auth/logout" method="post" className="mt-3">
            <button type="submit" className="btn-secondary w-full">
              Sign out
            </button>
          </form>
        </div>
      </aside>
    </>
  );
}
