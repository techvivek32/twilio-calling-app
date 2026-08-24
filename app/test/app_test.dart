import 'dart:io';

import 'package:business_connect/core/api_client.dart';
import 'package:business_connect/core/countries.dart';
import 'package:business_connect/core/format.dart';
import 'package:business_connect/core/session.dart';
import 'package:business_connect/core/theme.dart';
import 'package:business_connect/models/models.dart';
import 'package:business_connect/screens/contact_details_screen.dart';
import 'package:business_connect/screens/call_history_screen.dart';
import 'package:business_connect/screens/contacts_screen.dart';
import 'package:business_connect/screens/conversation_screen.dart';
import 'package:business_connect/screens/dialer_screen.dart';
import 'package:business_connect/screens/home_screen.dart';
import 'package:business_connect/screens/login_screen.dart';
import 'package:business_connect/screens/messages_screen.dart';
import 'package:business_connect/screens/new_message_screen.dart';
import 'package:business_connect/screens/settings_screen.dart';
import 'package:business_connect/screens/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'fake_server.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: AppTheme.build(),
  debugShowCheckedModeBanner: false,
  home: Scaffold(body: child),
);

void main() {
  group('formatting', () {
    final india = CountryLookup.byIso('IN')!;
    final us = CountryLookup.byIso('US')!;

    test('shows the picked country code with the typed digits', () {
      expect(formatDialedNumber(india, '8140126027'), '+91 81401 26027');
      expect(formatDialedNumber(us, '2025550199'), '+1 20255 50199');
      expect(formatDialedNumber(india, ''), '');
    });

    test('renders stored E.164 numbers for display', () {
      expect(formatPhoneNumber('+15550123456'), '+1 (555) 012-3456');
    });

    test('composes a national number with the chosen country', () {
      // The bug this replaces: a 10-digit Indian mobile was assumed to be
      // American, producing the invalid +18140126027 that Twilio rejected.
      expect(toE164(india, '8140126027'), '+918140126027');
      expect(toE164(us, '(202) 555-0199'), '+12025550199');
      expect(toE164(india, ''), '');
    });

    test('drops a national trunk zero', () {
      final uk = CountryLookup.byIso('GB')!;
      expect(toE164(uk, '07700900123'), '+447700900123');
    });

    test('cleans an already-international number without guessing', () {
      expect(normaliseE164('+44 7700 900123'), '+447700900123');
      expect(normaliseE164('(555) 012-3456'), '+5550123456');
      expect(normaliseE164(''), '');
    });

    test('recognises which country an E.164 number belongs to', () {
      expect(CountryLookup.fromE164('+918140126027')?.iso, 'IN');
      expect(CountryLookup.fromE164('+18259070036')?.iso, 'US');
      // Longest prefix wins, so +971 is the UAE rather than +9-something.
      expect(CountryLookup.fromE164('+971501234567')?.iso, 'AE');
    });

    test('rejects incomplete numbers', () {
      expect(looksLikeE164('+918140126027'), isTrue);
      expect(looksLikeE164('+9181401'), isFalse);
      expect(looksLikeE164('8140126027'), isFalse);
    });

    test('formats call durations', () {
      expect(formatDuration(0), '0s');
      expect(formatDuration(45), '45s');
      expect(formatDuration(312), '5m 12s');
    });
  });

  group('sign in', () {
    testWidgets('rejects empty credentials before calling the server', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final server = FakeServer();

      await tester.pumpWidget(
        wrap(LoginScreen(session: signedOutSession(server))),
      );

      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Email or username is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('surfaces the server message on a bad password', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final server = FakeServer();

      await tester.pumpWidget(
        wrap(LoginScreen(session: signedOutSession(server))),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'alex@businessconnect.local',
      );
      await tester.enterText(find.byType(TextFormField).last, 'nope');
      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(server.requests, contains('POST /api/mobile/auth/login'));
    });

    testWidgets('stores the assigned number after a good password', (
      tester,
    ) async {
      final server = FakeServer();
      final session = await signedInSession(server);

      expect(session.isSignedIn, isTrue);
      expect(session.hasNumber, isTrue);
      expect(session.number!.formatted, '+1 (555) 012-3456');
    });
  });

  group('home', () {
    testWidgets('renders live counters from the server', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(
        wrap(
          HomeScreen(
            session: session,
            onOpenDialer: () {},
            onOpenTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Alex'), findsWidgets);
      expect(find.text('+1 (555) 012-3456'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('2 Missed'), findsOneWidget);
      expect(find.text('10 Incoming'), findsOneWidget);

      // Recent activity sits below the fold on a phone.
      await tester.scrollUntilVisible(
        find.text('Call from John Doe'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Call from John Doe'), findsOneWidget);
    });

    testWidgets('shows the unassigned state when admin gave no number', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final session = await signedInSession(
        FakeServer(assignNumber: false),
      );

      await tester.pumpWidget(
        wrap(
          HomeScreen(
            session: session,
            onOpenDialer: () {},
            onOpenTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No number yet'), findsOneWidget);
      expect(find.text('Not assigned'), findsOneWidget);
    });

    testWidgets('shows the server error when the request fails', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final server = FakeServer();
      final session = await signedInSession(server);
      server.failStatus = 500;
      server.failMessage = 'Database unavailable.';

      await tester.pumpWidget(
        wrap(
          HomeScreen(
            session: session,
            onOpenDialer: () {},
            onOpenTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load'), findsOneWidget);
      expect(find.text('Database unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('calls', () {
    testWidgets('lists history and filters to missed', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(wrap(CallHistoryScreen(session: session)));
      await tester.pumpAndSettle();

      expect(find.text('Alexander Wright'), findsOneWidget);
      expect(find.text('Sarah Richards'), findsOneWidget);

      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();

      expect(find.text('Alexander Wright'), findsOneWidget);
      expect(find.text('Sarah Richards'), findsNothing);
    });

    testWidgets('search narrows the list', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(wrap(CallHistoryScreen(session: session)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'emily');
      await tester.pumpAndSettle();

      expect(find.text('Emily Chen'), findsOneWidget);
      expect(find.text('Alexander Wright'), findsNothing);
    });

    testWidgets('dialer places the call through the API', (tester) async {
      usePhoneViewport(tester);
      final server = FakeServer()..personalNumber = '+919876543210';
      final session = await signedInSession(server);

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialNumber: '+12025550199')),
      );
      await tester.pumpAndSettle();

      expect(find.text('20255 50199'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('Acme Corporation'), findsOneWidget);

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(server.placedCalls, hasLength(1));
      expect(server.placedCalls.first['to'], '+12025550199');

      // A placed call is not an answered one: no clock until it connects.
      expect(find.text('DIALLING VIA TWILIO'), findsOneWidget);
      expect(find.text('Calling…'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);

      server.callStatus = 'ringing';
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ringing…'), findsOneWidget);
      expect(find.text('RINGING'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);

      // Only once the far end picks up does the timer appear and run.
      server.callStatus = 'in-progress';
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('CONNECTED VIA TWILIO'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('Ringing…'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);
    });


    testWidgets('the dialler asks for the phone to ring, then calls', (
      tester,
    ) async {
      usePhoneViewport(tester);
      // A fresh account has no phone to ring.
      final server = FakeServer();
      final session = await signedInSession(server);

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialNumber: '+12025550199')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Call'));
      await tester.pumpAndSettle();

      // Rather than refusing and pointing elsewhere, it asks right here.
      expect(find.text('Which phone should ring?'), findsOneWidget);
      expect(server.placedCalls, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, '98765 43210'),
        '9876543210',
      );
      await tester.tap(find.text('Save and call'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Saved in full international form, and the call goes through.
      expect(server.personalNumber, '+919876543210');
      expect(server.placedCalls, hasLength(1));
      expect(server.placedCalls.first['to'], '+12025550199');
    });

    testWidgets('cancelling the phone prompt places no call', (tester) async {
      usePhoneViewport(tester);
      final server = FakeServer();
      final session = await signedInSession(server);

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialNumber: '+12025550199')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Call'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.placedCalls, isEmpty);
      expect(find.text('Which phone should ring?'), findsNothing);
    });


    testWidgets('calling from history actually dials', (tester) async {
      usePhoneViewport(tester);
      final server = FakeServer()..personalNumber = '+919876543210';
      final session = await signedInSession(server);

      await tester.pumpWidget(wrap(CallHistoryScreen(session: session)));
      await tester.pumpAndSettle();

      // The history row used to open the call screen without ever asking
      // Twilio to dial, so it sat at "Not connected".
      await tester.tap(find.byTooltip('Call back').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(server.placedCalls, hasLength(1));
      expect(find.text('Calling…'), findsOneWidget);
    });


    testWidgets('every screen that offers a call actually dials', (
      tester,
    ) async {
      // These paths drifted once already: history opened the call screen
      // without dialling, and contacts/details/conversation never asked for
      // the phone to bridge to, so they failed silently.
      final contact = Contact(
        id: 'c1',
        name: 'Sarah Jenkins',
        phone: '+919876500001',
      );

      final entries = <String, (Widget Function(AppSession), Finder)>{
        'contacts': (
          (s) => ContactsScreen(session: s),
          find.byTooltip('Call'),
        ),
        'contact details': (
          (s) => ContactDetailsScreen(contact: contact, session: s),
          find.text('Call'),
        ),
        'history': (
          (s) => CallHistoryScreen(session: s),
          find.byTooltip('Call back'),
        ),
      };

      for (final entry in entries.entries) {
        final (build, button) = entry.value;
        // Tear the previous tree down: Navigator state survives pumpWidget
        // when the root widget type matches, so the call screen pushed by the
        // last iteration would still be on top.
        await tester.pumpWidget(const SizedBox.shrink());
        usePhoneViewport(tester);
        final server = FakeServer()..personalNumber = '+919876543210';
        final session = await signedInSession(server);

        await tester.pumpWidget(wrap(build(session)));
        await tester.pumpAndSettle();

        expect(
          button,
          findsWidgets,
          reason: '${entry.key} should offer a call button',
        );

        await tester.tap(button.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          server.placedCalls,
          hasLength(1),
          reason: '${entry.key} must place the call, not just open the screen',
        );
      }
    });

    testWidgets('hanging up ends the call on Twilio, not just the screen', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final server = FakeServer()..personalNumber = '+919876543210';
      final session = await signedInSession(server);

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialNumber: '+12025550199')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final sid = server.placedCalls.first['sid'] ?? 'CA-test';
      await tester.tap(find.byTooltip('End call'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(server.hungUp, isNotEmpty);
      expect(server.hungUp.first, isNotEmpty);
      expect(sid, isNotNull);
    });

    testWidgets('an unanswered call reports why it ended', (tester) async {
      usePhoneViewport(tester);
      final server = FakeServer()..personalNumber = '+919876543210';
      final session = await signedInSession(server);

      await tester.pumpWidget(
        wrap(
          DialerScreen(session: session, initialNumber: '+12025550199'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Call'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      server.callStatus = 'no-answer';
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No answer'), findsOneWidget);

      // It then moves on to the summary, carrying the outcome across.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('No answer'), findsOneWidget);
    });

    testWidgets('keypad edits the dialled number', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialNumber: '+12025550199')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump();

      expect(find.text('20255 50197'), findsOneWidget);
    });

    testWidgets('dialer reports when no number is assigned', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer(assignNumber: false));

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialNumber: '+12025550199')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No number assigned to this account'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Call'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No phone number is assigned'),
        findsOneWidget,
      );
    });
  });

  group('messages', () {
    testWidgets('lists conversations from the server', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(wrap(MessagesScreen(session: session)));
      await tester.pumpAndSettle();

      expect(find.text('Sarah Jenkins'), findsOneWidget);
    });

    testWidgets('sends a reply and appends it to the thread', (tester) async {
      usePhoneViewport(tester);
      final server = FakeServer();
      final session = await signedInSession(server);
      final conversations = await session.loadConversations();

      await tester.pumpWidget(
        wrap(
          ConversationScreen(
            session: session,
            conversation: conversations.first,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'On my way');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(server.sentMessages, hasLength(1));
      expect(server.sentMessages.first['body'], 'On my way');
      expect(server.sentMessages.first['to'], '+15550198372');
      expect(find.text('On my way'), findsOneWidget);
    });

    testWidgets('retries a failed message', (tester) async {
      usePhoneViewport(tester);
      final server = FakeServer();
      final session = await signedInSession(server);
      final conversations = await session.loadConversations();

      await tester.pumpWidget(
        wrap(
          ConversationScreen(
            session: session,
            conversation: conversations.first,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(server.sentMessages, hasLength(1));
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('new message sends to a picked contact', (tester) async {
      usePhoneViewport(tester);
      final server = FakeServer();
      final session = await signedInSession(server);

      await tester.pumpWidget(
        wrap(
          NewMessageScreen(
            session: session,
            prefillNumber: '+15550198372',
            prefillName: 'Sarah Jenkins',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sarah Jenkins'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Type your message here...'),
        'Confirming tomorrow at 10.',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Send SMS'));
      await tester.tap(find.text('Send SMS'));
      await tester.pumpAndSettle();

      expect(server.sentMessages, hasLength(1));
      expect(server.sentMessages.first['to'], '+15550198372');
    });
  });

  group('contacts and settings', () {
    testWidgets('contacts come from the server', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(wrap(ContactsScreen(session: session)));
      await tester.pumpAndSettle();

      expect(find.text('Sarah Jenkins'), findsOneWidget);
      expect(find.text('Acme Corporation'), findsOneWidget);
      expect(find.text('+1 (202) 555-0199'), findsOneWidget);
    });


    testWidgets('the user can set their own phone from settings', (
      tester,
    ) async {
      usePhoneViewport(tester, size: const Size(390, 900));
      final server = FakeServer();
      final session = await signedInSession(server);

      await tester.pumpWidget(wrap(SettingsScreen(session: session)));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Your phone'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // A fresh account is told this is required.
      expect(find.text('Required'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '98765 43210'),
        '9876543210',
      );
      await tester.ensureVisible(find.text('Save my phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save my phone'));
      await tester.pumpAndSettle();

      // Saved in full international form, using the picked country.
      expect(server.personalNumber, '+919876543210');
      expect(session.user?.personalNumber, '+919876543210');
      expect(find.textContaining('Saved.'), findsOneWidget);
    });

    testWidgets('settings shows the assigned number and capabilities', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(wrap(SettingsScreen(session: session)));
      await tester.pumpAndSettle();

      expect(find.text('+1 (555) 012-3456'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('SMS messaging'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Voice calling'), findsOneWidget);
      expect(find.text('SMS messaging'), findsOneWidget);
    });

    testWidgets('settings explains an unassigned account', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer(assignNumber: false));

      await tester.pumpWidget(wrap(SettingsScreen(session: session)));
      await tester.pumpAndSettle();

      expect(find.text('No number assigned'), findsOneWidget);
      expect(find.text('Unassigned'), findsOneWidget);
    });
  });

  group('shell', () {
    testWidgets('bottom navigation moves between tabs', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(),
          home: ShellScreen(session: session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Quick Actions'.toUpperCase()),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Quick Actions'.toUpperCase()), findsOneWidget);

      await tester.tap(find.text('Calls'));
      await tester.pumpAndSettle();
      expect(find.text('Call History'), findsOneWidget);

      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsWidgets);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Connection Status'), findsOneWidget);
    });
  });

  group('server address check', () {
    test('accepts a healthy Vision Connect server', () async {
      final server = FakeServer();
      final api = ApiClient(
        httpClient: server.client(),
        baseUrl: 'http://test.local',
      );

      await api.ping();
      expect(server.requests, contains('GET /api/mobile/health'));
    });

    test('probes a candidate address without switching to it', () async {
      final server = FakeServer();
      final api = ApiClient(
        httpClient: server.client(),
        baseUrl: 'http://test.local',
      );

      await api.ping(candidate: 'http://192.168.1.20:3000/');
      // The saved address is only committed once the user signs in.
      expect(api.baseUrl, 'http://test.local');
    });

    test('rejects an address that is not the admin panel', () async {
      final server = FakeServer()
        ..healthBody = {'hello': 'some other service'};
      final api = ApiClient(
        httpClient: server.client(),
        baseUrl: 'http://test.local',
      );

      expect(
        () => api.ping(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('not the admin panel'),
          ),
        ),
      );
    });

    test('reports when the panel cannot reach its database', () async {
      final server = FakeServer()
        ..healthBody = {
          'ok': true,
          'service': 'business-connect-admin',
          'database': false,
        };
      final api = ApiClient(
        httpClient: server.client(),
        baseUrl: 'http://test.local',
      );

      expect(
        () => api.ping(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Start MongoDB'),
          ),
        ),
      );
    });

    test('rejects a bare host:port, which is the usual typo', () async {
      final server = FakeServer();
      final api = ApiClient(
        httpClient: server.client(),
        baseUrl: 'http://test.local',
      );

      expect(
        () => api.ping(candidate: '10.0.2.2:3000'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('not a valid address'),
          ),
        ),
      );
    });

    test('explains that 10.0.2.2 is emulator-only when it fails', () async {
      // Stands in for a real phone, where 10.0.2.2 resolves to nothing.
      final api = ApiClient(
        httpClient: MockClient((_) async => throw const SocketException('no route')),
        baseUrl: 'http://10.0.2.2:3000',
      );

      expect(
        () => api.ping(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('only works on an Android emulator'),
          ),
        ),
      );
    });

    test('rejects a hostname with no scheme', () async {
      final server = FakeServer();
      final api = ApiClient(
        httpClient: server.client(),
        baseUrl: 'http://test.local',
      );

      expect(
        () => api.ping(candidate: 'my-server'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('full address'),
          ),
        ),
      );
    });
  });

  group('layout', () {
    // The dialler packs a country button, the number and a backspace into one
    // row; on a small phone that row must still fit.
    testWidgets('the dialler fits a 360px phone', (tester) async {
      usePhoneViewport(tester, size: const Size(360, 720));
      final session = await signedInSession(FakeServer());

      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(
        wrap(
          DialerScreen(session: session, initialNumber: '+919876543210'),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = previous;
      for (final error in errors) {
        debugPrint(error.toString());
      }
      expect(errors, isEmpty);

      // Country and number sit side by side rather than stacked.
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('98765 43210'), findsOneWidget);
    });
  });
}
