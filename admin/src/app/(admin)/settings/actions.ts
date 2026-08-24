'use server';

import { revalidatePath } from 'next/cache';

import { requireAdmin } from '@/lib/auth';
import { encryptSecret } from '@/lib/crypto';
import { connectToDatabase } from '@/lib/db';
import { Setting } from '@/lib/models';
import {
  fetchAccountSnapshot,
  loadTwilioConfig,
  wireWebhooks,
} from '@/lib/twilio';

export type ActionState = { ok?: string; error?: string };

function text(formData: FormData, key: string): string {
  return String(formData.get(key) ?? '').trim();
}

export async function saveSettingsAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const accountSid = text(formData, 'accountSid');
    const authToken = text(formData, 'authToken');
    const apiKeySid = text(formData, 'apiKeySid');
    const apiKeySecret = text(formData, 'apiKeySecret');
    const twimlAppSid = text(formData, 'twimlAppSid');
    const webhookBaseUrl = text(formData, 'webhookBaseUrl');
    const defaultCallerId = text(formData, 'defaultCallerId');

    if (accountSid && !accountSid.startsWith('AC')) {
      return { error: 'A Twilio Account SID starts with "AC".' };
    }
    if (apiKeySid && !apiKeySid.startsWith('SK')) {
      return { error: 'A Twilio API Key SID starts with "SK".' };
    }
    if (twimlAppSid && !twimlAppSid.startsWith('AP')) {
      return { error: 'A TwiML App SID starts with "AP".' };
    }

    const update: Record<string, unknown> = {
      accountSid,
      apiKeySid,
      twimlAppSid,
      webhookBaseUrl,
      defaultCallerId,
    };

    // Blank secret fields mean "leave the stored value alone".
    if (authToken) update.authTokenEnc = encryptSecret(authToken);
    if (apiKeySecret) update.apiKeySecretEnc = encryptSecret(apiKeySecret);

    await Setting.updateOne({ key: 'twilio' }, { $set: update }, { upsert: true });

    revalidatePath('/settings');
    revalidatePath('/dashboard');
    revalidatePath('/numbers');
    return { ok: 'Twilio settings saved.' };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

export async function testConnectionAction(
  _prev: ActionState,
  _formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    const config = await loadTwilioConfig();

    if (!config.accountSid || !config.authToken) {
      return { error: 'Save an Account SID and Auth Token first.' };
    }

    const snapshot = await fetchAccountSnapshot(
      config.accountSid,
      config.authToken,
    );

    await Setting.updateOne(
      { key: 'twilio' },
      { $set: { lastVerifiedAt: new Date(), lastVerifyError: '' } },
    );
    revalidatePath('/settings');
    revalidatePath('/dashboard');

    return {
      ok: `Connected to "${snapshot.friendlyName}" (${snapshot.status}, ${snapshot.type}) — ${snapshot.numberCount} number(s) on the account.`,
    };
  } catch (error) {
    const message = (error as Error).message;
    await connectToDatabase();
    await Setting.updateOne(
      { key: 'twilio' },
      { $set: { lastVerifyError: message } },
    );
    revalidatePath('/settings');
    return { error: `Twilio rejected the credentials: ${message}` };
  }
}

/**
 * Points every Twilio number at this deployment.
 *
 * Inbound calls and texts only arrive if each number's webhooks name this
 * server, and setting them by hand in the Twilio Console is the step most
 * often missed.
 */
export async function wireWebhooksAction(
  _prev: ActionState,
  _formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    const { webhookBaseUrl } = await loadTwilioConfig();

    const { updated, total } = await wireWebhooks(webhookBaseUrl);
    revalidatePath('/settings');
    revalidatePath('/numbers');

    if (total === 0) {
      return { error: 'This Twilio account owns no phone numbers yet.' };
    }
    return {
      ok:
        updated === 0
          ? `All ${total} number(s) already point here.`
          : `Pointed ${updated} of ${total} number(s) at this server.`,
    };
  } catch (error) {
    return { error: (error as Error).message };
  }
}
