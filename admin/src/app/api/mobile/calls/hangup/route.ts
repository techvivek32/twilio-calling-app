import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson, requireMobileUser } from '@/lib/mobile';
import { CallLog } from '@/lib/models';
import { TwilioNotConfiguredError, getTwilioClient } from '@/lib/twilio';

type Body = { sid?: string };

/**
 * Ends a call the user placed.
 *
 * Hanging up in the app used to only close the screen, leaving the real call
 * up on Twilio — the two parties stayed connected. This completes it.
 */
export async function POST(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const sid = (await readJson<Body>(request))?.sid;
  if (!sid) return fail('A call "sid" is required.', 422);

  await connectToDatabase();

  // Only ever hang up a call this user placed.
  const log = await CallLog.findOne({ twilioSid: sid, userId: context.user.id });
  if (!log) return fail('Unknown call.', 404);

  try {
    const client = await getTwilioClient();
    const call = await client.calls(sid).update({ status: 'completed' });

    const durationSec = Number(call.duration ?? 0) || 0;
    log.status = 'completed';
    log.durationSec = durationSec;
    await log.save();

    return json({ sid, status: call.status, durationSec });
  } catch (error) {
    if (error instanceof TwilioNotConfiguredError) {
      return fail(error.message, 409);
    }
    // A call that already ended cannot be completed again; that is not a
    // failure from the user's point of view.
    return json({ sid, status: 'completed', durationSec: log.durationSec ?? 0 });
  }
}
