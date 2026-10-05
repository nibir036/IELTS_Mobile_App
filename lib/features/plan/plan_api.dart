import 'package:flutter/foundation.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/services/api_client.dart';
import '../../app/services/notification_service.dart';
import '../../app/services/sync_service.dart';

/// The personal study plan lives on the server (it is built from the
/// student's results there). Its tasks come down through the normal sync as
/// study tasks (kind 'plan' / 'checkpoint') with deep-link args, so the
/// Home card and the Schedule work offline; only set-up and changes need the
/// connection.
class PlanApi {
  PlanApi._();

  /// The last plan the server sent (null = none or not loaded yet).
  static final ValueNotifier<Map<String, dynamic>?> current = ValueNotifier<Map<String, dynamic>?>(null);

  /// Plans need an account on the server (not the offline demo).
  static bool get available => SyncService.I.active;

  static const List<String> modules = <String>['listening', 'reading', 'writing', 'speaking'];
  static const Map<String, String> levelLabels = <String, String>{
    'beginner': 'Beginner',
    'amateur': 'Some basics',
    'intermediate': 'Intermediate',
    'advanced': 'Advanced',
  };

  /// Today and the phone's time-zone offset, added to every set-up.
  static Map<String, dynamic> withClock(Map<String, dynamic> inputs) => <String, dynamic>{
        ...inputs,
        'startDate': Store.dateKey(DateTime.now()),
        'tzOffsetMin': DateTime.now().timeZoneOffset.inMinutes,
      };

  /// Set-up answers to start from: the current plan's, else the profile's.
  static Map<String, dynamic> defaults(Store store) {
    final plan = current.value;
    if (plan != null && plan['inputs'] is Map) {
      return Map<String, dynamic>.from(plan['inputs'] as Map);
    }
    final acc = store.current;
    return <String, dynamic>{
      'modules': List<String>.of(modules),
      'levels': <String, dynamic>{for (final m in modules) m: 'intermediate'},
      'targetBand': acc?.targetBand ?? 7.0,
      'testType': 'academic', // only Academic content in the app for now
      'examDate': acc?.examDate == null ? null : Store.dateKey(acc!.examDate!),
      'days': <int>[1, 2, 3, 4, 5, 6],
      'minutesPerDay': 30,
      'studyTime': '20:00',
    };
  }

  static Future<Map<String, dynamic>> preview(Map<String, dynamic> inputs) =>
      ApiClient.request('POST', '/v1/plan/preview', body: <String, dynamic>{'inputs': withClock(inputs)});

  static Future<Map<String, dynamic>?> load() async {
    final r = await ApiClient.get('/v1/plan');
    return _took(r, pull: true);
  }

  static Future<Map<String, dynamic>?> create(Map<String, dynamic> inputs) async {
    final r = await ApiClient.request(
      'POST',
      '/v1/plan',
      body: <String, dynamic>{'inputs': withClock(inputs)},
      timeout: const Duration(seconds: 60),
    );
    return _took(r, pull: true);
  }

  /// {action: 'pause', days} · {action: 'resume'} · {action: 'rebalance'} ·
  /// {action: 'update', days?, minutesPerDay?, studyTime?, targetBand?, examDate?}
  static Future<Map<String, dynamic>?> change(Map<String, dynamic> body) async {
    final r = await ApiClient.request('PATCH', '/v1/plan', body: <String, dynamic>{
      ...body,
      if (body['action'] == 'update') 'tzOffsetMin': DateTime.now().timeZoneOffset.inMinutes,
    });
    return _took(r, pull: true);
  }

  /// Scores the quick check's paragraph (Gemini on the server).
  static Future<Map<String, dynamic>> scoreParagraph(String question, String text) => ApiClient.request(
        'POST',
        '/v1/plan/quick-check/writing',
        body: <String, dynamic>{'question': question, 'text': text},
        timeout: const Duration(seconds: 90),
      );

  /// Saves the quick-check bands; the active plan (if any) is re-planned.
  static Future<Map<String, dynamic>?> saveQuickCheck(Map<String, dynamic> result) async {
    final r = await ApiClient.request('POST', '/v1/plan/quick-check', body: result, timeout: const Duration(seconds: 60));
    if (r['plan'] is Map) return _took(r, pull: true);
    await _refreshTasks();
    return null;
  }

  static Future<void> end() async {
    await ApiClient.request('DELETE', '/v1/plan');
    current.value = null;
    await _refreshTasks();
  }

  static Future<Map<String, dynamic>?> _took(Map<String, dynamic> r, {bool pull = false}) async {
    final p = r['plan'];
    current.value = p is Map ? Map<String, dynamic>.from(p) : null;
    if (pull) await _refreshTasks();
    return current.value;
  }

  /// New / moved / dropped plan tasks come down with the sync; then the
  /// reminders are planned again around them.
  static Future<void> _refreshTasks() async {
    try {
      await SyncService.I.syncNow();
    } catch (_) {}
    NotificationService.I.refresh();
  }

  // ── local helpers (work offline) ──────────────────────────────────────

  /// Plan tasks of [day] from the local store.
  static List<Map<String, dynamic>> tasksOn(Store store, DateTime day) => store.planTasksOn(day);

  /// "13 min · Practises matching headings …"
  static String subtitle(Map<String, dynamic> t) {
    final min = t.i('durationMin');
    final reason = t.s('reason');
    return <String>[if (min > 0) '$min min', if (reason.isNotEmpty) reason].join(' · ');
  }

  static String moduleLabel(String m) => switch (m) {
        'listening' => 'Listening',
        'reading' => 'Reading',
        'writing' => 'Writing',
        'speaking' => 'Speaking',
        _ => m,
      };
}
