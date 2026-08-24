import type { NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { CallLog, Contact, PhoneNumber, User } from '@/lib/models';
import { loadTwilioConfig } from '@/lib/twilio';
import { escapeXml, twiml, verifyTwilioRequest } from '@/lib/twilio-webhook';

/** How long the owner's phone rings before the call is treated as missed. */
const RING_SECONDS = 25;

/**
 * Voice webhook. Point a number's "A call comes in" here.
 *
 * An incoming call forwards to the phone the owner actually answers — the same
 * handset click-to-call rings. It used to dial `<Client>`, which needs the
 * Twilio Voice SDK registered from the device; the app has no SDK, so nothing
 * was listening and every call rang out.
 */
export async function POST(request: NextRequest) {
  const verified = await verifyTwilioRequest(request);
  if (!verified.ok) {
    // Do not describe the service to an unverified caller.
    return twiml('<Response><Reject/></Response>', 403);
  }

  const { params } = verified;
  const from = params.From ?? '';
  const to = params.To ?? '';
  const sid = params.CallSid ?? '';
  const isOutboundFromApp = (params.Direction ?? '').startsWith('outbound');

  await connectToDatabase();

  const businessNumber = await PhoneNumber.findOne({
    phoneNumber: isOutboundFromApp ? from : to,
  });

  if (!businessNumber?.assignedTo) {
    return twiml(
      '<Response><Say>This number is not in service.</Say><Hangup/></Response>',
    );
  }

  if (isOutboundFromApp) {
    // The outbound leg is already logged by /api/mobile/calls/place.
    return twiml(
      `<Response><Dial callerId="${escapeXml(businessNumber.phoneNumber)}" answerOnBridge="true">` +
        `${escapeXml(to)}</Dial></Response>`,
    );
  }

  const contact = await Contact.findOne({
    userId: businessNumber.assignedTo,
    phone: from,
  });

  // Record it now so a caller who hangs up mid-ring still shows as missed.
  // The completion callback below upgrades it once the call resolves.
  await CallLog.updateOne(
    { twilioSid: sid },
    {
      $setOnInsert: {
        userId: businessNumber.assignedTo,
        phoneNumberId: businessNumber._id,
        twilioSid: sid,
        from,
        to,
        contactName: contact?.name ?? '',
        direction: 'inbound',
        status: 'missed',
        durationSec: 0,
        startedAt: new Date(),
      },
    },
    { upsert: true },
  );

  const owner = await User.findById(businessNumber.assignedTo).lean();
  const forwardTo = owner?.personalNumber ?? '';

  if (!forwardTo) {
    return twiml(
      '<Response><Say>This number is not available right now.</Say>' +
        '<Hangup/></Response>',
    );
  }

  // `action` fires when the dial finishes, however it ends. That is how the
  // call gets its real outcome instead of staying "missed".
  const { webhookBaseUrl } = await loadTwilioConfig();
  const action = webhookBaseUrl
    ? ` action="${escapeXml(
        `${webhookBaseUrl.replace(/\/$/, '')}/api/twilio/voice/completed`,
      )}" method="POST"`
    : '';

  return twiml(
    `<Response><Dial timeout="${RING_SECONDS}"` +
      ` callerId="${escapeXml(businessNumber.phoneNumber)}"${action}>` +
      `${escapeXml(forwardTo)}</Dial></Response>`,
  );
}
