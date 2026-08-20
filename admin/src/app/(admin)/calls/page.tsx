import { Suspense } from 'react';

import {
  Card,
  EmptyState,
  PageHeader,
  Pill,
  StatCard,
  Table,
  formatDateTime,
  formatDuration,
} from '@/components/ui';
import { UserFilter } from '@/components/user-filter';
import { getCalls, getUsers } from '@/lib/queries';
import { formatPhone } from '@/lib/twilio';

export const dynamic = 'force-dynamic';

export default async function CallsPage({ searchParams }: PageProps<'/calls'>) {
  const { user } = await searchParams;
  const userId = typeof user === 'string' && user ? user : undefined;

  const [calls, users] = await Promise.all([getCalls(userId), getUsers()]);

  const totalSeconds = calls.reduce(
    (sum, call) => sum + Number(call.detail.replace('s', '') || 0),
    0,
  );
  const missed = calls.filter((call) => call.status === 'missed').length;

  return (
    <>
      <PageHeader
        title="Calls"
        subtitle="Every call placed or received through a Business Connect number."
        action={
          <Suspense fallback={null}>
            <UserFilter
              users={users.map((row) => ({ id: row.id, name: row.name }))}
            />
          </Suspense>
        }
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard label="Calls shown" value={calls.length} />
        <StatCard label="Missed" value={missed} tone={missed ? 'bad' : 'default'} />
        <StatCard label="Talk time" value={formatDuration(totalSeconds)} />
      </div>

      <Card className="mt-6">
        {calls.length === 0 ? (
          <EmptyState
            title="No calls logged"
            description="Calls appear here as soon as the app reports them."
          />
        ) : (
          <Table
            head={
              <tr>
                <th className="th">User</th>
                <th className="th">Contact</th>
                <th className="th">From → To</th>
                <th className="th">Direction</th>
                <th className="th">Duration</th>
                <th className="th">When</th>
              </tr>
            }
          >
            {calls.map((call) => (
              <tr key={call.id} className="hover:bg-surface-muted/60">
                <td className="td font-semibold">{call.userName}</td>
                <td className="td">
                  {call.contactName ||
                    formatPhone(
                      call.direction === 'outbound' ? call.to : call.from,
                    )}
                </td>
                <td className="td text-ink-soft">
                  {formatPhone(call.from)} → {formatPhone(call.to)}
                </td>
                <td className="td">
                  {call.status === 'missed' ? (
                    <Pill tone="bad" dot>
                      Missed
                    </Pill>
                  ) : call.direction === 'inbound' ? (
                    <Pill tone="neutral">Incoming</Pill>
                  ) : (
                    <Pill tone="brand">Outgoing</Pill>
                  )}
                </td>
                <td className="td">{call.detail}</td>
                <td className="td text-ink-soft">{formatDateTime(call.at)}</td>
              </tr>
            ))}
          </Table>
        )}
      </Card>
    </>
  );
}
