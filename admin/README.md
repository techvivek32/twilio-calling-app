# Business Connect — Admin Panel

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
| `/users/[id]` | Edit name/email/role/status, reset password, move numbers, delete the account |
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
npm run e2e                                   # 9 Playwright tests
npm run smoke -- <email> <password>           # mobile API, against a real app user
```

`npm run e2e` builds and serves the app on port 3100, provisions its own
fixtures through the UI, and cleans up first (`e2e/global-setup.ts`). It only
ever touches accounts whose email starts with `e2e-` and two reserved test
numbers, so it is safe to run against a populated panel.

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
