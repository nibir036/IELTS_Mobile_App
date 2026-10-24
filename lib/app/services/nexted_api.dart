import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/demo.dart';
import 'api_client.dart';
import 'config.dart';
import 'device_identity.dart';

/// Build-time configuration for the nexted.app study-abroad module.
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://api.<domain> \
///             --dart-define=NEXTED_API_BASE_URL=https://api.nexted.app
/// ```
///
/// The module is a thin client on the **main nexted.app backend** that already
/// powers the desktop web platform - not a second database. Everything the
/// mobile module reads or writes (profile, documents, applications, catalogue)
/// lives there, so staff on the web and students on the phone see the same
/// records (see chapter 25 of the app documentation).
///
/// Without `NEXTED_API_BASE_URL` the module still opens, but every screen says
/// the study-abroad server isn't connected yet instead of failing.
class NextedConfig {
  NextedConfig._();

  /// The study-abroad API. Defaults to the IELTS API (same server), so only
  /// `API_BASE_URL` has to be passed; set `NEXTED_API_BASE_URL` to split them.
  static const String apiBaseUrl = String.fromEnvironment(
    'NEXTED_API_BASE_URL',
    defaultValue: String.fromEnvironment('API_BASE_URL'),
  );

  /// Shows the nexted.app button even when the account has no study-abroad
  /// flag yet - for testing the module before the backend sets the flag.
  /// `--dart-define=NEXTED_FORCE_ACCESS=true`
  static const bool forceAccess = bool.fromEnvironment('NEXTED_FORCE_ACCESS', defaultValue: true);

  static bool get hasApi => apiBaseUrl.isNotEmpty;

  // ── Endpoints ────────────────────────────────────────────────────────────
  // Every path the module uses is listed here, so pointing the app at the
  // real backend is a change in this one block.

  /// The student's study-abroad profile (GET to read, PATCH to update).
  static const String profile = '/v1/nexted/profile';

  /// The student's documents (GET list).
  static const String documents = '/v1/nexted/documents';

  /// Upload one document: raw bytes, with `?kind=&ext=&name=`.
  static const String documentUpload = '/v1/nexted/documents';

  /// Applications: GET the list, POST to apply. `/:id` for one application
  /// with its status history.
  static const String applications = '/v1/nexted/applications';

  /// AI counsellor chat (POST {message, history} → {reply, usage}).
  static const String counsellor = '/v1/nexted/ai/counsellor';

  /// The same, typed out as it is written (Server-Sent Events: `token`
  /// pieces, then `done` with the full answer).
  static const String counsellorStream = '/v1/nexted/ai/counsellor/stream';

  /// The saved conversation (GET, oldest first) - DELETE starts it again.
  static const String counsellorThread = '/v1/nexted/ai/counsellor/thread';

  /// Course matching (POST {query?} → {courses: [...], usage}).
  static const String courseMatch = '/v1/nexted/ai/courses';

  /// The latest Course matching results, kept on the server until the
  /// student searches again (GET; {} when there are none yet).
  static const String courseMatchLast = '/v1/nexted/ai/courses/last';

  /// Scholarship finder (POST {query?} → {scholarships: [...], usage}).
  static const String scholarshipMatch = '/v1/nexted/ai/scholarships';

  /// The latest Scholarship finder results (GET; {} when there are none yet).
  static const String scholarshipMatchLast = '/v1/nexted/ai/scholarships/last';

  /// Today's AI allowance (GET → {usage: {used, limit, resetsAt}}).
  static const String aiUsage = '/v1/nexted/ai/usage';
}

/// JSON client for the nexted.app backend.
///
/// Shaped like [ApiClient] so screens handle one error type ([ApiException]),
/// but it talks to a different host and does not own a session of its own.
///
/// **Authentication (decision 25.7.2).** The guide keeps one login: the
/// student signs in to the IELTS app and the module rides that session. Until
/// the backend team confirms the contract, this sends the IELTS access token
/// as a bearer token plus the usual device headers. If the shared backend
/// wants its own token instead, exchange it once in [_authHeaders] and cache
/// it here - no screen has to change.
class NextedApi {
  NextedApi._();

  static final http.Client _http = http.Client();

  static bool get ready => NextedConfig.hasApi && ApiClient.signedIn;

  static Uri _uri(String path) {
    final base = NextedConfig.apiBaseUrl.endsWith('/')
        ? NextedConfig.apiBaseUrl.substring(0, NextedConfig.apiBaseUrl.length - 1)
        : NextedConfig.apiBaseUrl;
    return Uri.parse('$base$path');
  }

