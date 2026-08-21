import { connectToDatabase } from '@/lib/db';
import { json } from '@/lib/mobile';

/**
 * Unauthenticated reachability check for the mobile app's "Test connection"
 * button. Reports whether the database is up too, so a half-working server is
 * not mistaken for a healthy one.
 */
export async function GET() {
  let database = false;
  try {
    await connectToDatabase();
    database = true;
  } catch {
    database = false;
  }

  return json({
    ok: true,
    service: 'business-connect-admin',
    database,
  });
}
