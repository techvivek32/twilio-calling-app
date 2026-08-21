import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Raised for any non-2xx reply so callers can show the server's own message.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// The admin has not given this account a number yet, or Twilio is unset.
  bool get isConfigurationIssue => statusCode == 409;

  /// The stored token is missing, expired or the account was disabled.
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Thin JSON client for the Business Connect admin server.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? defaultBaseUrl;

  /// Android emulators reach the host machine on 10.0.2.2. Override at build
  /// time with `--dart-define=API_BASE_URL=http://192.168.1.20:3000`, or from
  /// the server field on the sign-in screen.
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const Duration timeout = Duration(seconds: 20);

  final http.Client _http;
  String _baseUrl;
  /// Bearer token for the signed-in app user; null when signed out.
  String? token;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) => _baseUrl = _normalise(value);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> get(String path) =>
      _send(() => _http.get(_uri(path), headers: _headers));

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(
    () => _http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body ?? const {}),
    ),
  );

  /// Checks that [candidate] (or the current address) is a reachable Business
  /// Connect server. Uses a short timeout so a wrong address fails fast.
  Future<void> ping({String? candidate}) async {
    final target = candidate == null ? _baseUrl : _normalise(candidate);
    if (target.isEmpty) {
      throw ApiException('Enter a server address first.');
    }

    final Uri uri;
    try {
      uri = Uri.parse('$target/api/mobile/health');
    } on FormatException {
      throw ApiException('"$target" is not a valid address.');
    }
    if (!uri.hasScheme || !uri.host.isNotEmpty) {
      throw ApiException(
        'Include the full address, for example http://10.0.2.2:3000',
      );
    }

    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw ApiException(
        'No answer from $target. Make sure the admin panel is running and '
        'that this device can reach that address.',
      );
    } catch (error) {
      throw ApiException('Cannot reach $target. ${_describe(error)}');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Something answered at $target, but it is not the admin panel '
        '(HTTP ${response.statusCode}).',
      );
    }

    Map<String, dynamic> body = const {};
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) body = parsed;
    } on FormatException {
      throw ApiException(
        'Something answered at $target, but it is not the admin panel.',
      );
    }

    if (body['service'] != 'business-connect-admin') {
      throw ApiException(
        'Something answered at $target, but it is not the admin panel.',
      );
    }
    if (body['database'] != true) {
      throw ApiException(
        'The admin panel is up but cannot reach its database. Start MongoDB '
        'and try again.',
      );
    }
  }

  static String _normalise(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'The server at $_baseUrl did not respond. Check the address and that '
        'the admin panel is running.',
      );
    } catch (error) {
      throw ApiException('Cannot reach $_baseUrl. ${_describe(error)}');
    }

    Map<String, dynamic> decoded = const {};
    if (response.body.isNotEmpty) {
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } on FormatException {
        throw ApiException(
          'The server returned an unexpected response (HTTP '
          '${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      decoded['error']?.toString() ??
          'Request failed with HTTP ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }

  String _describe(Object error) {
    final text = error.toString();
    if (text.contains('SocketException')) {
      return 'The device could not open a connection.';
    }
    return text;
  }

  void close() => _http.close();
}
