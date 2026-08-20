import Link from 'next/link';

import { ActionForm, AssignSelect, Disclosure } from '@/components/action-form';
import {
  Card,
  EmptyState,
  PageHeader,
  Pill,
  StatCard,
  Table,
  formatDateTime,
} from '@/components/ui';
import { getNumbers, getUsers } from '@/lib/queries';
import { formatPhone, loadTwilioConfig } from '@/lib/twilio';

import {
  addNumberAction,
  assignNumberAction,
  deleteNumberAction,
  setNumberStatusAction,
  syncNumbersAction,
} from './actions';

export const dynamic = 'force-dynamic';

export default async function NumbersPage() {
  const [numbers, users, twilio] = await Promise.all([
    getNumbers(),
    getUsers(),
    loadTwilioConfig(),
  ]);

  const configured = Boolean(twilio.accountSid && twilio.authToken);
  const userOptions = users.map((user) => ({ id: user.id, name: user.name }));
  const assigned = numbers.filter((number) => number.assignedTo).length;
  const fromTwilio = numbers.filter((number) => number.source === 'twilio').length;

  return (
    <>
      <PageHeader
        title="Phone Numbers"
        subtitle="Every number on the Twilio account and the user it belongs to."
        action={
          <ActionForm
            action={syncNumbersAction}
            submitLabel="Sync from Twilio"
            pendingLabel="Syncing…"
            variant="secondary"
            className="min-w-56"
          />
        }
      />

      {!configured ? (
        <div className="mb-6 rounded-lg border border-warn/30 bg-warn-soft px-4 py-3 text-sm text-warn">
          Twilio is not connected, so syncing will fail.{' '}
          <Link href="/settings" className="font-bold underline">
            Add credentials in Settings
          </Link>
          . You can still add numbers by hand below.
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard
          label="Numbers on account"
          value={numbers.length}
          hint={`${fromTwilio} synced from Twilio`}
        />
        <StatCard label="Assigned" value={assigned} tone="ok" />
        <StatCard
          label="Available"
          value={numbers.length - assigned}
          hint="Ready to hand to a user"
        />
      </div>

      <div className="mt-6">
        <Disclosure label="Add a number manually">
          <ActionForm
            action={addNumberAction}
            submitLabel="Add number"
            pendingLabel="Adding…"
          >
            <div className="mb-4 grid gap-4 sm:grid-cols-3">
              <div>
                <label className="field-label" htmlFor="phoneNumber">
                  Phone number
                </label>
                <input
                  id="phoneNumber"
                  name="phoneNumber"
                  required
                  className="field"
                  placeholder="+1 555 012 3456"
                />
              </div>
              <div>
                <label className="field-label" htmlFor="friendlyName">
                  Label
                </label>
                <input
                  id="friendlyName"
                  name="friendlyName"
                  className="field"
                  placeholder="Sales line"
                />
              </div>
              <div>
                <label className="field-label" htmlFor="assignedTo">
                  Assign to
                </label>
                <select
                  id="assignedTo"
                  name="assignedTo"
                  className="field"
                  defaultValue=""
                >
                  <option value="">— Unassigned —</option>
                  {users.map((user) => (
                    <option key={user.id} value={user.id}>
                      {user.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </ActionForm>
        </Disclosure>
      </div>

      <Card className="mt-6">
        {numbers.length === 0 ? (
          <EmptyState
            title="No numbers yet"
            description="Sync your Twilio account to pull in every number you own, or add one by hand."
          />
        ) : (
          <Table
            head={
              <tr>
                <th className="th">Number</th>
                <th className="th">Capabilities</th>
                <th className="th">Assigned to</th>
                <th className="th">Usage</th>
                <th className="th">Source</th>
                <th className="th" />
              </tr>
            }
          >
            {numbers.map((number) => (
              <tr key={number.id} className="hover:bg-surface-muted/60">
                <td className="td">
                  <span className="font-semibold">
                    {formatPhone(number.phoneNumber)}
                  </span>
                  <p className="text-xs text-ink-soft">
                    {number.friendlyName || '—'}
                  </p>
                  {number.status === 'inactive' ? (
                    <span className="mt-1 inline-block">
                      <Pill tone="bad">Inactive</Pill>
                    </span>
                  ) : null}
                </td>
                <td className="td">
                  <div className="flex flex-wrap gap-1">
                    {number.capabilities.voice ? (
                      <Pill tone="neutral">Voice</Pill>
                    ) : null}
                    {number.capabilities.sms ? (
                      <Pill tone="neutral">SMS</Pill>
                    ) : null}
                    {number.capabilities.mms ? (
                      <Pill tone="neutral">MMS</Pill>
                    ) : null}
                  </div>
                </td>
                <td className="td">
                  <AssignSelect
                    action={assignNumberAction}
                    numberId={number.id}
                    currentUserId={number.assignedTo?.id ?? null}
                    users={userOptions}
                  />
                  {number.assignedTo ? (
                    <p className="mt-1 text-xs text-ink-soft">
                      Since {formatDateTime(number.assignedAt)}
                    </p>
                  ) : null}
                </td>
                <td className="td text-ink-soft">
                  {number.callCount} calls
                  <span className="block">{number.messageCount} messages</span>
                </td>
                <td className="td">
                  {number.source === 'twilio' ? (
                    <Pill tone="brand">Twilio</Pill>
                  ) : (
                    <Pill tone="neutral">Manual</Pill>
                  )}
                </td>
                <td className="td">
                  <div className="flex justify-end gap-2">
                    <ActionForm
                      action={setNumberStatusAction}
                      submitLabel={
                        number.status === 'active' ? 'Disable' : 'Enable'
                      }
                      variant="secondary"
                      submitClassName="px-3 py-1.5 text-xs"
                      hideFeedback
                    >
                      <input
                        type="hidden"
                        name="numberId"
                        value={number.id}
                      />
                      <input
                        type="hidden"
                        name="status"
                        value={number.status === 'active' ? 'inactive' : 'active'}
                      />
                    </ActionForm>
                    <ActionForm
                      action={deleteNumberAction}
                      submitLabel="Remove"
                      variant="danger"
                      submitClassName="px-3 py-1.5 text-xs"
                      confirm={`Remove ${number.phoneNumber} from the panel? The number stays on your Twilio account.`}
                      hideFeedback
                    >
                      <input
                        type="hidden"
                        name="numberId"
                        value={number.id}
                      />
                    </ActionForm>
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
