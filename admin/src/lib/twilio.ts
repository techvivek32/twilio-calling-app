import twilio, { type Twilio } from 'twilio';

import { decryptSecret } from './crypto';
import { connectToDatabase } from './db';
import { Setting } from './models';

export type TwilioConfig = {
  accountSid: string;
  authToken: string;
  apiKeySid: string;
  apiKeySecret: string;
  twimlAppSid: string;
  webhookBaseUrl: string;
  defaultCallerId: string;
};

/** Loads the singleton settings document, creating it on first access. */
export async function loadSettings() {
  await connectToDatabase();
  const existing = await Setting.findOne({ key: 'twilio' });
  if (existing) return existing;
  return Setting.create({ key: 'twilio' });
}

export async function loadTwilioConfig(): Promise<TwilioConfig> {
  const settings = await loadSettings();
  return {
    accountSid: settings.accountSid ?? '',
    authToken: decryptSecret(settings.authTokenEnc ?? ''),
    apiKeySid: settings.apiKeySid ?? '',
    apiKeySecret: decryptSecret(settings.apiKeySecretEnc ?? ''),
    twimlAppSid: settings.twimlAppSid ?? '',
    webhookBaseUrl: settings.webhookBaseUrl ?? '',
    defaultCallerId: settings.defaultCallerId ?? '',
  };
}

export class TwilioNotConfiguredError extends Error {
  constructor() {
    super(
      'Twilio is not configured. Add your Account SID and Auth Token on the Settings page.',
    );
    this.name = 'TwilioNotConfiguredError';
  }
}

/** Returns a Twilio REST client, or throws if credentials are missing. */
export async function getTwilioClient(): Promise<Twilio> {
  const config = await loadTwilioConfig();
  if (!config.accountSid || !config.authToken) {
    throw new TwilioNotConfiguredError();
  }
  return twilio(config.accountSid, config.authToken);
}

export type AccountSnapshot = {
  friendlyName: string;
  status: string;
  type: string;
  numberCount: number;
};

/** Verifies credentials by fetching the account; used by the Settings page. */
export async function fetchAccountSnapshot(
  accountSid: string,
  authToken: string,
): Promise<AccountSnapshot> {
  const client = twilio(accountSid, authToken);
  const account = await client.api.v2010.accounts(accountSid).fetch();
  const numbers = await client.incomingPhoneNumbers.list({ limit: 1000 });

  return {
    friendlyName: account.friendlyName,
    status: account.status,
    type: account.type,
    numberCount: numbers.length,
  };
}

export type RemoteNumber = {
  sid: string;
  phoneNumber: string;
  friendlyName: string;
  capabilities: { voice: boolean; sms: boolean; mms: boolean };
};

/** Lists every phone number owned by the configured Twilio account. */
export async function listRemoteNumbers(): Promise<RemoteNumber[]> {
  const client = await getTwilioClient();
  const numbers = await client.incomingPhoneNumbers.list({ limit: 1000 });

  return numbers.map((number) => ({
    sid: number.sid,
    phoneNumber: number.phoneNumber,
    friendlyName: number.friendlyName ?? number.phoneNumber,
    capabilities: {
      voice: Boolean(number.capabilities?.voice),
      sms: Boolean(number.capabilities?.sms),
      mms: Boolean(number.capabilities?.mms),
    },
  }));
}

/** Sends an SMS through Twilio and returns the created message SID + status. */
export async function sendSms(params: {
  from: string;
  to: string;
  body: string;
}): Promise<{ sid: string; status: string }> {
  const client = await getTwilioClient();
  const message = await client.messages.create(params);
  return { sid: message.sid, status: message.status };
}

/**
 * Places an outbound call that bridges the dialled party to the user's
 * device. Requires a webhook base URL so Twilio can fetch TwiML.
 */
export async function placeCall(params: {
  from: string;
  to: string;
}): Promise<{ sid: string; status: string }> {
  const client = await getTwilioClient();
  const config = await loadTwilioConfig();

  const call = await client.calls.create({
    from: params.from,
    to: params.to,
    ...(config.webhookBaseUrl
      ? { url: `${config.webhookBaseUrl.replace(/\/$/, '')}/api/twilio/voice` }
      : {
          twiml: `<Response><Say>Connecting your call.</Say><Dial>${params.to}</Dial></Response>`,
        }),
  });

  return { sid: call.sid, status: call.status };
}

/**
 * Mints a Voice access token so the Flutter client can register as a device.
 * Needs an API Key pair and a TwiML App SID configured in Settings.
 */
export async function createVoiceAccessToken(
  identity: string,
): Promise<string> {
  const config = await loadTwilioConfig();
  if (!config.apiKeySid || !config.apiKeySecret || !config.twimlAppSid) {
    throw new Error(
      'Voice tokens need an API Key SID, API Key Secret and TwiML App SID in Settings.',
    );
  }

  const AccessToken = twilio.jwt.AccessToken;
  const token = new AccessToken(
    config.accountSid,
    config.apiKeySid,
    config.apiKeySecret,
    { identity, ttl: 3600 },
  );

  token.addGrant(
    new AccessToken.VoiceGrant({
      outgoingApplicationSid: config.twimlAppSid,
      incomingAllow: true,
    }),
  );

  return token.toJwt();
}

/**
 * Normalises user input to E.164 so lookups and Twilio calls agree.
 *
 * A bare national number is NOT assumed to be American. Guessing `+1` for any
 * 10-digit input turned Indian mobiles into invalid US numbers, which Twilio
 * rejected outright — so callers must supply the country code, and the app
 * sends a full `+…` number from its country picker.
 */
export function toE164(input: string): string {
  const trimmed = input.trim();
  if (!trimmed) return '';
  if (trimmed.startsWith('+')) {
    const digits = trimmed.slice(1).replace(/\D/g, '');
    return digits ? `+${digits}` : '';
  }

  const digits = trimmed.replace(/\D/g, '');
  if (!digits) return '';
  // Assume it is already E.164 without its plus, rather than inventing a
  // country. Genuinely national input is rejected by the caller instead.
  return `+${digits}`;
}

/** True when [value] is plausibly a full international number. */
export function looksLikeE164(value: string): boolean {
  return /^\+[1-9]\d{7,14}$/.test(value);
}

/** Formats E.164 US numbers as +1 (555) 012-3456 for display. */
export function formatPhone(value: string): string {
  const digits = value.replace(/\D/g, '');
  if (digits.length === 11 && digits.startsWith('1')) {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  }
  if (digits.length === 10) {
    return `+1 (${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }
  return value;
}
