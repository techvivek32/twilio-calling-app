import { NextResponse, type NextRequest } from 'next/server';

import { SESSION_COOKIE, verifyToken } from '@/lib/session';

/**
 * Origins allowed to call /api/mobile from a browser.
 *
 * The mobile API authenticates with a bearer token rather than cookies, so a
 * cross-origin request carries no ambient credentials — but the sign-in route
 * still accepts a password, so this stays deliberately narrow:
 *
 * - any loopback origin, which is where a Flutter web build runs in dev
 * - the host serving this request, so the app can be served from the panel
 * - anything listed in MOBILE_CORS_ORIGINS (comma separated) for deployments
 */
function corsOrigin(request: NextRequest): string | null {
  const origin = request.headers.get('origin');
  if (!origin) return null;

  const allowList = (process.env.MOBILE_CORS_ORIGINS ?? '')
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
  if (allowList.includes('*')) return origin;
  if (allowList.includes(origin)) return origin;

  let hostname: string;
  try {
    hostname = new URL(origin).hostname;
  } catch {
    return null;
  }

  if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1') {
    return origin;
  }
  if (hostname === request.nextUrl.hostname) return origin;

  return null;
}

function withCors(response: NextResponse, origin: string | null) {
  if (!origin) return response;
  response.headers.set('Access-Control-Allow-Origin', origin);
  response.headers.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization',
  );
  response.headers.set('Access-Control-Max-Age', '86400');
  // Caches must not reuse one origin's response for another.
  response.headers.set('Vary', 'Origin');
  return response;
}

/**
 * Adds CORS to the mobile API so a browser-hosted client can call it, and
 * gates every admin page behind a valid admin session cookie.
 */
export async function proxy(request: NextRequest) {
  if (request.nextUrl.pathname.startsWith('/api/mobile')) {
    const origin = corsOrigin(request);

    // Answer the preflight here; it never needs to reach a route handler.
    if (request.method === 'OPTIONS') {
      return withCors(new NextResponse(null, { status: 204 }), origin);
    }

    return withCors(NextResponse.next(), origin);
  }

  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const session = token ? await verifyToken(token) : null;

  if (!session || session.role !== 'admin') {
    const login = new URL('/login', request.url);
    const response = NextResponse.redirect(login);
    if (token) response.cookies.delete(SESSION_COOKIE);
    return response;
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/api/mobile/:path*',
    '/dashboard/:path*',
    '/users/:path*',
    '/numbers/:path*',
    '/calls/:path*',
    '/messages/:path*',
    '/settings/:path*',
  ],
};
