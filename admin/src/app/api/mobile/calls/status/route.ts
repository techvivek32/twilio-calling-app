import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, requireMobileUser } from '@/lib/mobile';
import { CallLog } from '@/lib/models';
import { TwilioNotConfiguredError, getTwilioClient } from '@/lib/twilio';

/** Twilio has accepted the call but the far end is not ringing yet. */
const DIALLING = new Set(['queued', 'initiated']);

const FINAL_STATUS: Record<string, string> = {
  completed: 'completed',
  busy: 'busy',
  failed: 'failed',
  'no-answer': 'no-answer',
  canceled: 'missed',
};

/**
 * Reports where an outbound call has actually got to, so the app can show
 * "Ringing" and only start its timer once the far end answers.
 *
 * `GET /api/mobile/calls/status?sid=CAxxxx`
 */
export async function GET(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const sid = request.nextUrl.searchParams.get('sid');
  if (!sid) return fail('A call "sid" is required.', 422);

  await connectToDatabase();

  // Only ever report on calls this user placed.
  const log = await CallLog.findOne({ twilioSid: sid, userId: context.user.id });
  if (!log) return fail('Unknown call.', 404);

  try {
    const client = await getTwilioClient();
    const call = await client.calls(sid).fetch();

    const twilioStatus = call.status ?? 'queued';
    const durationSec = Number(call.duration ?? 0) || 0;
    const answered = twilioStatus === 'in-progress';
    // Only a genuine 'ringing' means the far end is being alerted; 'queued'
    // just means Twilio has the request.
    const ringing = twilioStatus === 'ringing';
    const dialling = DIALLING.has(twilioStatus);
    const finalStatus = FINAL_STATUS[twilioStatus];

    // Persist the outcome so the admin panel shows the real result.
    if (finalStatus && log.status !== finalStatus) {
      log.status = finalStatus as typeof log.status;
      log.durationSec = durationSec;
      await log.save();
    }

    return json({
      sid,
      status: twilioStatus,
      dialling,
      ringing,
      answered,
      ended: Boolean(finalStatus),
      durationSec,
    });
  } catch (error) {
    if (error instanceof TwilioNotConfiguredError) {
      return fail(error.message, 409);
    }
    return fail(
      `Could not read the call state from Twilio: ${(error as Error).message}`,
      502,
    );
  }
}
