import Link from 'next/link';

import {
  Card,
  PageHeader,
  Pill,
  StatCard,
  Table,
  formatDateTime,
  formatDuration,
} from '@/components/ui';
import { getCalls, getDashboardStats, getMessages, getUsers } from '@/lib/queries';
import { formatPhone, loadTwilioConfig } from '@/lib/twilio';

export const dynamic = 'force-dynamic';

export default async function DashboardPage() {
  const [stats, users, calls, messages, twilio] = await Promise.all([
    getDashboardStats(),
    getUsers(),
    getCalls(),
    getMessages(),
    loadTwilioConfig(),
  ]);

  const configured = Boolean(twilio.accountSid && twilio.authToken);
  const topUsers = [...users]
    .filter((user) => user.role === 'user')
    .sort(
      (a, b) =>
        b.callCount + b.messageCount - (a.callCount + a.messageCount),
    )
    .slice(0, 5);

  const recent = [...calls.slice(0, 6), ...messages.slice(0, 6)]
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
    .slice(0, 8);

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle="Usage across every Business Connect user and Twilio number."
      />

      {!configured ? (
        <div className="mb-6 rounded-lg border border-warn/30 bg-warn-soft px-4 py-3 text-sm text-warn">
          Twilio is not connected yet.{' '}
          <Link href="/settings" className="font-bold underline">
            Add your Account SID and Auth Token
          </Link>{' '}
          to sync numbers and place real calls.
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Users"
          value={stats.users.total}
          hint={`${stats.users.active} active · ${stats.users.admins} admin`}
        />
        <StatCard
          label="Phone numbers"
          value={stats.numbers.total}
          hint={`${stats.numbers.assigned} assigned · ${stats.numbers.unassigned} free`}
        />
        <StatCard
          label="Calls today"
          value={stats.calls.today}
          hint={`${stats.calls.total} all time · ${formatDuration(stats.calls.talkTimeSec)} talk time`}
        />
        <StatCard
          label="Messages today"
          value={stats.messages.today}
          hint={`${stats.messages.total} all time`}
        />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_1fr]">
        <Card>
          <div className="flex items-center justify-between border-b border-line px-5 py-4">
            <h2 className="font-bold text-ink">Busiest users</h2>
            <Link
              href="/users"
              className="text-sm font-semibold text-brand-500 hover:underline"
            >
              All users
            </Link>
          </div>
          {topUsers.length === 0 ? (
            <p className="px-5 py-8 text-center text-sm text-ink-soft">
              No app users yet.
            </p>
          ) : (
            <Table
              head={
                <tr>
                  <th className="th">User</th>
                  <th className="th">Number</th>
                  <th className="th">Calls</th>
                  <th className="th">Messages</th>
                </tr>
              }
            >
              {topUsers.map((user) => (
                <tr key={user.id}>
                  <td className="td">
                    <Link
                      href={`/users/${user.id}`}
                      className="font-semibold text-ink hover:text-brand-500"
                    >
                      {user.name}
                    </Link>
                    <p className="text-xs text-ink-soft">{user.email}</p>
                  </td>
                  <td className="td">
                    {user.numbers.length ? (
                      <span className="font-medium">
                        {formatPhone(user.numbers[0].phoneNumber)}
                      </span>
                    ) : (
                      <Pill tone="warn">No number</Pill>
                    )}
                  </td>
                  <td className="td">{user.callCount}</td>
                  <td className="td">{user.messageCount}</td>
                </tr>
              ))}
            </Table>
          )}
        </Card>

        <Card>
          <div className="border-b border-line px-5 py-4">
            <h2 className="font-bold text-ink">Recent activity</h2>
          </div>
          {recent.length === 0 ? (
            <p className="px-5 py-8 text-center text-sm text-ink-soft">
              Nothing logged yet.
            </p>
          ) : (
            <ul className="divide-y divide-line">
              {recent.map((item) => (
                <li key={`${item.kind}-${item.id}`} className="px-5 py-3.5">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold text-ink">
                        {item.kind === 'call' ? '📞' : '💬'}{' '}
                        {item.contactName || formatPhone(item.to)}
                      </p>
                      <p className="truncate text-xs text-ink-soft">
                        {item.userName} ·{' '}
                        {item.direction === 'inbound' ? 'Inbound' : 'Outbound'}{' '}
                        · {item.kind === 'call' ? item.detail : item.status}
                      </p>
                    </div>
                    <span className="shrink-0 text-xs text-ink-muted">
                      {formatDateTime(item.at)}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </>
  );
}
