import { MongoClient } from 'mongodb';

/** Numbers and accounts the suite creates, so cleanup can be precise. */
export const E2E_NUMBER = '+15550000123';
export const E2E_NUMBER_ALT = '+15550000456';
export const E2E_EMAIL_PREFIX = 'e2e-';

/** Where the real Twilio settings are parked while the suite runs. */
const BACKUP_KEY = 'twilio:e2e-backup';

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

  // Real Twilio credentials must survive a test run. Snapshot them, then
  // blank the two fields the settings spec types into; the teardown puts the
  // originals back. Clearing them outright used to destroy a configured
  // account SID, which took live calling down until it was re-entered.
  const settings = db.collection('settings');
  const current = await settings.findOne({ key: 'twilio' });

  if (current && !(await settings.findOne({ key: BACKUP_KEY }))) {
    await settings.insertOne({
      key: BACKUP_KEY,
      accountSid: current.accountSid ?? '',
      webhookBaseUrl: current.webhookBaseUrl ?? '',
    });
  }

  await settings.updateOne(
    { key: 'twilio' },
    { $set: { accountSid: '', webhookBaseUrl: '' } },
  );

  await client.close();
}

/** Puts the real Twilio settings back after the suite. */
export async function restoreSettings() {
  process.loadEnvFile('.env.local');

  const uri = process.env.MONGODB_URI;
  if (!uri) return;

  const client = new MongoClient(uri);
  await client.connect();
  const settings = client.db().collection('settings');

  const backup = await settings.findOne({ key: BACKUP_KEY });
  if (backup) {
    await settings.updateOne(
      { key: 'twilio' },
      {
        $set: {
          accountSid: backup.accountSid ?? '',
          webhookBaseUrl: backup.webhookBaseUrl ?? '',
        },
      },
    );
    await settings.deleteOne({ key: BACKUP_KEY });
  }

  await client.close();
}

export default resetE2EData;
