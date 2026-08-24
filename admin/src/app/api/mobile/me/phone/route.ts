import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson, requireMobileUser } from '@/lib/mobile';
import { User } from '@/lib/models';
import { looksLikeE164, toE164 } from '@/lib/twilio';

type Body = { personalNumber?: string };

/**
 * Sets the caller's own phone — the leg click-to-call rings first.
 *
 * Users can set this themselves so they are not blocked waiting on an admin;
 * the admin can still change it from the user's page.
 */
export async function POST(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const body = await readJson<Body>(request);
  const raw = (body?.personalNumber ?? '').trim();

  // An empty value clears it, which disables placing calls again.
  if (!raw) {
    await connectToDatabase();
    await User.updateOne(
      { _id: context.user.id },
      { $set: { personalNumber: '' } },
    );
    return json({ personalNumber: '' });
  }

  // Require an explicit country code. Without the leading '+', a national
  // number like 9876543210 becomes '+9876543210' — a syntactically valid but
  // completely different country's number, which is the mistake this whole
  // flow exists to prevent.
  const personalNumber = toE164(raw);
  if (!raw.startsWith('+') || !looksLikeE164(personalNumber)) {
    return fail(
      'Enter your phone in full international form, including the country ' +
        'code — for example +91 98765 43210.',
      422,
    );
  }

  if (personalNumber === context.number?.phoneNumber) {
    return fail(
      'This is your Vision Connect number. Enter the phone you actually ' +
        'answer, so calls can ring it.',
      422,
    );
  }

  await connectToDatabase();
  await User.updateOne(
    { _id: context.user.id },
    { $set: { personalNumber } },
  );

  return json({ personalNumber });
}
