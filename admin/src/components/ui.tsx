import type { ComponentType, ReactNode } from 'react';

export function Card({
  children,
  className = '',
}: {
  children: ReactNode;
  className?: string;
}) {
  return <section className={`card ${className}`}>{children}</section>;
}

export function CardHeader({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-3 border-b border-line px-5 py-4">
      <div className="min-w-0">
        <h2 className="text-[15px] font-semibold tracking-tight text-ink">
          {title}
        </h2>
        {description ? (
          <p className="mt-0.5 text-sm text-ink-soft">{description}</p>
        ) : null}
      </div>
      {action}
    </div>
  );
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
    <header className="mb-6 flex flex-wrap items-start justify-between gap-4 border-b border-line pb-5">
      <div className="min-w-0">
        <h1 className="text-[22px] font-semibold tracking-tight text-ink">
          {title}
        </h1>
        {subtitle ? (
          <p className="mt-1 max-w-2xl text-sm text-ink-soft">{subtitle}</p>
        ) : null}
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </header>
  );
}

export function StatCard({
  label,
  value,
  hint,
  Icon,
  tone = 'default',
}: {
  label: string;
  value: string | number;
  hint?: string;
  Icon?: ComponentType<{ size?: number }>;
  tone?: 'default' | 'ok' | 'bad' | 'muted';
}) {
  const valueTone = {
    default: 'text-ink',
    ok: 'text-ok',
    bad: 'text-bad',
    muted: 'text-ink-muted',
  }[tone];

  return (
    <div className="card p-5">
      <div className="flex items-start justify-between gap-3">
        <p className="eyebrow">{label}</p>
        {Icon ? (
          <span className="text-ink-muted">
            <Icon size={18} />
          </span>
        ) : null}
      </div>
      <p
        className={`mt-3 text-[28px] font-semibold leading-none tracking-tight tabular-nums ${valueTone}`}
      >
        {value}
      </p>
      {hint ? <p className="mt-2 text-sm text-ink-soft">{hint}</p> : null}
    </div>
  );
}

type PillTone = 'ok' | 'bad' | 'warn' | 'neutral' | 'brand';

const PILL_TONES: Record<PillTone, string> = {
  ok: 'border-ok/25 bg-ok-soft text-ok',
  bad: 'border-bad/25 bg-bad-soft text-bad',
  warn: 'border-warn/25 bg-warn-soft text-warn',
  brand: 'border-brand/25 bg-brand-soft text-brand',
  neutral: 'border-line bg-sunken text-ink-soft',
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
      {dot ? <span className="size-1.5 rounded-full bg-current" /> : null}
      {children}
    </span>
  );
}

export function EmptyState({
  title,
  description,
  Icon,
  action,
}: {
  title: string;
  description?: string;
  Icon?: ComponentType<{ size?: number }>;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 px-6 py-16 text-center">
      {Icon ? (
        <span className="flex size-11 items-center justify-center rounded-full border border-line bg-sunken text-ink-muted">
          <Icon size={20} />
        </span>
      ) : null}
      <p className="text-[15px] font-semibold text-ink">{title}</p>
      {description ? (
        <p className="max-w-md text-sm leading-relaxed text-ink-soft">
          {description}
        </p>
      ) : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  );
}

export function Avatar({ name, size = 36 }: { name: string; size?: number }) {
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
      className="inline-flex shrink-0 items-center justify-center rounded-full border border-line bg-sunken font-semibold text-ink-soft"
      style={{ width: size, height: size, fontSize: size * 0.36 }}
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
      <table className="w-full min-w-170 border-collapse">
        <thead className="border-b border-line bg-sunken">{head}</thead>
        <tbody className="divide-y divide-line">{children}</tbody>
      </table>
    </div>
  );
}

export function Alert({
  tone,
  children,
}: {
  tone: 'ok' | 'bad' | 'warn' | 'brand';
  children: ReactNode;
}) {
  const tones = {
    ok: 'border-ok/25 bg-ok-soft text-ok',
    bad: 'border-bad/25 bg-bad-soft text-bad',
    warn: 'border-warn/25 bg-warn-soft text-warn',
    brand: 'border-brand/25 bg-brand-soft text-brand',
  } as const;

  return (
    <div
      className={`rounded-lg border px-4 py-3 text-sm leading-relaxed ${tones[tone]}`}
    >
      {children}
    </div>
  );
}

/** Key/value line used by the detail cards. */
export function DetailRow({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-4 py-2.5">
      <dt className="text-sm text-ink-soft">{label}</dt>
      <dd className="min-w-0 text-right text-sm font-medium text-ink">
        {children}
      </dd>
    </div>
  );
}

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
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const rest = seconds % 60;
  if (hours) return `${hours}h ${minutes}m`;
  return minutes ? `${minutes}m ${rest}s` : `${rest}s`;
}
