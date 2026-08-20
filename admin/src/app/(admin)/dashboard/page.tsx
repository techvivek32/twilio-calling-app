import Link from 'next/link';

import {
  IconCallIncoming,
  IconCallMissed,
  IconCallOutgoing,
  IconCheck,
  IconHash,
  IconInbox,
  IconMessage,
  IconPhone,
  IconUsers,
} from '@/components/icons';
import {
  Card,
  CardHeader,
  EmptyState,
  PageHeader,
  Pill,
  StatCard,
  Table,
  formatDateTime,
  formatDuration,
} from '@/components/ui';
import {
  getCalls,
  getDashboardStats,
  getMessages,
  getNumbers,
  getUsers,
} from '@/lib/queries';
import { formatPhone, loadTwilioConfig } from '@/lib/twilio';

export const dynamic = 'force-dynamic';

/** Ordered setup steps shown until the panel is fully configured. */
function SetupChecklist({
  twilioReady,
  numberCount,
  userCount,
  assignedCount,
}: {
  twilioReady: boolean;
  numberCount: number;
  userCount: number;
  assignedCount: number;
}) {
  const steps = [
    {
      done: twilioReady,
      title: 'Connect your Twilio account',
      body: 'Add the Account SID and Auth Token, then run Test connection.',
      href: '/settings',
      cta: 'Open settings',
    },
    {
      done: numberCount > 0,
      title: 'Import your phone numbers',
      body: 'Sync pulls every number your Twilio account owns into the panel.',
      href: '/numbers',
      cta: 'Sync numbers',
    },
    {
      done: userCount > 0,
      title: 'Create app users',
      body: 'Each person who signs in to the mobile app needs an account here.',
      href: '/users',
      cta: 'Add a user',
    },
    {
      done: assignedCount > 0,
      title: 'Assign a number to each user',
      body: 'A user can only call and text once they own a number.',
      href: '/numbers',
      cta: 'Assign numbers',
    },
  ];

  const next = steps.find((step) => !step.done);
  if (!next) return null;

  const completed = steps.filter((step) => step.done).length;

  return (
    <Card className="mb-6">
      <CardHeader
        title="Finish setting up"
        description={`${completed} of ${steps.length} steps complete`}
      />
      <ol className="divide-y divide-line">
        {steps.map((step) => (
          <li
            key={step.title}
            className="flex flex-wrap items-center gap-3 px-5 py-3.5"
          >
            <span
              className={`flex size-6 shrink-0 items-center justify-center rounded-full border ${
                step.done
                  ? 'border-ok/30 bg-ok-soft text-ok'
                  : 'border-line bg-sunken text-ink-muted'
              }`}
            >
              {step.done ? <IconCheck size={13} /> : null}
            </span>
            <span className="min-w-0 flex-1">
              <span
                className={`block text-sm font-medium ${
                  step.done ? 'text-ink-muted line-through' : 'text-ink'
                }`}
              >
                {step.title}
              </span>
              {!step.done ? (
                <span className="mt-0.5 block text-sm text-ink-soft">
                  {step.body}
                </span>
              ) : null}
            </span>
            {step === next ? (
              <Link href={step.href} className="btn-secondary shrink-0 py-2">
                {step.cta}
              </Link>
            ) : null}
          </li>
        ))}
      </ol>
    </Card>
  );
}

