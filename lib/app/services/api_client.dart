import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/l10n.dart';
import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status, this.code = '', this.data = const <String, dynamic>{}]);

  final String message;
  final int? status;

  /// The whole error body (e.g. `feature` with 'upgrade_required').
  final Map<String, dynamic> data;

  /// Server error code ('wrong_password', 'phone_taken', 'otp_invalid' …);
  /// 'network' when the server couldn't be reached.
  final String code;

  bool get isNetwork => code == 'network';

  /// A free-plan allowance is used up (HTTP 402): show the upgrade sheet.
  bool get isUpgrade => code == 'upgrade_required';
  String get feature => '${data['feature'] ?? ''}';

  @override
  String toString() => message;
}

/// The signed-in device's tokens (server `issueSession` response).
class ApiSession {
  ApiSession({
    required this.userId,
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
  });

  final String userId;
  String accessToken;
  DateTime accessExpiresAt;
  String refreshToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'accessToken': accessToken,
        'accessExpiresAt': accessExpiresAt.toIso8601String(),
        'refreshToken': refreshToken,
      };

  static ApiSession? fromJson(Object? j) {
    if (j is! Map) return null;
    final m = j.cast<String, dynamic>();
    final user = m['userId'], access = m['accessToken'], refresh = m['refreshToken'];
    if (user is! String || access is! String || refresh is! String || user.isEmpty) return null;
    return ApiSession(
      userId: user,
      accessToken: access,
      accessExpiresAt: DateTime.tryParse('${m['accessExpiresAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      refreshToken: refresh,
    );
  }

  /// From a login / register / refresh response.
  static ApiSession fromAuth(Map<String, dynamic> r) {
    final user = r['user'];
    return ApiSession(
      userId: user is Map ? '${user['id']}' : '',
      accessToken: '${r['accessToken']}',
      accessExpiresAt: DateTime.tryParse('${r['accessTokenExpiresAt']}') ??
          DateTime.now().add(const Duration(minutes: 50)),
      refreshToken: '${r['refreshToken']}',
    );
  }
}

/// JSON client for the IELTS AI API server (`server/`).
///
/// Signed-in calls send `Authorization: Bearer <access token>`; an expired
/// access token is renewed with the refresh token once and the call retried.
/// Tokens are kept in SharedPreferences, apart from the local store.
class ApiClient {
  ApiClient._();

  static final http.Client _http = http.Client();
  static const String _prefsKey = 'ielts_ai_api_session_v1';

  static ApiSession? _session;
  static ApiSession? get session => _session;
  static bool get signedIn => _session != null;

  /// Called when the server ends the session (refresh token rejected).
  static void Function()? onSessionEnded;

