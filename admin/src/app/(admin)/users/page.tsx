import Link from 'next/link';

import { ActionForm, Disclosure } from '@/components/action-form';
import {
  Avatar,
  Card,
  EmptyState,
  PageHeader,
  Pill,
  Table,
  formatDateTime,
  formatDuration,
} from '@/components/ui';
import { getNumbers, getUsers } from '@/lib/queries';
import { formatPhone } from '@/lib/twilio';

import { createUserAction } from './actions';

export const dynamic = 'force-dynamic';

export default async function UsersPage() {
  const [users, numbers] = await Promise.all([getUsers(), getNumbers()]);
  const freeNumbers = numbers.filter((number) => !number.assignedTo);

  return (
    <>
      <PageHeader
        title="Users"
        subtitle="App accounts, the number each one dials from, and their usage."
      />

      <Disclosure label="Add a user">
        <ActionForm
          action={createUserAction}
          submitLabel="Create user"
          pendingLabel="Creating…"
        >
          <div className="mb-4 grid gap-4 sm:grid-cols-2">
            <div>
              <label className="field-label" htmlFor="name">
                Full name
              </label>
              <input id="name" name="name" required className="field" />
            </div>
            <div>
              <label className="field-label" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                name="email"
                type="email"
                required
                className="field"
              />
            </div>
            <div>
              <label className="field-label" htmlFor="password">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="text"
                minLength={8}
                required
                className="field"
                placeholder="At least 8 characters"
              />
            </div>
            <div>
              <label className="field-label" htmlFor="role">
                Role
              </label>
              <select id="role" name="role" className="field" defaultValue="user">
                <option value="user">App user</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="field-label" htmlFor="numberId">
                Assign a phone number (optional)
              </label>
              <select id="numberId" name="numberId" className="field" defaultValue="">
                <option value="">— None —</option>
                {freeNumbers.map((number) => (
                  <option key={number.id} value={number.id}>
                    {formatPhone(number.phoneNumber)}
                    {number.friendlyName ? ` · ${number.friendlyName}` : ''}
                  </option>
                ))}
              </select>
              {freeNumbers.length === 0 ? (
                <p className="mt-1.5 text-xs text-ink-soft">
                  Every number is taken.{' '}
                  <Link href="/numbers" className="font-semibold text-brand-500">
                    Sync or add more numbers
                  </Link>
                  .
                </p>
              ) : null}
            </div>
          </div>
        </ActionForm>
      </Disclosure>

      <Card className="mt-6">
        {users.length === 0 ? (
          <EmptyState
            title="No users yet"
            description="Create the first app account to hand out a number."
          />
        ) : (
          <Table
            head={
              <tr>
                <th className="th">User</th>
                <th className="th">Number</th>
                <th className="th">Role</th>
                <th className="th">Calls</th>
                <th className="th">Messages</th>
                <th className="th">Last login</th>
                <th className="th" />
              </tr>
            }
          >
            {users.map((user) => (
              <tr key={user.id} className="hover:bg-surface-muted/60">
                <td className="td">
                  <div className="flex items-center gap-3">
                    <Avatar name={user.name} />
                    <div className="min-w-0">
                      <Link
                        href={`/users/${user.id}`}
                        className="font-semibold text-ink hover:text-brand-500"
                      >
                        {user.name}
                      </Link>
                      <p className="truncate text-xs text-ink-soft">
                        {user.email}
                      </p>
                    </div>
                  </div>
                </td>
                <td className="td">
                  {user.numbers.length === 0 ? (
                    <Pill tone="warn">No number</Pill>
                  ) : (
                    <div className="flex flex-col gap-1">
                      {user.numbers.map((number) => (
                        <span key={number.id} className="font-medium">
                          {formatPhone(number.phoneNumber)}
                        </span>
                      ))}
                    </div>
                  )}
                </td>
                <td className="td">
                  {user.role === 'admin' ? (
                    <Pill tone="brand">Admin</Pill>
                  ) : user.status === 'active' ? (
                    <Pill tone="ok" dot>
                      Active
                    </Pill>
                  ) : (
                    <Pill tone="bad" dot>
                      Suspended
                    </Pill>
                  )}
                </td>
                <td className="td">
                  {user.callCount}
                  <span className="block text-xs text-ink-soft">
                    {formatDuration(user.talkTimeSec)}
                  </span>
                </td>
                <td className="td">{user.messageCount}</td>
                <td className="td text-ink-soft">
                  {formatDateTime(user.lastLoginAt)}
                </td>
                <td className="td text-right">
                  <Link
                    href={`/users/${user.id}`}
                    className="text-sm font-semibold text-brand-500 hover:underline"
                  >
                    Manage
                  </Link>
                </td>
              </tr>
            ))}
          </Table>
        )}
      </Card>
    </>
  );
}
