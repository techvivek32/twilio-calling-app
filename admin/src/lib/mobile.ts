import { NextResponse, type NextRequest } from 'next/server';

import { bearerFrom, verifyToken } from './session';
import { connectToDatabase } from './db';
import { PhoneNumber, User } from './models';

export type MobileContext = {
  user: {
    id: string;
    name: string;
    email: string;
    status: 'active' | 'suspended';
  };
  /** The Twilio number the admin assigned to this user, if any. */
  number: {
    id: string;
    phoneNumber: string;
    friendlyName: string;
    capabilities: { voice: boolean; sms: boolean; mms: boolean };
    status: 'active' | 'inactive';
  } | null;
};

export function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status });
}

export function fail(message: string, status = 400) {
  return NextResponse.json({ error: message }, { status });
}

/**
 * Resolves the caller from the `Authorization: Bearer` header and loads the
 * number the admin assigned to them. Returns a NextResponse on failure so
 * handlers can `if (context instanceof NextResponse) return context`.
 */
export async function requireMobileUser(
  request: NextRequest,
): Promise<MobileContext | NextResponse> {
  const token = bearerFrom(request.headers.get('authorization'));
  if (!token) return fail('Missing bearer token.', 401);

  const payload = await verifyToken(token);
  if (!payload) return fail('Session expired. Sign in again.', 401);

  await connectToDatabase();
  const user = await User.findById(payload.sub).lean();
  if (!user) return fail('Account no longer exists.', 401);
  if (user.status !== 'active') return fail('This account is suspended.', 403);

  const number = await PhoneNumber.findOne({
    assignedTo: user._id,
    status: 'active',
  })
    .sort({ assignedAt: 1 })
    .lean();

  return {
    user: {
      id: String(user._id),
      name: user.name,
      email: user.email,
      status: user.status as 'active' | 'suspended',
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
          status: number.status as 'active' | 'inactive',
        }
      : null,
  };
}

export async function readJson<T>(request: NextRequest): Promise<T | null> {
  try {
    return (await request.json()) as T;
  } catch {
    return null;
  }
}
