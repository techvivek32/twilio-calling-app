import type { NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { CallLog } from '@/lib/models';
import { twiml, verifyTwilioRequest } from '@/lib/twilio-webhook';

/** Twilio's DialCallStatus values mapped to the outcomes we store. */
const OUTCOME: Record<string, string> = {
  completed: 'completed',
  answered: 'completed',
  busy: 'busy',
  failed: 'failed',
  'no-answer': 'missed',
  canceled: 'missed',
};

/**
 * Fires when an inbound call's forward finishes, whatever the outcome.
 *
 * Without this an incoming call stays at the pessimistic "missed" it was
 * logged as, with no duration — the caller could talk for ten minutes and the
 * panel would still show a missed call.
 */
export async function POST(request: NextRequest) {
  const verified = await verifyTwilioRequest(request);
  if (!verified.ok) return twiml('<Response/>', 403);

  const { params } = verified;
  const sid = params.CallSid ?? '';
  const dialStatus = params.DialCallStatus ?? '';
  const duration = Number(params.DialCallDuration ?? 0) || 0;

  if (sid) {
    await connectToDatabase();
    await CallLog.updateOne(
      { twilioSid: sid },
      {
        $set: {
          status: OUTCOME[dialStatus] ?? 'missed',
          durationSec: duration,
          twilioSyncedAt: new Date(),
        },
      },
    );
  }

  // Nothing more to say; hanging up ends the call cleanly.
  return twiml('<Response><Hangup/></Response>');
}
