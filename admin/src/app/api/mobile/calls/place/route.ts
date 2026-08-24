import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson, requireMobileUser } from '@/lib/mobile';
import { CallLog } from '@/lib/models';
import {
  TwilioNotConfiguredError,
  looksLikeE164,
  placeCall,
  toE164,
} from '@/lib/twilio';

type PlaceCallBody = { to?: string; contactName?: string };

/**
 * Starts a real outbound call through Twilio from the user's assigned number
 * and logs it. Returns 409 when Twilio has not been configured by the admin.
 */
export async function POST(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const body = await readJson<PlaceCallBody>(request);
  const to = toE164(body?.to ?? '');
  if (!to) return fail('A "to" number is required.', 422);
  if (!looksLikeE164(to)) {
    return fail(
      'Enter the number in full international form, including the country ' +
        'code — for example +91 81401 26027.',
      422,
    );
  }

  if (!context.number) {
    return fail(
      'No phone number is assigned to your account. Ask your administrator.',
      409,
    );
  }
  if (!context.number.capabilities.voice) {
    return fail('Your assigned number cannot make voice calls.', 409);
  }

  try {
    const result = await placeCall({ from: context.number.phoneNumber, to });

    await connectToDatabase();
    const call = await CallLog.create({
      userId: context.user.id,
      phoneNumberId: context.number.id,
      twilioSid: result.sid,
      from: context.number.phoneNumber,
      to,
      contactName: body?.contactName ?? '',
      direction: 'outbound',
      status: 'completed',
      durationSec: 0,
      startedAt: new Date(),
    });

    return json({
      callSid: result.sid,
      status: result.status,
      logId: String(call._id),
    });
  } catch (error) {
    if (error instanceof TwilioNotConfiguredError) {
      return fail(error.message, 409);
    }
    return fail(`Twilio rejected the call: ${(error as Error).message}`, 502);
  }
}
