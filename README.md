# Business Connect

A Twilio-backed business phone system: an Android app for users, and a web
admin panel that hands out numbers and watches usage.

```
twilio-call/
├── admin/     Next.js 16 + MongoDB — admin UI and the app's API
├── app/       Flutter 3.38 — the Android client
└── release/   prebuilt release APKs
```

## Quick start

```sh
# 1. Backend + admin panel
cd admin
npm install
cp .env.example .env.local        # fill in AUTH_SECRET and APP_ENCRYPTION_KEY
npm run seed
npm run dev                       # http://localhost:3000

# 2. App
cd ../app
flutter pub get
flutter run
```

Sign in to the admin panel as `admin@businessconnect.local` / `ChangeMe123!`,
and to the app as `alex@businessconnect.local` / `Password123!`.

On a physical phone, set **Server address** on the app's sign-in screen to
`http://<your-computer-LAN-IP>:3000`. An Android emulator works with the
default `http://10.0.2.2:3000`.

## How the two halves fit together

The admin owns everything; the app only ever sees what it was granted.

1. Admin adds their Twilio credentials on **Settings**.
2. **Sync from Twilio** pulls every number on the account into the panel.
3. Admin assigns a number to a user on **Phone Numbers** (or when creating the
   user).
4. That user signs in to the app and dials, texts and receives from that number.
5. Every call and message is written back, so **Calls**, **Messages** and the
   dashboard show who used which number, how often, and for how long.

Change an assignment and the app follows on its next refresh. Take the number
away and the app says so instead of failing.

## Verification

| Command | What it covers |
| --- | --- |
| `cd admin && npm run lint && npm run build` | Types and production build |
| `cd admin && npm run e2e` | 8 Playwright tests: login, auth gating, assignment both ways, user create/delete, duplicate rejection, Twilio settings persistence, manual numbers, sign-out |
| `cd admin && npm run smoke` | 15 checks over every mobile endpoint incl. 401/409 paths |
| `cd app && flutter analyze && flutter test` | 24 tests against a mocked API |

## Twilio setup

Everything is configured from the admin panel — nothing is hardcoded.

Required for calls and SMS: Account SID + Auth Token.
Required for inbound: a public webhook base URL, with each number pointed at
`/api/twilio/voice` and `/api/twilio/sms`.
Required for in-app audio: API Key SID + Secret + TwiML App SID.

Secrets are encrypted at rest with AES-256-GCM and never returned to the browser.

## Current limits

- In-call audio is not yet routed through the Twilio Voice SDK; the server
  bridges the call and the app shows the call UI over it. See `app/README.md`.
- Release APKs are signed with the Flutter debug key.
- The app allows cleartext HTTP so it can reach a local server; drop that once
  the API is on HTTPS.
