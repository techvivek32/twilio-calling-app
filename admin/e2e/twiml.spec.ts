import { expect, test } from '@playwright/test';

import { buildBridgeTwiml, looksLikeE164, toE164, webhookTargets } from '../src/lib/twilio';

test.describe('click-to-call TwiML', () => {
  test('dials the person called, not the leg Twilio already made', () => {
    const twiml = buildBridgeTwiml('+18259070036', '+918140126027');

    // The far end must appear exactly once. Dialling the created leg again
    // rang the callee twice, which the handset showed as a call on hold.
    expect(twiml.match(/\+918140126027/g)).toHaveLength(1);
    expect(twiml).toContain('callerId="+18259070036"');
    expect(twiml).not.toContain('<Say>');
    expect(twiml).toContain('answerOnBridge="true"');
  });

  test('escapes XML so a crafted number cannot inject TwiML', () => {
    const twiml = buildBridgeTwiml('+1"><Hangup/><Dial>', '+91<Hangup/>');
    expect(twiml).not.toContain('<Hangup/>');
    expect(twiml).toContain('&lt;Hangup/&gt;');
  });
});

test.describe('number normalisation', () => {
  test('never invents a country code', () => {
    expect(toE164('8140126027')).toBe('+8140126027');
    expect(looksLikeE164('+8140126027')).toBe(true);
    expect(toE164('+91 81401 26027')).toBe('+918140126027');
    expect(toE164('')).toBe('');
  });

  test('rejects numbers that are too short to dial', () => {
    expect(looksLikeE164('+9181401')).toBe(false);
    expect(looksLikeE164('8140126027')).toBe(false);
  });
});

test.describe('webhook targets', () => {
  test('builds the URLs a number must call, without a double slash', () => {
    expect(webhookTargets('https://app.vercel.app/')).toEqual({
      voice: 'https://app.vercel.app/api/twilio/voice',
      sms: 'https://app.vercel.app/api/twilio/sms',
    });
  });
});

test.describe('webhook security', () => {
  // These endpoints are public. Without signature checking anyone who knew a
  // URL could forge call and message records, or make the server dial out.
  const routes = [
    '/api/twilio/voice',
    '/api/twilio/voice/completed',
    '/api/twilio/sms',
  ];

  for (const route of routes) {
    test(`${route} refuses an unsigned request`, async ({ request }) => {
      const response = await request.post(route, {
        form: {
          From: '+919876500123',
          To: '+18259070036',
          CallSid: 'CAforged',
          MessageSid: 'SMforged',
          Body: 'forged',
          Direction: 'inbound',
        },
      });

      expect(response.status()).toBe(403);
      expect(await response.text()).not.toContain('<Dial');
    });
  }

  test('a forged signature is rejected too', async ({ request }) => {
    const response = await request.post('/api/twilio/voice', {
      headers: { 'X-Twilio-Signature': 'not-a-real-signature' },
      form: { From: '+91987650123', To: '+18259070036', CallSid: 'CAx' },
    });

    expect(response.status()).toBe(403);
  });
});
