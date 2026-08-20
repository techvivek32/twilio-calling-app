'use server';

import { redirect } from 'next/navigation';

import {
  hashPassword,
  setSessionCookie,
  signToken,
  verifyPassword,
} from '@/lib/auth';
import { connectToDatabase } from '@/lib/db';
import { User } from '@/lib/models';

export type LoginState = { error?: string };

export async function loginAction(
  _prev: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const email = String(formData.get('email') ?? '')
    .trim()
    .toLowerCase();
  const password = String(formData.get('password') ?? '');

  if (!email || !password) {
    return { error: 'Enter your email and password.' };
  }

  await connectToDatabase();
  const user = await User.findOne({ email });

  // Hash a throwaway value when the account is missing so a wrong email and a
  // wrong password take about the same time to answer.
  if (!user) {
    await hashPassword(password);
    return { error: 'Invalid email or password.' };
  }

  if (user.role !== 'admin') {
    return { error: 'This account cannot sign in to the admin panel.' };
  }

  if (user.status !== 'active') {
    return { error: 'This admin account is suspended.' };
  }

  const valid = await verifyPassword(password, user.passwordHash);
  if (!valid) {
    return { error: 'Invalid email or password.' };
  }

  user.lastLoginAt = new Date();
  await user.save();

  const token = await signToken({
    sub: String(user._id),
    email: user.email,
    name: user.name,
    role: 'admin',
  });
  await setSessionCookie(token);

  redirect('/dashboard');
}
