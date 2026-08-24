import type { NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { CallLog, Contact, PhoneNumber, User } from '@/lib/models';

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

  // Inbound: forward to the phone the user actually answers.
  //
  // This used to dial <Client>, which needs the Twilio Voice SDK registered
  // from the device. The app has no SDK, so nothing was ever listening and
  // every incoming call rang out. Forwarding to their own handset works with
  // no SDK at all, and mirrors how outbound already bridges.
  const owner = await User.findById(businessNumber.assignedTo).lean();
  const forwardTo = owner?.personalNumber ?? '';

  if (!forwardTo) {
    return twiml(
      '<Response><Say>This number is not available right now.</Say>' +
        '<Hangup/></Response>',
    );
  }

  // callerId must be a number the account owns, so the business number is
  // shown rather than the original caller's.
  return twiml(
    `<Response><Dial timeout="25" callerId="${escapeXml(businessNumber.phoneNumber)}">` +
      `${escapeXml(forwardTo)}</Dial></Response>`,
  );
}
