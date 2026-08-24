import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson, requireMobileUser } from '@/lib/mobile';
import { MessageLog } from '@/lib/models';
import {
  TwilioNotConfiguredError,
  looksLikeE164,
  sendSms,
  toE164,
} from '@/lib/twilio';

type SendBody = { to?: string; body?: string; contactName?: string };

/** Returns the user's SMS history grouped into conversations by counterpart. */
export async function GET(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  await connectToDatabase();
  const messages = await MessageLog.find({ userId: context.user.id })
    .sort({ sentAt: 1 })
    .limit(500)
    .lean();

  const own = context.number?.phoneNumber ?? '';
  const threads = new Map<
    string,
    {
      peer: string;
      contactName: string;
      messages: {
        id: string;
        body: string;
        fromMe: boolean;
        status: string;
        sentAt: Date;
      }[];
    }
  >();

  for (const message of messages) {
    const fromMe = message.direction === 'outbound';
    const peer = fromMe ? message.to : message.from;
    if (peer === own) continue;

    const thread = threads.get(peer) ?? {
      peer,
      contactName: message.contactName ?? '',
      messages: [],
    };
    if (!thread.contactName && message.contactName) {
      thread.contactName = message.contactName;
    }
    thread.messages.push({
      id: String(message._id),
      body: message.body ?? '',
      fromMe,
      status: message.status ?? 'sent',
      sentAt: message.sentAt,
    });
    threads.set(peer, thread);
  }

  const conversations = [...threads.values()].sort((a, b) => {
    const aLast = a.messages.at(-1)?.sentAt ?? 0;
    const bLast = b.messages.at(-1)?.sentAt ?? 0;
    return new Date(bLast).getTime() - new Date(aLast).getTime();
  });

  return json({ conversations });
}

/** Sends an SMS from the user's assigned number and records the result. */
export async function POST(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const payload = await readJson<SendBody>(request);
  const to = toE164(payload?.to ?? '');
  const text = (payload?.body ?? '').trim();

  if (!to) return fail('A "to" number is required.', 422);
  if (!(payload?.to ?? '').trim().startsWith('+') || !looksLikeE164(to)) {
    return fail(
      'Enter the number in full international form, including the country ' +
        'code — for example +91 81401 26027.',
      422,
    );
  }
  if (!text) return fail('Message body cannot be empty.', 422);
  if (!context.number) {
    return fail(
      'No phone number is assigned to your account. Ask your administrator.',
      409,
    );
  }
  if (!context.number.capabilities.sms) {
    return fail('Your assigned number cannot send SMS.', 409);
  }

  await connectToDatabase();

  let status: 'sent' | 'failed' | 'queued' = 'queued';
  let twilioSid: string | null = null;
  let warning: string | null = null;

  try {
    const result = await sendSms({
      from: context.number.phoneNumber,
      to,
      body: text,
    });
    twilioSid = result.sid;
    status = 'sent';
  } catch (error) {
    if (error instanceof TwilioNotConfiguredError) {
      // Log it so the thread stays coherent, but say plainly it did not send.
      warning = error.message;
      status = 'queued';
    } else {
      warning = (error as Error).message;
      status = 'failed';
    }
  }

  const message = await MessageLog.create({
    userId: context.user.id,
    phoneNumberId: context.number.id,
    twilioSid,
    from: context.number.phoneNumber,
    to,
    contactName: payload?.contactName ?? '',
    body: text,
    direction: 'outbound',
    status,
    sentAt: new Date(),
  });

  return json(
    {
      message: {
        id: String(message._id),
        body: message.body,
        fromMe: true,
        status: message.status,
        sentAt: message.sentAt,
      },
      warning,
    },
    status === 'failed' ? 502 : 201,
  );
}
