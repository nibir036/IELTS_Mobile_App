import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes.dart';
import '../services/api_client.dart';
import '../services/config.dart';
import '../services/sync_service.dart';
import 'demo.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Local "backend" for the demo build.
//
// • CONTENT (tests, passages, questions, word lists, channels…) is global and
//   comes from `Demo.section(...)` — the same for every student.
// • USER DATA (account, onboarding answers, attempts/scores, essays,
//   recordings, saved words, schedule, notifications, chat messages, drafts…)
//   lives here, per account, persisted on the device with SharedPreferences.
//
// A brand-new account has NO user data, so every screen that shows progress
// must render its empty state. The seeded demo account (Tanvir Ahmed) has a
// full history so the "lived-in" designs can be seen.
//
// Read in widgets with `context.store` (rebuilds on change) or `Store.I`
// (no rebuild, for callbacks).
// ═════════════════════════════════════════════════════════════════════════════

/// OTP bypass for the demo build (no SMS provider yet).
const String kDemoOtp = '123456';

/// Skills used in [Attempt.skill].
class Skill {
  Skill._();
  static const listening = 'listening';
  static const reading = 'reading';
  static const writing = 'writing';
  static const speaking = 'speaking';
  static const mock = 'mock';
  static const vocab = 'vocab';

  static const core = <String>[listening, reading, writing, speaking];

  static String label(String skill) => switch (skill) {
        listening => 'Listening',
        reading => 'Reading',
        writing => 'Writing',
        speaking => 'Speaking',
        mock => 'Mock',
        vocab => 'Vocabulary',
        _ => skill,
      };

  static String letter(String skill) => switch (skill) {
        listening => 'L',
        reading => 'R',
        writing => 'W',
        speaking => 'S',
        mock => 'M',
        vocab => 'V',
        _ => '•',
      };
}

/// A registered student.
class Account {
  Account({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.createdAt,
    this.isDemo = false,
    Map<String, dynamic>? profile,
  }) : profile = profile ?? <String, dynamic>{};

  final String id;
  String name;

  /// National number, digits only, without country code or leading 0
  /// (e.g. "1734519208").
  final String phone;
  String password;
  final DateTime createdAt;
  final bool isDemo;

  /// Onboarding + settings: targetBand (double), examDate (ISO yyyy-mm-dd),
  /// testType ('Academic'|'General Training'), diagnostic ('diagnostic'|'custom'),
  /// focusSkills (`List<String>`), dailyMinutes (int), micAllowed (bool),
  /// onboarded (bool), plan ('Free'|'Pro'), email …
  final Map<String, dynamic> profile;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  /// "+880 1734 ••• 208"
  String get phoneMasked {
    if (phone.length < 7) return '+880 $phone';
    return '+880 ${phone.substring(0, 4)} ••• ${phone.substring(phone.length - 3)}';
  }

  /// "+880 1734 519208"
  String get phoneDisplay {
    if (phone.length <= 4) return '+880 $phone';
    return '+880 ${phone.substring(0, 4)} ${phone.substring(4)}';
  }

  double? get targetBand {
    final v = profile['targetBand'];
    return v is num ? v.toDouble() : null;
  }

  DateTime? get examDate {
    final v = profile['examDate'];
    return v is String ? DateTime.tryParse(v) : null;
  }

  int? get daysToExam {
    final d = examDate;
    if (d == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(d).difference(today).inDays;
  }

  String get testType => (profile['testType'] as String?) ?? 'Academic';
  bool get onboarded => profile['onboarded'] == true;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'password': password,
        'createdAt': createdAt.toIso8601String(),
        'isDemo': isDemo,
        'profile': profile,
      };

  static Account fromJson(Map<String, dynamic> j) => Account(
        id: j.s('id'),
        name: j.s('name'),
        phone: j.s('phone'),
        password: j.s('password'),
        createdAt: DateTime.tryParse(j.s('createdAt')) ?? DateTime.now(),
        isDemo: j.b('isDemo'),
        profile: j.m('profile'),
      );
}

/// One finished piece of practice (a scored test, essay, recording, quiz…).
class Attempt {
  Attempt({
    required this.id,
    required this.skill,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.refId = '',
    this.band,
    this.score,
    this.total,
    this.durationSec = 0,
    Map<String, dynamic>? data,
  }) : data = data ?? <String, dynamic>{};

  final String id;

  /// One of [Skill].
  final String skill;

  /// Sub-type, e.g. 'test', 'mini', 'lesson', 'task1', 'task2', 'part1',
  /// 'part2', 'part3', 'pronunciation', 'mock', 'quiz', 'drill'.
  final String kind;
  final String title;

  /// Content id this attempt was made on (test id, prompt id, cue card id…).
  final String refId;

  /// Band score if the attempt is band-scored.
  final double? band;

  /// Raw correct answers / total, when relevant.
  final int? score;
  final int? total;

  /// Time spent — counts toward study time.
  final int durationSec;
  final DateTime createdAt;

  /// Anything else the result screens need: answers, essay text, criteria
  /// bands, transcript, feedback items, per-section bands…
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'id': id,
        'skill': skill,
        'kind': kind,
        'title': title,
        'refId': refId,
        'band': band,
        'score': score,
        'total': total,
        'durationSec': durationSec,
        'createdAt': createdAt.toIso8601String(),
        'data': data,
      };

  /// Seed rows may use `"daysAgo": n` (and optional `"hour"`) instead of
  /// `createdAt`, so the demo history always looks recent.
  static Attempt fromJson(Map<String, dynamic> j) {
    DateTime created;
    if (j.containsKey('daysAgo')) {
      final now = DateTime.now();
      final day = DateUtils.dateOnly(now).subtract(Duration(days: j.i('daysAgo')));
      final hour = j.containsKey('hour') ? j.i('hour') : 18;
      created = day.add(Duration(hours: hour));
      if (created.isAfter(now)) created = now.subtract(const Duration(minutes: 5));
    } else {
      created = DateTime.tryParse(j.s('createdAt')) ?? DateTime.now();
    }
    return Attempt(
      id: j.s('id').isEmpty ? Store.newId('att') : j.s('id'),
      skill: j.s('skill'),
      kind: j.s('kind'),
      title: j.s('title'),
      refId: j.s('refId'),
      band: j['band'] is num ? (j['band'] as num).toDouble() : null,
      score: j['score'] is num ? (j['score'] as num).toInt() : null,
      total: j['total'] is num ? (j['total'] as num).toInt() : null,
      durationSec: j.i('durationSec'),
      createdAt: created,
      data: j.m('data'),
    );
  }
}

