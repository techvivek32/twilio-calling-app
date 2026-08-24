import type { NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { Contact, MessageLog, PhoneNumber } from '@/lib/models';
import { twiml, verifyTwilioRequest } from '@/lib/twilio-webhook';

const EMPTY = '<Response/>';

/**
 * Inbound SMS webhook. Point a number's "A message comes in" here.
 *
 * The message is filed against whoever owns the number, so it appears in that
 * user's thread in the app and in the admin panel.
 */
export async function POST(request: NextRequest) {
  const verified = await verifyTwilioRequest(request);
  if (!verified.ok) return twiml(EMPTY, 403);

  const { params } = verified;
  const from = params.From ?? '';
  const to = params.To ?? '';
  const body = params.Body ?? '';
  const sid = params.MessageSid ?? '';

  if (!from || !to) return twiml(EMPTY);

  await connectToDatabase();
  const number = await PhoneNumber.findOne({ phoneNumber: to });

  // Nothing to attribute the message to — acknowledge and drop it.
  if (!number?.assignedTo) return twiml(EMPTY);

  const contact = await Contact.findOne({
    userId: number.assignedTo,
    phone: from,
  });

  // Keyed on the SID so a Twilio retry cannot duplicate the message.
  await MessageLog.updateOne(
    { twilioSid: sid },
    {
      $setOnInsert: {
        userId: number.assignedTo,
        phoneNumberId: number._id,
        twilioSid: sid || null,
        from,
        to,
        contactName: contact?.name ?? '',
        body,
        direction: 'inbound',
        status: 'received',
        sentAt: new Date(),
      },
    },
    { upsert: true },
  );

  return twiml(EMPTY);
}
