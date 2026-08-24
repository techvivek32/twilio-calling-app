import twilio from 'twilio';
import type { NextRequest } from 'next/server';

import { loadTwilioConfig } from './twilio';

/**
 * Rebuilds the URL Twilio signed.
 *
 * Behind Vercel the request arrives over HTTP on an internal host, so the
 * proto and host must come from the forwarded headers or the signature will
 * never match.
 */
function publicUrl(request: NextRequest): string {
  const proto =
    request.headers.get('x-forwarded-proto') ?? request.nextUrl.protocol.replace(':', '');
  const host =
    request.headers.get('x-forwarded-host') ??
    request.headers.get('host') ??
    request.nextUrl.host;

  return `${proto}://${host}${request.nextUrl.pathname}${request.nextUrl.search}`;
}

export type WebhookResult =
  | { ok: true; params: Record<string, string> }
  | { ok: false; reason: string };

/**
 * Verifies a Twilio webhook and returns its form fields.
 *
 * These endpoints are public, so without this anyone who knows the URL could
 * forge call and message records, or make the server dial a number of their
 * choosing. Requests are rejected unless they carry a signature Twilio could
 * only have produced with the account's auth token.
 */
export async function verifyTwilioRequest(
  request: NextRequest,
): Promise<WebhookResult> {
  const form = await request.formData();
  const params: Record<string, string> = {};
  for (const [key, value] of form.entries()) {
    if (typeof value === 'string') params[key] = value;
  }

  const { authToken } = await loadTwilioConfig();
  if (!authToken) {
    return { ok: false, reason: 'Twilio is not configured on this server.' };
  }

  const signature = request.headers.get('x-twilio-signature');
  if (!signature) {
    return { ok: false, reason: 'Missing Twilio signature.' };
  }

  const valid = twilio.validateRequest(
    authToken,
    signature,
    publicUrl(request),
    params,
  );

  if (!valid) return { ok: false, reason: 'Signature did not match.' };
  return { ok: true, params };
}

/** TwiML response with the right content type. */
export function twiml(body: string, status = 200): Response {
  return new Response(`<?xml version="1.0" encoding="UTF-8"?>${body}`, {
    status,
    headers: { 'Content-Type': 'text/xml; charset=utf-8' },
  });
}

export function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
