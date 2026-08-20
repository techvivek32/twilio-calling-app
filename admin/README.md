# Business Connect — Admin Panel

Next.js 16 (App Router) + MongoDB. It is both the admin UI and the API the
Flutter app talks to.

## Setup

```sh
npm install
cp .env.example .env.local     # then fill in the two secrets
npm run seed                   # creates the admin + demo data
npm run dev                    # http://localhost:3000
```

`npm run seed` prints the credentials it creates. By default:

| Account | Email | Password |
| --- | --- | --- |
| Admin | `admin@businessconnect.local` | `ChangeMe123!` |
| App user | `alex@businessconnect.local` | `Password123!` |
| App user | `priya@businessconnect.local` | `Password123!` |

Change `SEED_ADMIN_PASSWORD` in `.env.local` before seeding a real deployment.

### Environment

| Variable | Purpose |
| --- | --- |
| `MONGODB_URI` | Mongo connection string (defaults to a local `twilio_call` db) |
| `AUTH_SECRET` | Signs admin session cookies and mobile bearer tokens |
| `APP_ENCRYPTION_KEY` | 64 hex chars; AES-256-GCM key for Twilio secrets at rest |
| `SEED_ADMIN_*` | Used only by `npm run seed` |

## What the admin can do

| Page | Capability |
| --- | --- |
| `/dashboard` | Users, numbers, calls and messages at a glance; busiest users; recent activity |
| `/users` | Create users, assign a number at creation, see per-user call/SMS counts |
| `/users/[id]` | Edit name/email/role/status, reset password, move numbers, delete the account |
| `/numbers` | Sync every number from Twilio, add numbers manually, **assign a number to a user**, enable/disable, remove |
| `/calls` | Every call with a per-user filter |
| `/messages` | Every SMS with a per-user filter |
| `/settings` | Twilio Account SID, Auth Token, API Key pair, TwiML App SID, webhook base URL; **Test connection** verifies them live |

Guard rails: the last active admin cannot be demoted, suspended or deleted, and
an admin cannot delete the account they are signed in with.

## Twilio

Add the Account SID and Auth Token on `/settings`, press **Test connection**,
then **Sync from Twilio** on `/numbers` to import every number you own.
Assignments survive re-syncs.

Secrets are encrypted with AES-256-GCM before they are written to MongoDB and
are never sent back to the browser — the form shows a masked placeholder and
leaving a secret field blank keeps the stored value.

For inbound traffic, set the webhook base URL on `/settings` and point each
number at:

- Voice: `<base>/api/twilio/voice`
- Messaging: `<base>/api/twilio/sms`

Inbound calls and texts are logged against whichever user owns the number.
Outbound voice from the app needs the API Key pair + TwiML App SID so
`/api/mobile/voice-token` can mint a Voice SDK token.

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

## Testing

```sh
npm run lint
npm run build
npm run e2e     # Playwright: 8 browser tests against a production build on :3100
npm run smoke   # 15 mobile-API checks against a running server on :3000
```

`npm run e2e` resets its own fixtures first (see `e2e/global-setup.ts`), so it
is safe to re-run.

## Notes

- `src/proxy.ts` is the Next 16 replacement for `middleware.ts`; it redirects
  signed-out visitors away from every admin route.
- Admin pages are Server Components reading MongoDB directly; mutations go
  through Server Actions in each route's `actions.ts`.
- `AssignSelect` calls its action outside a `<form>` on purpose: React 19 resets
  a form once its action resolves, which would snap the dropdown back to the
  previously rendered owner even though the change was saved.
