import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/home/certificates_screen.dart' show evaluateCertificates;
import '../../features/writing/writing_data.dart' show WritingDrafts;
import '../data/demo.dart';
import '../data/l10n.dart';
import '../data/lessons.dart';
import '../data/store.dart';
import '../nav.dart';
import '../routes.dart';
import 'ai_service.dart';
import 'notification_texts.dart';

/// Notification groups the student can switch on and off
/// (Profile › Notifications).
class NotifGroup {
  NotifGroup._();
  static const study = 'study';
  static const exam = 'exam';
  static const results = 'results';
  static const achievements = 'achievements';
  static const news = 'news';

  static const all = <String>[study, exam, results, achievements, news];

  static String label(String g) => switch (g) {
        study => 'Study reminders',
        exam => 'Exam & schedule',
        results => 'Results',
        achievements => 'Achievements',
        _ => 'News & account',
      };

  static String description(String g) => switch (g) {
        study => 'Daily reminder, streak alerts and a weekly recap',
        exam => 'Exam countdown, mock test days and planned sessions',
        results => 'When your writing or speaking has been scored',
        achievements => 'New milestones and finished course stages',
        _ => 'New content, plan updates and AI scoring limits',
      };
}

/// One planned (scheduled) device notification.
class _Planned {
  _Planned(this.id, this.group, this.at, this.title, this.body, this.route, [this.args]);
  final int id;
  final String group;
  final DateTime at;
  final String title;
  final String body;
  final String route;
  final Map<String, dynamic>? args;

  String get sig => '$id|${at.millisecondsSinceEpoch}|$title|$body|$route';
}