  static Map<String, String> _authHeaders() {
    final s = ApiClient.session;
    return <String, String>{
      ...DeviceIdentity.headers,
      if (AppConfig.appKey.isNotEmpty) 'X-App-Key': AppConfig.appKey,
      // One login, two front doors: the IELTS session identifies the student.
      if (s != null) 'Authorization': 'Bearer ${s.accessToken}',
      // Lets the backend refuse staff-type actions from a phone (25.2).
      'X-Client': 'ielts-mobile',
    };
  }

  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = <String, dynamic>{};
    try {
      final decoded = jsonDecode(plainDashes(utf8.decode(res.bodyBytes)));
      if (decoded is Map) body = decoded.cast<String, dynamic>();
      if (decoded is List) body = <String, dynamic>{'items': decoded};
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

  static Never _networkError(Object e) {
    if (e is TimeoutException) {
      throw ApiException('The study-abroad server is not responding.', null, 'network');
    }
    throw ApiException('Can’t reach the study-abroad server. Check your connection.', null, 'network');
  }

  static Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!NextedConfig.hasApi) {
      throw ApiException('The study-abroad server isn’t connected in this build.', null, 'not_configured');
    }
    if (!ApiClient.signedIn) {
      throw ApiException('Please log in again.', 401, 'no_token');
    }
    try {
      final req = http.Request(method, _uri(path));
      req.headers.addAll(_authHeaders());
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final res = await _http.send(req).then(http.Response.fromStream).timeout(timeout);
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      _networkError(e);
    }
  }

  static Future<Map<String, dynamic>> get(String path) => request('GET', path);

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      request('PATCH', path, body: body);

  /// AI answers can take a while: the first search for something new reads
  /// university pages on the web before it replies.
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) => request(
        'POST',
        path,
        body: body,
        // Always longer than the API server's own wait (NEXTED_AI_TIMEOUT_SECONDS).
        timeout: path.contains('/ai/') ? const Duration(seconds: 170) : const Duration(seconds: 30),
      );

  /// POSTs [body] and reads the answer as Server-Sent Events.
  ///
  /// Calls [onToken] with each piece of text as it arrives and returns the
  /// `done` body. An error before the first piece comes back as a normal JSON
  /// error and is thrown as [ApiException]; an `error` event part way through
  /// is thrown the same way. (On the web the browser may deliver the whole
  /// answer at once - it still works, it just doesn't type.)
  static Future<Map<String, dynamic>> stream(
    String path,
    Map<String, dynamic> body, {
    required void Function(String text) onToken,
    Duration timeout = const Duration(seconds: 170),
  }) async {
    if (!NextedConfig.hasApi) {
      throw ApiException('The study-abroad server isn’t connected in this build.', null, 'not_configured');
    }
    if (!ApiClient.signedIn) {
      throw ApiException('Please log in again.', 401, 'no_token');
    }
    final client = http.Client();
    try {
      final req = http.Request('POST', _uri(path));
      req.headers.addAll(_authHeaders());
      req.headers['Content-Type'] = 'application/json';
      req.headers['Accept'] = 'text/event-stream';
      req.body = jsonEncode(body);
      final res = await client.send(req).timeout(timeout);
      final type = res.headers['content-type'] ?? '';
      if (res.statusCode < 200 || res.statusCode >= 300 || !type.contains('text/event-stream')) {
        // A JSON reply: an error, or a server without streaming.
        return _decode(await http.Response.fromStream(res));
      }

      Map<String, dynamic>? done;
      var buffer = '';
      await for (final chunk in res.stream
          .transform(utf8.decoder)
          .timeout(timeout)) {
        buffer += chunk.replaceAll('\r\n', '\n');
        var cut = buffer.indexOf('\n\n');
        while (cut >= 0) {
          final frame = buffer.substring(0, cut);
          buffer = buffer.substring(cut + 2);
          cut = buffer.indexOf('\n\n');
          var event = 'message';
          final data = StringBuffer();
          for (final line in frame.split('\n')) {
            if (line.startsWith('event:')) {
              event = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              if (data.isNotEmpty) data.write('\n');
              data.write(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
            }
          }
          Map<String, dynamic> m = <String, dynamic>{};
          try {
            final d = jsonDecode(data.toString());
            if (d is Map) m = d.cast<String, dynamic>();
          } catch (_) {
            continue;
          }
          if (event == 'token') {
            final t = m['t'];
            if (t is String && t.isNotEmpty) onToken(plainDashes(t));
          } else if (event == 'done') {
            done = m;
          } else if (event == 'error') {
            throw ApiException(
              '${m['error'] ?? m['message'] ?? 'Something went wrong.'}',
              null,
              '${m['code'] ?? ''}',
              m,
            );
          }
        }
      }
      if (done == null) {
        throw ApiException('The answer stopped part way. Please try again.', null, 'ai_failed');
      }
      return done;
    } on ApiException {
      rethrow;
    } catch (e) {
      _networkError(e);
    } finally {
      client.close();
    }
  }

  /// Uploads one document as raw bytes, the way the IELTS server already
  /// takes files (`POST /v1/nexted/documents?kind=&ext=&name=`). Returns the
  /// created record.
  static Future<Map<String, dynamic>> upload(
    String path, {
    required Uint8List bytes,
    required String kind,
    required String ext,
    String name = '',
    String contentType = 'application/octet-stream',
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!NextedConfig.hasApi) {
      throw ApiException('The study-abroad server isn’t connected in this build.', null, 'not_configured');
    }
    if (!ApiClient.signedIn) {
      throw ApiException('Please log in again.', 401, 'no_token');
    }
    final query = Uri(queryParameters: <String, String>{
      'kind': kind,
      'ext': ext,
      if (name.isNotEmpty) 'name': name,
    }).query;
    try {
      final req = http.Request('POST', _uri('$path?$query'));
      req.headers.addAll(_authHeaders());
      req.headers['Content-Type'] = contentType;
      req.bodyBytes = bytes;
      final res = await _http.send(req).then(http.Response.fromStream).timeout(timeout);
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      _networkError(e);
    }
  }
}

