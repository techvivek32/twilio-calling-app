import { connectToDatabase } from './db';
import { CallLog } from './models';
import { getTwilioClient } from './twilio';

/** Twilio statuses that mean the call is over, mapped to our own wording. */
const FINAL_STATUS: Record<string, string> = {
  completed: 'completed',
  busy: 'busy',
  failed: 'failed',
  'no-answer': 'no-answer',
  canceled: 'missed',
};

/**
 * Fills in the real duration and outcome for calls that were never reconciled.
 *
 * The app writes a log the moment Twilio accepts a call, when the duration is
 * necessarily zero, and only updates it while the in-call screen is open. A
 * call ended after the app was closed therefore stayed at 0s. This reads the
 * finished call back from Twilio so the panel shows what actually happened.
 *
 * Best-effort: a Twilio outage or missing credentials must not break the page.
 */
export async function backfillCallDurations(limit = 25): Promise<number> {
  await connectToDatabase();

  const pending = await CallLog.find({
    twilioSid: { $ne: null },
    twilioSyncedAt: null,
  })
    .sort({ startedAt: -1 })
    .limit(limit);

  if (pending.length === 0) return 0;

  let client;
  try {
    client = await getTwilioClient();
  } catch {
    return 0;
  }

  const results = await Promise.allSettled(
    pending.map(async (log) => {
      const call = await client.calls(String(log.twilioSid)).fetch();
      const status = call.status ?? '';
      const mapped = FINAL_STATUS[status];

      // Still in progress: leave it alone so a later load picks it up.
      if (!mapped) return false;

      log.status = mapped as typeof log.status;
      log.durationSec = Number(call.duration ?? 0) || 0;
      log.twilioSyncedAt = new Date();
      await log.save();
      return true;
    }),
  );

  return results.filter((r) => r.status === 'fulfilled' && r.value).length;
}
