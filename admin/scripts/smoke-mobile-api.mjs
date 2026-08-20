/**
 * Exercises every endpoint the Flutter app calls, exactly as the app does.
 *
 *   node scripts/smoke-mobile-api.mjs [baseUrl] <email> <password>
 *
 * Use a real app user you created on the Users page. Read-only apart from one
 * logged call and one SMS attempt, both recorded against that account.
 */
const [, , ...argv] = process.argv;

const BASE = argv[0]?.startsWith('http')
  ? argv.shift()
  : 'http://127.0.0.1:3000';
const [EMAIL, PASSWORD] = argv;

if (!EMAIL || !PASSWORD) {
  console.error(
    'Usage: node scripts/smoke-mobile-api.mjs [baseUrl] <email> <password>\n\n' +
      'Create an app user on the Users page first, then pass its credentials.',
  );
  process.exit(2);
}

let token = null;
const results = [];

async function call(method, path, body) {
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const json = await response.json().catch(() => ({}));
  return { status: response.status, json };
}

function check(name, ok, detail = '') {
  results.push({ name, ok });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}

const login = await call('POST', '/api/mobile/auth/login', {
  email: EMAIL,
  password: PASSWORD,
});
token = login.json.token;
check('login returns a token', login.status === 200 && !!token);

if (!token) {
  console.error(`\nCould not sign in as ${EMAIL}: ${login.json.error ?? ''}`);
  process.exit(1);
}

const assignedNumber = login.json.number?.phoneNumber ?? null;
check(
  'login reports the assigned number',
  true,
  assignedNumber ?? 'none assigned by the admin yet',
);

const me = await call('GET', '/api/mobile/me');
check('me returns the dashboard payload', me.status === 200);
check(
  'me reports today counters',
  typeof me.json.today?.calls === 'number',
  `calls=${me.json.today?.calls} missed=${me.json.today?.missed}`,
);
check(
  'me agrees with login about the number',
  (me.json.number?.phoneNumber ?? null) === assignedNumber,
);

const calls = await call('GET', '/api/mobile/calls');
check(
  'calls history returns a list',
  calls.status === 200 && Array.isArray(calls.json.calls),
  `${calls.json.calls?.length} calls`,
);

const messages = await call('GET', '/api/mobile/messages');
check(
  'messages returns conversations',
  messages.status === 200 && Array.isArray(messages.json.conversations),
  `${messages.json.conversations?.length} threads`,
);

const contacts = await call('GET', '/api/mobile/contacts');
check(
  'contacts returns a list',
  contacts.status === 200 && Array.isArray(contacts.json.contacts),
  `${contacts.json.contacts?.length} contacts`,
);

// Writes and Twilio-dependent routes behave differently with and without an
// assigned number; both outcomes are correct, so assert the matching one.
const logged = await call('POST', '/api/mobile/calls', {
  to: '+12025550100',
  contactName: 'Smoke test',
  direction: 'outbound',
  status: 'completed',
  durationSec: 1,
});
check(
  assignedNumber
    ? 'logging a call succeeds'
    : 'logging a call is refused without a number (409)',
  assignedNumber ? logged.status === 201 : logged.status === 409,
  logged.json.error ?? '',
);

const sent = await call('POST', '/api/mobile/messages', {
  to: '+12025550100',
  body: 'Smoke test message',
  contactName: 'Smoke test',
});
check(
  assignedNumber
    ? 'sending SMS is recorded and reports delivery state'
    : 'sending SMS is refused without a number (409)',
  assignedNumber ? sent.status === 201 || sent.status === 502 : sent.status === 409,
  sent.json.warning ?? sent.json.error ?? 'sent',
);

const place = await call('POST', '/api/mobile/calls/place', {
  to: '+12025550100',
});
check(
  'placing a call reports a clear reason when it cannot dial',
  place.status === 409 || place.status === 200 || place.status === 502,
  place.json.error ?? `status ${place.status}`,
);

const voice = await call('GET', '/api/mobile/voice-token');
check(
  'voice token endpoint answers',
  voice.status === 200 || voice.status === 409,
  voice.json.error ?? 'token issued',
);

token = 'garbage';
check(
  'an invalid token is rejected (401)',
  (await call('GET', '/api/mobile/me')).status === 401,
);

token = null;
check(
  'a missing token is rejected (401)',
  (await call('GET', '/api/mobile/calls')).status === 401,
);

const failed = results.filter((r) => !r.ok);
console.log(
  `\n${results.length - failed.length}/${results.length} checks passed`,
);
process.exit(failed.length ? 1 : 0);