/// Everything user-specific for one account.
class UserData {
  UserData({
    List<Attempt>? attempts,
    List<Map<String, dynamic>>? notifications,
    List<Map<String, dynamic>>? tasks,
    Map<String, dynamic>? kv,
  })  : attempts = attempts ?? <Attempt>[],
        notifications = notifications ?? <Map<String, dynamic>>[],
        tasks = tasks ?? <Map<String, dynamic>>[],
        kv = kv ?? <String, dynamic>{};

  /// Newest first.
  final List<Attempt> attempts;

  /// {id, type, title, body, createdAt, read, target (route), args?}
  final List<Map<String, dynamic>> notifications;

  /// Schedule items: {id, title, skill, date (yyyy-mm-dd), time ('19:30'),
  /// durationMin, done, target (route)?}
  final List<Map<String, dynamic>> tasks;

  /// Free-form per-user state for screens (saved words, bookmarks, drafts,
  /// chat messages, read markers, settings, recent searches …).
  /// Use namespaced keys: 'writing.draft.task2', 'resources.savedWords' …
  final Map<String, dynamic> kv;

  Map<String, dynamic> toJson() => {
        'attempts': attempts.map((a) => a.toJson()).toList(),
        'notifications': notifications,
        'tasks': tasks,
        'kv': kv,
      };

  static UserData fromJson(Map<String, dynamic> j) {
    final attempts = j.l('attempts').map(Attempt.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return UserData(
      attempts: attempts,
      notifications: j.l('notifications').map(_resolveSeedDate).toList(),
      tasks: j.l('tasks').map(_resolveSeedTaskDate).toList(),
      kv: j.m('kv'),
    );
  }

  static Map<String, dynamic> _resolveSeedDate(Map<String, dynamic> n) {
    if (!n.containsKey('daysAgo') && !n.containsKey('minutesAgo')) return n;
    final now = DateTime.now();
    final created = now.subtract(
      Duration(days: n.i('daysAgo'), minutes: n.i('minutesAgo')),
    );
    final copy = Map<String, dynamic>.from(n)
      ..remove('daysAgo')
      ..remove('minutesAgo');
    copy['createdAt'] = created.toIso8601String();
    return copy;
  }

  static Map<String, dynamic> _resolveSeedTaskDate(Map<String, dynamic> t) {
    if (!t.containsKey('dayOffset')) return t;
    final day = DateUtils.dateOnly(DateTime.now()).add(Duration(days: t.i('dayOffset')));
    final copy = Map<String, dynamic>.from(t)..remove('dayOffset');
    copy['date'] = Store.dateKey(day);
    return copy;
  }
}

enum AuthResult {
  ok,
  noAccount,
  wrongPassword,
  phoneTaken,
  invalidPhone,
  invalidOtp,
  weakPassword,

  /// The API server couldn't be reached ([Store.lastAuthError] says why).
  network,

  /// Any other server refusal; the message is in [Store.lastAuthError].
  failed,
}

/// Registration waiting for OTP.
class PendingSignup {
  PendingSignup({required this.name, required this.phone, required this.password});
  final String name;
  final String phone;
  final String password;
}

class Store extends ChangeNotifier {
  Store._();

  static final Store I = Store._();

  static const _prefsKey = 'ielts_ai_store_v1';

  SharedPreferences? _prefs;
  final List<Account> _accounts = <Account>[];
  final Map<String, UserData> _data = <String, UserData>{};
  String? _currentId;
  bool _keepSignedIn = true;
  bool _night = false;

  /// Device-level Day/Night preference (persisted).
  bool get nightMode => _night;
  void setNightMode(bool v) {
    if (_night == v) return;
    _night = v;
    _save();
  }

