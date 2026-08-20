import Link from 'next/link';

import { ActionForm, AssignSelect, Disclosure } from '@/components/action-form';
import { IconHash, IconRefresh } from '@/components/icons';
import {
  Alert,
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
  const fromTwilio = numbers.filter((n) => n.source === 'twilio').length;

  return (
    <>
      <PageHeader
        title="Phone Numbers"
        subtitle="Every number on your Twilio account and the user it belongs to."
        action={
          <ActionForm
            action={syncNumbersAction}
            submitLabel="Sync from Twilio"
            pendingLabel="Syncing…"
            variant="secondary"
            className="w-full sm:w-64"
            submitClassName="w-full"
          />
        }
      />

      {!configured ? (
        <div className="mb-6">
          <Alert tone="warn">
            Twilio is not connected, so syncing will fail.{' '}
            <Link href="/settings" className="font-semibold underline">
              Add your credentials in Settings
            </Link>
            . You can still add numbers by hand below.
          </Alert>
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard
          label="Numbers"
          value={numbers.length}
          Icon={IconHash}
          hint={
            numbers.length
              ? `${fromTwilio} synced from Twilio`
              : 'None imported yet'
          }
        />
        <StatCard
          label="Assigned"
          value={assigned}
          tone={assigned ? 'ok' : 'muted'}
          hint={assigned ? 'In active use' : 'Nobody can call yet'}
        />
        <StatCard
          label="Available"
          value={numbers.length - assigned}
          hint="Ready to hand to a user"
        />
      </div>

      <div className="mt-6">
        <Disclosure
          label="Add a number manually"
          description="For numbers you have not imported from Twilio."
        >
          <ActionForm
            action={addNumberAction}
            submitLabel="Add number"
            pendingLabel="Adding…"
          >
            <div className="mb-5 grid gap-4 sm:grid-cols-3">
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
            Icon={IconHash}
            title="No phone numbers yet"
            description={
              configured
                ? 'Use “Sync from Twilio” above to import every number your account owns, or add one by hand.'
                : 'Connect your Twilio account first, then sync to import every number you own.'
            }
            action={
              configured ? null : (
                <Link href="/settings" className="btn-primary">
                  Connect Twilio
                </Link>
              )
            }
          />
        ) : (
          <Table
            head={
              <tr>
                <th className="th">Number</th>
                <th className="th">Capabilities</th>
                <th className="th">Assigned to</th>
                <th className="th text-right">Usage</th>
                <th className="th">Source</th>
                <th className="th" />
              </tr>
            }
          >
            {numbers.map((number) => (
              <tr key={number.id} className="transition-colors hover:bg-sunken">
                <td className="td">
                  <span className="font-medium tabular-nums">
                    {formatPhone(number.phoneNumber)}
                  </span>
                  <p className="mt-0.5 text-xs text-ink-muted">
                    {number.friendlyName || '—'}
                  </p>
                  {number.status === 'inactive' ? (
                    <span className="mt-1.5 inline-block">
                      <Pill tone="bad">Disabled</Pill>
                    </span>
                  ) : null}
                </td>
                <td className="td">
                  <div className="flex flex-wrap gap-1">
                    {number.capabilities.voice ? <Pill>Voice</Pill> : null}
                    {number.capabilities.sms ? <Pill>SMS</Pill> : null}
                    {number.capabilities.mms ? <Pill>MMS</Pill> : null}
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
                    <p className="mt-1 text-xs text-ink-muted">
                      Since {formatDateTime(number.assignedAt)}
                    </p>
                  ) : null}
                </td>
                <td className="td text-right text-ink-soft tabular-nums">
                  {number.callCount} calls
                  <span className="block">{number.messageCount} messages</span>
                </td>
                <td className="td">
                  {number.source === 'twilio' ? (
                    <Pill tone="brand">Twilio</Pill>
                  ) : (
                    <Pill>Manual</Pill>
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
                      <input type="hidden" name="numberId" value={number.id} />
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
                      <input type="hidden" name="numberId" value={number.id} />
                    </ActionForm>
                  </div>
                </td>
              </tr>
            ))}
          </Table>
        )}
      </Card>

      {numbers.length > 0 && configured ? (
        <p className="mt-4 flex items-center gap-1.5 text-xs text-ink-muted">
          <IconRefresh size={13} />
          Re-syncing updates labels and capabilities; assignments are kept.
        </p>
      ) : null}
    </>
  );
}