/// Whether this student may open the nexted.app module.
///
/// The button is shown only to users who have study-abroad access (25.1): a
/// flag on the user record, set when they register in the module or when a
/// counsellor links them. It is read from the IELTS account
/// (`GET /v1/me` → `studyAbroad`), so the IELTS app decides what to show and
/// the shared backend still checks every request.
class NextedAccess extends ChangeNotifier {
  NextedAccess._();

  static final NextedAccess I = NextedAccess._();

  bool _enabled = false;
  bool _loaded = false;

  /// Known yet? Until then the button stays hidden.
  bool get loaded => _loaded || NextedConfig.forceAccess;

  bool get enabled => NextedConfig.forceAccess || _enabled;

  /// Reads the flag from the IELTS account. Safe to call often; failures
  /// leave the last answer in place.
  Future<void> refresh() async {
    if (NextedConfig.forceAccess) {
      _enabled = true;
      _loaded = true;
      notifyListeners();
      return;
    }
    if (!AppConfig.hasApi || !ApiClient.signedIn) return;
    try {
      final r = await ApiClient.get('/v1/me');
      apply(r);
    } catch (_) {
      // Offline or the field isn't served yet: keep what we had.
    }
  }

  /// Applies a `GET /v1/me` (or login) response.
  void apply(Object? me) {
    if (me is! Map) return;
    final m = me.cast<String, dynamic>();
    final user = m.m('user');
    final flag = user.isNotEmpty ? user : m;
    _enabled = flag.b('studyAbroad') || flag.b('nextedAccess');
    _loaded = true;
    notifyListeners();
  }

  /// Signed out: forget the last account's answer.
  void clear() {
    _enabled = false;
    _loaded = false;
    notifyListeners();
  }
}

/// Today's AI allowance, as the backend reports it.
///
/// **The cap itself lives in the shared backend** (25.5), around the code that
/// actually issues the AI request - a counter kept on the phone could be
/// edited, and a student must not be able to dodge the limit by switching
/// between the web app and the phone. This class only *shows* what the server
/// says and refuses early so the student doesn't type a long question for
/// nothing. Every AI response is expected to carry a `usage` object
/// (`{used, limit, resetsAt}`), and the server answers `ai_limit_reached`
/// when the quota is gone.
class NextedUsage extends ChangeNotifier {
  NextedUsage._();

  static final NextedUsage I = NextedUsage._();

  int _used = 0;
  int _limit = 0;
  DateTime? _resetsAt;
  bool _loaded = false;

  bool get loaded => _loaded;
  int get used => _used;

  /// 0 means the server reports no limit for this student.
  int get limit => _limit;

  int get left => _limit <= 0 ? -1 : (_limit - _used).clamp(0, _limit);

  bool get unlimited => _loaded && _limit <= 0;

  bool get exhausted => _loaded && _limit > 0 && _used >= _limit;

  DateTime? get resetsAt => _resetsAt;

  /// What to show when the allowance is gone.
  static const String limitMessage =
      'You have reached today’s AI limit. It resets at midnight.';

  /// Reads `usage` from any AI response (or the usage endpoint itself).
  void apply(Object? source) {
    if (source is! Map) return;
    final m = source.cast<String, dynamic>();
    final u = m.m('usage').isEmpty ? m : m.m('usage');
    if (!u.containsKey('used') && !u.containsKey('limit')) return;
    _used = u.i('used');
    _limit = u.i('limit');
    _resetsAt = DateTime.tryParse(u.s('resetsAt'))?.toLocal();
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!NextedApi.ready) return;
    try {
      apply(await NextedApi.get(NextedConfig.aiUsage));
    } catch (_) {
      // Keep the last known numbers.
    }
  }

  /// Counts one AI action locally after a successful call, so the bar moves
  /// even if that response carried no `usage` (the server stays the authority).
  void countOne() {
    if (!_loaded || _limit <= 0) return;
    _used = (_used + 1).clamp(0, _limit);
    notifyListeners();
  }

  /// True when the error is the server refusing over the daily cap.
  static bool isLimit(ApiException e) =>
      e.code == 'ai_limit_reached' || e.code == 'ai_quota_exceeded' || e.status == 429;

  void clear() {
    _used = 0;
    _limit = 0;
    _resetsAt = null;
    _loaded = false;
    notifyListeners();
  }
}
