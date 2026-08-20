import Link from 'next/link';
import { notFound } from 'next/navigation';

import { ActionForm, AssignSelect } from '@/components/action-form';
import {
  Avatar,
  Card,
  EmptyState,
  PageHeader,
  Pill,
  StatCard,
  Table,
  formatDateTime,
  formatDuration,
} from '@/components/ui';
import { getCalls, getMessages, getNumbers, getUserById, getUsers } from '@/lib/queries';
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
        className="mb-4 inline-block text-sm font-semibold text-brand-500 hover:underline"
      >
        ← All users
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
          hint={`${formatDuration(user.talkTimeSec)} talk time`}
        />
        <StatCard label="Messages" value={user.messageCount} />
        <StatCard
          label="Numbers"
          value={user.numbers.length}
          hint={
            user.numbers.length
              ? formatPhone(user.numbers[0].phoneNumber)
              : 'None assigned'
          }
        />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <Card className="p-5">
          <div className="mb-4 flex items-center gap-3">
            <Avatar name={user.name} size={44} />
            <div>
              <h2 className="font-bold text-ink">Profile</h2>
              <p className="text-xs text-ink-soft">
                Joined {formatDateTime(user.createdAt)}
              </p>
            </div>
          </div>

          <ActionForm
            action={updateUserAction}
            submitLabel="Save changes"
            pendingLabel="Saving…"
          >
            <input type="hidden" name="id" value={user.id} />
            <div className="mb-4 grid gap-4 sm:grid-cols-2">
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

          <div className="mt-6 border-t border-line pt-5">
            <p className="mb-2 text-sm font-semibold text-ink">Danger zone</p>
            <p className="mb-3 text-sm text-ink-soft">
              Deleting removes the account, its call and message history, and
              releases any assigned number.
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
          <div className="border-b border-line px-5 py-4">
            <h2 className="font-bold text-ink">Assigned numbers</h2>
            <p className="text-xs text-ink-soft">
              Pick a user on any row to move that number.
            </p>
          </div>
          {assignable.length === 0 ? (
            <EmptyState
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
                    <span className="font-semibold">
                      {formatPhone(number.phoneNumber)}
                    </span>
                    <p className="text-xs text-ink-soft">
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
          <div className="border-b border-line px-5 py-4">
            <h2 className="font-bold text-ink">Recent calls</h2>
          </div>
          {calls.length === 0 ? (
            <EmptyState title="No calls logged" />
          ) : (
            <Table
              head={
                <tr>
                  <th className="th">Contact</th>
                  <th className="th">Direction</th>
                  <th className="th">Duration</th>
                  <th className="th">When</th>
                </tr>
              }
            >
              {calls.slice(0, 15).map((call) => (
                <tr key={call.id}>
                  <td className="td">
                    {call.contactName || formatPhone(
                      call.direction === 'outbound' ? call.to : call.from,
                    )}
                  </td>
                  <td className="td">
                    {call.status === 'missed' ? (
                      <Pill tone="bad">Missed</Pill>
                    ) : (
                      <Pill tone="neutral">
                        {call.direction === 'inbound' ? 'Incoming' : 'Outgoing'}
                      </Pill>
                    )}
                  </td>
                  <td className="td">{call.detail}</td>
                  <td className="td text-ink-soft">{formatDateTime(call.at)}</td>
                </tr>
              ))}
            </Table>
          )}
        </Card>

        <Card>
          <div className="border-b border-line px-5 py-4">
            <h2 className="font-bold text-ink">Recent messages</h2>
          </div>
          {messages.length === 0 ? (
            <EmptyState title="No messages logged" />
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
              {messages.slice(0, 15).map((message) => (
                <tr key={message.id}>
                  <td className="td">
                    {message.contactName || formatPhone(
                      message.direction === 'outbound'
                        ? message.to
                        : message.from,
                    )}
                  </td>
                  <td className="td max-w-64 truncate text-ink-soft">
                    {message.detail}
                  </td>
                  <td className="td">
                    <Pill
                      tone={message.status === 'failed' ? 'bad' : 'neutral'}
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
      </div>
    </>
  );
}
