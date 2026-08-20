import { clearSessionCookie } from '@/lib/auth';

export async function POST() {
  await clearSessionCookie();

  // A relative Location keeps the admin on whatever host they were using.
  // Building an absolute URL from `request.url` can resolve to a different
  // origin (localhost vs a LAN IP), which strands the browser and drops
  // origin-scoped storage such as the saved theme.
  return new Response(null, {
    status: 303,
    headers: { Location: '/login' },
  });
}
