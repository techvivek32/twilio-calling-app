import { expect, test } from '@playwright/test';

import { buildBridgeTwiml, looksLikeE164, toE164 } from '../src/lib/twilio';

test.describe('click-to-call TwiML', () => {
  test('dials the person called, not the leg Twilio already made', () => {
    const twiml = buildBridgeTwiml('+18259070036', '+918140126027');

    // The far end must appear exactly once. Dialling the created leg again
    // rang the callee twice, which the handset showed as a call on hold.
    expect(twiml.match(/\+918140126027/g)).toHaveLength(1);
    expect(twiml).toContain('callerId="+18259070036"');
    expect(twiml).not.toContain('<Say>');
    // answerOnBridge keeps the caller hearing real ringing until pickup.
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
    // The bug this guards: a 10-digit Indian mobile became an invalid US
    // number, which Twilio rejected when sending SMS.
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