/// Device notifications and the in-app inbox.
///
/// * Scheduled on the device (work with the app closed): daily study
///   reminder, streak at risk, come-back nudges, weekly recap, planned
///   sessions, mock test days and the exam countdown. They are re-planned
///   whenever progress, settings or the language change.
/// * Events (inbox, plus a device notification when the app is in the
///   background): scores, personal bests, targets reached, milestones,
///   finished course stages and the AI scoring limit.
///
/// Rules: no study nudges between 22:30 and 08:00, at most one study nudge
/// a day, and nudges stop 14 days after the last activity.
/// Push from the server (FCM) is added separately.
class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  static const _channelNames = <String, String>{
    NotifGroup.study: 'Study reminders',
    NotifGroup.exam: 'Exam & schedule',
    NotifGroup.results: 'Results',
    NotifGroup.achievements: 'Achievements',
    NotifGroup.news: 'News & account',
  };

  // Ids < 1000 are scheduled (re-planned each time); ≥ 1000 are shown now.
  static const _idDaily = 1; // +0..2
  static const _idStreak = 10; // +0..1
  static const _idComeback = 20; // +0..1
  static const _idWeekly = 30;
  static const _idTask = 100; // +0..199
  static const _idMockDay = 400; // +0..49
  static const _idExam = 500; // +0..5
  static const _maxScheduledId = 1000;

  static const _kGroups = 'notif.groups';
  static const _kTime = 'notif.time';
  static const _kLegacyStudy = 'home.studyReminders';
  static const _kSeeded = 'notif.seeded';
  static const _kAttempts = 'notif.attempts';
  static const _kBadges = 'notif.badges';
  static const _kStages = 'notif.stages';
  static const _kInbox = 'notif.inbox';
  static const _kQuota = 'notif.quotaMonth';
  static const _kAsked = 'notif.permissionAsked';

  static const defaultTime = '20:00';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _started = false;
  Timer? _debounce;
  String _lastSig = '';
  String? _account;
  int _showSeq = 0;
  Map<String, dynamic>? _launchPayload;
  List<_Planned> _lastPlan = <_Planned>[];

  /// Why device notifications are unavailable ('' when they work).
  String initError = '';

  /// Bumped whenever [upcoming] changes.
  final ValueNotifier<int> planChanged = ValueNotifier<int>(0);

  /// Device notifications can be shown on this phone.
  bool get ready => _ready;

  /// Planned device notifications, soonest first: (time, title).
  List<(DateTime, String)> get upcoming {
    final l = List<_Planned>.of(_lastPlan)..sort((a, b) => a.at.compareTo(b.at));
    return <(DateTime, String)>[for (final p in l) (p.at, p.title)];
  }

  /// Device notifications work on Android and iOS; elsewhere only the inbox.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // ── start-up ────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_started) return;
    _started = true;
    if (_supported) {
      try {
        tzdata.initializeTimeZones();
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_nexted'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (r) => _openPayload(r.payload),
        );
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          _launchPayload = _decode(launch?.notificationResponse?.payload);
        }
        _ready = true;
      } catch (e) {
        initError = '$e';
        debugPrint('Notifications unavailable: $e');
      }
    } else {
      initError = 'Phone notifications only work in the Android / iOS app.';
    }
    AiService.onFailure = _onAiFailure;
    Store.I.addListener(_onChange);
    ContentL10n.lang.addListener(_onChange);
    _onChange();
    if (_launchPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final p = _launchPayload;
        _launchPayload = null;
        if (p != null) _open(p);
      });
    }
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _run);
  }

  /// Re-plans now (settings screen, app back in front).
  void refresh() {
    _debounce?.cancel();
    unawaited(_run());
  }

  Future<void> _run() async {
    final store = Store.I;
    final acc = store.current;
    if (acc == null) {
      if (_account != null) {
        _account = null;
        _lastSig = '';
        await _cancelScheduled();
      }
      return;
    }
    if (_account != acc.id) {
      _account = acc.id;
      _lastSig = '';
    }
    if (store.kv<bool>(_kSeeded) != true) {
      _seed(store);
    } else {
      _detectEvents(store);
    }
    await _maybeAskPermission(store);
    await _schedule(store);
  }

  // ── settings ────────────────────────────────────────────────────────────

  bool enabled(String group, [Store? s]) {
    final store = s ?? Store.I;
    final m = store.kv<Map>(_kGroups);
    final v = m?[group];
    if (v is bool) return v;
    if (group == NotifGroup.study) return store.kv<bool>(_kLegacyStudy) ?? true;
    return true;
  }

  void setEnabled(String group, bool value) {
    final store = Store.I;
    final m = <String, dynamic>{...?store.kv<Map>(_kGroups)?.cast<String, dynamic>(), group: value};
    store.setKv(_kGroups, m);
    if (group == NotifGroup.study) store.setKv(_kLegacyStudy, value);
    if (value) unawaited(requestPermission());
  }

  /// Daily reminder time 'HH:MM' (08:00–22:30).
  String reminderTime([Store? s]) {
    final v = (s ?? Store.I).kv<String>(_kTime);
    return v != null && _parseTime(v) != null ? v : defaultTime;
  }

  void setReminderTime(TimeOfDay t) {
    final raw = t.hour * 60 + t.minute;
    final m = raw < 8 * 60 ? 8 * 60 : (raw > 22 * 60 + 30 ? 22 * 60 + 30 : raw);
    Store.I.setKv(_kTime, '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
  }

  static TimeOfDay? _parseTime(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Whether the phone allows our notifications (null = unknown / n/a).
  Future<bool?> systemEnabled() async {
    if (!_ready) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
      }
    } catch (_) {}
    return null;
  }

  /// Shows the system permission prompt (Android 13+, iOS).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Asks once, after onboarding (not on the splash or login screens).
  Future<void> _maybeAskPermission(Store store) async {
    if (!_ready || store.current?.onboarded != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAsked) == true) return;
      await prefs.setBool(_kAsked, true);
      await requestPermission();
    } catch (_) {}
  }

  // ── events → inbox (+ device notification in the background) ────────────

  String get _lang => ContentL10n.current;

  /// Records what exists now, so old results don't notify after an update.
  void _seed(Store store) {
    store.setKv(_kAttempts, <String>[for (final a in store.data.attempts) a.id]);
    store.setKv(_kBadges, _earnedBadges(store).toList());
    store.setKv(_kStages, _doneStages(store).toList());
    store.setKv(_kInbox, <String>[for (final n in store.notifications) n.s('id')]);
    store.setKv(_kSeeded, true);
  }

  void _detectEvents(Store store) {
    // New scored attempts (AI writing / speaking): result, personal best,
    // target reached. Mock and diagnostic results add their own entry.
    final seen = <String>{...?store.kv<List>(_kAttempts)?.map((e) => '$e')};
    final fresh = store.data.attempts.where((a) => !seen.contains(a.id)).toList();
    if (fresh.isNotEmpty) {
      final ids = <String>[...seen, for (final a in fresh) a.id];
      store.setKv(_kAttempts, ids.length > 500 ? ids.sublist(ids.length - 500) : ids);
      for (final a in fresh) {
        _onAttempt(store, a);
      }
    }

    // Milestones.
    final badges = _earnedBadges(store);
    final knownBadges = <String>{...?store.kv<List>(_kBadges)?.map((e) => '$e')};
    final newBadges = badges.difference(knownBadges);
    if (newBadges.isNotEmpty) {
      store.setKv(_kBadges, badges.union(knownBadges).toList());
      final defs = <String, String>{
        for (final c in evaluateCertificates(store)) c.id: c.title,
      };
      for (final id in newBadges.take(3)) {
        _inbox(store, NotifGroup.achievements, <String, dynamic>{
          'type': 'system',
          'icon': 'medal',
          'title': NotifTexts.t('badge_title', _lang, <String, Object?>{'name': defs[id] ?? id}),
          'body': NotifTexts.t('badge_body', _lang),
          'target': Routes.certificates,
        });
      }
    }

    // Course stages.
    final stages = _doneStages(store);
    final knownStages = <String>{...?store.kv<List>(_kStages)?.map((e) => '$e')};
    final newStages = stages.difference(knownStages);
    if (newStages.isNotEmpty) {
      store.setKv(_kStages, stages.union(knownStages).toList());
      for (final key in newStages) {
        final i = key.indexOf('/');
        final module = key.substring(0, i);
        final stageId = key.substring(i + 1);
        final stage = Lessons.stages(module).firstWhere(
          (s) => s.s('id') == stageId,
          orElse: () => <String, dynamic>{},
        );
        _inbox(store, NotifGroup.achievements, <String, dynamic>{
          'type': 'system',
          'icon': 'school',
          'title': NotifTexts.t('stage_title', _lang,
              <String, Object?>{'stage': lessonText(stage['title'], module: module)}),
          'body': NotifTexts.t('stage_body', _lang, <String, Object?>{'course': Lessons.name(module)}),
          'target': Lessons.route(module),
        });
      }
    }

    // Anything new in the inbox (from here or other screens, e.g. a mock
    // scored while the app was in the background) → device notification.
    final knownInbox = <String>{...?store.kv<List>(_kInbox)?.map((e) => '$e')};
    final newInbox = store.notifications
        .where((n) => n['read'] != true && !knownInbox.contains(n.s('id')))
        .toList();
    if (newInbox.isNotEmpty) {
      store.setKv(_kInbox, <String>[
        for (final n in store.notifications.take(300)) n.s('id'),
      ]);
      final background =
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
      if (background) {
        for (final n in newInbox.take(3)) {
          final group = n.s('group').isNotEmpty
              ? n.s('group')
              : (n.s('type') == 'score' ? NotifGroup.results : NotifGroup.news);
          if (!enabled(group, store)) continue;
          final args = <String, dynamic>{...n.m('args')};
          String route = n.s('target');
          if (n.s('attemptId').isNotEmpty) {
            route = '@attempt';
            args['attemptId'] = n.s('attemptId');
          }
          if (route.isEmpty) route = Routes.notifications;
          unawaited(_showNow(group, n.s('title'), n.s('body'), route, args));
        }
      }
    }
  }

  void _onAttempt(Store store, Attempt a) {
    final band = a.band;
    if (band == null) return;
    if (a.skill != Skill.writing && a.skill != Skill.speaking) return;
    if (a.data['source'] != 'ai') return;
    final skill = Skill.label(a.skill);
    final earlier = store.data.attempts
        .where((x) => x.id != a.id && x.skill == a.skill && x.band != null && x.createdAt.isBefore(a.createdAt))
        .map((x) => x.band!)
        .toList();
    final best = earlier.isEmpty ? null : earlier.reduce((x, y) => x > y ? x : y);
    final target = store.current?.targetBand;
    final vars = <String, Object?>{'skill': skill, 'band': Store.formatBand(band)};
    String titleKey = 'result_title';
    String body = NotifTexts.t('result_body', _lang);
    if (target != null && band >= target && (best == null || best < target)) {
      titleKey = 'target_title';
      body = NotifTexts.t('best_body', _lang);
    } else if (best != null && band > best) {
      titleKey = 'best_title';
      body = NotifTexts.t('best_body', _lang);
    }
    _inbox(store, NotifGroup.results, <String, dynamic>{
      'type': 'score',
      'skill': a.skill,
      'icon': a.skill,
      'title': NotifTexts.t(titleKey, _lang, vars),
      'body': body,
      'attemptId': a.id,
    });
  }

  void _onAiFailure(String code) {
    if (code != 'upgrade_required') return;
    final store = Store.I;
    if (!store.isLoggedIn) return;
    final now = DateTime.now();
    final month = '${now.year}-${now.month}';
    if (store.kv<String>(_kQuota) == month) return;
    store.setKv(_kQuota, month);
    _inbox(store, NotifGroup.news, <String, dynamic>{
      'type': 'system',
      'icon': 'sparkle',
      'title': NotifTexts.t('quota_title', _lang),
      'body': NotifTexts.t('quota_body', _lang),
      'target': Routes.plans,
    });
  }

  void _inbox(Store store, String group, Map<String, dynamic> n) {
    store.addNotification(<String, dynamic>{'group': group, ...n});
  }

  Set<String> _earnedBadges(Store store) {
    try {
      return <String>{
        for (final c in evaluateCertificates(store))
          if (c.earned) c.id,
      };
    } catch (_) {
      return <String>{};
    }
  }

  Set<String> _doneStages(Store store) => <String>{
        for (final m in Lessons.modules)
          for (final s in Lessons.stages(m))
            if (Lessons.stageDone(store, s)) '$m/${s.s('id')}',
      };

  // ── scheduled device notifications ──────────────────────────────────────

  Future<void> _schedule(Store store) async {
    final plan = _plan(store, DateTime.now());
    _lastPlan = plan;
    planChanged.value++;
    if (!_ready) return;
    final sig = '${plan.map((p) => p.sig).join(';')}#$_lang';
    if (sig == _lastSig) return;
    _lastSig = sig;
    await _cancelScheduled();
    for (final p in plan) {
      try {
        await _plugin.zonedSchedule(
          id: p.id,
          title: p.title,
          body: p.body,
          scheduledDate: tz.TZDateTime.from(p.at.toUtc(), tz.UTC),
          notificationDetails: _details(p.group, p.body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _encode(p.route, p.args),
        );
      } catch (e) {
        debugPrint('Could not schedule notification ${p.id}: $e');
      }
    }
  }

  Future<void> _cancelScheduled() async {
    if (!_ready) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id < _maxScheduledId && p.id != 999) await _plugin.cancel(id: p.id);
      }
    } catch (_) {}
  }

  List<_Planned> _plan(Store store, DateTime now) {
    final acc = store.current;
    if (acc == null) return <_Planned>[];
    final lang = _lang;
    final out = <_Planned>[];
    final today = DateUtils.dateOnly(now);
    DateTime at(DateTime day, int h, int m) => DateTime(day.year, day.month, day.day, h, m);
    bool future(DateTime d) => d.isAfter(now.add(const Duration(minutes: 1)));
    final band = Store.formatBand(acc.targetBand ?? 7.0);

    // Last activity (attempt or lesson).
    DateTime? last;
    for (final a in store.data.attempts) {
      final c = a.createdAt.toLocal();
      if (last == null || c.isAfter(last)) last = c;
    }
    for (final d in Lessons.completions(store)) {
      final l = d.toLocal();
      if (last == null || l.isAfter(last)) last = l;
    }
    final lastDay = DateUtils.dateOnly(last ?? now);
    final studiedToday = last != null && DateUtils.dateOnly(last) == today;
    final streak = store.streakDays;

    // ── study group: one nudge per day ──
    if (enabled(NotifGroup.study, store)) {
      final time = _parseTime(reminderTime(store)) ?? const TimeOfDay(hour: 20, minute: 0);
      final nudges = <DateTime, _Planned>{};

      // Come back after 5 and 14 quiet days.
      for (final (i, days, key) in <(int, int, String)>[(0, 5, 'comeback5'), (1, 14, 'comeback14')]) {
        final day = lastDay.add(Duration(days: days));
        final when = at(day, time.hour, time.minute);
        if (future(when)) {
          nudges[day] = _Planned(_idComeback + i, NotifGroup.study, when,
              NotifTexts.t('${key}_title', lang, <String, Object?>{'band': band}),
              NotifTexts.t('${key}_body', lang), Routes.home);
        }
      }

      // Streak at risk at 21:00 (today, or tomorrow after studying today).
      if (streak >= 2) {
        final day = studiedToday ? today.add(const Duration(days: 1)) : today;
        final when = at(day, 21, 0);
        if (future(when)) {
          nudges[day] = _Planned(_idStreak + (studiedToday ? 1 : 0), NotifGroup.study, when,
              NotifTexts.t('streak_title', lang, <String, Object?>{'n': streak}),
              NotifTexts.t('streak_body', lang), Routes.home);
        }
      }

      // Daily reminder for the next three days (stops 14 days after the last
      // activity; skipped today once they've studied).
      final reminder = _dailyText(store, lang, band);
      for (var d = 0; d < 3; d++) {
        final day = today.add(Duration(days: d));
        if (nudges.containsKey(day)) continue;
        if (d == 0 && studiedToday) continue;
        if (day.difference(lastDay).inDays > 14) continue;
        final when = at(day, time.hour, time.minute);
        if (!future(when)) continue;
        // A study-plan day names the day's tasks instead.
        final plan = store.planTasksOn(day).where((t) => t['done'] != true).toList();
        if (plan.isNotEmpty) {
          final min = plan.fold<int>(0, (m, t) => m + t.i('durationMin'));
          nudges[day] = _Planned(_idDaily + d, NotifGroup.study, when, NotifTexts.t('daily_title', lang),
              NotifTexts.t('daily_plan', lang, <String, Object?>{'n': plan.length, 'min': min, 'task': plan.first.s('title')}),
              Routes.studyPlan);
          continue;
        }
        nudges[day] = _Planned(_idDaily + d, NotifGroup.study, when,
            NotifTexts.t('daily_title', lang), reminder.$1, reminder.$2, reminder.$3);
      }
      out.addAll(nudges.values);

      // Weekly recap: Friday 18:00, while they're active.
      if (today.difference(lastDay).inDays <= 14) {
        var day = today;
        while (day.weekday != DateTime.friday || !future(at(day, 18, 0))) {
          day = day.add(const Duration(days: 1));
        }
        out.add(_Planned(_idWeekly, NotifGroup.study, at(day, 18, 0),
            NotifTexts.t('weekly_title', lang), NotifTexts.t('weekly_body', lang), Routes.analytics));
      }
    }

    // ── exam & schedule group ──
    if (enabled(NotifGroup.exam, store)) {
      // Planned sessions (15 minutes before) and mock days (08:30).
      final horizon = now.add(const Duration(days: 14));
      var ti = 0;
      var mi = 0;
      final mockDays = <DateTime>{};
      final tasks = List<Map<String, dynamic>>.of(store.tasks)
        ..sort((a, b) => '${a['date']} ${a['time']}'.compareTo('${b['date']} ${b['time']}'));
      for (final t in tasks) {
        if (t['done'] == true) continue;
        final date = DateTime.tryParse(t.s('date'));
        if (date == null) continue;
        final tm = _parseTime(t.s('time'));
        // Plan tasks are covered by the daily reminder (one per day, not one per task).
        if (tm != null && ti < 200 && !Store.isPlanTask(t)) {
          final when = at(date, tm.hour, tm.minute).subtract(const Duration(minutes: 15));
          if (future(when) && when.isBefore(horizon)) {
            out.add(_Planned(_idTask + ti++, NotifGroup.exam, when,
                NotifTexts.t('task_title', lang, <String, Object?>{'task': t.s('title')}),
                NotifTexts.t('task_body', lang), Routes.schedule));
          }
        }
        if (t.s('skill') == Skill.mock && mi < 50 && mockDays.add(DateUtils.dateOnly(date))) {
          final when = at(date, 8, 30);
          if (future(when) && when.isBefore(horizon)) {
            out.add(_Planned(_idMockDay + mi++, NotifGroup.exam, when,
                NotifTexts.t('mock_title', lang), NotifTexts.t('mock_body', lang), Routes.mockLibrary));
          }
        }
      }

      // Exam countdown.
      final exam = acc.examDate;
      if (exam != null) {
        final examDay = DateUtils.dateOnly(exam);
        const offsets = <int>[30, 14, 7, 3, 1];
        for (var i = 0; i < offsets.length; i++) {
          final n = offsets[i];
          final when = at(examDay.subtract(Duration(days: n)), 9, 0);
          if (!future(when)) continue;
          out.add(_Planned(_idExam + i, NotifGroup.exam, when,
              n == 1
                  ? NotifTexts.t('exam1_title', lang)
                  : NotifTexts.t('exam_title', lang, <String, Object?>{'n': n}),
              NotifTexts.t(n == 1 ? 'exam1_body' : 'exam_body', lang), Routes.home));
        }
        final day = at(examDay, 7, 30);
        if (future(day)) {
          out.add(_Planned(_idExam + 5, NotifGroup.exam, day, NotifTexts.t('examday_title', lang),
              NotifTexts.t('examday_body', lang), Routes.home));
        }
      }
    }
    return out;
  }

  /// Daily reminder body and where it opens: an unfinished essay, else the
  /// next lesson, else a general nudge.
  (String, String, Map<String, dynamic>?) _dailyText(Store store, String lang, String band) {
    for (final task in const <int>[2, 1]) {
      if (WritingDrafts.read(store, task) != null) {
        return (
          NotifTexts.t('daily_draft', lang, <String, Object?>{'task': 'Writing Task $task'}),
          Routes.writingSelector,
          null,
        );
      }
    }
    // The course they used most recently, else Writing.
    String module = 'writing';
    DateTime? latest;
    final done = store.kv<Map>('lessons.done');
    done?.forEach((_, v) {
      if (v is Map && v['at'] is String && v['module'] is String) {
        final t = DateTime.tryParse(v['at'] as String);
        if (t != null && (latest == null || t.isAfter(latest!))) {
          latest = t;
          module = v['module'] as String;
        }
      }
    });
    final next = Lessons.has(module) ? Lessons.resume(store, module) : null;
    if (next != null) {
      return (
        NotifTexts.t('daily_lesson', lang,
            <String, Object?>{'lesson': lessonText(next.lesson['title'], module: module)}),
        Routes.lesson,
        <String, dynamic>{'lesson': next.id},
      );
    }
    return (NotifTexts.t('daily_generic', lang, <String, Object?>{'band': band}), Routes.home, null);
  }

  // ── tests (Profile › Notifications) ──

  /// Shows a notification now. False when the phone blocks it.
  Future<bool> sendTest() async {
    if (!_ready) return false;
    await _showNow(NotifGroup.study, NotifTexts.t('daily_title', _lang),
        'Notifications are working. Tap to open the app.', Routes.home, <String, dynamic>{});
    return true;
  }

  /// Schedules a test 1 minute from now (close the app to check that
  /// reminders arrive while it isn't running).
  Future<bool> scheduleTest() async {
    if (!_ready) return false;
    try {
      await _plugin.zonedSchedule(
        id: 999,
        title: NotifTexts.t('daily_title', _lang),
        body: 'Scheduled test: reminders arrive even when the app is closed.',
        scheduledDate: tz.TZDateTime.from(DateTime.now().toUtc().add(const Duration(minutes: 1)), tz.UTC),
        notificationDetails: _details(NotifGroup.study, 'Scheduled test'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _encode(Routes.home, null),
      );
      return true;
    } catch (e) {
      initError = '$e';
      return false;
    }
  }

  // ── showing and opening ─────────────────────────────────────────────────

  NotificationDetails _details(String group, String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'nexted_$group',
          _channelNames[group] ?? 'IELTS AI',
          channelDescription: NotifGroup.description(group),
          importance: group == NotifGroup.results || group == NotifGroup.exam
              ? Importance.high
              : Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_stat_nexted',
          color: const Color(0xFFF2785C),
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      );

  Future<void> _showNow(String group, String title, String body, String route, Map<String, dynamic> args) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _maxScheduledId + (_showSeq++ % 100000),
        title: title,
        body: body,
        notificationDetails: _details(group, body),
        payload: _encode(route, args),
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  static String _encode(String route, Map<String, dynamic>? args) =>
      jsonEncode(<String, dynamic>{'route': route, if (args != null && args.isNotEmpty) 'args': args});

  static Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final v = jsonDecode(payload);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  void _openPayload(String? payload) {
    final p = _decode(payload);
    if (p != null) _open(p);
  }

  void _open(Map<String, dynamic> p) {
    final nav = appNavigatorKey.currentState;
    if (nav == null || !Store.I.isLoggedIn) return;
    final route = p.s('route');
    final args = p.m('args');
    if (route == '@attempt') {
      final a = Store.I.attemptById(args.s('attemptId'));
      if (a != null) {
        nav.pushNamed(resultRouteFor(a), arguments: <String, dynamic>{'attemptId': a.id});
      } else {
        nav.pushNamed(Routes.notifications);
      }
      return;
    }
    if (route.isEmpty) return;
    if (Routes.tabRoutes.containsKey(route)) {
      nav.pushNamedAndRemoveUntil(route, (r) => false);
    } else {
      nav.pushNamed(route, arguments: args.isEmpty ? null : args);
    }
  }
}
