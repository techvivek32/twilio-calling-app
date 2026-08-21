import 'package:business_connect/core/api_client.dart';
import 'package:business_connect/core/format.dart';
import 'package:business_connect/core/theme.dart';
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

import 'fake_server.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: AppTheme.build(),
  debugShowCheckedModeBanner: false,
  home: Scaffold(body: child),
);

void main() {
  group('formatting', () {
    test('formats a full US number as it is dialled', () {
      expect(formatDialedNumber('12025550199'), '+1 (202) 555-0199');
      expect(formatDialedNumber('1202'), '+1 (202');
      expect(formatDialedNumber(''), '');
    });

    test('keeps digits beyond a US-length number', () {
      expect(formatDialedNumber('447700900123'), '+447700900123');
    });

    test('renders stored E.164 numbers for display', () {
      expect(formatPhoneNumber('+15550123456'), '+1 (555) 012-3456');
    });

    test('normalises typed input to E.164', () {
      expect(toE164('(555) 012-3456'), '+15550123456');
      expect(toE164('+44 7700 900123'), '+447700900123');
      expect(toE164(''), '');
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
      final server = FakeServer();
      final session = await signedInSession(server);

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialDigits: '12025550199')),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1 (202) 555-0199'), findsOneWidget);
      expect(find.text('Acme Corporation'), findsOneWidget);

      await tester.tap(find.byTooltip('Call'));
      await tester.pumpAndSettle();

      expect(server.placedCalls, hasLength(1));
      expect(server.placedCalls.first['to'], '+12025550199');
      expect(find.text('CONNECTED VIA TWILIO'), findsOneWidget);
    });

    testWidgets('keypad edits the dialled number', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer());

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialDigits: '12025550199')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump();

      expect(find.text('+1 (202) 555-0197'), findsOneWidget);
    });

    testWidgets('dialer reports when no number is assigned', (tester) async {
      usePhoneViewport(tester);
      final session = await signedInSession(FakeServer(assignNumber: false));

      await tester.pumpWidget(
        wrap(DialerScreen(session: session, initialDigits: '12025550199')),
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
    test('accepts a healthy Business Connect server', () async {
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
}
