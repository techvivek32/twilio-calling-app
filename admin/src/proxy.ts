import { NextResponse, type NextRequest } from 'next/server';

import { SESSION_COOKIE, verifyToken } from '@/lib/session';

/** Gates every admin page behind a valid admin session cookie. */
export async function proxy(request: NextRequest) {
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
    '/dashboard/:path*',
    '/users/:path*',
    '/numbers/:path*',
    '/calls/:path*',
    '/messages/:path*',
    '/settings/:path*',
  ],
};
