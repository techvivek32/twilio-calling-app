import { ActionForm } from '@/components/action-form';
import { IconLink } from '@/components/icons';
import {
  Card,
  CardHeader,
  DetailRow,
  PageHeader,
  Pill,
  formatDateTime,
} from '@/components/ui';
import { decryptSecret, maskSecret } from '@/lib/crypto';
import { serverAddresses } from '@/lib/network';
import { loadSettings } from '@/lib/twilio';

import { saveSettingsAction, testConnectionAction } from './actions';

export const dynamic = 'force-dynamic';

export default async function SettingsPage() {
  const settings = await loadSettings();
  const addresses = serverAddresses();

  const authTokenSet = Boolean(settings.authTokenEnc);
  const apiSecretSet = Boolean(settings.apiKeySecretEnc);
  const connected = Boolean(settings.accountSid && authTokenSet);
  const voiceReady = Boolean(
    settings.apiKeySid && apiSecretSet && settings.twimlAppSid,
  );

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

      <div className="grid gap-6 xl:grid-cols-[1.5fr_1fr]">
        <Card>
          <CardHeader
            title="Account credentials"
            description="From the Twilio Console. Secrets are encrypted with AES-256-GCM before they reach the database and are never sent back to this page."
          />
          <div className="p-5">
            <ActionForm
              action={saveSettingsAction}
              submitLabel="Save settings"
              pendingLabel="Saving…"
            >
              <fieldset className="mb-6">
                <legend className="eyebrow mb-3">Required for calls & SMS</legend>
                <div className="grid gap-4">
                  <div>
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
                  <div>
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
                          ? `Stored ${maskSecret(decryptSecret(settings.authTokenEnc ?? ''))} — leave blank to keep`
                          : 'Your Twilio auth token'
                      }
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
                </div>
              </fieldset>

              <fieldset className="mb-6 border-t border-line pt-5">
                <legend className="eyebrow mb-3">
                  Optional — in-app voice
                </legend>
                <div className="grid gap-4 sm:grid-cols-2">
                  <div>
                    <label className="field-label" htmlFor="apiKeySid">
                      API Key SID
                    </label>
                    <input
                      id="apiKeySid"
                      name="apiKeySid"
                      className="field font-mono"
                      defaultValue={settings.apiKeySid ?? ''}
                      placeholder="SKxxxxxxxx"
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
                        apiSecretSet
                          ? 'Stored — leave blank to keep'
                          : 'API key secret'
                      }
                    />
                  </div>
                  <div className="sm:col-span-2">
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
                </div>
              </fieldset>

              <fieldset className="mb-6 border-t border-line pt-5">
                <legend className="eyebrow mb-3">
                  Optional — inbound webhooks
                </legend>
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
                <p className="mt-2 text-xs leading-relaxed text-ink-muted">
                  Where Twilio reaches this server. Point each number&apos;s
                  webhooks at{' '}
                  <code className="rounded border border-line bg-sunken px-1.5 py-0.5 font-mono text-ink-soft">
                    /api/twilio/voice
                  </code>{' '}
                  and{' '}
                  <code className="rounded border border-line bg-sunken px-1.5 py-0.5 font-mono text-ink-soft">
                    /api/twilio/sms
                  </code>
                  .
                </p>
              </fieldset>
            </ActionForm>
          </div>
        </Card>

        <div className="flex flex-col gap-6">
          <Card>
            <CardHeader
              title="Connection"
              description="Calls the Twilio API with the saved credentials."
            />
            <div className="p-5">
              <dl className="divide-y divide-line">
                <DetailRow label="Account SID">
                  <span className="font-mono text-xs">
                    {settings.accountSid || '—'}
                  </span>
                </DetailRow>
                <DetailRow label="Auth token">
                  {authTokenSet ? (
                    <Pill tone="ok">Stored</Pill>
                  ) : (
                    <Pill tone="warn">Missing</Pill>
                  )}
                </DetailRow>
                <DetailRow label="In-app voice">
                  {voiceReady ? (
                    <Pill tone="ok">Ready</Pill>
                  ) : (
                    <Pill>Not set up</Pill>
                  )}
                </DetailRow>
                <DetailRow label="Last verified">
                  {formatDateTime(settings.lastVerifiedAt)}
                </DetailRow>
              </dl>

              {settings.lastVerifyError ? (
                <p className="mt-4 rounded-lg border border-bad/25 bg-bad-soft px-3 py-2 text-xs leading-relaxed text-bad">
                  {settings.lastVerifyError}
                </p>
              ) : null}

              <div className="mt-5">
                <ActionForm
                  action={testConnectionAction}
                  submitLabel="Test connection"
                  pendingLabel="Contacting Twilio…"
                  variant="secondary"
                  submitClassName="w-full"
                />
              </div>
            </div>
          </Card>

          <Card>
            <CardHeader
              title="Server address"
              description="Type one of these into Server address on the app's sign-in screen, then press Test connection."
            />
            <ul className="divide-y divide-line">
              {addresses.map((address) => (
                <li key={address.url} className="px-5 py-3">
                  <p className="font-mono text-sm text-ink">{address.url}</p>
                  <p className="mt-0.5 text-xs text-ink-muted">
                    {address.external
                      ? `A phone on the same network as "${address.label}"`
                      : address.label}
                  </p>
                </li>
              ))}
              {addresses.every((address) => !address.external) ? (
                <li className="px-5 py-3 text-xs leading-relaxed text-warn">
                  This machine has no network address right now, so a physical
                  phone cannot reach it. Connect to Wi-Fi and reload.
                </li>
              ) : null}
            </ul>
            <p className="border-t border-line px-5 py-3 text-xs leading-relaxed text-ink-muted">
              A network address is handed out by DHCP and changes when this
              machine reconnects — if the app stops connecting, check back here.
            </p>
          </Card>

          <Card>
            <CardHeader
              title="Mobile API"
              description="Endpoints the Flutter app calls. Users sign in with the credentials you set on the Users page."
            />
            <ul className="divide-y divide-line">
              {[
                'POST /api/mobile/auth/login',
                'GET  /api/mobile/me',
                'GET  POST /api/mobile/calls',
                'GET  POST /api/mobile/messages',
                'GET  POST /api/mobile/contacts',
                'GET  /api/mobile/voice-token',
              ].map((route) => (
                <li
                  key={route}
                  className="flex items-center gap-2 px-5 py-2.5 font-mono text-xs text-ink-soft"
                >
                  <span className="text-ink-muted">
                    <IconLink size={13} />
                  </span>
                  {route}
                </li>
              ))}
            </ul>
          </Card>
        </div>
      </div>
    </>
  );
}
