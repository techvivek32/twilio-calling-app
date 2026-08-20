# Business Connect — Flutter app

Flutter 3.38 / Dart 3.10 client for the Business Connect admin panel. Users
sign in with the account an admin created for them, and dial from the Twilio
number the admin assigned them. The app ships no sample data — everything on
screen comes from the server.

## Running

The admin panel must be running first (see `../admin/README.md`).

```sh
flutter pub get
flutter run
```

### Pointing the app at the server

| Where the app runs | Server address |
| --- | --- |
| Android emulator | `http://10.0.2.2:3000` (the default) |
| Physical device | `http://<your-computer-LAN-IP>:3000` |
| Production | your `https://` host |

Three ways to set it, in order of precedence:

1. In the app — open **Server address** on the sign-in screen. This is the one
   to use for the prebuilt APKs.
2. At build time — `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000`
3. Otherwise the default above applies.

The address is saved with the session, so it survives restarts.

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
