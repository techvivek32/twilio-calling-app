# Vision Connect — Admin Panel

Next.js 16 (App Router) + MongoDB. It is both the admin UI and the API the
Flutter app talks to.

## Setup

```sh
npm install
cp .env.example .env.local     # fill in the secrets, and set SEED_ADMIN_PASSWORD
npm run seed                   # creates the admin account, nothing else
npm run dev                    # http://localhost:3000
```

`npm run seed` creates **only** the admin account, using `SEED_ADMIN_EMAIL` and
`SEED_ADMIN_PASSWORD` from `.env.local`. It refuses to run without a password
and never overwrites an existing admin. There is no demo data — every user,
number, call and message in the panel is real.

If you ever need to clear the panel back to a fresh state:

```sh
npm run purge   # deletes all app users, numbers, calls, messages and contacts
```

That keeps your admin accounts and your saved Twilio settings.

### Environment

| Variable | Purpose |
| --- | --- |
| `MONGODB_URI` | Mongo connection string (defaults to a local `twilio_call` db) |
| `AUTH_SECRET` | Signs admin session cookies and mobile bearer tokens |
| `APP_ENCRYPTION_KEY` | 64 hex chars; AES-256-GCM key for Twilio secrets at rest |
| `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` / `SEED_ADMIN_NAME` | Used only by `npm run seed` |
| `MOBILE_CORS_ORIGINS` | Extra origins allowed to call `/api/mobile` from a browser, comma separated. Loopback origins are always allowed. |

## First run

The dashboard shows a checklist until the panel is fully set up:

1. **Connect Twilio** — Account SID + Auth Token on Settings, then *Test connection*.
2. **Import numbers** — *Sync from Twilio* on Phone Numbers pulls in everything
   your account owns.
3. **Create app users** — one account per person who signs in to the mobile app.
4. **Assign a number** — a user cannot call or text until they own one.

## What the admin can do

| Page | Capability |
| --- | --- |
| `/dashboard` | Setup checklist, users/numbers/calls/messages counters, busiest users, recent activity |
| `/users` | Create users, assign a number at creation, see per-user call/SMS counts |
| `/users/[id]` | Edit name/email/role/status, **set their own phone**, reset password, move numbers, delete the account |
| `/numbers` | Sync from Twilio, add numbers manually, **assign a number to a user**, enable/disable, remove |
| `/calls` | Every call with a per-user filter |
| `/messages` | Every SMS with a per-user filter |
| `/settings` | Twilio credentials, API key pair, TwiML App SID, webhook base URL, live connection test |

Guard rails: the last active admin cannot be demoted, suspended or deleted, and
an admin cannot delete the account they are signed in with.

## Theme

Light, dark and system, switched from the control above the account block in
the sidebar (and on the sign-in screen). The choice is stored per browser in
`localStorage` and applied by an inline script before first paint, so there is
no flash of the wrong palette on load.

Colours are runtime CSS variables mapped into Tailwind with `@theme inline`, so
`bg-surface` / `text-ink` / `border-line` follow the active theme without a
second set of `dark:` classes. Tokens live at the top of `src/app/globals.css`.

## Twilio

Add the Account SID and Auth Token on `/settings`, press **Test connection**,
then **Sync from Twilio** on `/numbers`. Assignments survive re-syncs.

Secrets are encrypted with AES-256-GCM before they are written to MongoDB and
are never sent back to the browser — the form shows a masked placeholder and
leaving a secret field blank keeps the stored value.

For inbound traffic, set the webhook base URL on `/settings` and point each
number at:

- Voice: `<base>/api/twilio/voice`
- Messaging: `<base>/api/twilio/sms`

Inbound calls and texts are logged against whichever user owns the number.

### Incoming calls and texts

An incoming call **forwards to the owner's own phone** — the same handset
click-to-call rings — with the business number as the caller ID. It previously
dialled `<Client>`, which needs the Twilio Voice SDK registered from the
device; the app has no SDK, so nothing was listening and every incoming call
rang out. A number whose owner has no phone on file answers with a spoken
notice rather than ringing nowhere.

The flow:

1. `POST /api/twilio/voice` — verifies the signature, logs the call as missed
   up front so a caller who gives up mid-ring is still recorded, then dials the
   owner's phone for 25 seconds.
2. `POST /api/twilio/voice/completed` — Twilio's `action` callback, which fires
   however the dial ends. It writes the true outcome (answered, busy, no
   answer) and the real duration. Without it every answered call would stay
   filed as missed.
