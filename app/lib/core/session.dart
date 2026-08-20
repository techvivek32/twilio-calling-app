import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'format.dart';

/// Holds the signed-in account and brokers every call to the admin server.
class AppSession extends ChangeNotifier {
  AppSession({ApiClient? api}) : api = api ?? ApiClient();

  static final AppSession instance = AppSession();

  static const _tokenKey = 'bc.token';
  static const _userKey = 'bc.user';
  static const _numberKey = 'bc.number';
  static const _serverKey = 'bc.server';

  final ApiClient api;

  AppUser? _user;
  AssignedNumber? _number;
  bool _restored = false;

  AppUser? get user => _user;
  AssignedNumber? get number => _number;
  bool get isSignedIn => api.token != null && _user != null;
  bool get hasNumber => _number != null;
  bool get restored => _restored;
  String get serverUrl => api.baseUrl;

  /// Reads a persisted session so a returning user skips the login screen.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();

    final server = prefs.getString(_serverKey);
    if (server != null && server.isNotEmpty) api.baseUrl = server;

    final token = prefs.getString(_tokenKey);
    final rawUser = prefs.getString(_userKey);
    if (token != null && rawUser != null) {
      api.token = token;
      _user = AppUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);

      final rawNumber = prefs.getString(_numberKey);
      _number = rawNumber == null
          ? null
          : AssignedNumber.fromJson(
              jsonDecode(rawNumber) as Map<String, dynamic>,
            );
    }

    _restored = true;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
    String? serverUrl,
  }) async {
    if (serverUrl != null && serverUrl.trim().isNotEmpty) {
      api.baseUrl = serverUrl;
    }

    final response = await api.post('/api/mobile/auth/login', {
      'email': email.trim(),
      'password': password,
    });

    api.token = response['token']?.toString();
    _user = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    _number = response['number'] is Map<String, dynamic>
        ? AssignedNumber.fromJson(response['number'] as Map<String, dynamic>)
        : null;

    await _persist();
    notifyListeners();
  }

  Future<void> signOut() async {
    api.token = null;
    _user = null;
    _number = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_numberKey);

    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, api.baseUrl);

    if (api.token != null) await prefs.setString(_tokenKey, api.token!);
    if (_user != null) {
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    }
    if (_number != null) {
      await prefs.setString(_numberKey, jsonEncode(_number!.toJson()));
    } else {
      await prefs.remove(_numberKey);
    }
  }

  // ---------------------------------------------------------------- reads

  Future<HomeSummary> loadHome() async {
    final response = await api.get('/api/mobile/me');
    final summary = HomeSummary.fromJson(response);

    // The admin may have changed the assignment since sign-in.
    _user = summary.user;
    _number = summary.number;
    await _persist();

    return summary;
  }

  Future<List<CallRecord>> loadCalls() async {
    final response = await api.get('/api/mobile/calls');
    final calls = response['calls'];
    if (calls is! List) return const [];
    return calls
        .whereType<Map<String, dynamic>>()
        .map(CallRecord.fromJson)
        .toList();
  }

  Future<List<Conversation>> loadConversations() async {
    final response = await api.get('/api/mobile/messages');
    final conversations = response['conversations'];
    if (conversations is! List) return const [];
    return conversations
        .whereType<Map<String, dynamic>>()
        .map(Conversation.fromJson)
        .toList();
  }

  Future<List<Contact>> loadContacts() async {
    final response = await api.get('/api/mobile/contacts');
    final contacts = response['contacts'];
    if (contacts is! List) return const [];
    return contacts
        .whereType<Map<String, dynamic>>()
        .map(Contact.fromJson)
        .toList();
  }

  // --------------------------------------------------------------- writes

  /// Asks Twilio to dial [to]. Returns the call SID.
  Future<String> placeCall({required String to, String contactName = ''}) async {
    final response = await api.post('/api/mobile/calls/place', {
      'to': toE164(to),
      'contactName': contactName,
    });
    return response['callSid']?.toString() ?? '';
  }

  /// Records a finished call so it appears in history and the admin panel.
  Future<void> logCall({
    required String to,
    required int durationSec,
    String contactName = '',
    String status = 'completed',
    String direction = 'outbound',
  }) async {
    await api.post('/api/mobile/calls', {
      'to': toE164(to),
      'contactName': contactName,
      'direction': direction,
      'status': status,
      'durationSec': durationSec,
    });
  }

  /// Sends an SMS. [warning] on the result explains a non-delivery.
  Future<({ChatMessage message, String? warning})> sendMessage({
    required String to,
    required String body,
    String contactName = '',
  }) async {
    final response = await api.post('/api/mobile/messages', {
      'to': toE164(to),
      'body': body,
      'contactName': contactName,
    });

    return (
      message: ChatMessage.fromJson(
        response['message'] as Map<String, dynamic>,
      ),
      warning: response['warning']?.toString(),
    );
  }

  Future<Contact> addContact({
    required String name,
    required String phone,
    String role = '',
    String label = 'Mobile',
  }) async {
    final response = await api.post('/api/mobile/contacts', {
      'name': name,
      'phone': toE164(phone),
      'role': role,
      'label': label,
    });
    return Contact.fromJson(response['contact'] as Map<String, dynamic>);
  }
}
