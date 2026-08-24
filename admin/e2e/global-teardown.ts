import { resetE2EData, restoreSettings } from './global-setup';

/**
 * Leaves the database holding only real records, with the real Twilio
 * credentials back in place.
 */
export default async function globalTeardown() {
  await resetE2EData();
  await restoreSettings();
}