  static Future<void> loadSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      _session = raw == null ? null : ApiSession.fromJson(jsonDecode(raw));
    } catch (_) {
      _session = null;
    }
  }

  static Future<void> setSession(ApiSession? s) async {
    _session = s;
    try {
      final p = await SharedPreferences.getInstance();
      if (s == null) {
        await p.remove(_prefsKey);
      } else {
        await p.setString(_prefsKey, jsonEncode(s.toJson()));
      }
    } catch (_) {}
  }

  static Uri _uri(String path) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    return Uri.parse('$base$path');
  }

  static Map<String, String> get _headers => <String, String>{
        if (AppConfig.appKey.isNotEmpty) 'X-App-Key': AppConfig.appKey,
        if (_session != null) 'Authorization': 'Bearer ${_session!.accessToken}',
      };

  /// Headers for fetching protected files (recordings).
  static Map<String, String> get headers => _headers;

  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(plainDashes(utf8.decode(res.bodyBytes)));
      if (decoded is Map) body = decoded.cast<String, dynamic>();
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        '${body['error'] ?? 'Something went wrong (${res.statusCode}).'}',
        res.statusCode,
        '${body['code'] ?? ''}',
        body,
      );
    }
    return body;
  }

  static Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    Uint8List? bytes,
    String? contentType,
    required Duration timeout,
  }) {
    final req = http.Request(method, _uri(path));
    req.headers.addAll(_headers);
    if (bytes != null) {
      req.headers['Content-Type'] = contentType ?? 'application/octet-stream';
      req.bodyBytes = bytes;
    } else if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    return _http.send(req).then(http.Response.fromStream).timeout(timeout);
  }

  static Future<void>? _refreshing;

  /// Swaps the refresh token for a new pair. Ends the session when the
  /// server rejects it.
  static Future<void> _refresh() {
    return _refreshing ??= () async {
      final s = _session;
      if (s == null) throw ApiException('Please log in.', 401, 'no_token');
      try {
        final res = await _http
            .post(
              _uri('/v1/auth/refresh'),
              headers: <String, String>{'Content-Type': 'application/json'},
              body: jsonEncode(<String, dynamic>{'refreshToken': s.refreshToken}),
            )
            .timeout(const Duration(seconds: 20));
        final r = _decode(res);
        await setSession(ApiSession.fromAuth(r));
      } on ApiException catch (e) {
        if (e.status == 401) {
          await setSession(null);
          onSessionEnded?.call();
        }
        rethrow;
      } on TimeoutException {
        throw ApiException('The server is not responding.', null, 'network');
      } catch (e) {
        throw ApiException('Can’t reach the server. Check your connection.', null, 'network');
      }
    }()
        .whenComplete(() => _refreshing = null);
  }

  /// Any JSON call. [auth] calls renew an expired access token and retry once.
  static Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Object? body,
    Uint8List? bytes,
    String? contentType,
    bool auth = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!AppConfig.hasApi) throw ApiException('No API configured', null, 'network');
    if (auth && _session != null && _session!.accessExpiresAt.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      await _refresh();
    }
    Future<Map<String, dynamic>> once() async {
      try {
        final res = await _send(method, path, body: body, bytes: bytes, contentType: contentType, timeout: timeout);
        return _decode(res);
      } on ApiException {
        rethrow;
      } on TimeoutException {
        onNetworkError?.call();
        throw ApiException('The server is not responding. Try again.', null, 'network');
      } catch (_) {
        onNetworkError?.call();
        throw ApiException('Can’t reach the server. Check your connection.', null, 'network');
      }
    }

    try {
      return await once();
    } on ApiException catch (e) {
      if (auth && e.status == 401 && _session != null && e.code == 'token_expired') {
        await _refresh();
        return once();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> get(String path, {bool auth = true}) => request('GET', path, auth: auth);

  /// Told when a request couldn't reach the server (see [ConnectionGate]).
  static void Function()? onNetworkError;

  /// True when the server answers at all (any HTTP status): the phone is
  /// online. Used by the "turn on mobile data" screen.
  static Future<bool> ping() async {
    if (!AppConfig.hasApi) return true;
    try {
      await _http.get(_uri('/health')).timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// POST JSON → JSON map (AI calls add the chosen feedback language).
  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 90),
    bool auth = true,
  }) =>
      request(
        'POST',
        path,
        body: <String, dynamic>{
          ...body,
          if (ContentL10n.current != 'en' && !body.containsKey('feedbackLanguage'))
            'feedbackLanguage': ContentL10n.current,
        },
        timeout: timeout,
        auth: auth,
      );

  /// PUT raw bytes (recordings) → JSON map.
  static Future<Map<String, dynamic>> putBytes(
    String path,
    Uint8List bytes, {
    String contentType = 'audio/wav',
    Duration timeout = const Duration(seconds: 120),
  }) =>
      request('PUT', path, bytes: bytes, contentType: contentType, timeout: timeout);

  /// Absolute URL for a stored recording key (needs [headers] to fetch).
  static String uploadUrl(String key) => _uri('/v1/uploads/$key').toString();
}

/// Replaces em dashes (U+2014) with a normal dash, spaced like the rest of
/// the app ("word - word"). Applied to every server response, so AI feedback
/// written by the model never shows em dashes. Works on raw JSON text: the
/// dash is never part of the JSON syntax itself.
String plainDashes(String s) {
  const em = '\u2014';
  const bs = '\\';
  if (s.contains('${bs}u2014')) s = s.replaceAll('${bs}u2014', em);
  if (!s.contains(em)) return s;
  final text = s;
  return text.replaceAllMapped(RegExp('[ \t]*$em[ \t]*'), (m) {
    final b1 = m.start > 0 ? text[m.start - 1] : '';
    final b2 = m.start > 1 ? text[m.start - 2] : '';
    final after = m.end < text.length ? text[m.end] : '';
    final a2 = m.end + 1 < text.length ? text[m.end + 1] : '';
    // Start of a JSON string, or right after an escaped line break.
    final noLead = b1.isEmpty ||
        (b1 == '"' && b2 != bs) ||
        (b1 == 'n' && b2 == bs) ||
        '([{'.contains(b1);
    // End of a JSON string, an escaped line break, or punctuation.
    final noTrail = after.isEmpty ||
        (after == bs && a2 == 'n') ||
        '")]},.;:'.contains(after);
    return '${noLead ? '' : ' '}-${noTrail ? '' : ' '}';
  });
}