  /// Set during sign-up (A3 → A4) or password reset (A5).
  PendingSignup? pendingSignup;
  String? pendingResetPhone;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }
    final raw = _prefs?.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
        for (final a in j.l('accounts')) {
          _accounts.add(Account.fromJson(a));
        }
        final data = j.m('data');
        for (final e in data.entries) {
          if (e.value is Map) {
            _data[e.key] = UserData.fromJson((e.value as Map).cast<String, dynamic>());
          }
        }
        _night = j['night'] == true;
        final keep = j['keepSignedIn'] != false;
        _keepSignedIn = keep;
        final cur = j['currentId'];
        _currentId = keep && cur is String && cur.isNotEmpty ? cur : null;
      } catch (_) {
        _accounts.clear();
        _data.clear();
        _currentId = null;
      }
    }
    if (AppConfig.hasApi) {
      // Signed in = a server session for an account cached on this device.
      await ApiClient.loadSession();
      final session = ApiClient.session;
      if (session != null && !_keepSignedIn) await ApiClient.setSession(null);
      final sid = ApiClient.session?.userId;
      _currentId = sid != null && account(sid) != null ? sid : null;
      ApiClient.onSessionEnded = () {
        if (_currentId == null) return;
        _currentId = null;
        commit();
      };
    } else {
      _ensureDemoAccounts();
    }
    if (_currentId != null && account(_currentId!) == null) _currentId = null;
  }

  /// Adds the seeded demo accounts from `demo_data.json → accounts` if they
  /// aren't stored yet.
  void _ensureDemoAccounts() {
    for (final seed in Demo.all.l('accounts')) {
      final acc = Account.fromJson(seed.m('account'));
      final version = seed.i('seedVersion');
      final existing = account(acc.id);
      if (existing != null) {
        // Content ids changed → refresh the demo history (keeps the account).
        final stored = existing.profile['seedVersion'];
        if (existing.isDemo && (stored is! num || stored.toInt() < version)) {
          _data[acc.id] = UserData.fromJson(seed.m('data'));
          existing.profile['seedVersion'] = version;
        }
        continue;
      }
      acc.profile['seedVersion'] = version;
      final days = acc.profile['examDaysFromNow'];
      if (days is num) {
        final d = DateUtils.dateOnly(DateTime.now()).add(Duration(days: days.toInt()));
        acc.profile['examDate'] = dateKey(d);
        acc.profile.remove('examDaysFromNow');
      }
      _accounts.add(acc);
      _data[acc.id] = UserData.fromJson(seed.m('data'));
    }
  }

  /// Resets the signed-in account's progress: the demo account goes back to
  /// its seed, any other account back to empty.
  Future<void> resetProgress() async {
    final acc = current;
    if (acc == null) return;
    if (acc.isDemo) {
      final seed = Demo.all.l('accounts').where((s) => s.m('account').s('id') == acc.id);
      _data[acc.id] = seed.isEmpty ? UserData() : UserData.fromJson(seed.first.m('data'));
    } else {
      _data[acc.id] = UserData();
      _welcome(acc);
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    final j = <String, dynamic>{
      'accounts': _accounts.map((a) => a.toJson()).toList(),
      'data': _data.map((k, v) => MapEntry(k, v.toJson())),
      'currentId': _currentId ?? '',
      'keepSignedIn': _keepSignedIn,
      'night': _night,
    };
    try {
      await p.setString(_prefsKey, jsonEncode(j));
    } catch (_) {}
  }

  /// Persist + rebuild listeners. Call after mutating [data] directly.
  void commit() {
    notifyListeners();
    _scheduleSave();
    onCommit?.call();
  }

  /// Set by [SyncService]: told about every change so it can upload it.
  static void Function()? onCommit;

  /// Server data merged into [data] (no upload: it came from the server).
  void applyRemoteChanges() {
    notifyListeners();
    _scheduleSave();
  }

  Timer? _saveTimer;

  /// Coalesces bursts of changes into one write (encoding the whole store
  /// on every tap made low-end phones stutter).
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  /// Write pending changes now (e.g. when the app goes to the background).
  Future<void> flush() async {
    if (_saveTimer?.isActive != true) return;
    _saveTimer?.cancel();
    await _save();
  }

  // ── accounts & auth ───────────────────────────────────────────────────────

  List<Account> get accounts => List.unmodifiable(_accounts);
  Account? account(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Account? get current => _currentId == null ? null : account(_currentId!);
  bool get isLoggedIn => current != null;

  /// Current user's data (empty object if logged out).
  UserData get data {
    final id = _currentId;
    if (id == null) return UserData();
    return _data.putIfAbsent(id, UserData.new);
  }

  /// "01734-519208", "+8801734519208", "1734 519208" → "1734519208".
  static String normalizePhone(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('880')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d;
  }

  static bool isValidPhone(String input) {
    final d = normalizePhone(input);
    return RegExp(r'^1[3-9]\d{8}$').hasMatch(d);
  }

  /// 8+ characters, at least one number and one symbol.
  static bool isStrongPassword(String p) =>
      p.length >= 8 && RegExp(r'\d').hasMatch(p) && RegExp(r'[^A-Za-z0-9]').hasMatch(p);

  /// 0–4 strength segments for the sign-up meter.
  static int passwordStrength(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p) && p.length >= 10) s++;
    return s;
  }

  Account? findByPhone(String input) {
    final p = normalizePhone(input);
    for (final a in _accounts) {
      if (a.phone == p) return a;
    }
    return null;
  }

  AuthResult login(String phone, String password, {bool keepSignedIn = true}) {
    if (!isValidPhone(phone)) return AuthResult.invalidPhone;
    final acc = findByPhone(phone);
    if (acc == null) return AuthResult.noAccount;
    if (acc.password != password) return AuthResult.wrongPassword;
    _currentId = acc.id;
    _keepSignedIn = keepSignedIn;
    commit();
    return AuthResult.ok;
  }

  /// Step 1 of sign-up: validate and hold the details until the OTP is entered.
  AuthResult startSignup({required String name, required String phone, required String password}) {
    if (!isValidPhone(phone)) return AuthResult.invalidPhone;
    if (findByPhone(phone) != null) return AuthResult.phoneTaken;
    if (!isStrongPassword(password)) return AuthResult.weakPassword;
    pendingSignup = PendingSignup(
      name: name.trim().isEmpty ? 'Student' : name.trim(),
      phone: normalizePhone(phone),
      password: password,
    );
    return AuthResult.ok;
  }

  /// Step 2 of sign-up: OTP must be [kDemoOtp]. Creates the account (with no
  /// progress data) and signs in.
  AuthResult verifySignupOtp(String code) {
    final p = pendingSignup;
    if (p == null) return AuthResult.noAccount;
    if (code != kDemoOtp) return AuthResult.invalidOtp;
    final acc = Account(
      id: newId('usr'),
      name: p.name,
      phone: p.phone,
      password: p.password,
      createdAt: DateTime.now(),
      profile: <String, dynamic>{'plan': 'Free', 'onboarded': false},
    );
    _accounts.add(acc);
    _data[acc.id] = UserData();
    _currentId = acc.id;
    _keepSignedIn = true;
    pendingSignup = null;
    _welcome(acc);
    commit();
    return AuthResult.ok;
  }

  void _welcome(Account acc) {
    _data[acc.id]!.notifications.insert(0, <String, dynamic>{
      'id': newId('ntf'),
      'type': 'system',
      'title': 'Welcome to IELTS AI, ${acc.firstName}',
      'body': 'Set your target band and take the diagnostic to get a study plan.',
      'createdAt': DateTime.now().toIso8601String(),
      'read': false,
      'target': '/onboarding/diagnostic',
    });
  }

  /// Password reset, step 1: the phone must belong to an account.
  AuthResult startReset(String phone) {
    if (!isValidPhone(phone)) return AuthResult.invalidPhone;
    if (findByPhone(phone) == null) return AuthResult.noAccount;
    pendingResetPhone = normalizePhone(phone);
    return AuthResult.ok;
  }

  /// Password reset, step 2.
  AuthResult verifyResetOtp(String code) =>
      code == kDemoOtp ? AuthResult.ok : AuthResult.invalidOtp;

  /// Password reset, step 3.
  AuthResult finishReset(String newPassword) {
    final phone = pendingResetPhone;
    if (phone == null) return AuthResult.noAccount;
    if (!isStrongPassword(newPassword)) return AuthResult.weakPassword;
    final acc = findByPhone(phone);
    if (acc == null) return AuthResult.noAccount;
    acc.password = newPassword;
    pendingResetPhone = null;
    commit();
    return AuthResult.ok;
  }

  void logout() {
    _currentId = null;
    commit();
  }

  /// Change the signed-in account's password (needs the current one).
  AuthResult changePassword(String currentPassword, String newPassword) {
    final acc = current;
    if (acc == null) return AuthResult.noAccount;
    if (acc.password != currentPassword) return AuthResult.wrongPassword;
    if (!isStrongPassword(newPassword)) return AuthResult.weakPassword;
    acc.password = newPassword;
    commit();
    return AuthResult.ok;
  }

  /// Permanently delete the signed-in account and all its data, then sign
  /// out. The demo account is re-created from its seed on next launch.
  AuthResult deleteAccount(String password) {
    final acc = current;
    if (acc == null) return AuthResult.noAccount;
    if (acc.password != password) return AuthResult.wrongPassword;
    _accounts.removeWhere((a) => a.id == acc.id);
    _data.remove(acc.id);
    _currentId = null;
    commit();
    return AuthResult.ok;
  }

  /// Update onboarding/profile fields of the signed-in account.
  void updateProfile(Map<String, dynamic> values, {String? name}) {
    final acc = current;
    if (acc == null) return;
    acc.profile.addAll(values);
    if (name != null && name.trim().isNotEmpty) acc.name = name.trim();
    commit();
  }

  static String authMessage(AuthResult r) => switch (r) {
        AuthResult.ok => '',
        AuthResult.noAccount => 'No account found for this number.',
        AuthResult.wrongPassword => 'Incorrect password. Try again.',
        AuthResult.phoneTaken => 'This number already has an account. Log in instead.',
        AuthResult.invalidPhone => 'Enter a valid Bangladeshi mobile number.',
        AuthResult.invalidOtp => AppConfig.hasApi
            ? (lastAuthError ?? 'That code is incorrect.')
            : 'That code is incorrect. (Demo code: $kDemoOtp)',
        AuthResult.weakPassword => 'Use 8+ characters with a number and a symbol.',
        AuthResult.network => lastAuthError ?? 'Can’t reach the server. Check your connection.',
        AuthResult.failed => lastAuthError ?? 'Something went wrong. Try again.',
      };

  // ── server accounts (when the app is built with API_BASE_URL) ─────────────
  //
  // The screens call these async versions. Without an API they fall back to
  // the local demo methods above, so the offline build behaves as before.

  /// Last server message for [AuthResult.network] / [AuthResult.failed] /
  /// [AuthResult.invalidOtp].
  static String? lastAuthError;

  /// Development servers (SMS_PROVIDER=console) return the OTP; shown in a toast.
  static String? lastDevCode;

  String? _resetProof;

  AuthResult _fail(ApiException e) {
    lastAuthError = e.message;
    return switch (e.code) {
      'network' => AuthResult.network,
      'no_account' => AuthResult.noAccount,
      'wrong_password' => AuthResult.wrongPassword,
      'phone_taken' => AuthResult.phoneTaken,
      'invalid_phone' => AuthResult.invalidPhone,
      'weak_password' => AuthResult.weakPassword,
      'otp_invalid' || 'otp_expired' || 'otp_too_many_attempts' => AuthResult.invalidOtp,
      _ => AuthResult.failed,
    };
  }

  /// Creates or refreshes the cached copy of a server account.
  void applyRemoteUser(Map<String, dynamic> u) {
    final id = u.s('id');
    if (id.isEmpty) return;
    final old = account(id);
    final profile = <String, dynamic>{...u.m('profile')};
    final seed = old?.profile['seedVersion'];
    if (seed != null) profile['seedVersion'] = seed;
    final acc = Account(
      id: id,
      name: u.s('name').isEmpty ? (old?.name ?? 'Student') : u.s('name'),
      phone: u.s('phone'),
      password: '',
      createdAt: DateTime.tryParse(u.s('createdAt')) ?? old?.createdAt ?? DateTime.now(),
      isDemo: u.b('isDemo'),
      profile: profile,
    );
    final i = _accounts.indexWhere((a) => a.id == id);
    if (i >= 0) {
      _accounts[i] = acc;
    } else {
      _accounts.add(acc);
    }
    _data.putIfAbsent(id, UserData.new);
    notifyListeners();
    _scheduleSave();
  }

  /// Stores the tokens from a login / register / reset response, signs the
  /// account in on this device and downloads its progress.
  Future<void> _adoptSession(Map<String, dynamic> r, {bool keepSignedIn = true}) async {
    final user = r.m('user');
    await ApiClient.setSession(ApiSession.fromAuth(r));
    applyRemoteUser(user);
    _currentId = user.s('id');
    _keepSignedIn = keepSignedIn;
    await _save();
    notifyListeners();
    await SyncService.I.syncNow();
  }

  Future<AuthResult> signIn(String phone, String password, {bool keepSignedIn = true}) async {
    if (!AppConfig.hasApi) return login(phone, password, keepSignedIn: keepSignedIn);
    if (!isValidPhone(phone)) return AuthResult.invalidPhone;
    try {
      final r = await ApiClient.request('POST', '/v1/auth/login',
          body: <String, dynamic>{'phone': normalizePhone(phone), 'password': password}, auth: false);
      await _adoptSession(r, keepSignedIn: keepSignedIn);
      return AuthResult.ok;
    } on ApiException catch (e) {
      return _fail(e);
    }
  }

  Future<AuthResult> _sendCode(String phone, String purpose) async {
    try {
      final r = await ApiClient.request('POST', '/v1/auth/otp/send',
          body: <String, dynamic>{'phone': phone, 'purpose': purpose}, auth: false);
      lastDevCode = r['devCode'] is String ? r['devCode'] as String : null;
      return AuthResult.ok;
    } on ApiException catch (e) {
      return _fail(e);
    }
  }

  /// Sign-up step 1: checks the details and texts a code.
  Future<AuthResult> beginSignup({required String name, required String phone, required String password}) async {
    if (!AppConfig.hasApi) return startSignup(name: name, phone: phone, password: password);
    if (!isValidPhone(phone)) return AuthResult.invalidPhone;
    if (!isStrongPassword(password)) return AuthResult.weakPassword;
    final p = normalizePhone(phone);
    final r = await _sendCode(p, 'signup');
    if (r != AuthResult.ok) return r;
    pendingSignup = PendingSignup(name: name.trim().isEmpty ? 'Student' : name.trim(), phone: p, password: password);
    return AuthResult.ok;
  }

  Future<AuthResult> resendSignupCode() async {
    final p = pendingSignup;
    if (!AppConfig.hasApi) return AuthResult.ok;
    if (p == null) return AuthResult.noAccount;
    return _sendCode(p.phone, 'signup');
  }

  /// Sign-up step 2: checks the code, creates the account and signs in.
  Future<AuthResult> completeSignup(String code) async {
    if (!AppConfig.hasApi) return verifySignupOtp(code);
    final p = pendingSignup;
    if (p == null) return AuthResult.noAccount;
    try {
      final v = await ApiClient.request('POST', '/v1/auth/otp/verify',
          body: <String, dynamic>{'phone': p.phone, 'purpose': 'signup', 'code': code}, auth: false);
      final r = await ApiClient.request('POST', '/v1/auth/register',
          body: <String, dynamic>{'name': p.name, 'phone': p.phone, 'password': p.password, 'proof': v['proof']},
          auth: false);
      pendingSignup = null;
      await _adoptSession(r);
      final acc = current;
      if (acc != null && data.notifications.isEmpty) {
        _welcome(acc);
        commit();
      }
      return AuthResult.ok;
    } on ApiException catch (e) {
      return _fail(e);
    }
  }

  /// Password reset step 1: texts a code to an existing account's number.
  Future<AuthResult> beginReset(String phone) async {
    if (!AppConfig.hasApi) return startReset(phone);
    if (!isValidPhone(phone)) return AuthResult.invalidPhone;
    final p = normalizePhone(phone);
    final r = await _sendCode(p, 'reset');
    if (r == AuthResult.ok) pendingResetPhone = p;
    return r;
  }

  Future<AuthResult> resendResetCode() async {
    final p = pendingResetPhone;
    if (!AppConfig.hasApi) return AuthResult.ok;
    if (p == null) return AuthResult.noAccount;
    return _sendCode(p, 'reset');
  }

  /// Password reset step 2.
  Future<AuthResult> checkResetCode(String code) async {
    if (!AppConfig.hasApi) return verifyResetOtp(code);
    final p = pendingResetPhone;
    if (p == null) return AuthResult.noAccount;
    try {
      final v = await ApiClient.request('POST', '/v1/auth/otp/verify',
          body: <String, dynamic>{'phone': p, 'purpose': 'reset', 'code': code}, auth: false);
      _resetProof = '${v['proof']}';
      return AuthResult.ok;
    } on ApiException catch (e) {
      return _fail(e);
    }
  }

  /// Password reset step 3. With a server this also signs in (every other
  /// device is signed out).
  Future<AuthResult> completeReset(String newPassword) async {
    if (!AppConfig.hasApi) return finishReset(newPassword);
    final p = pendingResetPhone, proof = _resetProof;
    if (p == null || proof == null) return AuthResult.noAccount;
    if (!isStrongPassword(newPassword)) return AuthResult.weakPassword;
    try {
      final r = await ApiClient.request('POST', '/v1/auth/reset-password',
          body: <String, dynamic>{'phone': p, 'password': newPassword, 'proof': proof}, auth: false);
      pendingResetPhone = null;
      _resetProof = null;
      await _adoptSession(r);
      return AuthResult.ok;
    } on ApiException catch (e) {
      return _fail(e);
    }
  }

  Future<AuthResult> updatePassword(String currentPassword, String newPassword) async {
    if (!AppConfig.hasApi) return changePassword(currentPassword, newPassword);
    if (!isStrongPassword(newPassword)) return AuthResult.weakPassword;
    try {
      await ApiClient.request('POST', '/v1/me/password',
          body: <String, dynamic>{'currentPassword': currentPassword, 'newPassword': newPassword});
      return AuthResult.ok;
    } on ApiException catch (e) {
      return _fail(e);
    }
  }

  Future<AuthResult> removeAccount(String password) async {
    if (!AppConfig.hasApi) return deleteAccount(password);
    final acc = current;
    if (acc == null) return AuthResult.noAccount;
    try {
      await ApiClient.request('DELETE', '/v1/me', body: <String, dynamic>{'password': password});
    } on ApiException catch (e) {
      return _fail(e);
    }
    await SyncService.I.forget(acc.id);
    await ApiClient.setSession(null);
    _accounts.removeWhere((a) => a.id == acc.id);
    _data.remove(acc.id);
    _currentId = null;
    commit();
    return AuthResult.ok;
  }

  /// Log out (uploads unsent changes first; the server session is ended).
  Future<void> signOut() async {
    if (AppConfig.hasApi && ApiClient.signedIn) {
      final refresh = ApiClient.session?.refreshToken;
      await SyncService.I.flush().timeout(const Duration(seconds: 8), onTimeout: () {});
      try {
        await ApiClient.request('POST', '/v1/auth/logout',
            body: <String, dynamic>{'refreshToken': refresh}, auth: false, timeout: const Duration(seconds: 8));
      } catch (_) {}
      await ApiClient.setSession(null);
    }
    logout();
  }

  // ── attempts ──────────────────────────────────────────────────────────────

  List<Attempt> get attempts => data.attempts;
  bool get hasActivity => data.attempts.isNotEmpty;

  /// Save a finished attempt (newest first) and log a notification.
  Attempt addAttempt(Attempt a, {bool notify = true}) {
    data.attempts.insert(0, a);
    if (notify && a.band != null) {
      data.notifications.insert(0, <String, dynamic>{
        'id': newId('ntf'),
        'type': 'score',
        'skill': a.skill,
        'title': '${Skill.label(a.skill)} scored · Band ${formatBand(a.band)}',
        'body': a.title,
        'createdAt': DateTime.now().toIso8601String(),
        'read': false,
        'attemptId': a.id,
      });
    }
    commit();
    return a;
  }

  void updateAttempt(Attempt a) {
    final i = data.attempts.indexWhere((x) => x.id == a.id);
    if (i >= 0) data.attempts[i] = a;
    commit();
  }

  void deleteAttempt(String id) {
    data.attempts.removeWhere((a) => a.id == id);
    commit();
  }

  Attempt? attemptById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in data.attempts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Attempts filtered by skill and/or kind, newest first. Plain study-time
  /// rows (`kind: 'session'`) are skipped unless asked for explicitly.
  List<Attempt> attemptsFor({String? skill, String? kind, String? kindPrefix}) =>
      data.attempts
          .where((a) =>
              (kind == 'session' || a.kind != 'session') &&
              (skill == null || a.skill == skill) &&
              (kind == null || a.kind == kind) &&
              (kindPrefix == null || a.kind.startsWith(kindPrefix)))
          .toList();

  Attempt? latest({String? skill, String? kind, String? kindPrefix}) {
    final l = attemptsFor(skill: skill, kind: kind, kindPrefix: kindPrefix);
    return l.isEmpty ? null : l.first;
  }

  /// Latest attempt for a result screen: the one passed as
  /// `routeArgs['attemptId']` or the newest matching one.
  Attempt? resolveAttempt(Map<String, dynamic> args, {String? skill, String? kind, String? kindPrefix}) {
    final byId = attemptById(args['attemptId'] as String?);
    return byId ?? latest(skill: skill, kind: kind, kindPrefix: kindPrefix);
  }

  // ── derived stats ─────────────────────────────────────────────────────────

  /// Current band for a skill: mean of the last 3 band-scored attempts
  /// (mock sections count too), rounded to .5. Null if never practised.
  double? skillBand(String skill) {
    final bands = <double>[];
    for (final a in data.attempts) {
      if (bands.length >= 3) break;
      if (a.skill == skill && a.band != null) {
        bands.add(a.band!);
      } else if (a.skill == Skill.mock) {
        final s = a.data['sections'];
        if (s is Map && s[skill] is num) bands.add((s[skill] as num).toDouble());
      }
    }
    if (bands.isEmpty) return null;
    return roundBand(bands.reduce((x, y) => x + y) / bands.length);
  }

  /// Overall estimate (average of the four skills that have data).
  double? get estimatedBand {
    final b = Skill.core.map(skillBand).whereType<double>().toList();
    if (b.isEmpty) return null;
    return roundBand(b.reduce((x, y) => x + y) / b.length);
  }

  /// Progress 0..1 of a skill band toward the target band.
  double skillProgress(String skill) {
    final b = skillBand(skill);
    final target = current?.targetBand ?? 7.0;
    if (b == null) return 0;
    return (b / target).clamp(0.0, 1.0).toDouble();
  }

  /// Study minutes for each day of the week containing [anyDay] (Mon..Sun).
  List<int> weekMinutes([DateTime? anyDay]) {
    final d = DateUtils.dateOnly(anyDay ?? DateTime.now());
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final out = List<int>.filled(7, 0);
    for (final a in data.attempts) {
      final ad = DateUtils.dateOnly(a.createdAt);
      final diff = ad.difference(monday).inDays;
      if (diff >= 0 && diff < 7) out[diff] += (a.durationSec / 60).round();
    }
    return out;
  }

  int minutesOn(DateTime day) {
    final d = DateUtils.dateOnly(day);
    var m = 0;
    for (final a in data.attempts) {
      if (DateUtils.isSameDay(a.createdAt, d)) m += (a.durationSec / 60).round();
    }
    return m;
  }

  /// Consecutive days (ending today or yesterday) with at least one attempt.
  int get streakDays {
    if (data.attempts.isEmpty) return 0;
    final days = data.attempts.map((a) => DateUtils.dateOnly(a.createdAt)).toSet();
    var day = DateUtils.dateOnly(DateTime.now());
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(day)) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get totalMinutes =>
      data.attempts.fold<int>(0, (s, a) => s + (a.durationSec / 60).round());

  /// Band history for a skill (oldest → newest) for charts.
  List<double> bandHistory(String? skill, {int max = 12}) {
    final l = data.attempts
        .where((a) => a.band != null && (skill == null || a.skill == skill))
        .toList()
        .reversed
        .map((a) => a.band!)
        .toList();
    return l.length > max ? l.sublist(l.length - max) : l;
  }

  // ── notifications & tasks ────────────────────────────────────────────────

  List<Map<String, dynamic>> get notifications => data.notifications;
  int get unreadNotifications => data.notifications.where((n) => n['read'] != true).length;

  void addNotification(Map<String, dynamic> n) {
    data.notifications.insert(0, <String, dynamic>{
      'id': newId('ntf'),
      'createdAt': DateTime.now().toIso8601String(),
      'read': false,
      ...n,
    });
    commit();
  }

  void markNotificationRead(String id) {
    for (final n in data.notifications) {
      if (n['id'] == id) n['read'] = true;
    }
    commit();
  }

  void markAllNotificationsRead() {
    for (final n in data.notifications) {
      n['read'] = true;
    }
    commit();
  }

  List<Map<String, dynamic>> get tasks => data.tasks;

  List<Map<String, dynamic>> tasksOn(DateTime day) {
    final k = dateKey(day);
    final l = data.tasks.where((t) => t['date'] == k).toList()
      ..sort((a, b) => '${a['time']}'.compareTo('${b['time']}'));
    return l;
  }

  void addTask(Map<String, dynamic> t) {
    data.tasks.add(<String, dynamic>{'id': newId('tsk'), 'done': false, ...t});
    commit();
  }

  void toggleTask(String id) {
    for (final t in data.tasks) {
      if (t['id'] == id) t['done'] = t['done'] != true;
    }
    commit();
  }

  void removeTask(String id) {
    data.tasks.removeWhere((t) => t['id'] == id);
    commit();
  }

  // ── key/value user state ─────────────────────────────────────────────────

  T? kv<T>(String key) {
    final v = data.kv[key];
    return v is T ? v : null;
  }

  void setKv(String key, Object? value) {
    if (value == null) {
      data.kv.remove(key);
    } else {
      data.kv[key] = value;
    }
    commit();
  }

  /// String-set helpers (saved words, bookmarks, read rooms …).
  Set<String> kvSet(String key) {
    final v = data.kv[key];
    if (v is List) return v.map((e) => '$e').toSet();
    return <String>{};
  }

  bool kvSetHas(String key, String value) => kvSet(key).contains(value);

  void kvSetToggle(String key, String value) {
    final s = kvSet(key);
    if (!s.remove(value)) s.add(value);
    setKv(key, s.toList());
  }

  /// List-of-maps helpers (chat messages, notes …).
  List<Map<String, dynamic>> kvList(String key) {
    final v = data.kv[key];
    if (v is List) {
      return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  void kvListAdd(String key, Map<String, dynamic> item) {
    final l = kvList(key)..add(item);
    setKv(key, l);
  }

  // ── utils ─────────────────────────────────────────────────────────────────

  static int _seq = 0;
  static String newId(String prefix) {
    _seq++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$_seq';
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static double roundBand(double v) => ((v * 2).round() / 2).clamp(0.0, 9.0).toDouble();

  /// 6.5 → "6.5", 7 → "7.0", null → "–".
  static String formatBand(double? b) => b == null ? '–' : b.toStringAsFixed(1);

  static const _months = <String>['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "Today", "Yesterday", "Sat 3 Oct".
  static String relativeDay(DateTime d) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(d);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  /// "21 Sep".
  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// "Sat 14 Nov".
  static String weekdayDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  static String weekdayShort(int weekday) => _weekdays[(weekday - 1) % 7];
  static String monthShort(int month) => _months[(month - 1) % 12];

  /// "2 min ago", "3 h ago", "Yesterday", "21 Sep".
  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return shortDate(d);
  }

  /// "5 hr 40 mins" style parts.
  static (int, int) hoursMinutes(int minutes) => (minutes ~/ 60, minutes % 60);

  /// "Good morning / afternoon / evening".
  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Where to open an attempt's result (pass `args: {'attemptId': a.id}`).
String resultRouteFor(Attempt a) => switch (a.skill) {
      Skill.listening => Routes.listeningResults,
      Skill.reading => a.kind == 'lesson' ? Routes.readingLesson : Routes.readingSolution,
      Skill.writing => a.kind == 'drill' ? Routes.sentenceBuilder : Routes.writingBandReport,
      Skill.speaking => a.kind == 'pronunciation' ? Routes.pronunciation : Routes.speakingEvaluation,
      Skill.mock => Routes.mockResults,
      Skill.vocab => Routes.vocabQuizScore,
      _ => Routes.home,
    };

// ═════════════════════════════════════════════════════════════════════════════
// Scoring (demo AI) — deterministic so the same input gives the same band.
// ═════════════════════════════════════════════════════════════════════════════

class Scoring {
  Scoring._();

  /// IELTS Listening raw score (out of 40) → band.
  static double listeningBand(int correct, [int total = 40]) {
    final raw = total == 40 ? correct : (correct * 40 / math.max(1, total)).round();
    const table = <int, double>{
      39: 9.0, 37: 8.5, 35: 8.0, 32: 7.5, 30: 7.0, 26: 6.5, 23: 6.0,
      18: 5.5, 16: 5.0, 13: 4.5, 11: 4.0, 8: 3.5, 6: 3.0, 4: 2.5,
    };
    for (final e in table.entries) {
      if (raw >= e.key) return e.value;
    }
    return raw > 0 ? 2.0 : 0.0;
  }

  /// IELTS Academic Reading raw score (out of 40) → band.
  static double readingBand(int correct, [int total = 40, bool general = false]) {
    final raw = total == 40 ? correct : (correct * 40 / math.max(1, total)).round();
    final table = general
        ? const <int, double>{
            40: 9.0, 39: 8.5, 37: 8.0, 36: 7.5, 34: 7.0, 32: 6.5, 30: 6.0,
            27: 5.5, 23: 5.0, 19: 4.5, 15: 4.0, 12: 3.5, 9: 3.0, 6: 2.5,
          }
        : const <int, double>{
            39: 9.0, 37: 8.5, 35: 8.0, 33: 7.5, 30: 7.0, 27: 6.5, 23: 6.0,
            19: 5.5, 15: 5.0, 13: 4.5, 10: 4.0, 8: 3.5, 6: 3.0, 4: 2.5,
          };
    for (final e in table.entries) {
      if (raw >= e.key) return e.value;
    }
    return raw > 0 ? 2.0 : 0.0;
  }

  static const _linkers = <String>[
    'however', 'moreover', 'furthermore', 'therefore', 'although', 'whereas',
    'in addition', 'on the other hand', 'for example', 'for instance',
    'consequently', 'nevertheless', 'in conclusion', 'overall', 'firstly',
    'secondly', 'finally', 'while', 'as a result', 'in contrast',
  ];

  /// Demo "AI" writing score from the essay text.
  /// Returns {band, TA, CC, LR, GRA, words, feedback: [..]}.
  static Map<String, dynamic> writing(String text, {required int task}) {
    final words = RegExp(r"[A-Za-z']+").allMatches(text).map((m) => m.group(0)!.toLowerCase()).toList();
    final n = words.length;
    final minWords = task == 1 ? 150 : 250;
    final sentences = RegExp(r'[.!?]+').allMatches(text).length;
    final paragraphs = text.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;
    final unique = words.toSet().length;
    final ttr = n == 0 ? 0.0 : unique / n;
    final lower = text.toLowerCase();
    final linkers = _linkers.where(lower.contains).length;
    final longWords = words.where((w) => w.length >= 8).length;
    final avgSentence = sentences == 0 ? n.toDouble() : n / sentences;

    double clampBand(double v) => Store.roundBand(v.clamp(3.0, 9.0).toDouble());

    final lengthRatio = n / minWords;
    final ta = clampBand(4.0 + math.min(lengthRatio, 1.1) * 2.6 + (paragraphs >= (task == 1 ? 3 : 4) ? 0.8 : 0));
    final cc = clampBand(4.0 + math.min(linkers, 6) * 0.45 + (paragraphs >= 3 ? 0.6 : 0));
    final lr = clampBand(3.8 + ttr * 3.2 + math.min(longWords / math.max(1, n) * 12, 1.4));
    final gra = clampBand(4.2 + (avgSentence >= 12 && avgSentence <= 26 ? 1.4 : 0.6) + math.min(sentences / 12, 1.0));
    final band = n < 20 ? 3.0 : Store.roundBand((ta + cc + lr + gra) / 4);

    final feedback = <String>[
      if (n < minWords) 'Write at least $minWords words — you wrote $n.',
      if (paragraphs < (task == 1 ? 3 : 4)) 'Organise your answer into clear paragraphs (intro, body, conclusion).',
      if (linkers < 3) 'Use more linking words (however, moreover, as a result) to improve coherence.',
      if (ttr < 0.5) 'Vary your vocabulary — avoid repeating the same words.',
      if (avgSentence > 28) 'Some sentences are very long; split them for accuracy.',
      if (avgSentence < 10 && n > 40) 'Combine short sentences with complex structures.',
    ];
    return <String, dynamic>{
      'band': band,
      'TA': ta,
      'CC': cc,
      'LR': lr,
      'GRA': gra,
      'words': n,
      'feedback': feedback,
    };
  }

  /// Demo speaking score from how long the student spoke (seconds) against
  /// the expected length. Returns {band, FC, LR, GRA, P}.
  static Map<String, dynamic> speaking(int spokenSec, {int expectedSec = 120, int seed = 0}) {
    final ratio = (spokenSec / math.max(1, expectedSec)).clamp(0.0, 1.2);
    final base = 4.0 + ratio * 2.8;
    double j(int k) => ((seed * 31 + k * 17) % 5 - 2) * 0.25;
    final fc = Store.roundBand((base + j(1)).clamp(3.0, 9.0).toDouble());
    final lr = Store.roundBand((base + j(2)).clamp(3.0, 9.0).toDouble());
    final gra = Store.roundBand((base - 0.3 + j(3)).clamp(3.0, 9.0).toDouble());
    final p = Store.roundBand((base + 0.2 + j(4)).clamp(3.0, 9.0).toDouble());
    return <String, dynamic>{
      'band': Store.roundBand((fc + lr + gra + p) / 4),
      'FC': fc,
      'LR': lr,
      'GRA': gra,
      'P': p,
    };
  }

  /// Overall IELTS band from four section bands (standard rounding).
  static double overall(List<double> bands) {
    if (bands.isEmpty) return 0;
    final avg = bands.reduce((a, b) => a + b) / bands.length;
    final floor = avg.floorToDouble();
    final frac = avg - floor;
    if (frac < 0.25) return floor;
    if (frac < 0.75) return floor + 0.5;
    return floor + 1;
  }

  /// Normalises an answer for comparison ("  The Museum " == "museum").
  static String norm(String s) => s
      .toLowerCase()
      // Hyphens, dashes, slashes and tabs separate words ("well-known").
      .replaceAll(RegExp(r'[\s\-\u2013\u2014/]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^(the|a|an)\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// True if [given] matches any of the accepted answers (pipe-separated
  /// alternatives allowed: "museum|the museum").
  static bool matches(String given, Object? accepted) {
    final g = norm(given);
    if (g.isEmpty) return false;
    final list = accepted is List ? accepted.map((e) => '$e') : '${accepted ?? ''}'.split('|');
    return list.any((a) => norm(a) == g);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Widget access
// ═════════════════════════════════════════════════════════════════════════════

class StoreScope extends InheritedNotifier<Store> {
  StoreScope({super.key, required super.child}) : super(notifier: Store.I);
}

extension StoreContext on BuildContext {
  /// The store; the calling widget rebuilds when user data changes.
  Store get store {
    dependOnInheritedWidgetOfExactType<StoreScope>();
    return Store.I;
  }
}
