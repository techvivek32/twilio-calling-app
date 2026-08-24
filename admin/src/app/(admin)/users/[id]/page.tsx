import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ActionForm, AssignSelect } from '@/components/action-form';
import {
  IconArrowLeft,
  IconCallMissed,
  IconHash,
  IconMessage,
  IconPhone,
} from '@/components/icons';
import {
  Avatar,
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
  getMessages,
  getNumbers,
  getUserById,
  getUsers,
} from '@/lib/queries';
import { formatPhone } from '@/lib/twilio';

import { assignNumberAction } from '../../numbers/actions';
import { deleteUserAction, updateUserAction } from '../actions';

export const dynamic = 'force-dynamic';

export default async function UserDetailPage({
  params,
}: PageProps<'/users/[id]'>) {
  const { id } = await params;

  const [user, numbers, allUsers, calls, messages] = await Promise.all([
    getUserById(id),
    getNumbers(),
    getUsers(),
    getCalls(id),
    getMessages(id),
  ]);

  if (!user) notFound();

  const userOptions = allUsers.map((row) => ({ id: row.id, name: row.name }));
  const assignable = numbers.filter(
    (number) => !number.assignedTo || number.assignedTo.id === user.id,
  );

  return (
    <>
      <Link
        href="/users"
        className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-ink-soft transition-colors hover:text-brand"
      >
        <IconArrowLeft size={15} />
        All users
      </Link>

      <PageHeader
        title={user.name}
        subtitle={user.email}
        action={
          <div className="flex items-center gap-2">
            {user.role === 'admin' ? <Pill tone="brand">Admin</Pill> : null}
            {user.status === 'active' ? (
              <Pill tone="ok" dot>
                Active
              </Pill>
            ) : (
              <Pill tone="bad" dot>
                Suspended
              </Pill>
            )}
          </div>
        }
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard
          label="Calls"
          value={user.callCount}
          Icon={IconPhone}
          hint={`${formatDuration(user.talkTimeSec)} talk time`}
        />
        <StatCard
          label="Messages"
          value={user.messageCount}
          Icon={IconMessage}
        />
        <StatCard
          label="Numbers"
          value={user.numbers.length}
          Icon={IconHash}
          tone={user.numbers.length ? 'default' : 'muted'}
          hint={
            user.numbers.length
              ? formatPhone(user.numbers[0].phoneNumber)
              : 'None assigned'
          }
        />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <Card>
          <CardHeader
            title="Profile"
            description={`Joined ${formatDateTime(user.createdAt)}`}
            action={<Avatar name={user.name} size={40} />}
          />
          <div className="p-5">
            <ActionForm
              action={updateUserAction}
              submitLabel="Save changes"
              pendingLabel="Saving…"
            >
              <input type="hidden" name="id" value={user.id} />
              <div className="mb-5 grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="field-label" htmlFor="u-name">
                    Full name
                  </label>
                  <input
                    id="u-name"
                    name="name"
                    defaultValue={user.name}
                    className="field"
                  />
                </div>
                <div>
                  <label className="field-label" htmlFor="u-email">
                    Email
                  </label>
                  <input
                    id="u-email"
                    name="email"
                    type="email"
                    defaultValue={user.email}
                    className="field"
                  />
                </div>
                <div>
                  <label className="field-label" htmlFor="u-role">
                    Role
                  </label>
                  <select
                    id="u-role"
                    name="role"
                    defaultValue={user.role}
                    className="field"
                  >
                    <option value="user">App user</option>
                    <option value="admin">Admin</option>
                  </select>
                </div>
                <div>
                  <label className="field-label" htmlFor="u-status">
                    Status
                  </label>
                  <select
                    id="u-status"
                    name="status"
                    defaultValue={user.status}
                    className="field"
                  >
                    <option value="active">Active</option>
                    <option value="suspended">Suspended</option>
                  </select>
                </div>
                <div className="sm:col-span-2">
                  <label className="field-label" htmlFor="u-personal">
                    Their own phone
                  </label>
                  <input
                    id="u-personal"
                    name="personalNumber"
                    defaultValue={user.personalNumber}
                    className="field"
                    placeholder="+91 98765 43210"
                  />
                  <p className="mt-1.5 text-xs leading-relaxed text-ink-muted">
                    Calls from the app ring this phone first, then connect the
                    person they dialled — with their business number shown as
                    the caller ID. Without it they cannot place calls.
                  </p>
                </div>
                <div className="sm:col-span-2">
                  <label className="field-label" htmlFor="u-password">
                    New password
                  </label>
                  <input
                    id="u-password"
                    name="password"
                    type="text"
                    className="field"
                    placeholder="Leave blank to keep the current password"
                  />
                </div>
              </div>
            </ActionForm>
          </div>

          <div className="border-t border-line bg-sunken p-5">
            <p className="text-sm font-semibold text-ink">Delete this user</p>
            <p className="mt-1 mb-3 text-sm leading-relaxed text-ink-soft">
              Removes the account, its call and message history, and releases
              any assigned number. This cannot be undone.
            </p>
            <ActionForm
              action={deleteUserAction}
              submitLabel="Delete user"
              pendingLabel="Deleting…"
              variant="danger"
              confirm={`Delete ${user.name} and all of their history?`}
            >
              <input type="hidden" name="id" value={user.id} />
            </ActionForm>
          </div>
        </Card>

        <Card>
          <CardHeader
            title="Phone numbers"
            description="Change the owner on any row to move that number."
          />
          {assignable.length === 0 ? (
            <EmptyState
              Icon={IconHash}
              title="No numbers available"
              description="Sync your Twilio account or add a number first."
              action={
                <Link href="/numbers" className="btn-secondary">
                  Go to numbers
                </Link>
              }
            />
          ) : (
            <Table
              head={
                <tr>
                  <th className="th">Number</th>
                  <th className="th">Assigned to</th>
                </tr>
              }
            >
              {assignable.map((number) => (
                <tr key={number.id}>
                  <td className="td">
                    <span className="font-medium tabular-nums">
                      {formatPhone(number.phoneNumber)}
                    </span>
                    <p className="mt-0.5 text-xs text-ink-muted">
                      {number.friendlyName || '—'}
                    </p>
                  </td>
                  <td className="td">
                    <AssignSelect
                      action={assignNumberAction}
                      numberId={number.id}
                      currentUserId={number.assignedTo?.id ?? null}
                      users={userOptions}
                    />
                  </td>
                </tr>
              ))}
            </Table>
          )}
        </Card>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <Card>
          <CardHeader
            title="Recent calls"
            action={
              calls.length ? (
                <Link
                  href={`/calls?user=${user.id}`}
                  className="text-sm font-medium text-brand hover:underline"
                >
                  View all
                </Link>
              ) : null
            }
          />
          {calls.length === 0 ? (
            <EmptyState Icon={IconPhone} title="No calls logged" />
          ) : (
            <Table
              head={
                <tr>
                  <th className="th">Contact</th>
                  <th className="th">Direction</th>
                  <th className="th text-right">Duration</th>
                  <th className="th">When</th>
                </tr>
              }
            >
              {calls.slice(0, 10).map((call) => (
                <tr key={call.id}>
                  <td className="td">
                    {call.contactName ||
                      formatPhone(
                        call.direction === 'outbound' ? call.to : call.from,
                      )}
                  </td>
                  <td className="td">
                    {call.status === 'missed' ? (
                      <Pill tone="bad">
                        <IconCallMissed size={12} />
                        Missed
                      </Pill>
                    ) : (
                      <Pill>
                        {call.direction === 'inbound' ? 'Incoming' : 'Outgoing'}
                      </Pill>
                    )}
                  </td>
                  <td className="td text-right tabular-nums">{call.detail}</td>
                  <td className="td text-ink-soft">{formatDateTime(call.at)}</td>
                </tr>
              ))}
            </Table>
          )}
        </Card>

        <Card>
          <CardHeader
            title="Recent messages"
            action={
              messages.length ? (
                <Link
                  href={`/messages?user=${user.id}`}
                  className="text-sm font-medium text-brand hover:underline"
                >
                  View all
                </Link>
              ) : null
            }
          />
          {messages.length === 0 ? (
            <EmptyState Icon={IconMessage} title="No messages logged" />
          ) : (
            <Table
              head={
                <tr>
                  <th className="th">Contact</th>
                  <th className="th">Message</th>
                  <th className="th">Status</th>
                  <th className="th">When</th>
                </tr>
              }
            >
              {messages.slice(0, 10).map((message) => (
                <tr key={message.id}>
                  <td className="td">
                    {message.contactName ||
                      formatPhone(
                        message.direction === 'outbound'
                          ? message.to
                          : message.from,
                      )}
                  </td>
                  <td className="td max-w-64 truncate text-ink-soft">
                    {message.detail}
                  </td>
                  <td className="td">
                    <Pill tone={message.status === 'failed' ? 'bad' : 'neutral'}>
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
      </div>
    </>
  );
}
