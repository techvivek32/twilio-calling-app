import { SignJWT, jwtVerify } from 'jose';

/**
 * Edge-safe half of auth: only `jose`, no Node built-ins. Middleware imports
 * this directly so bcrypt and `next/headers` stay out of the edge bundle.
 */

export const SESSION_COOKIE = 'bc_session';

export type SessionPayload = {
  sub: string;
  email: string;
  name: string;
  role: 'admin' | 'user';
};

function secret(): Uint8Array {
  const value = process.env.AUTH_SECRET;
  if (!value) throw new Error('AUTH_SECRET is not set. See .env.example.');
  return new TextEncoder().encode(value);
}

export async function signToken(
  payload: SessionPayload,
  expiresIn = '7d',
): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(payload.sub)
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(secret());
}

export async function verifyToken(
  token: string,
): Promise<SessionPayload | null> {
  try {
    const { payload } = await jwtVerify(token, secret());
    if (!payload.sub || !payload.role) return null;
    return {
      sub: String(payload.sub),
      email: String(payload.email ?? ''),
      name: String(payload.name ?? ''),
      role: payload.role === 'admin' ? 'admin' : 'user',
    };
  } catch {
    return null;
  }
}

/** Extracts a mobile client's bearer token from an Authorization header. */
export function bearerFrom(header: string | null): string | null {
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) return null;
  return token;
}
