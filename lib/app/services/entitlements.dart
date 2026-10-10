import 'package:flutter/foundation.dart';

import '../data/demo.dart';
import 'api_client.dart';
import 'config.dart';

/// The free plan's allowances (server `GET /v1/me/usage`, also inside
/// `GET /v1/me`), so the app can lock a test BEFORE the student spends
/// time on it. The server enforces the same rules (lib/entitlements.ts)
/// and answers 402 `upgrade_required` with the feature that is used up.
///
/// Lifetime, per account: Writing Task 1 ×1, Task 2 ×1, one Writing Test,
/// Speaking Part 1 / 2 / 3 ×1 each, one Speaking Test, one Full Mock Test,
/// the level test once, 5 pronunciation checks, 1 Band 8 rewrite, a 3-day
/// study plan without AI or quick check.
class Entitlements extends ChangeNotifier {
  Entitlements._();
  static final Entitlements I = Entitlements._();

  String _plan = 'free';
  Map<String, dynamic> _limits = <String, dynamic>{};
  bool _loaded = false;

  /// Pro (or a build without a server, where nothing is limited).
  bool get isPro => !AppConfig.hasApi || _plan == 'pro';

  /// Known yet? Until then nothing is locked here (the server still checks).
  bool get loaded => _loaded;

  /// From `usage` in GET /v1/me or GET /v1/me/usage.
  void apply(Object? usage) {
    if (usage is! Map) return;
    final u = usage.cast<String, dynamic>();
    _plan = u.s('plan') == 'pro' ? 'pro' : 'free';
    _limits = u.m('limits');
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!AppConfig.hasApi || !ApiClient.signedIn) return;
    try {
      apply(await ApiClient.get('/v1/me/usage'));
    } catch (_) {}
  }

  /// Signed out: forget the last account's numbers.
  void clear() {
    _plan = 'free';
    _limits = <String, dynamic>{};
    _loaded = false;
    notifyListeners();
  }

  Map<String, dynamic> _item(String key) => _limits.m(key);
  static List<int> _nums(Object? v) => v is List ? [for (final x in v) if (x is num) x.toInt()] : const <int>[];
  bool _usedUp(String key) => _loaded && !isPro && _item(key).isNotEmpty && _item(key).i('left') <= 0;

  /// Free uses left of [key] ('pronunciation', 'rewrite' …); null when unlimited.
  int? left(String key) => isPro || !_loaded ? null : _item(key).i('left');

  /// "wt_12_t1" → "wt_12"; "st_03_cc" → "st_03"; else ''.
  static String fullTestOf(String ref) {
    final m = RegExp(r'^((?:wt|st)_\d+)(?:_|$)').firstMatch(ref);
    return m == null ? '' : m.group(1)!;
  }

  /// Null when this writing task can be AI-scored; else the used-up feature.
  String? blockWriting({required int task, String promptId = ''}) {
    if (isPro || !_loaded) return null;
    final test = fullTestOf(promptId);
    if (test.startsWith('wt_')) {
      final t = _item('writingTest');
      final started = t.s('test');
      if (started.isEmpty) return t.i('left') > 0 ? null : 'writing_test';
      if (started != test) return 'writing_test';
      return _nums(t['tasksDone']).contains(task) ? 'writing_test' : null;
    }
    return _usedUp(task == 1 ? 'writingTask1' : 'writingTask2') ? 'writing_task$task' : null;
  }

  /// Null when this speaking part can be AI-scored; else the used-up feature.
  String? blockSpeaking({required int part, String refId = ''}) {
    if (isPro || !_loaded) return null;
    final test = fullTestOf(refId);
    if (test.startsWith('st_')) {
      final t = _item('speakingTest');
      final started = t.s('test');
      if (started.isEmpty) return t.i('left') > 0 ? null : 'speaking_test';
      if (started != test) return 'speaking_test';
      return _nums(t['partsDone']).contains(part) ? 'speaking_test' : null;
    }
    return _usedUp('speakingPart$part') ? 'speaking_part$part' : null;
  }

  /// A new Full Mock Test can't be started (the free one is used).
  bool get mockUsedUp => _usedUp('mock');
  bool get diagnosticUsedUp => _usedUp('diagnostic');
  bool get pronunciationUsedUp => _usedUp('pronunciation');
  bool get rewriteUsedUp => _usedUp('rewrite');

  /// Study plan AI notes, weekly re-planning and the quick check.
  bool get planExtras => isPro;
}
