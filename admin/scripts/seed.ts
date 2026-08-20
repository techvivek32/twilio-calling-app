/**
 * Creates the first admin account, and nothing else.
 *
 * Everything the panel manages — users, phone numbers, call and message
 * history — comes from real usage or from syncing your Twilio account.
 * Run with: npm run seed
 */
import mongoose from 'mongoose';

import { hashPassword } from '../src/lib/auth';
import { connectToDatabase } from '../src/lib/db';
import { Setting, User } from '../src/lib/models';

async function main() {
  await connectToDatabase();
  console.log('Connected to MongoDB.');

  const email = (
    process.env.SEED_ADMIN_EMAIL ?? 'admin@businessconnect.local'
  ).toLowerCase();
  const password = process.env.SEED_ADMIN_PASSWORD;

  if (!password) {
    console.error(
      'SEED_ADMIN_PASSWORD is not set. Add it to .env.local before seeding.',
    );
    await mongoose.disconnect();
    process.exit(1);
  }

  // The settings singleton must exist so the Settings page has a row to edit.
  await Setting.updateOne(
    { key: 'twilio' },
    { $setOnInsert: { key: 'twilio' } },
    { upsert: true },
  );

  const existing = await User.findOne({ email });
  if (existing) {
    console.log(`Admin already exists: ${email} (nothing changed).`);
    await mongoose.disconnect();
    return;
  }

  await User.create({
    name: process.env.SEED_ADMIN_NAME ?? 'Administrator',
    email,
    passwordHash: await hashPassword(password),
    role: 'admin',
    status: 'active',
  });

  console.log(`Created admin ${email}.`);
  console.log('Sign in, add your Twilio credentials, then sync your numbers.');
  await mongoose.disconnect();
}

main().catch(async (error) => {
  console.error(error);
  await mongoose.disconnect();
  process.exit(1);
});
