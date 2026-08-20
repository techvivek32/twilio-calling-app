import { ActionForm } from '@/components/action-form';
import { Card, PageHeader, Pill, formatDateTime } from '@/components/ui';
import { decryptSecret, maskSecret } from '@/lib/crypto';
import { loadSettings } from '@/lib/twilio';

import { saveSettingsAction, testConnectionAction } from './actions';

export const dynamic = 'force-dynamic';

export default async function SettingsPage() {
  const settings = await loadSettings();

  const authTokenSet = Boolean(settings.authTokenEnc);
  const apiSecretSet = Boolean(settings.apiKeySecretEnc);
  const connected = Boolean(settings.accountSid && authTokenSet);

  return (
    <>
      <PageHeader
        title="Twilio Settings"
        subtitle="Credentials used for every call and message the app sends."
        action={
          connected ? (
            <Pill tone="ok" dot>
              Configured
            </Pill>
          ) : (
            <Pill tone="warn" dot>
              Not configured
            </Pill>
          )
        }
      />

      <div className="grid gap-6 xl:grid-cols-[1.4fr_1fr]">
        <Card className="p-5">
          <h2 className="mb-1 font-bold text-ink">Account credentials</h2>
          <p className="mb-5 text-sm text-ink-soft">
            Find these in the Twilio Console. Secrets are encrypted with
            AES-256-GCM before they touch the database and are never sent back
            to this page.
          </p>

          <ActionForm
            action={saveSettingsAction}
            submitLabel="Save settings"
            pendingLabel="Saving…"
          >
            <div className="mb-5 grid gap-4 sm:grid-cols-2">
              <div className="sm:col-span-2">
                <label className="field-label" htmlFor="accountSid">
                  Account SID
                </label>
                <input
                  id="accountSid"
                  name="accountSid"
                  className="field font-mono"
                  defaultValue={settings.accountSid ?? ''}
                  placeholder="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="field-label" htmlFor="authToken">
                  Auth Token
                </label>
                <input
                  id="authToken"
                  name="authToken"
                  type="password"
                  className="field font-mono"
                  placeholder={
                    authTokenSet
                      ? `Stored (${maskSecret(decryptSecret(settings.authTokenEnc ?? ''))}) — leave blank to keep`
                      : 'Your Twilio auth token'
                  }
                />
              </div>

              <div>
                <label className="field-label" htmlFor="apiKeySid">
                  API Key SID
                </label>
                <input
                  id="apiKeySid"
                  name="apiKeySid"
                  className="field font-mono"
                  defaultValue={settings.apiKeySid ?? ''}
                  placeholder="SKxxxxxxxx (for Voice SDK tokens)"
                />
              </div>

              <div>
                <label className="field-label" htmlFor="apiKeySecret">
                  API Key Secret
                </label>
                <input
                  id="apiKeySecret"
                  name="apiKeySecret"
                  type="password"
                  className="field font-mono"
                  placeholder={
                    apiSecretSet ? 'Stored — leave blank to keep' : 'API key secret'
                  }
                />
              </div>

              <div>
                <label className="field-label" htmlFor="twimlAppSid">
                  TwiML App SID
                </label>
                <input
                  id="twimlAppSid"
                  name="twimlAppSid"
                  className="field font-mono"
                  defaultValue={settings.twimlAppSid ?? ''}
                  placeholder="APxxxxxxxx"
                />
              </div>

              <div>
                <label className="field-label" htmlFor="defaultCallerId">
                  Default caller ID
                </label>
                <input
                  id="defaultCallerId"
                  name="defaultCallerId"
                  className="field"
                  defaultValue={settings.defaultCallerId ?? ''}
                  placeholder="+15550123456"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="field-label" htmlFor="webhookBaseUrl">
                  Public webhook base URL
                </label>
                <input
                  id="webhookBaseUrl"
                  name="webhookBaseUrl"
                  className="field"
                  defaultValue={settings.webhookBaseUrl ?? ''}
                  placeholder="https://your-tunnel.ngrok.app"
                />
                <p className="mt-1.5 text-xs text-ink-soft">
                  Where Twilio reaches this server for voice and SMS webhooks.
                  Point your number&apos;s webhooks at{' '}
                  <code className="rounded bg-surface-muted px-1 py-0.5">
                    /api/twilio/voice
                  </code>{' '}
                  and{' '}
                  <code className="rounded bg-surface-muted px-1 py-0.5">
                    /api/twilio/sms
                  </code>
                  .
                </p>
              </div>
            </div>
          </ActionForm>
        </Card>

        <div className="flex flex-col gap-6">
          <Card className="p-5">
            <h2 className="mb-1 font-bold text-ink">Connection</h2>
            <p className="mb-4 text-sm text-ink-soft">
              Calls the Twilio API with the saved credentials and reports what
              it finds.
            </p>

            <dl className="mb-4 space-y-2 text-sm">
              <div className="flex justify-between gap-3">
                <dt className="text-ink-soft">Account SID</dt>
                <dd className="truncate font-mono text-xs">
                  {settings.accountSid || '—'}
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-ink-soft">Auth token</dt>
                <dd>
                  {authTokenSet ? (
                    <Pill tone="ok">Stored</Pill>
                  ) : (
                    <Pill tone="warn">Missing</Pill>
                  )}
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-ink-soft">Voice SDK keys</dt>
                <dd>
                  {settings.apiKeySid && apiSecretSet && settings.twimlAppSid ? (
                    <Pill tone="ok">Ready</Pill>
                  ) : (
                    <Pill tone="neutral">Optional</Pill>
                  )}
                </dd>
              </div>
              <div className="flex justify-between gap-3">
                <dt className="text-ink-soft">Last verified</dt>
                <dd>{formatDateTime(settings.lastVerifiedAt)}</dd>
              </div>
            </dl>

            {settings.lastVerifyError ? (
              <p className="mb-4 rounded-lg border border-bad/30 bg-bad-soft px-3 py-2 text-xs text-bad">
                {settings.lastVerifyError}
              </p>
            ) : null}

            <ActionForm
              action={testConnectionAction}
              submitLabel="Test connection"
              pendingLabel="Contacting Twilio…"
              variant="secondary"
              submitClassName="w-full"
            />
          </Card>

          <Card className="p-5">
            <h2 className="mb-1 font-bold text-ink">Mobile API</h2>
            <p className="mb-3 text-sm text-ink-soft">
              Point the Flutter app at this server. Users sign in with the
              email and password you set on the Users page.
            </p>
            <ul className="space-y-1.5 text-xs text-ink-soft">
              <li>
                <code className="rounded bg-surface-muted px-1.5 py-0.5">
                  POST /api/mobile/auth/login
                </code>
              </li>
              <li>
                <code className="rounded bg-surface-muted px-1.5 py-0.5">
                  GET /api/mobile/me
                </code>
              </li>
              <li>
                <code className="rounded bg-surface-muted px-1.5 py-0.5">
                  GET/POST /api/mobile/calls
                </code>
              </li>
              <li>
                <code className="rounded bg-surface-muted px-1.5 py-0.5">
                  GET/POST /api/mobile/messages
                </code>
              </li>
              <li>
                <code className="rounded bg-surface-muted px-1.5 py-0.5">
                  GET/POST /api/mobile/contacts
                </code>
              </li>
            </ul>
          </Card>
        </div>
      </div>
    </>
  );
}
