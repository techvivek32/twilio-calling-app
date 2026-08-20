import { NextResponse, type NextRequest } from 'next/server';

import { fail, json, requireMobileUser } from '@/lib/mobile';
import { createVoiceAccessToken } from '@/lib/twilio';

/**
 * Mints a Twilio Voice access token so the app can register as a client and
 * receive inbound calls. Needs API Key + TwiML App SID in admin Settings.
 */
export async function GET(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  if (!context.number) {
    return fail('No phone number is assigned to your account.', 409);
  }

  try {
    const token = await createVoiceAccessToken(context.user.id);
    return json({ token, identity: context.user.id });
  } catch (error) {
    return fail((error as Error).message, 409);
  }
}
