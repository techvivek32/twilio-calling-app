import { MongoClient } from 'mongodb';

/**
 * Clears anything a previous e2e run created or changed, so the suite starts
 * from the seeded state every time.
 */
export default async function globalSetup() {
  process.loadEnvFile('.env.local');

  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is not set; cannot reset e2e data.');

  const client = new MongoClient(uri);
  await client.connect();
  const db = client.db();

  const users = db.collection('users');
  const numbers = db.collection('phonenumbers');

  const leftovers = await users
    .find({ email: { $regex: '^e2e-' } })
    .toArray();

  for (const user of leftovers) {
    await numbers.updateMany(
      { assignedTo: user._id },
      { $set: { assignedTo: null, assignedAt: null } },
    );
  }
  await users.deleteMany({ email: { $regex: '^e2e-' } });
  await numbers.deleteMany({ phoneNumber: '+15550000123' });

  // The spare line must start unassigned for the assignment test.
  await numbers.updateOne(
    { phoneNumber: '+15550777333' },
    { $set: { assignedTo: null, assignedAt: null, status: 'active' } },
  );

  // Twilio settings start empty so the validation test sees a clean form.
  await db
    .collection('settings')
    .updateOne(
      { key: 'twilio' },
      { $set: { accountSid: '', webhookBaseUrl: '' } },
    );

  await client.close();
}
