# Vision Connect

A Twilio-backed business phone system: an Android app for users, and a web
admin panel that hands out numbers and watches usage.

```
twilio-call/
├── admin/     Next.js 16 + MongoDB — admin UI and the app's API
└── app/       Flutter 3.38 — the Android client
```

## Quick start

```sh
# 1. Backend + admin panel
cd admin
npm install
cp .env.example .env.local        # set AUTH_SECRET, APP_ENCRYPTION_KEY and SEED_ADMIN_PASSWORD
npm run seed                      # creates only the admin account
npm run dev                       # http://localhost:3000

# 2. App
cd ../app
flutter pub get
flutter run
```

Sign in to the admin panel with the `SEED_ADMIN_*` credentials from your
`.env.local`. There is no demo data: create your own app users on the **Users**
page, and they sign in to the mobile app with those credentials.

`npm run dev` also works from the repo root; it forwards to `admin/`.

An Android emulator reaches the server on the default `http://10.0.2.2:3000`.
On a physical phone, open **Server address** on the app's sign-in screen, enter
the **Network** address that `npm run dev` printed, and press **Test
connection**. Note that this LAN IP changes when your computer reconnects to
Wi-Fi — over USB, `adb reverse tcp:3000 tcp:3000` lets the phone use
`http://127.0.0.1:3000` permanently instead.

## How the two halves fit together

The admin owns everything; the app only ever sees what it was granted.

1. Admin adds their Twilio credentials on **Settings**.
2. **Sync from Twilio** pulls every number on the account into the panel.
3. Admin creates app users, then assigns each one a number on **Phone Numbers**
   (or at the moment they create the user).
4. That user signs in to the app and dials, texts and receives from that number.
5. Every call and message is written back, so **Calls**, **Messages** and the
   dashboard show who used which number, how often, and for how long.

Change an assignment and the app follows on its next refresh. Take the number
away and the app says so instead of failing.

## Verification

| Command | What it covers |
| --- | --- |
| `cd admin && npm run lint && npm run build` | Types and production build |
| `cd admin && npm run e2e` | 21 Playwright tests: auth gating, theme persistence, provision → assign → release → delete, validation, Twilio settings, mobile-API CORS, sticky layout, click-to-call TwiML, webhook signature rejection |
| `cd admin && npm run smoke -- <email> <password>` | Every mobile endpoint incl. 401/409 paths, against a real app user |
| `cd app && flutter analyze && flutter test` | 42 tests against a mocked API |

## Twilio setup

Everything is configured from the admin panel — nothing is hardcoded.

Required for calls and SMS: Account SID + Auth Token.
Required for inbound: a public webhook base URL, with each number pointed at
`/api/twilio/voice` and `/api/twilio/sms`.
Required for in-app audio: API Key SID + Secret + TwiML App SID.

Secrets are encrypted at rest with AES-256-GCM and never returned to the browser.

## Theme

The admin panel ships light and dark themes with a Light / Dark / System
switcher in the sidebar. The choice is remembered per browser and applied
before first paint.

## Current limits

- In-call audio is not routed through the Twilio Voice SDK. Calls are a
  click-to-call bridge: Twilio rings the user's own phone, then connects the
  person they dialled. Each user therefore needs their own phone number set by
  an admin on `/users/[id]`.
- Release APKs are signed with the Flutter debug key.
- The app allows cleartext HTTP so it can reach a local server; drop that once
  the API is on HTTPS.