export default async function DashboardPage() {
  const [stats, users, numbers, calls, messages, twilio] = await Promise.all([
    getDashboardStats(),
    getUsers(),
    getNumbers(),
    getCalls(),
    getMessages(),
    loadTwilioConfig(),
  ]);

  const twilioReady = Boolean(twilio.accountSid && twilio.authToken);
  const appUsers = users.filter((user) => user.role === 'user');

  const topUsers = [...appUsers]
    .sort((a, b) => b.callCount + b.messageCount - (a.callCount + a.messageCount))
    .slice(0, 5);

  const recent = [...calls.slice(0, 8), ...messages.slice(0, 8)]
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
    .slice(0, 8);

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle="Usage across every Business Connect user and Twilio number."
      />

      <SetupChecklist
        twilioReady={twilioReady}
        numberCount={numbers.length}
        userCount={appUsers.length}
        assignedCount={stats.numbers.assigned}
      />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="App users"
          value={appUsers.length}
          Icon={IconUsers}
          hint={
            appUsers.length
              ? `${stats.users.active} active · ${stats.users.admins} admin`
              : 'No app accounts yet'
          }
        />
        <StatCard
          label="Phone numbers"
          value={stats.numbers.total}
          Icon={IconHash}
          hint={
            stats.numbers.total
              ? `${stats.numbers.assigned} assigned · ${stats.numbers.unassigned} free`
              : 'Sync from Twilio to import'
          }
        />
        <StatCard
          label="Calls today"
          value={stats.calls.today}
          Icon={IconPhone}
          hint={`${stats.calls.total} all time · ${formatDuration(stats.calls.talkTimeSec)} talk time`}
        />
        <StatCard
          label="Messages today"
          value={stats.messages.today}
          Icon={IconMessage}
          hint={`${stats.messages.total} all time`}
        />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.25fr_1fr]">
        <Card>
          <CardHeader
            title="Busiest users"
            action={
              appUsers.length ? (
                <Link
                  href="/users"
                  className="text-sm font-medium text-brand hover:underline"
                >
                  View all
                </Link>
              ) : null
            }
          />
          {topUsers.length === 0 ? (
            <EmptyState
              Icon={IconUsers}
              title="No app users yet"
              description="Create an account for each person who will use the mobile app."
              action={
                <Link href="/users" className="btn-primary">
                  Add a user
                </Link>
              }
            />
          ) : (
            <Table
              head={
                <tr>
                  <th className="th">User</th>
                  <th className="th">Number</th>
                  <th className="th text-right">Calls</th>
                  <th className="th text-right">Messages</th>
                </tr>
              }
            >
              {topUsers.map((user) => (
                <tr key={user.id} className="transition-colors hover:bg-sunken">
                  <td className="td">
                    <Link
                      href={`/users/${user.id}`}
                      className="font-medium text-ink hover:text-brand"
                    >
                      {user.name}
                    </Link>
                    <p className="mt-0.5 text-xs text-ink-muted">{user.email}</p>
                  </td>
                  <td className="td">
                    {user.numbers.length ? (
                      <span className="tabular-nums">
                        {formatPhone(user.numbers[0].phoneNumber)}
                      </span>
                    ) : (
                      <Pill tone="warn">No number</Pill>
                    )}
                  </td>
                  <td className="td text-right tabular-nums">
                    {user.callCount}
                  </td>
                  <td className="td text-right tabular-nums">
                    {user.messageCount}
                  </td>
                </tr>
              ))}
            </Table>
          )}
        </Card>

        <Card>
          <CardHeader title="Recent activity" />
          {recent.length === 0 ? (
            <EmptyState
              Icon={IconInbox}
              title="Nothing logged yet"
              description="Calls and messages appear here as soon as the app reports them."
            />
          ) : (
            <ul className="divide-y divide-line">
              {recent.map((item) => {
                const missed = item.status === 'missed';
                const Icon =
                  item.kind === 'message'
                    ? IconMessage
                    : missed
                      ? IconCallMissed
                      : item.direction === 'inbound'
                        ? IconCallIncoming
                        : IconCallOutgoing;

                return (
                  <li
                    key={`${item.kind}-${item.id}`}
                    className="flex items-start gap-3 px-5 py-3.5"
                  >
                    <span
                      className={`mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-full border ${
                        missed
                          ? 'border-bad/25 bg-bad-soft text-bad'
                          : 'border-line bg-sunken text-ink-soft'
                      }`}
                    >
                      <Icon size={15} />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-medium text-ink">
                        {item.contactName || formatPhone(item.to)}
                      </span>
                      <span className="mt-0.5 block truncate text-xs text-ink-muted">
                        {item.userName} ·{' '}
                        {item.direction === 'inbound' ? 'Inbound' : 'Outbound'} ·{' '}
                        {item.kind === 'call' ? item.detail : item.status}
                      </span>
                    </span>
                    <span className="shrink-0 text-xs text-ink-muted">
                      {formatDateTime(item.at)}
                    </span>
                  </li>
                );
              })}
            </ul>
          )}
        </Card>
      </div>
    </>
  );
}
