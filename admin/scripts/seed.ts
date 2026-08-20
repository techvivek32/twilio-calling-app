/**
 * Creates the first admin account and a small demo dataset.
 * Run with: npm run seed
 */
import mongoose from 'mongoose';

import { hashPassword } from '../src/lib/auth';
import { connectToDatabase } from '../src/lib/db';
import {
  CallLog,
  Contact,
  MessageLog,
  PhoneNumber,
  Setting,
  User,
} from '../src/lib/models';

async function main() {
  await connectToDatabase();
  console.log('Connected to MongoDB.');

  const adminEmail = (
    process.env.SEED_ADMIN_EMAIL ?? 'admin@businessconnect.local'
  ).toLowerCase();
  const adminPassword = process.env.SEED_ADMIN_PASSWORD ?? 'ChangeMe123!';

  const existingAdmin = await User.findOne({ email: adminEmail });
  if (existingAdmin) {
    console.log(`Admin already exists: ${adminEmail}`);
  } else {
    await User.create({
      name: process.env.SEED_ADMIN_NAME ?? 'Admin',
      email: adminEmail,
      passwordHash: await hashPassword(adminPassword),
      role: 'admin',
      status: 'active',
    });
    console.log(`Created admin ${adminEmail} / ${adminPassword}`);
  }

  await Setting.updateOne(
    { key: 'twilio' },
    { $setOnInsert: { key: 'twilio' } },
    { upsert: true },
  );

  const userCount = await User.countDocuments({ role: 'user' });
  if (userCount > 0) {
    console.log(`${userCount} app user(s) already present, skipping demo data.`);
    await mongoose.disconnect();
    return;
  }

  const demoPassword = await hashPassword('Password123!');
  const [alex, priya] = await User.create([
    {
      name: 'Alex Morgan',
      email: 'alex@businessconnect.local',
      passwordHash: demoPassword,
      role: 'user',
      status: 'active',
    },
    {
      name: 'Priya Nair',
      email: 'priya@businessconnect.local',
      passwordHash: demoPassword,
      role: 'user',
      status: 'active',
    },
  ]);

  const [numberOne, numberTwo] = await PhoneNumber.create([
    {
      phoneNumber: '+15550123456',
      friendlyName: 'Sales line',
      source: 'manual',
      assignedTo: alex._id,
      assignedAt: new Date(),
    },
    {
      phoneNumber: '+15550987654',
      friendlyName: 'Support line',
      source: 'manual',
      assignedTo: priya._id,
      assignedAt: new Date(),
    },
    {
      phoneNumber: '+15550777333',
      friendlyName: 'Unassigned spare',
      source: 'manual',
    },
  ]);

  await Contact.create([
    {
      userId: alex._id,
      name: 'Sarah Jenkins',
      phone: '+15550198372',
      role: 'VP of Operations',
      label: 'Work',
    },
    {
      userId: alex._id,
      name: 'Acme Corporation',
      phone: '+12025550199',
      role: 'Enterprise Account',
      label: 'Work',
    },
    {
      userId: priya._id,
      name: 'Mark Ruff',
      phone: '+15554487712',
      role: 'Vendor',
      label: 'Mobile',
    },
  ]);

  const now = Date.now();
  const hoursAgo = (hours: number) => new Date(now - hours * 3600_000);

  await CallLog.create([
    {
      userId: alex._id,
      phoneNumberId: numberOne._id,
      from: '+15550123456',
      to: '+12025550199',
      contactName: 'Acme Corporation',
      direction: 'outbound',
      status: 'completed',
      durationSec: 312,
      startedAt: hoursAgo(2),
    },
    {
      userId: alex._id,
      phoneNumberId: numberOne._id,
      from: '+15550198372',
      to: '+15550123456',
      contactName: 'Sarah Jenkins',
      direction: 'inbound',
      status: 'missed',
      durationSec: 0,
      startedAt: hoursAgo(5),
    },
    {
      userId: priya._id,
      phoneNumberId: numberTwo._id,
      from: '+15554487712',
      to: '+15550987654',
      contactName: 'Mark Ruff',
      direction: 'inbound',
      status: 'completed',
      durationSec: 765,
      startedAt: hoursAgo(26),
    },
  ]);

  await MessageLog.create([
    {
      userId: alex._id,
      phoneNumberId: numberOne._id,
      from: '+15550123456',
      to: '+15550198372',
      contactName: 'Sarah Jenkins',
      body: 'Hi Sarah, confirming our meeting tomorrow at 10 AM PST.',
      direction: 'outbound',
      status: 'delivered',
      sentAt: hoursAgo(3),
    },
    {
      userId: alex._id,
      phoneNumberId: numberOne._id,
      from: '+15550198372',
      to: '+15550123456',
      contactName: 'Sarah Jenkins',
      body: 'Can we reschedule our 3PM call to tomorrow?',
      direction: 'inbound',
      status: 'received',
      sentAt: hoursAgo(1),
    },
    {
      userId: priya._id,
      phoneNumberId: numberTwo._id,
      from: '+15550987654',
      to: '+15554487712',
      contactName: 'Mark Ruff',
      body: 'Invoice #4821 has been approved for payment.',
      direction: 'outbound',
      status: 'sent',
      sentAt: hoursAgo(30),
    },
  ]);

  console.log('Seeded 2 app users, 3 numbers, 3 calls, 3 messages.');
  console.log('App logins: alex@businessconnect.local / Password123!');
  await mongoose.disconnect();
}

main().catch(async (error) => {
  console.error(error);
  await mongoose.disconnect();
  process.exit(1);
});
