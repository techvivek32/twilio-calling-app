// Exercises every endpoint the Flutter app calls, exactly as the app does.
const BASE = process.argv[2] ?? 'http://127.0.0.1:3000';

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
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}

const login = await call('POST', '/api/mobile/auth/login', {
  email: 'alex@businessconnect.local',
  password: 'Password123!',
});
token = login.json.token;
check('login returns a token', login.status === 200 && !!token);
check(
  'login returns the admin-assigned number',
  login.json.number?.phoneNumber === '+15550123456',
  login.json.number?.phoneNumber,
);

const me = await call('GET', '/api/mobile/me');
check('me returns the dashboard payload', me.status === 200);
check(
  'me reports today counters',
  typeof me.json.today?.calls === 'number',
  `calls=${me.json.today?.calls} missed=${me.json.today?.missed}`,
);
check(
  'me reports the assigned number',
  me.json.number?.phoneNumber === '+15550123456',
);

const calls = await call('GET', '/api/mobile/calls');
check(
  'calls history returns a list',
  calls.status === 200 && Array.isArray(calls.json.calls),
  `${calls.json.calls?.length} calls`,
);

const logged = await call('POST', '/api/mobile/calls', {
  to: '+12025550199',
  contactName: 'Acme Corporation',
  direction: 'outbound',
  status: 'completed',
  durationSec: 42,
});
check('logging a call succeeds', logged.status === 201);

const messages = await call('GET', '/api/mobile/messages');
check(
  'messages returns conversations',
  messages.status === 200 && Array.isArray(messages.json.conversations),
  `${messages.json.conversations?.length} threads`,
);

const sent = await call('POST', '/api/mobile/messages', {
  to: '+15550198372',
  body: 'Smoke-test message',
  contactName: 'Sarah Jenkins',
});
check(
  'sending SMS records the message',
  sent.status === 201 && !!sent.json.message?.id,
);
check(
  'sending SMS explains an unconfigured Twilio',
  typeof sent.json.warning === 'string' && sent.json.warning.length > 0,
  sent.json.warning,
);

const place = await call('POST', '/api/mobile/calls/place', {
  to: '+12025550199',
});
check(
  'placing a call reports Twilio is not configured (409)',
  place.status === 409,
  place.json.error,
);

const contacts = await call('GET', '/api/mobile/contacts');
check(
  'contacts returns a list',
  contacts.status === 200 && Array.isArray(contacts.json.contacts),
  `${contacts.json.contacts?.length} contacts`,
);

const voice = await call('GET', '/api/mobile/voice-token');
check(
  'voice token reports missing API keys (409)',
  voice.status === 409,
  voice.json.error,
);

token = 'garbage';
const unauthorised = await call('GET', '/api/mobile/me');
check('an invalid token is rejected (401)', unauthorised.status === 401);

token = null;
const anonymous = await call('GET', '/api/mobile/calls');
check('a missing token is rejected (401)', anonymous.status === 401);

const failed = results.filter((r) => !r.ok);
console.log(
  `\n${results.length - failed.length}/${results.length} checks passed`,
);
process.exit(failed.length ? 1 : 0);
