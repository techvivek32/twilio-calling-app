import type { NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { MessageLog } from '@/lib/models';
import { twiml, verifyTwilioRequest } from '@/lib/twilio-webhook';

/** Twilio's final MessageStatus values mapped to the outcomes we store. */
const OUTCOME: Record<string, 'delivered' | 'failed'> = {
  delivered: 'delivered',
  undelivered: 'failed',
  failed: 'failed',
};

/**
 * Status callback for outbound SMS.
 *
 * Without it every message Twilio accepted shows as sent, even when the
 * carrier later refused it — the user sees a tick on a text that never
 * arrived.
 */
export async function POST(request: NextRequest) {
  const verified = await verifyTwilioRequest(request);
  if (!verified.ok) return twiml('<Response/>', 403);

  const { params } = verified;
  const sid = params.MessageSid ?? '';
  const outcome = OUTCOME[params.MessageStatus ?? ''];

  // Intermediate states (queued, sending, sent) change nothing we show.
  if (sid && outcome) {
    await connectToDatabase();
    await MessageLog.updateOne(
      { twilioSid: sid },
      { $set: { status: outcome, errorCode: params.ErrorCode ?? '' } },
    );
  }

  return twiml('<Response/>');
}
