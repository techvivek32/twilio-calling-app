import { connectToDatabase, serialize } from './db';
import { CallLog, MessageLog, PhoneNumber, User } from './models';

export type UserRow = {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'user';
  status: 'active' | 'suspended';
  createdAt: string;
  lastLoginAt: string | null;
  numbers: { id: string; phoneNumber: string; friendlyName: string }[];
  callCount: number;
  messageCount: number;
  talkTimeSec: number;
};

export type NumberRow = {
  id: string;
  sid: string | null;
  phoneNumber: string;
  friendlyName: string;
  capabilities: { voice: boolean; sms: boolean; mms: boolean };
  status: 'active' | 'inactive';
  source: 'twilio' | 'manual';
  assignedTo: { id: string; name: string; email: string } | null;
  assignedAt: string | null;
  callCount: number;
  messageCount: number;
};

function startOfToday(): Date {
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  return now;
}

/** Counts grouped by user id, keyed for O(1) lookup while building rows. */
async function usageByUser() {
  const [calls, messages] = await Promise.all([
    CallLog.aggregate<{ _id: unknown; count: number; talkTime: number }>([
      {
        $group: {
          _id: '$userId',
          count: { $sum: 1 },
          talkTime: { $sum: '$durationSec' },
        },
      },
    ]),
    MessageLog.aggregate<{ _id: unknown; count: number }>([
      { $group: { _id: '$userId', count: { $sum: 1 } } },
    ]),
  ]);

  const callMap = new Map(
    calls.map((row) => [String(row._id), { count: row.count, talkTime: row.talkTime }]),
  );
  const messageMap = new Map(
    messages.map((row) => [String(row._id), row.count]),
  );
  return { callMap, messageMap };
}

export async function getUsers(): Promise<UserRow[]> {
  await connectToDatabase();

  const [users, numbers, usage] = await Promise.all([
    User.find().sort({ createdAt: -1 }).lean(),
    PhoneNumber.find({ assignedTo: { $ne: null } }).lean(),
    usageByUser(),
  ]);

  const assignedNumbers = new Map<
    string,
    { id: string; phoneNumber: string; friendlyName: string }[]
  >();
  for (const number of numbers) {
    const key = String(number.assignedTo);
    const list = assignedNumbers.get(key) ?? [];
    list.push({
      id: String(number._id),
      phoneNumber: number.phoneNumber,
      friendlyName: number.friendlyName ?? '',
    });
    assignedNumbers.set(key, list);
  }

  return users.map((user) => {
    const id = String(user._id);
    const calls = usage.callMap.get(id);
    return {
      id,
      name: user.name,
      email: user.email,
      role: user.role as 'admin' | 'user',
      status: user.status as 'active' | 'suspended',
      createdAt: serialize(user.createdAt) as unknown as string,
      lastLoginAt: user.lastLoginAt
        ? (serialize(user.lastLoginAt) as unknown as string)
        : null,
      numbers: assignedNumbers.get(id) ?? [],
      callCount: calls?.count ?? 0,
      talkTimeSec: calls?.talkTime ?? 0,
      messageCount: usage.messageMap.get(id) ?? 0,
    };
  });
}

export async function getUserById(id: string): Promise<UserRow | null> {
  const users = await getUsers();
  return users.find((user) => user.id === id) ?? null;
}

export async function getNumbers(): Promise<NumberRow[]> {
  await connectToDatabase();

  const [numbers, calls, messages] = await Promise.all([
    PhoneNumber.find()
      .sort({ createdAt: -1 })
      .populate<{ assignedTo: { _id: string; name: string; email: string } }>(
        'assignedTo',
        'name email',
      )
      .lean(),
    CallLog.aggregate<{ _id: unknown; count: number }>([
      { $match: { phoneNumberId: { $ne: null } } },
      { $group: { _id: '$phoneNumberId', count: { $sum: 1 } } },
    ]),
    MessageLog.aggregate<{ _id: unknown; count: number }>([
      { $match: { phoneNumberId: { $ne: null } } },
      { $group: { _id: '$phoneNumberId', count: { $sum: 1 } } },
    ]),
  ]);

  const callMap = new Map(calls.map((row) => [String(row._id), row.count]));
  const messageMap = new Map(
    messages.map((row) => [String(row._id), row.count]),
  );

  return numbers.map((number) => {
    const id = String(number._id);
    const assignee = number.assignedTo as unknown as {
      _id: string;
      name: string;
      email: string;
    } | null;

    return {
      id,
      sid: number.sid ?? null,
      phoneNumber: number.phoneNumber,
      friendlyName: number.friendlyName ?? '',
      capabilities: {
        voice: Boolean(number.capabilities?.voice),
        sms: Boolean(number.capabilities?.sms),
        mms: Boolean(number.capabilities?.mms),
      },
      status: number.status as 'active' | 'inactive',
      source: number.source as 'twilio' | 'manual',
      assignedTo: assignee
        ? {
            id: String(assignee._id),
            name: assignee.name,
            email: assignee.email,
          }
        : null,
      assignedAt: number.assignedAt
        ? (serialize(number.assignedAt) as unknown as string)
        : null,
      callCount: callMap.get(id) ?? 0,
      messageCount: messageMap.get(id) ?? 0,
    };
  });
}

