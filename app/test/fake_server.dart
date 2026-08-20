import 'dart:convert';

import 'package:business_connect/core/api_client.dart';
import 'package:business_connect/core/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the admin server, so widget tests exercise the real
/// request/parse path without a live Next.js instance.
class FakeServer {
  FakeServer({this.assignNumber = true});

  /// When false, every endpoint behaves as though no admin assigned a number.
  final bool assignNumber;

  final List<String> requests = [];
  final List<Map<String, dynamic>> sentMessages = [];
  final List<Map<String, dynamic>> loggedCalls = [];
  final List<Map<String, dynamic>> placedCalls = [];

  /// Set to make the next matching request fail with this status/message.
  int? failStatus;
  String failMessage = 'Something went wrong.';

  static final String _now = DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic>? get _number => assignNumber
      ? {
          'id': 'num1',
          'phoneNumber': '+15550123456',
          'friendlyName': 'Sales line',
          'capabilities': {'voice': true, 'sms': true, 'mms': false},
        }
      : null;

  http.Client client() {
    return MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');

      if (failStatus != null) {
        final status = failStatus!;
        failStatus = null;
        return _json({'error': failMessage}, status);
      }

      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;

      switch ('${request.method} $path') {
        case 'POST /api/mobile/auth/login':
          if (body['password'] != 'Password123!') {
            return _json({'error': 'Invalid email or password.'}, 401);
          }
          return _json({
            'token': 'test-token',
            'user': {
              'id': 'u1',
              'name': 'Alex Morgan',
              'email': body['email'],
              'role': 'user',
            },
            'number': _number,
          });

        case 'GET /api/mobile/me':
          return _json({
            'user': {
              'id': 'u1',
              'name': 'Alex Morgan',
              'email': 'alex@businessconnect.local',
            },
            'number': _number,
            'twilioConfigured': true,
            'today': {'calls': 12, 'missed': 2, 'incoming': 10},
            'messages': {
              'unread': 3,
              'latest': {
                'from': 'Sarah Jenkins',
                'body': 'Can we reschedule our 3PM call to tomorrow?',
              },
            },
            'activity': [
              {
                'kind': 'call',
                'title': 'Call from John Doe',
                'subtitle': 'Duration: 4m 12s',
                'isAlert': false,
                'at': _now,
              },
              {
                'kind': 'message',
                'title': 'SMS from Sarah Jenkins',
                'subtitle': 'Can we reschedule our 3PM call to tomorrow?',
                'isAlert': false,
                'at': _now,
              },
              {
                'kind': 'call',
                'title': 'Missed call from +1 (987) 654-3210',
                'subtitle': 'Left voicemail',
                'isAlert': true,
                'at': _now,
              },
            ],
          });

        case 'GET /api/mobile/calls':
          return _json({
            'calls': [
              {
                'id': 'c1',
                'from': '+15552204411',
                'to': '+15550123456',
                'contactName': 'Alexander Wright',
                'direction': 'inbound',
                'status': 'missed',
                'durationSec': 0,
                'startedAt': _now,
              },
              {
                'id': 'c2',
                'from': '+15550123456',
                'to': '+15556642290',
                'contactName': 'Sarah Richards',
                'direction': 'outbound',
                'status': 'completed',
                'durationSec': 312,
                'startedAt': _now,
              },
              {
                'id': 'c3',
                'from': '+15557710043',
                'to': '+15550123456',
                'contactName': 'Emily Chen',
                'direction': 'inbound',
                'status': 'completed',
                'durationSec': 765,
                'startedAt': _now,
              },
            ],
          });

        case 'POST /api/mobile/calls':
          loggedCalls.add(body);
          return _json({'call': body}, 201);

        case 'POST /api/mobile/calls/place':
          placedCalls.add(body);
          if (!assignNumber) {
            return _json({
              'error':
                  'No phone number is assigned to your account. Ask your '
                  'administrator.',
            }, 409);
          }
          return _json({'callSid': 'CA123', 'status': 'queued'});

        case 'GET /api/mobile/messages':
          return _json({
            'conversations': [
              {
                'peer': '+15550198372',
                'contactName': 'Sarah Jenkins',
                'messages': [
                  {
                    'id': 'm1',
                    'body':
                        "Hi there, I'm checking on the status of my recent "
                        'service request #88492. Do you have an ETA?',
                    'fromMe': false,
                    'status': 'received',
                    'sentAt': _now,
                  },
                  {
                    'id': 'm2',
                    'body':
                        "Hello Sarah. I'm looking into that for you right now.",
                    'fromMe': true,
                    'status': 'delivered',
                    'sentAt': _now,
                  },
                  {
                    'id': 'm3',
                    'body':
                        'Please make sure someone is available to grant '
                        'access to the equipment room.',
                    'fromMe': true,
                    'status': 'failed',
                    'sentAt': _now,
                  },
                ],
              },
            ],
          });

        case 'POST /api/mobile/messages':
          sentMessages.add(body);
          return _json({
            'message': {
              'id': 'm-new',
              'body': body['body'],
              'fromMe': true,
              'status': 'sent',
              'sentAt': _now,
            },
            'warning': null,
          }, 201);

        case 'GET /api/mobile/contacts':
          return _json({
            'contacts': [
              {
                'id': 'k1',
                'name': 'Sarah Jenkins',
                'phone': '+15550198372',
                'role': 'VP of Operations',
                'label': 'Work',
              },
              {
                'id': 'k2',
                'name': 'Acme Corporation',
                'phone': '+12025550199',
                'role': 'Enterprise Account',
                'label': 'Work',
              },
            ],
          });

        case 'POST /api/mobile/contacts':
          return _json({
            'contact': {
              'id': 'k-new',
              'name': body['name'],
              'phone': body['phone'],
              'role': '',
              'label': 'Mobile',
            },
          }, 201);
      }

      return _json({'error': 'Unhandled route $path'}, 404);
    });
  }

  static http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );
}

/// Builds a signed-in session backed by [server].
Future<AppSession> signedInSession(FakeServer server) async {
  SharedPreferences.setMockInitialValues({});
  final session = AppSession(
    api: ApiClient(
      httpClient: server.client(),
      baseUrl: 'http://test.local',
    ),
  );
  await session.signIn(
    email: 'alex@businessconnect.local',
    password: 'Password123!',
  );
  return session;
}

/// Session with no credentials, for testing the sign-in screen.
AppSession signedOutSession(FakeServer server) {
  SharedPreferences.setMockInitialValues({});
  return AppSession(
    api: ApiClient(
      httpClient: server.client(),
      baseUrl: 'http://test.local',
    ),
  );
}

/// Drives the widget tree on a phone-shaped surface, matching the mockups.
void usePhoneViewport(WidgetTester tester, {Size size = const Size(390, 844)}) {
  final view = tester.view;
  view.devicePixelRatio = 1.0;
  view.physicalSize = size;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}
