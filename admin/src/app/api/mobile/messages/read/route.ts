import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson, requireMobileUser } from '@/lib/mobile';
import { MessageLog } from '@/lib/models';
import { toE164 } from '@/lib/twilio';

type Body = { peer?: string };

/** Marks a thread's inbound messages read, so the unread badge can go down. */
export async function POST(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const peer = toE164((await readJson<Body>(request))?.peer ?? '');
  if (!peer) return fail('A "peer" number is required.', 422);

  await connectToDatabase();
  const result = await MessageLog.updateMany(
    {
      userId: context.user.id,
      direction: 'inbound',
      from: peer,
      readAt: null,
    },
    { $set: { readAt: new Date() } },
  );

  return json({ peer, marked: result.modifiedCount });
}
