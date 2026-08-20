/**
 * Deletes every non-admin record so the panel starts from real data only:
 * app users, phone numbers, call logs, message logs and contacts.
 *
 * Admin accounts and your saved Twilio settings are kept.
 * Run with: npm run purge
 */
import mongoose from 'mongoose';

import { connectToDatabase } from '../src/lib/db';
import {
  CallLog,
  Contact,
  MessageLog,
  PhoneNumber,
  User,
} from '../src/lib/models';

async function main() {
  await connectToDatabase();
  console.log('Connected to MongoDB.\n');

  const admins = await User.countDocuments({ role: 'admin' });
  if (admins === 0) {
    console.error('No admin account found — run `npm run seed` first.');
    await mongoose.disconnect();
    process.exit(1);
  }

  const [calls, messages, contacts, numbers, users] = await Promise.all([
    CallLog.deleteMany({}),
    MessageLog.deleteMany({}),
    Contact.deleteMany({}),
    PhoneNumber.deleteMany({}),
    User.deleteMany({ role: { $ne: 'admin' } }),
  ]);

  console.log(`Removed ${users.deletedCount} app user(s)`);
  console.log(`Removed ${numbers.deletedCount} phone number(s)`);
  console.log(`Removed ${calls.deletedCount} call log(s)`);
  console.log(`Removed ${messages.deletedCount} message log(s)`);
  console.log(`Removed ${contacts.deletedCount} contact(s)`);
  console.log(`\nKept ${admins} admin account(s) and your Twilio settings.`);

  await mongoose.disconnect();
}

main().catch(async (error) => {
  console.error(error);
  await mongoose.disconnect();
  process.exit(1);
});
