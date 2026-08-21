# Business Connect — Flutter app

Flutter 3.38 / Dart 3.10 client for the Business Connect admin panel. Users
sign in with the account an admin created for them, and dial from the Twilio
number the admin assigned them. The app ships no sample data — everything on
screen comes from the server.

## Running

The admin panel must be running first (see `../admin/README.md`).

```sh
flutter pub get
flutter run                 # pick a device
flutter run -d chrome       # or run it in the browser
```

Running in a browser is cross-origin — the app is served from its own port
while the API is on 3000 — so the admin panel sends CORS headers for
`/api/mobile/*`. Loopback origins are allowed out of the box; for a deployed
build, list its origin in `MOBILE_CORS_ORIGINS` on the server.

### Pointing the app at the server

The admin panel must be running (`npm run dev` from the repo root). It prints
both addresses on startup:

```
- Local:    http://localhost:3000
- Network:  http://10.212.112.52:3000     <- what a physical phone needs
```

| Where the app runs | Server address |
| --- | --- |
| Chrome / Edge (`flutter run -d chrome`) | `http://localhost:3000` (the default on web) |
| Android emulator | `http://10.0.2.2:3000` (the default on Android) |
| Physical device, USB | `http://127.0.0.1:3000` after `adb reverse tcp:3000 tcp:3000` |
| Physical device, Wi-Fi | the **Network** address printed above |
| Production | your `https://` host |

The default adapts to the platform, so running in a browser or on an emulator
needs no configuration at all.

Open **Server address** on the sign-in screen and press **Test connection**.
It says plainly whether the address is reachable, whether the thing answering
is actually the admin panel, and whether that panel can reach MongoDB — so a
wrong address never looks like a wrong password.

> **The Wi-Fi address changes.** Your computer's LAN IP is handed out by DHCP
> and will differ after reconnecting or switching networks, at which point the
> saved address stops working. `adb reverse tcp:3000 tcp:3000` over USB avoids
> this entirely: the phone then reaches the server on `http://127.0.0.1:3000`
> no matter what the Wi-Fi does.

Three ways to set the address, in order of precedence:

1. In the app — **Server address** on the sign-in screen. This is the one to
   use for a prebuilt APK.
2. At build time — `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000`
3. Otherwise the default above applies.

The address is saved with the session, so it survives restarts.

### If sign-in fails

| What you see | Cause |
| --- | --- |
| "did not respond" / "could not open a connection" | The panel is not running, or the address is wrong for this device. Press **Test connection**. |
| "not the admin panel" | Something else is on that port. |
| "cannot reach its database" | The panel is up but MongoDB is not running. |
| "Invalid email or password" | The account really is wrong — create or reset it on the panel's **Users** page. |
| Signed in, but no number | The admin has not assigned this account a number yet (**Phone Numbers** page). |

## Screens

| Screen | File | Backed by |
| --- | --- | --- |
| Permissions onboarding | `lib/screens/permissions_screen.dart` | — |
| Sign in | `lib/screens/login_screen.dart` | `POST /auth/login` |
| Home dashboard | `lib/screens/home_screen.dart` | `GET /me` |
| Dialer | `lib/screens/dialer_screen.dart` | `POST /calls/place` |
| Call history | `lib/screens/call_history_screen.dart` | `GET /calls` |
| Active call / call ended | `lib/screens/active_call_screen.dart`, `call_ended_screen.dart` | `POST /calls` |
| Messages / thread | `lib/screens/messages_screen.dart`, `conversation_screen.dart` | `GET,POST /messages` |
| New message | `lib/screens/new_message_screen.dart` | `POST /messages` |
| Message details | `lib/screens/message_details_screen.dart` | — |
| Contacts / contact details | `lib/screens/contacts_screen.dart`, `contact_details_screen.dart` | `GET,POST /contacts` |
| Settings | `lib/screens/settings_screen.dart` | `GET /me` |

Core plumbing lives in `lib/core/`: `api_client.dart` (HTTP + errors),
`session.dart` (auth, persistence, every request), `format.dart` (phone and
date formatting), `theme.dart` (design tokens).

## Behaviour worth knowing

- **No number assigned.** Every screen says so plainly and the dialer refuses to
  call, rather than failing with a generic error. Assigning a number in the
  admin panel unlocks it on the next refresh — no reinstall.
- **Twilio not configured.** Sending an SMS still records the message and shows
  the server's explanation; placing a call is refused with the same message.
- **Failed messages** show a retry control that re-sends through the API.

## Testing

```sh
flutter analyze
flutter test    # 24 tests
```

`test/fake_server.dart` is an in-memory stand-in for the admin API built on
`http`'s `MockClient`, so widget tests drive the real request/parse path without
a live server — including the no-number-assigned and server-error states.

## Building the APK

```sh
flutter build apk --release                    # universal
flutter build apk --release --split-per-abi    # smaller, per-device
```

Prebuilt APKs are in `../release/`.

Two things to know before shipping:

- Release builds are signed with the Flutter **debug key**. Add a real
  `signingConfig` in `android/app/build.gradle.kts` before distributing.
- `android/app/src/main/res/xml/network_security_config.xml` permits cleartext
  HTTP so the app can reach a local admin panel. Remove it once you serve the
  API over HTTPS.

## Not implemented

The in-call audio path is not wired to the Twilio Voice SDK: `POST /calls/place`
asks Twilio to bridge the call, and the call screen is a timer and control
surface over that. Mute, speaker, hold, keypad, conference and video are UI
only. Adding `twilio_voice` and the `/api/mobile/voice-token` endpoint (already
built server-side) is the next step for true in-app audio.