3. `POST /api/twilio/sms` — files an inbound message against the number's
   owner, keyed on the message SID so a Twilio retry cannot duplicate it.

**Every webhook verifies `X-Twilio-Signature`** and answers `403` otherwise.
These URLs are public: unsigned, anyone who learned one could forge call and
message records or make the server dial a number of their choosing.

Set the public webhook base URL on `/settings`, then press **Point numbers at
this server** — it writes the voice and messaging webhooks onto every number
through the Twilio API, so nothing has to be typed into the Twilio Console.
The card lists each number as *Wired* or *Not wired*.

On Vercel the base URL defaults to the deployment's own address, so a fresh
deploy only needs the button pressed.

## Mobile API

All routes are under `/api/mobile` and use `Authorization: Bearer <token>`
except login.

| Route | Purpose |
| --- | --- |
| `POST /auth/login` | Email + password → token, profile, assigned number |
| `GET /me` | Dashboard payload: number, today's counters, recent activity |
| `GET /calls` · `POST /calls` | History; log a call the app handled |
| `POST /calls/place` | Dial through Twilio from the user's number |
| `GET /messages` · `POST /messages` | Threads; send an SMS |
| `GET /contacts` · `POST /contacts` | Per-user contact book |
| `GET /voice-token` | Twilio Voice access token |

When the admin has not assigned a number, or Twilio is unconfigured, these
return `409` with a message the app shows verbatim rather than failing silently.

### How a call is placed

Click-to-call is a two-leg bridge, so the app needs no in-device audio stack:

1. Twilio rings the user's **own phone** (`personalNumber` on their account).
2. When they answer, the TwiML dials the person they wanted, with their
   business number as the caller ID.

The leg Twilio creates must go to the user's phone. Creating it to the person
being called and then `<Dial>`ing that same number rang them twice — the
second call landing while the first was still up, which the handset showed as
a call on hold. `buildBridgeTwiml` is unit-tested against exactly that.

`POST /api/mobile/calls/place` returns `409` until an admin sets the user's own
phone on `/users/[id]`. A call the app logged while it was open only carries a
provisional outcome, so the Calls and Dashboard pages reconcile recent calls
against Twilio on load (`src/lib/call-sync.ts`) and write back the real status
and duration. Without that a finished call stayed at `0s` forever. `GET /api/mobile/calls/status?sid=…` reports Twilio's
live state so the app can show *Ringing* and start its timer only once the far
end answers; it also writes the final outcome and duration back to the call log.

Numbers are never assumed to be American. The app composes E.164 from its
country picker, and the API rejects anything that is not a full international
number — a 10-digit Indian mobile silently becoming `+1…` was why SMS failed.

`GET /api/mobile/health` is unauthenticated and backs the app's **Test
connection** button: it confirms the server is this panel and that MongoDB is
reachable.

A Flutter web build runs on its own port, so its calls are cross-origin.
`src/proxy.ts` answers the preflight and echoes the origin for `/api/mobile/*`
— loopback origins always, plus anything in `MOBILE_CORS_ORIGINS`. Unrelated
origins get no CORS headers, so the browser blocks them.

## Testing

```sh
npm run lint
npm run build
npm run e2e                                   # 21 Playwright tests
npm run smoke -- <email> <password>           # mobile API, against a real app user
```

`npm run e2e` builds and serves the app on port 3100, provisions its own
fixtures through the UI, and cleans up first (`e2e/global-setup.ts`). It only
ever touches accounts whose email starts with `e2e-` and two reserved test
numbers, so it is safe to run against a populated panel.

The settings spec types into the Twilio fields, so the suite snapshots the real
Account SID and webhook URL before it runs and restores them afterwards. It
used to blank them outright, which silently took a configured account offline
until someone noticed and re-entered it.

## Notes

- `src/proxy.ts` is the Next 16 replacement for `middleware.ts`; it redirects
  signed-out visitors away from every admin route.
- Admin pages are Server Components reading MongoDB directly; mutations go
  through Server Actions in each route's `actions.ts`.
- `AssignSelect` calls its action outside a `<form>` on purpose: React 19 resets
  a form once its action resolves, which would snap the dropdown back to the
  previously rendered owner even though the change was saved.
- Sign-out returns a **relative** `Location`. Building an absolute URL from
  `request.url` can redirect to a different origin (`localhost` vs a LAN IP),
  which strands the browser and drops origin-scoped storage such as the theme.
