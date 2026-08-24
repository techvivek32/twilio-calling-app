import type { NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { CallLog, Contact, PhoneNumber } from '@/lib/models';

function twiml(body: string) {
  return new Response(`<?xml version="1.0" encoding="UTF-8"?>${body}`, {
    headers: { 'Content-Type': 'text/xml; charset=utf-8' },
  });
}

function escapeXml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Twilio webhook for voice.
 *
 * - Outbound: the app dials through a TwiML App, so `To` is the party being
 *   called and we bridge the leg from the user's assigned number.
 * - Inbound: someone rang a Vision Connect number, so we ring the assigned
 *   user's registered client and log the call either way.
 */
export async function POST(request: NextRequest) {
  const form = await request.formData();
  const from = String(form.get('From') ?? '');
  const to = String(form.get('To') ?? '');
  const sid = String(form.get('CallSid') ?? '');
  const direction = String(form.get('Direction') ?? '');

  await connectToDatabase();

  const isOutboundFromApp = direction.startsWith('outbound');
  const businessNumber = await PhoneNumber.findOne({
    phoneNumber: isOutboundFromApp ? from : to,
  });

  if (!businessNumber?.assignedTo) {
    return twiml(
      '<Response><Say>This number is not in service.</Say><Hangup/></Response>',
    );
  }

  const peer = isOutboundFromApp ? to : from;
  const contact = await Contact.findOne({
    userId: businessNumber.assignedTo,
    phone: peer,
  });

  await CallLog.create({
    userId: businessNumber.assignedTo,
    phoneNumberId: businessNumber._id,
    twilioSid: sid || null,
    from,
    to,
    contactName: contact?.name ?? '',
    direction: isOutboundFromApp ? 'outbound' : 'inbound',
    status: 'completed',
    durationSec: 0,
    startedAt: new Date(),
  });

  if (isOutboundFromApp) {
    return twiml(
      `<Response><Dial callerId="${escapeXml(businessNumber.phoneNumber)}">${escapeXml(to)}</Dial></Response>`,
    );
  }

  // Inbound: ring the Voice SDK client registered as the user's id.
  return twiml(
    `<Response><Dial timeout="25"><Client>${escapeXml(String(businessNumber.assignedTo))}</Client></Dial></Response>`,
  );
}
