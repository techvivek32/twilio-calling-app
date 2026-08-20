import type { NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { Contact, MessageLog, PhoneNumber } from '@/lib/models';

const EMPTY_TWIML = '<?xml version="1.0" encoding="UTF-8"?><Response/>';

function twiml(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/xml; charset=utf-8' },
  });
}

/**
 * Twilio webhook for inbound SMS. Point your number's "A message comes in"
 * webhook at `<webhookBaseUrl>/api/twilio/sms`.
 */
export async function POST(request: NextRequest) {
  const form = await request.formData();
  const from = String(form.get('From') ?? '');
  const to = String(form.get('To') ?? '');
  const body = String(form.get('Body') ?? '');
  const sid = String(form.get('MessageSid') ?? '');

  if (!from || !to) return twiml(EMPTY_TWIML);

  await connectToDatabase();
  const number = await PhoneNumber.findOne({ phoneNumber: to });

  // Nothing to attribute the message to — acknowledge and drop it.
  if (!number?.assignedTo) return twiml(EMPTY_TWIML);

  const contact = await Contact.findOne({
    userId: number.assignedTo,
    phone: from,
  });

  await MessageLog.create({
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
  });

  return twiml(EMPTY_TWIML);
}
