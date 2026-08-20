import type { ReactNode } from 'react';

export function Card({
  children,
  className = '',
}: {
  children: ReactNode;
  className?: string;
}) {
  return <div className={`card ${className}`}>{children}</div>;
}

export function PageHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-ink">{title}</h1>
        {subtitle ? (
          <p className="mt-1 text-sm text-ink-soft">{subtitle}</p>
        ) : null}
      </div>
      {action}
    </div>
  );
}

export function StatCard({
  label,
  value,
  hint,
  tone = 'default',
}: {
  label: string;
  value: string | number;
  hint?: string;
  tone?: 'default' | 'ok' | 'bad';
}) {
  const valueTone =
    tone === 'ok' ? 'text-ok-ink' : tone === 'bad' ? 'text-bad' : 'text-ink';

  return (
    <Card className="p-5">
      <p className="card-label">{label}</p>
      <p className={`mt-2 text-3xl font-extrabold tracking-tight ${valueTone}`}>
        {value}
      </p>
      {hint ? <p className="mt-1 text-sm text-ink-soft">{hint}</p> : null}
    </Card>
  );
}

type PillTone = 'ok' | 'bad' | 'warn' | 'neutral' | 'brand';

const PILL_TONES: Record<PillTone, string> = {
  ok: 'bg-ok-soft text-ok-ink',
  bad: 'bg-bad-soft text-bad',
  warn: 'bg-warn-soft text-warn',
  brand: 'bg-brand-100 text-brand-700',
  neutral: 'bg-surface-muted text-ink-soft',
};

export function Pill({
  children,
  tone = 'neutral',
  dot = false,
}: {
  children: ReactNode;
  tone?: PillTone;
  dot?: boolean;
}) {
  return (
    <span className={`pill ${PILL_TONES[tone]}`}>
      {dot ? (
        <span className="size-1.5 rounded-full bg-current opacity-80" />
      ) : null}
      {children}
    </span>
  );
}

export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-6 py-14 text-center">
      <p className="text-base font-semibold text-ink">{title}</p>
      {description ? (
        <p className="max-w-md text-sm text-ink-soft">{description}</p>
      ) : null}
      {action ? <div className="mt-3">{action}</div> : null}
    </div>
  );
}

export function Avatar({
  name,
  size = 36,
}: {
  name: string;
  size?: number;
}) {
  const initials =
    name
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase() || '?';

  return (
    <span
      className="inline-flex shrink-0 items-center justify-center rounded-full border border-line bg-brand-50 font-bold text-brand-700"
      style={{ width: size, height: size, fontSize: size * 0.38 }}
    >
      {initials}
    </span>
  );
}

export function Table({
  head,
  children,
}: {
  head: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[640px] border-collapse">
        <thead className="border-b border-line bg-surface-muted">{head}</thead>
        <tbody className="divide-y divide-line">{children}</tbody>
      </table>
    </div>
  );
}

export function Alert({
  tone,
  children,
}: {
  tone: 'ok' | 'bad' | 'warn';
  children: ReactNode;
}) {
  const tones = {
    ok: 'border-ok/30 bg-ok-soft text-ok-ink',
    bad: 'border-bad/30 bg-bad-soft text-bad',
    warn: 'border-warn/30 bg-warn-soft text-warn',
  } as const;

  return (
    <div className={`rounded-lg border px-4 py-3 text-sm ${tones[tone]}`}>
      {children}
    </div>
  );
}

/** Formats an ISO date for the admin tables. */
export function formatDateTime(value: string | Date | null | undefined) {
  if (!value) return '—';
  const date = typeof value === 'string' ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

export function formatDuration(seconds: number) {
  if (!seconds) return '0s';
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return minutes ? `${minutes}m ${rest}s` : `${rest}s`;
}
