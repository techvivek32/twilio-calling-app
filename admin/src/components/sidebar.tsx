'use client';

import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, type ComponentType } from 'react';

import {
  IconClose,
  IconDashboard,
  IconHash,
  IconLogout,
  IconMenu,
  IconMessage,
  IconPhone,
  IconSettings,
  IconUsers,
} from './icons';
import { ThemeToggle } from './theme-toggle';

type NavLink = {
  href: string;
  label: string;
  Icon: ComponentType<{ size?: number }>;
};

const LINKS: NavLink[] = [
  { href: '/dashboard', label: 'Dashboard', Icon: IconDashboard },
  { href: '/users', label: 'Users', Icon: IconUsers },
  { href: '/numbers', label: 'Phone Numbers', Icon: IconHash },
  { href: '/calls', label: 'Calls', Icon: IconPhone },
  { href: '/messages', label: 'Messages', Icon: IconMessage },
  { href: '/settings', label: 'Twilio Settings', Icon: IconSettings },
];

function Wordmark() {
  return (
    <div className="flex items-center gap-2.5">
      <Image
        src="/logo-mark.png"
        alt=""
        width={36}
        height={36}
        className="size-9 shrink-0 rounded-lg"
        priority
      />
      <span className="min-w-0">
        <span className="block truncate text-[15px] font-semibold tracking-tight text-ink">
          Vision Connect
        </span>
        <span className="block eyebrow">Admin</span>
      </span>
    </div>
  );
}

function NavList({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();

  return (
    <nav className="flex flex-col gap-0.5">
      {LINKS.map(({ href, label, Icon }) => {
        const active = pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            href={href}
            onClick={onNavigate}
            aria-current={active ? 'page' : undefined}
            className={`group flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              active
                ? 'bg-brand-soft text-brand'
                : 'text-ink-soft hover:bg-sunken hover:text-ink'
            }`}
          >
            <span
              className={
                active
                  ? 'text-brand'
                  : 'text-ink-muted transition-colors group-hover:text-ink-soft'
              }
            >
              <Icon size={18} />
            </span>
            {label}
          </Link>
        );
      })}
    </nav>
  );
}

function AccountFooter({
  adminName,
  adminEmail,
}: {
  adminName: string;
  adminEmail: string;
}) {
  const initials =
    adminName
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase() || 'A';

  return (
    <div className="space-y-3">
      <ThemeToggle />
      <div className="flex items-center gap-2.5 rounded-lg border border-line bg-sunken px-3 py-2.5">
        <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-brand-muted text-xs font-semibold text-brand">
          {initials}
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-medium text-ink">
            {adminName}
          </span>
          <span className="block truncate text-xs text-ink-muted">
            {adminEmail}
          </span>
        </span>
        <form action="/api/auth/logout" method="post">
          <button
            type="submit"
            title="Sign out"
            aria-label="Sign out"
            className="flex size-8 items-center justify-center rounded-md text-ink-muted transition-colors hover:bg-surface hover:text-bad"
          >
            <IconLogout size={16} />
          </button>
        </form>
      </div>
    </div>
  );
}

export function Sidebar({
  adminName,
  adminEmail,
}: {
  adminName: string;
  adminEmail: string;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  // Never leave the drawer covering the page after a route change (including
  // browser back/forward). Adjusted during render rather than in an effect.
  const [seenPath, setSeenPath] = useState(pathname);
  if (seenPath !== pathname) {
    setSeenPath(pathname);
    setOpen(false);
  }

  return (
    <>
      {/* Mobile top bar */}
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-line bg-surface px-4 py-3 lg:hidden">
        <Wordmark />
        <button
          type="button"
          onClick={() => setOpen((value) => !value)}
          aria-expanded={open}
          aria-label={open ? 'Close menu' : 'Open menu'}
          className="flex size-9 items-center justify-center rounded-lg border border-line text-ink-soft transition-colors hover:bg-sunken"
        >
          {open ? <IconClose size={18} /> : <IconMenu size={18} />}
        </button>
      </header>

      {open ? (
        <div className="border-b border-line bg-surface px-4 py-4 lg:hidden">
          <NavList onNavigate={() => setOpen(false)} />
          <div className="mt-4">
            <AccountFooter adminName={adminName} adminEmail={adminEmail} />
          </div>
        </div>
      ) : null}

      {/* Desktop rail */}
      <aside
        aria-label="Main navigation"
        className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col border-r border-line bg-surface p-4 lg:flex"
      >
        <div className="px-1 pb-6">
          <Wordmark />
        </div>
        <NavList />
        <div className="mt-auto pt-4">
          <AccountFooter adminName={adminName} adminEmail={adminEmail} />
        </div>
      </aside>
    </>
  );
}
