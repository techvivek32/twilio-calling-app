import { MongoClient } from 'mongodb';

/** Numbers and accounts the suite creates, so cleanup can be precise. */
export const E2E_NUMBER = '+15550000123';
export const E2E_NUMBER_ALT = '+15550000456';
export const E2E_EMAIL_PREFIX = 'e2e-';

/**
 * Clears every record the suite creates. Real data is untouched: only accounts
 * whose email starts with `e2e-` and the two reserved test numbers.
 *
 * Run before the suite (in case a previous run crashed) and again after it, so
 * the panel is left holding nothing but real records.
 */
export async function resetE2EData() {
  process.loadEnvFile('.env.local');

  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is not set; cannot reset e2e data.');

  const client = new MongoClient(uri);
  await client.connect();
  const db = client.db();

  const users = db.collection('users');
  const numbers = db.collection('phonenumbers');

  const leftovers = await users
    .find({ email: { $regex: `^${E2E_EMAIL_PREFIX}` } })
    .toArray();

  for (const user of leftovers) {
    await Promise.all([
      numbers.updateMany(
        { assignedTo: user._id },
        { $set: { assignedTo: null, assignedAt: null } },
      ),
      db.collection('calllogs').deleteMany({ userId: user._id }),
      db.collection('messagelogs').deleteMany({ userId: user._id }),
      db.collection('contacts').deleteMany({ userId: user._id }),
    ]);
  }

  await users.deleteMany({ email: { $regex: `^${E2E_EMAIL_PREFIX}` } });
  await numbers.deleteMany({
    phoneNumber: { $in: [E2E_NUMBER, E2E_NUMBER_ALT] },
  });

  // Twilio settings start empty so the validation test sees a clean form.
  await db
    .collection('settings')
    .updateOne(
      { key: 'twilio' },
      { $set: { accountSid: '', webhookBaseUrl: '' } },
    );

  await client.close();
}

export default resetE2EData;
