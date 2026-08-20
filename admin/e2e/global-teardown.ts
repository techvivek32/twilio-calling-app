import { resetE2EData } from './global-setup';

/** Leaves the database holding only real records after the suite finishes. */
export default async function globalTeardown() {
  await resetE2EData();
}