export type ActivityRow = {
  id: string;
  kind: 'call' | 'message';
  userName: string;
  from: string;
  to: string;
  contactName: string;
  direction: 'inbound' | 'outbound';
  status: string;
  detail: string;
  at: string;
};

export async function getCalls(userId?: string): Promise<ActivityRow[]> {
  await connectToDatabase();

  const filter = userId ? { userId } : {};
  const calls = await CallLog.find(filter)
    .sort({ startedAt: -1 })
    .limit(300)
    .populate<{ userId: { name: string } }>('userId', 'name')
    .lean();

  return calls.map((call) => ({
    id: String(call._id),
    kind: 'call' as const,
    userName: (call.userId as unknown as { name?: string })?.name ?? 'Unknown',
    from: call.from,
    to: call.to,
    contactName: call.contactName ?? '',
    direction: call.direction as 'inbound' | 'outbound',
    status: call.status ?? 'completed',
    detail: `${call.durationSec ?? 0}s`,
    at: serialize(call.startedAt) as unknown as string,
  }));
}

export async function getMessages(userId?: string): Promise<ActivityRow[]> {
  await connectToDatabase();

  const filter = userId ? { userId } : {};
  const messages = await MessageLog.find(filter)
    .sort({ sentAt: -1 })
    .limit(300)
    .populate<{ userId: { name: string } }>('userId', 'name')
    .lean();

  return messages.map((message) => ({
    id: String(message._id),
    kind: 'message' as const,
    userName:
      (message.userId as unknown as { name?: string })?.name ?? 'Unknown',
    from: message.from,
    to: message.to,
    contactName: message.contactName ?? '',
    direction: message.direction as 'inbound' | 'outbound',
    status: message.status ?? 'sent',
    detail: message.body ?? '',
    at: serialize(message.sentAt) as unknown as string,
  }));
}

export type DashboardStats = {
  users: { total: number; active: number; admins: number };
  numbers: { total: number; assigned: number; unassigned: number };
  calls: { total: number; today: number; missedToday: number; talkTimeSec: number };
  messages: { total: number; today: number };
};

export async function getDashboardStats(): Promise<DashboardStats> {
  await connectToDatabase();
  const today = startOfToday();

  const [
    totalUsers,
    activeUsers,
    admins,
    totalNumbers,
    assignedNumbers,
    totalCalls,
    callsToday,
    missedToday,
    talkTime,
    totalMessages,
    messagesToday,
  ] = await Promise.all([
    User.countDocuments(),
    User.countDocuments({ status: 'active' }),
    User.countDocuments({ role: 'admin' }),
    PhoneNumber.countDocuments(),
    PhoneNumber.countDocuments({ assignedTo: { $ne: null } }),
    CallLog.countDocuments(),
    CallLog.countDocuments({ startedAt: { $gte: today } }),
    CallLog.countDocuments({ startedAt: { $gte: today }, status: 'missed' }),
    CallLog.aggregate<{ total: number }>([
      { $group: { _id: null, total: { $sum: '$durationSec' } } },
    ]),
    MessageLog.countDocuments(),
    MessageLog.countDocuments({ sentAt: { $gte: today } }),
  ]);

  return {
    users: { total: totalUsers, active: activeUsers, admins },
    numbers: {
      total: totalNumbers,
      assigned: assignedNumbers,
      unassigned: totalNumbers - assignedNumbers,
    },
    calls: {
      total: totalCalls,
      today: callsToday,
      missedToday,
      talkTimeSec: talkTime[0]?.total ?? 0,
    },
    messages: { total: totalMessages, today: messagesToday },
  };
}
