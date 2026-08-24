import { Suspense } from 'react';

import {
  IconCallIncoming,
  IconCallMissed,
  IconCallOutgoing,
  IconClock,
  IconPhone,
} from '@/components/icons';
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
import { backfillCallDurations } from '@/lib/call-sync';
import { getCalls, getUsers } from '@/lib/queries';
import { formatPhone } from '@/lib/twilio';

export const dynamic = 'force-dynamic';

export default async function CallsPage({ searchParams }: PageProps<'/calls'>) {
  const { user } = await searchParams;
  const userId = typeof user === 'string' && user ? user : undefined;

  // Calls logged while the app was closed never had their outcome written
  // back, so reconcile the recent ones before reading.
  await backfillCallDurations();
  const [calls, users] = await Promise.all([getCalls(userId), getUsers()]);

  const totalSeconds = calls.reduce(
    (sum, call) => sum + Number(call.detail.replace('s', '') || 0),
    0,
  );
  const failedStates = ['missed', 'failed', 'busy', 'no-answer'];
  const missed = calls.filter((call) =>
    failedStates.includes(call.status),
  ).length;

  return (
    <>
      <PageHeader
        title="Calls"
        subtitle="Every call placed or received through a Vision Connect number."
        action={
          <Suspense fallback={null}>
            <UserFilter
              users={users.map((row) => ({ id: row.id, name: row.name }))}
            />
          </Suspense>
        }
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard label="Calls shown" value={calls.length} Icon={IconPhone} />
        <StatCard
          label="Not connected"
          value={missed}
          Icon={IconCallMissed}
          tone={missed ? 'bad' : 'default'}
        />
        <StatCard
          label="Talk time"
          value={formatDuration(totalSeconds)}
          Icon={IconClock}
        />
      </div>

      <Card className="mt-6">
        {calls.length === 0 ? (
          <EmptyState
            Icon={IconPhone}
            title="No calls logged"
            description={
              userId
                ? 'This user has not made or received a call yet.'
                : 'Calls appear here as soon as the app reports them.'
            }
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
              <tr key={call.id} className="transition-colors hover:bg-sunken">
                <td className="td font-medium">{call.userName}</td>
                <td className="td">
                  {call.contactName ||
                    formatPhone(
                      call.direction === 'outbound' ? call.to : call.from,
                    )}
                </td>
                <td className="td text-ink-soft tabular-nums">
                  {formatPhone(call.from)} → {formatPhone(call.to)}
                </td>
                <td className="td">
                  {/* An unsuccessful call reads as its outcome; only a
                      connected one is described by its direction. */}
                  {call.status === 'missed' ? (
                    <Pill tone="bad">
                      <IconCallMissed size={12} />
                      Missed
                    </Pill>
                  ) : call.status === 'failed' ? (
                    <Pill tone="bad">Failed</Pill>
                  ) : call.status === 'busy' ? (
                    <Pill tone="warn">Busy</Pill>
                  ) : call.status === 'no-answer' ? (
                    <Pill tone="warn">No answer</Pill>
                  ) : call.direction === 'inbound' ? (
                    <Pill>
                      <IconCallIncoming size={12} />
                      Incoming
                    </Pill>
                  ) : (
                    <Pill tone="brand">
                      <IconCallOutgoing size={12} />
                      Outgoing
                    </Pill>
                  )}
                </td>
                <td className="td tabular-nums">{call.detail}</td>
                <td className="td text-ink-soft">{formatDateTime(call.at)}</td>
              </tr>
            ))}
          </Table>
        )}
      </Card>
    </>
  );
}
