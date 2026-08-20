import Link from 'next/link';

import { ActionForm, Disclosure } from '@/components/action-form';
import { IconChevronRight, IconUsers } from '@/components/icons';
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

      <Disclosure
        label="Add a user"
        description="They sign in to the mobile app with this email and password."
      >
        <ActionForm
          action={createUserAction}
          submitLabel="Create user"
          pendingLabel="Creating…"
        >
          <div className="mb-5 grid gap-4 sm:grid-cols-2">
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
              <p className="mt-1.5 text-xs text-ink-muted">
                Shown in clear text so you can pass it on, then change it.
              </p>
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
                Assign a phone number
              </label>
              <select
                id="numberId"
                name="numberId"
                className="field"
                defaultValue=""
              >
                <option value="">— None for now —</option>
                {freeNumbers.map((number) => (
                  <option key={number.id} value={number.id}>
                    {formatPhone(number.phoneNumber)}
                    {number.friendlyName ? ` · ${number.friendlyName}` : ''}
                  </option>
                ))}
              </select>
              <p className="mt-1.5 text-xs text-ink-muted">
                {numbers.length === 0 ? (
                  <>
                    No numbers imported yet —{' '}
                    <Link href="/numbers" className="text-brand underline">
                      sync your Twilio account
                    </Link>
                    .
                  </>
                ) : freeNumbers.length === 0 ? (
                  <>
                    Every number is taken —{' '}
                    <Link href="/numbers" className="text-brand underline">
                      free one up or add another
                    </Link>
                    .
                  </>
                ) : (
                  `${freeNumbers.length} number(s) available.`
                )}
              </p>
            </div>
          </div>
        </ActionForm>
      </Disclosure>

      <Card className="mt-6">
        {users.length === 0 ? (
          <EmptyState
            Icon={IconUsers}
            title="No users yet"
            description="Create the first account, then give it one of your Twilio numbers."
          />
        ) : (
          <Table
            head={
              <tr>
                <th className="th">User</th>
                <th className="th">Number</th>
                <th className="th">Role</th>
                <th className="th text-right">Calls</th>
                <th className="th text-right">Messages</th>
                <th className="th">Last sign-in</th>
                <th className="th" />
              </tr>
            }
          >
            {users.map((user) => (
              <tr key={user.id} className="transition-colors hover:bg-sunken">
                <td className="td">
                  <div className="flex items-center gap-3">
                    <Avatar name={user.name} />
                    <div className="min-w-0">
                      <Link
                        href={`/users/${user.id}`}
                        className="font-medium text-ink hover:text-brand"
                      >
                        {user.name}
                      </Link>
                      <p className="truncate text-xs text-ink-muted">
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
                        <span key={number.id} className="tabular-nums">
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
                <td className="td text-right tabular-nums">
                  {user.callCount}
                  <span className="block text-xs text-ink-muted">
                    {formatDuration(user.talkTimeSec)}
                  </span>
                </td>
                <td className="td text-right tabular-nums">
                  {user.messageCount}
                </td>
                <td className="td text-ink-soft">
                  {formatDateTime(user.lastLoginAt)}
                </td>
                <td className="td">
                  <div className="flex justify-end">
                    <Link
                      href={`/users/${user.id}`}
                      aria-label={`Manage ${user.name}`}
                      className="btn-ghost px-2 py-1.5"
                    >
                      Manage
                      <IconChevronRight size={15} />
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </Table>
        )}
      </Card>
    </>
  );
}
