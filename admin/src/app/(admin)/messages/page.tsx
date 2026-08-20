import { Suspense } from 'react';

import { IconAlert, IconMessage } from '@/components/icons';
import {
  Card,
  EmptyState,
  PageHeader,
  Pill,
  StatCard,
  Table,
  formatDateTime,
} from '@/components/ui';
import { UserFilter } from '@/components/user-filter';
import { getMessages, getUsers } from '@/lib/queries';
import { formatPhone } from '@/lib/twilio';

export const dynamic = 'force-dynamic';

export default async function MessagesPage({
  searchParams,
}: PageProps<'/messages'>) {
  const { user } = await searchParams;
  const userId = typeof user === 'string' && user ? user : undefined;

  const [messages, users] = await Promise.all([
    getMessages(userId),
    getUsers(),
  ]);

  const outbound = messages.filter((m) => m.direction === 'outbound').length;
  const failed = messages.filter((m) => m.status === 'failed').length;

  return (
    <>
      <PageHeader
        title="Messages"
        subtitle="SMS traffic across every assigned Twilio number."
        action={
          <Suspense fallback={null}>
            <UserFilter
              users={users.map((row) => ({ id: row.id, name: row.name }))}
            />
          </Suspense>
        }
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard
          label="Messages shown"
          value={messages.length}
          Icon={IconMessage}
        />
        <StatCard label="Outbound" value={outbound} />
        <StatCard
          label="Failed"
          value={failed}
          Icon={IconAlert}
          tone={failed ? 'bad' : 'default'}
        />
      </div>

      <Card className="mt-6">
        {messages.length === 0 ? (
          <EmptyState
            Icon={IconMessage}
            title="No messages logged"
            description={
              userId
                ? 'This user has not sent or received an SMS yet.'
                : 'Messages appear here as soon as the app sends or receives one.'
            }
          />
        ) : (
          <Table
            head={
              <tr>
                <th className="th">User</th>
                <th className="th">Contact</th>
                <th className="th">Body</th>
                <th className="th">Direction</th>
                <th className="th">Status</th>
                <th className="th">When</th>
              </tr>
            }
          >
            {messages.map((message) => (
              <tr key={message.id} className="transition-colors hover:bg-sunken">
                <td className="td font-medium">{message.userName}</td>
                <td className="td">
                  {message.contactName ||
                    formatPhone(
                      message.direction === 'outbound'
                        ? message.to
                        : message.from,
                    )}
                </td>
                <td className="td max-w-80 truncate text-ink-soft">
                  {message.detail}
                </td>
                <td className="td">
                  {message.direction === 'inbound' ? (
                    <Pill>Inbound</Pill>
                  ) : (
                    <Pill tone="brand">Outbound</Pill>
                  )}
                </td>
                <td className="td">
                  <Pill
                    tone={
                      message.status === 'failed'
                        ? 'bad'
                        : message.status === 'delivered'
                          ? 'ok'
                          : 'neutral'
                    }
                  >
                    {message.status}
                  </Pill>
                </td>
                <td className="td text-ink-soft">
                  {formatDateTime(message.at)}
                </td>
              </tr>
            ))}
          </Table>
        )}
      </Card>
    </>
  );
}
