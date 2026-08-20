import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson, requireMobileUser } from '@/lib/mobile';
import { CallLog } from '@/lib/models';
import { toE164 } from '@/lib/twilio';

type LogCallBody = {
  to?: string;
  from?: string;
  contactName?: string;
  direction?: 'inbound' | 'outbound';
  status?: 'completed' | 'missed' | 'failed' | 'busy' | 'no-answer';
  durationSec?: number;
  twilioSid?: string;
  startedAt?: string;
};

export async function GET(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  await connectToDatabase();
  const calls = await CallLog.find({ userId: context.user.id })
    .sort({ startedAt: -1 })
    .limit(100)
    .lean();

  return json({
    calls: calls.map((call) => ({
      id: String(call._id),
      from: call.from,
      to: call.to,
      contactName: call.contactName ?? '',
      direction: call.direction,
      status: call.status,
      durationSec: call.durationSec ?? 0,
      startedAt: call.startedAt,
    })),
  });
}

/** Records a call the app just handled so it shows up in the admin panel. */
export async function POST(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const body = await readJson<LogCallBody>(request);
  if (!body) return fail('Expected a JSON body.', 422);

  const direction = body.direction === 'inbound' ? 'inbound' : 'outbound';
  const ownNumber = context.number?.phoneNumber ?? '';
  const other = toE164(body.to ?? body.from ?? '');

  if (!other) return fail('A "to" number is required.', 422);
  if (!ownNumber) {
    return fail(
      'No phone number is assigned to your account. Ask your administrator.',
      409,
    );
  }

  await connectToDatabase();
  const call = await CallLog.create({
    userId: context.user.id,
    phoneNumberId: context.number?.id ?? null,
    twilioSid: body.twilioSid ?? null,
    from: direction === 'outbound' ? ownNumber : other,
    to: direction === 'outbound' ? other : ownNumber,
    contactName: body.contactName ?? '',
    direction,
    status: body.status ?? 'completed',
    durationSec: Math.max(0, Math.round(body.durationSec ?? 0)),
    startedAt: body.startedAt ? new Date(body.startedAt) : new Date(),
  });

  return json(
    {
      call: {
        id: String(call._id),
        from: call.from,
        to: call.to,
        contactName: call.contactName,
        direction: call.direction,
        status: call.status,
        durationSec: call.durationSec,
        startedAt: call.startedAt,
      },
    },
    201,
  );
}
