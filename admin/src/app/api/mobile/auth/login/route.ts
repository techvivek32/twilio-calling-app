import type { NextRequest } from 'next/server';

import { hashPassword, signToken, verifyPassword } from '@/lib/auth';
import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson } from '@/lib/mobile';
import { PhoneNumber, User } from '@/lib/models';

type LoginBody = { email?: string; password?: string };

/** Signs an app user in and returns a bearer token plus their number. */
export async function POST(request: NextRequest) {
  const body = await readJson<LoginBody>(request);
  const email = (body?.email ?? '').trim().toLowerCase();
  const password = body?.password ?? '';

  if (!email || !password) {
    return fail('Email and password are required.', 422);
  }

  await connectToDatabase();
  const user = await User.findOne({ email });

  if (!user) {
    // Keep the timing similar to a real password check.
    await hashPassword(password);
    return fail('Invalid email or password.', 401);
  }
  if (user.status !== 'active') {
    return fail('This account is suspended. Contact your administrator.', 403);
  }
  if (!(await verifyPassword(password, user.passwordHash))) {
    return fail('Invalid email or password.', 401);
  }

  user.lastLoginAt = new Date();
  await user.save();

  const number = await PhoneNumber.findOne({
    assignedTo: user._id,
    status: 'active',
  })
    .sort({ assignedAt: 1 })
    .lean();

  const token = await signToken(
    {
      sub: String(user._id),
      email: user.email,
      name: user.name,
      role: user.role === 'admin' ? 'admin' : 'user',
    },
    '30d',
  );

  return json({
    token,
    user: {
      id: String(user._id),
      name: user.name,
      email: user.email,
      role: user.role,
    },
    number: number
      ? {
          id: String(number._id),
          phoneNumber: number.phoneNumber,
          friendlyName: number.friendlyName ?? '',
          capabilities: {
            voice: Boolean(number.capabilities?.voice),
            sms: Boolean(number.capabilities?.sms),
            mms: Boolean(number.capabilities?.mms),
          },
        }
      : null,
  });
}
