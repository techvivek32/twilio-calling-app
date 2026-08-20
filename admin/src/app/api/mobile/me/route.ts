import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { json, requireMobileUser } from '@/lib/mobile';
import { CallLog, MessageLog } from '@/lib/models';
import { loadTwilioConfig } from '@/lib/twilio';

/** Home-screen payload: profile, assigned number and today's counters. */
export async function GET(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  await connectToDatabase();
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);

  const [
    callsToday,
    missedToday,
    incomingToday,
    unreadMessages,
    lastInbound,
    recentCalls,
    recentMessages,
    twilio,
  ] = await Promise.all([
    CallLog.countDocuments({
      userId: context.user.id,
      startedAt: { $gte: startOfDay },
    }),
    CallLog.countDocuments({
      userId: context.user.id,
      startedAt: { $gte: startOfDay },
      status: 'missed',
    }),
    CallLog.countDocuments({
      userId: context.user.id,
      startedAt: { $gte: startOfDay },
      direction: 'inbound',
    }),
    MessageLog.countDocuments({
      userId: context.user.id,
      direction: 'inbound',
    }),
    MessageLog.findOne({ userId: context.user.id, direction: 'inbound' })
      .sort({ sentAt: -1 })
      .lean(),
    CallLog.find({ userId: context.user.id })
      .sort({ startedAt: -1 })
      .limit(5)
      .lean(),
    MessageLog.find({ userId: context.user.id })
      .sort({ sentAt: -1 })
      .limit(5)
      .lean(),
    loadTwilioConfig(),
  ]);

  const activity = [
    ...recentCalls.map((call) => ({
      kind: 'call' as const,
      title:
        call.direction === 'inbound'
          ? `Call from ${call.contactName || call.from}`
          : `Call to ${call.contactName || call.to}`,
      subtitle:
        call.status === 'missed'
          ? 'Missed call'
          : `Duration: ${Math.floor((call.durationSec ?? 0) / 60)}m ${(call.durationSec ?? 0) % 60}s`,
      isAlert: call.status === 'missed',
      at: call.startedAt,
    })),
    ...recentMessages.map((message) => ({
      kind: 'message' as const,
      title:
        message.direction === 'inbound'
          ? `SMS from ${message.contactName || message.from}`
          : `SMS to ${message.contactName || message.to}`,
      subtitle: message.body ?? '',
      isAlert: message.status === 'failed',
      at: message.sentAt,
    })),
  ]
    .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
    .slice(0, 6);

  return json({
    user: context.user,
    number: context.number,
    twilioConfigured: Boolean(twilio.accountSid),
    today: {
      calls: callsToday,
      missed: missedToday,
      incoming: incomingToday,
    },
    messages: {
      unread: unreadMessages,
      latest: lastInbound
        ? {
            from: lastInbound.contactName || lastInbound.from,
            body: lastInbound.body ?? '',
          }
        : null,
    },
    activity,
  });
}
