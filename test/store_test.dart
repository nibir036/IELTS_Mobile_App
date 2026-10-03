// Store (local accounts + progress) tests.
//
// `Store.I` is a process-wide singleton with no reset hook, so every test
// here is order-independent by construction:
//   • setUp() signs out before each test;
//   • tests that need the demo student sign in themselves and never change
//     its password or add attempts to it;
//   • tests that mutate an account create their own fresh account with a
//     unique phone number (see [signUpFresh]).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/data/demo.dart';
import 'package:nexted_ielts_app/app/data/store.dart';
import 'package:nexted_ielts_app/app/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String demoPhone = '01734519208';
const String demoPassword = 'Demo@1234';
const String testPassword = 'Test@1234';

int _phoneSeq = 0;

/// A valid, unused Bangladeshi mobile number ("01911" + 6 digits).
String freshPhone() {
  _phoneSeq++;
  return '01911${100000 + _phoneSeq}';
}

/// Signs up (A3 → A4 with the demo OTP) and returns the new, signed-in
/// account. Its password is [testPassword].
Account signUpFresh({String name = 'Test Student', String? phone}) {
  Store.I.logout();
  final p = phone ?? freshPhone();
  expect(
    Store.I.startSignup(name: name, phone: p, password: testPassword),
    AuthResult.ok,
  );
  expect(Store.I.verifySignupOtp(kDemoOtp), AuthResult.ok);
  return Store.I.current!;
}

Attempt attempt(String skill, double? band, {String kind = 'test', int durationSec = 600, Map<String, dynamic>? data}) =>
    Attempt(
      id: Store.newId('att'),
      skill: skill,
      kind: kind,
      title: '$skill $kind',
      band: band,
      durationSec: durationSec,
      createdAt: DateTime.now(),
      data: data,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Demo.load();
    await Store.I.load();
  });

  setUp(() {
    Store.I.logout();
  });

  group('demo account', () {
    test('is seeded from demo_data.json', () {
      final demo = Store.I.findByPhone(demoPhone);
      expect(demo, isNotNull);
      expect(demo!.isDemo, isTrue);
      expect(demo.phone, '1734519208');
      expect(demo.name, 'Tanvir Ahmed');
      expect(demo.initials, 'TA');
      expect(demo.firstName, 'Tanvir');
      expect(demo.phoneMasked, '+880 1734 ••• 208');
      expect(demo.phoneDisplay, '+880 1734 519208');
      // examDaysFromNow is turned into a real date on first load.
      expect(demo.examDate, isNotNull);
      // (47 in time zones where a DST change falls inside the 48 days.)
      expect(demo.daysToExam, inInclusiveRange(47, 48));
    });

    test('logs in with 01734519208 / Demo@1234', () {
      expect(Store.I.login(demoPhone, demoPassword), AuthResult.ok);
      expect(Store.I.isLoggedIn, isTrue);
      expect(Store.I.current!.isDemo, isTrue);
      expect(Store.I.hasActivity, isTrue);
      expect(Store.I.attempts, isNotEmpty);
      expect(Store.I.current!.targetBand, 7.5);
      expect(Store.I.current!.onboarded, isTrue);
    });

    test('accepts other ways of writing the number', () {
      for (final p in <String>['+8801734519208', '01734-519208', '1734 519208', '8801734519208']) {
        Store.I.logout();
        expect(Store.I.login(p, demoPassword), AuthResult.ok, reason: p);
        expect(Store.I.current!.isDemo, isTrue);
      }
    });

    test('wrong password → wrongPassword, stays signed out', () {
      expect(Store.I.login(demoPhone, 'demo@1234'), AuthResult.wrongPassword);
      expect(Store.I.login(demoPhone, ''), AuthResult.wrongPassword);
      expect(Store.I.isLoggedIn, isFalse);
      expect(Store.I.current, isNull);
    });

    test('unknown number → noAccount, invalid number → invalidPhone', () {
      expect(Store.I.login('01999999999', demoPassword), AuthResult.noAccount);
      expect(Store.I.login('12345', demoPassword), AuthResult.invalidPhone);
      expect(Store.I.isLoggedIn, isFalse);
    });

    test('skill bands match the canvas (L 7.0 · R 6.5 · W 6.0 · S 6.5)', () {
      expect(Store.I.login(demoPhone, demoPassword), AuthResult.ok);
      expect(Store.I.skillBand(Skill.listening), 7.0);
      expect(Store.I.skillBand(Skill.reading), 6.5);
      expect(Store.I.skillBand(Skill.writing), 6.0);
      expect(Store.I.skillBand(Skill.speaking), 6.5);
      expect(Store.I.estimatedBand, 6.5);
      expect(Store.I.streakDays, greaterThan(0));
      expect(Store.I.totalMinutes, greaterThan(0));
    });

    test('attempts are newest first and session rows are hidden from lists', () {
      expect(Store.I.login(demoPhone, demoPassword), AuthResult.ok);
      final all = Store.I.attempts;
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i - 1].createdAt.isBefore(all[i].createdAt),
          isFalse,
          reason: 'attempt $i is newer than attempt ${i - 1}',
        );
      }
      expect(Store.I.attemptsFor().any((a) => a.kind == 'session'), isFalse);
      expect(Store.I.attemptsFor(kind: 'session'), isNotEmpty);
      expect(Store.I.attemptsFor(skill: Skill.mock, kind: 'mock'), isNotEmpty);
      final ids = all.map((a) => a.id).toSet();
      expect(ids.length, all.length, reason: 'seed attempt ids must be unique');
    });

    test('logout clears the session but keeps the data', () {
      expect(Store.I.login(demoPhone, demoPassword), AuthResult.ok);
      final n = Store.I.attempts.length;
      Store.I.logout();
      expect(Store.I.isLoggedIn, isFalse);
      expect(Store.I.current, isNull);
      expect(Store.I.attempts, isEmpty);
      expect(Store.I.hasActivity, isFalse);
      expect(Store.I.skillBand(Skill.listening), isNull);
      expect(Store.I.login(demoPhone, demoPassword), AuthResult.ok);
      expect(Store.I.attempts.length, n);
    });
  });

  group('sign-up', () {
    test('new account after OTP 123456 is signed in with ZERO progress', () {
      final phone = freshPhone();
      expect(
        Store.I.startSignup(name: '  Nadia  Rahman ', phone: phone, password: testPassword),
        AuthResult.ok,
      );
      expect(Store.I.pendingSignup, isNotNull);
      expect(Store.I.isLoggedIn, isFalse);

      expect(Store.I.verifySignupOtp('000000'), AuthResult.invalidOtp);
      expect(Store.I.isLoggedIn, isFalse);
      expect(Store.I.verifySignupOtp(kDemoOtp), AuthResult.ok);
      expect(Store.I.pendingSignup, isNull);

      final acc = Store.I.current!;
      expect(acc.name, 'Nadia  Rahman');
      expect(acc.firstName, 'Nadia');
      expect(acc.initials, 'NR');
      expect(acc.isDemo, isFalse);
      expect(acc.phone, Store.normalizePhone(phone));
      expect(acc.onboarded, isFalse);
      expect(acc.profile['plan'], 'Free');
      expect(acc.targetBand, isNull);
      expect(acc.daysToExam, isNull);

      // Blank dashboard rule: nothing scored, nothing studied.
      expect(Store.I.attempts, isEmpty);
      expect(Store.I.hasActivity, isFalse);
      for (final s in Skill.core) {
        expect(Store.I.skillBand(s), isNull, reason: s);
        expect(Store.I.skillProgress(s), 0.0, reason: s);
        expect(Store.I.bandHistory(s), isEmpty, reason: s);
      }
      expect(Store.I.estimatedBand, isNull);
      expect(Store.I.streakDays, 0);
      expect(Store.I.totalMinutes, 0);
      expect(Store.I.weekMinutes(), everyElement(0));
      expect(Store.I.minutesOn(DateTime.now()), 0);
      expect(Store.I.latest(), isNull);
      expect(Store.I.resolveAttempt(<String, dynamic>{}, skill: Skill.listening), isNull);
      expect(Store.I.tasks, isEmpty);
      expect(Store.I.data.kv, isEmpty);
      // Only the welcome notification.
      expect(Store.I.notifications.length, 1);
      expect(Store.I.notifications.first['type'], 'system');
      expect(Store.I.unreadNotifications, 1);
    });

    test('can log out and back in with the new password', () {
      final phone = freshPhone();
      signUpFresh(phone: phone);
      Store.I.logout();
      expect(Store.I.login(phone, testPassword), AuthResult.ok);
      expect(Store.I.current!.phone, Store.normalizePhone(phone));
    });

    test('blank name becomes "Student"', () {
      final acc = signUpFresh(name: '   ');
      expect(acc.name, 'Student');
    });

    test('rejects taken, invalid and weak inputs', () {
      expect(
        Store.I.startSignup(name: 'X', phone: demoPhone, password: testPassword),
        AuthResult.phoneTaken,
      );
      expect(
        Store.I.startSignup(name: 'X', phone: '0123', password: testPassword),
        AuthResult.invalidPhone,
      );
      expect(
        Store.I.startSignup(name: 'X', phone: freshPhone(), password: 'password'),
        AuthResult.weakPassword,
      );
    });

    test('verifying without a pending sign-up → noAccount', () {
      Store.I.pendingSignup = null;
      expect(Store.I.verifySignupOtp(kDemoOtp), AuthResult.noAccount);
    });
  });

  group('account management', () {
    test('changePassword', () {
      final phone = freshPhone();
      signUpFresh(phone: phone);
      expect(Store.I.changePassword('nope', 'New@12345'), AuthResult.wrongPassword);
      expect(Store.I.changePassword(testPassword, 'short'), AuthResult.weakPassword);
      expect(Store.I.changePassword(testPassword, 'New@12345'), AuthResult.ok);
      Store.I.logout();
      expect(Store.I.login(phone, testPassword), AuthResult.wrongPassword);
      expect(Store.I.login(phone, 'New@12345'), AuthResult.ok);
    });

    test('changePassword while signed out → noAccount', () {
      expect(Store.I.changePassword(demoPassword, 'New@12345'), AuthResult.noAccount);
    });

    test('deleteAccount', () {
      final phone = freshPhone();
      final acc = signUpFresh(phone: phone);
      Store.I.addAttempt(attempt(Skill.reading, 6.0));
      expect(Store.I.deleteAccount('wrong'), AuthResult.wrongPassword);
      expect(Store.I.isLoggedIn, isTrue);
      expect(Store.I.deleteAccount(testPassword), AuthResult.ok);
      expect(Store.I.isLoggedIn, isFalse);
      expect(Store.I.account(acc.id), isNull);
      expect(Store.I.findByPhone(phone), isNull);
      expect(Store.I.login(phone, testPassword), AuthResult.noAccount);
      // The number can be registered again, and starts blank.
      signUpFresh(phone: phone);
      expect(Store.I.attempts, isEmpty);
    });

    test('deleteAccount while signed out → noAccount', () {
      expect(Store.I.deleteAccount(demoPassword), AuthResult.noAccount);
    });

    test('password reset (A5)', () {
      final phone = freshPhone();
      signUpFresh(phone: phone);
      Store.I.logout();
      expect(Store.I.startReset('01999999998'), AuthResult.noAccount);
      expect(Store.I.startReset('123'), AuthResult.invalidPhone);
      expect(Store.I.startReset(phone), AuthResult.ok);
      expect(Store.I.verifyResetOtp('111111'), AuthResult.invalidOtp);
      expect(Store.I.verifyResetOtp(kDemoOtp), AuthResult.ok);
      expect(Store.I.finishReset('weak'), AuthResult.weakPassword);
      expect(Store.I.finishReset('Reset#2026'), AuthResult.ok);
      expect(Store.I.login(phone, testPassword), AuthResult.wrongPassword);
      expect(Store.I.login(phone, 'Reset#2026'), AuthResult.ok);
    });

    test('updateProfile', () {
      signUpFresh();
      Store.I.updateProfile(<String, dynamic>{'targetBand': 7.0, 'onboarded': true}, name: ' Rafi Karim ');
      expect(Store.I.current!.targetBand, 7.0);
      expect(Store.I.current!.onboarded, isTrue);
      expect(Store.I.current!.name, 'Rafi Karim');
      Store.I.updateProfile(<String, dynamic>{}, name: '   ');
      expect(Store.I.current!.name, 'Rafi Karim');
    });

    test('changes are written to SharedPreferences', () async {
      final acc = signUpFresh(name: 'Persist Me');
      await Store.I.flush();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ielts_ai_store_v1');
      expect(raw, isNotNull);
      expect(raw, contains(acc.id));
      expect(raw, contains('Persist Me'));
    });
  });

  group('attempts & derived stats', () {
    test('addAttempt updates skillBand and estimatedBand', () {
      signUpFresh();
      final a1 = Store.I.addAttempt(attempt(Skill.listening, 7.0));
      expect(Store.I.hasActivity, isTrue);
      expect(Store.I.skillBand(Skill.listening), 7.0);
      expect(Store.I.estimatedBand, 7.0);

      Store.I.addAttempt(attempt(Skill.reading, 6.0));
      expect(Store.I.skillBand(Skill.reading), 6.0);
      expect(Store.I.estimatedBand, 6.5); // (7.0 + 6.0) / 2

      // Mean of the three newest band-scored attempts, rounded to .5.
      Store.I.addAttempt(attempt(Skill.listening, 6.0));
      Store.I.addAttempt(attempt(Skill.listening, 6.5));
      expect(Store.I.skillBand(Skill.listening), 6.5); // 6.5 6.0 7.0
      Store.I.addAttempt(attempt(Skill.listening, 8.0));
      expect(Store.I.skillBand(Skill.listening), 7.0); // 8.0 6.5 6.0 = 6.83

      // Unscored attempts (vocab quiz) don't count as bands.
      Store.I.addAttempt(attempt(Skill.vocab, null, kind: 'quiz'));
      expect(Store.I.skillBand(Skill.listening), 7.0);

      expect(Store.I.attemptById(a1.id), same(a1));
      expect(Store.I.attemptsFor(skill: Skill.listening).length, 4);
      expect(Store.I.latest(skill: Skill.listening)!.band, 8.0);
      expect(
        Store.I.resolveAttempt(<String, dynamic>{'attemptId': a1.id}, skill: Skill.listening),
        same(a1),
      );
      expect(Store.I.bandHistory(Skill.listening), <double>[7.0, 6.0, 6.5, 8.0]);
      expect(Store.I.skillProgress(Skill.listening), greaterThan(0));
    });

    test('mock section bands count toward the skill bands', () {
      signUpFresh();
      Store.I.addAttempt(attempt(
        Skill.mock,
        5.5,
        kind: 'mock',
        data: <String, dynamic>{
          'sections': <String, dynamic>{'listening': 6.0, 'reading': 5.0, 'writing': 5.5, 'speaking': 6.0},
          'overall': 5.5,
        },
      ));
      expect(Store.I.skillBand(Skill.listening), 6.0);
      expect(Store.I.skillBand(Skill.reading), 5.0);
      expect(Store.I.skillBand(Skill.writing), 5.5);
      expect(Store.I.skillBand(Skill.speaking), 6.0);
      expect(Store.I.estimatedBand, 5.5); // 5.625 → 5.5
    });

    test('scored attempts notify, study time and streak update', () {
      signUpFresh();
      final before = Store.I.notifications.length;
      final a = Store.I.addAttempt(attempt(Skill.writing, 6.5, kind: 'task2', durationSec: 40 * 60));
      expect(Store.I.notifications.length, before + 1);
      expect(Store.I.notifications.first['attemptId'], a.id);
      expect(Store.I.notifications.first['type'], 'score');

      Store.I.addAttempt(attempt(Skill.writing, 6.0, kind: 'task1'), notify: false);
      expect(Store.I.notifications.length, before + 1);

      expect(Store.I.totalMinutes, 50);
      expect(Store.I.minutesOn(DateTime.now()), 50);
      final week = Store.I.weekMinutes();
      expect(week.length, 7);
      expect(week[DateTime.now().weekday - 1], 50);
      expect(Store.I.streakDays, 1);
    });

    test('deleteAttempt', () {
      signUpFresh();
      final a = Store.I.addAttempt(attempt(Skill.speaking, 6.0, kind: 'part2'));
      Store.I.deleteAttempt(a.id);
      expect(Store.I.attemptById(a.id), isNull);
      expect(Store.I.skillBand(Skill.speaking), isNull);
    });

    test('resultRouteFor', () {
      Attempt a(String skill, String kind) => attempt(skill, 6.0, kind: kind);
      expect(resultRouteFor(a(Skill.listening, 'test')), Routes.listeningResults);
      expect(resultRouteFor(a(Skill.reading, 'test')), Routes.readingSolution);
      expect(resultRouteFor(a(Skill.reading, 'lesson')), Routes.readingLesson);
      expect(resultRouteFor(a(Skill.writing, 'task2')), Routes.writingBandReport);
      expect(resultRouteFor(a(Skill.writing, 'drill')), Routes.sentenceBuilder);
      expect(resultRouteFor(a(Skill.speaking, 'part2')), Routes.speakingEvaluation);
      expect(resultRouteFor(a(Skill.speaking, 'pronunciation')), Routes.pronunciation);
      expect(resultRouteFor(a(Skill.mock, 'mock')), Routes.mockResults);
      expect(resultRouteFor(a(Skill.vocab, 'quiz')), Routes.vocabQuizScore);
    });
  });

  group('per-user state', () {
    test('kv helpers', () {
      signUpFresh();
      Store.I.setKv('test.value', 'hello');
      expect(Store.I.kv<String>('test.value'), 'hello');
      expect(Store.I.kv<int>('test.value'), isNull);
      Store.I.setKv('test.value', null);
      expect(Store.I.kv<String>('test.value'), isNull);

      Store.I.kvSetToggle('test.saved', 'w1');
      Store.I.kvSetToggle('test.saved', 'w2');
      expect(Store.I.kvSet('test.saved'), <String>{'w1', 'w2'});
      Store.I.kvSetToggle('test.saved', 'w1');
      expect(Store.I.kvSetHas('test.saved', 'w1'), isFalse);
      expect(Store.I.kvSetHas('test.saved', 'w2'), isTrue);

      Store.I.kvListAdd('test.list', <String, dynamic>{'n': 1});
      Store.I.kvListAdd('test.list', <String, dynamic>{'n': 2});
      expect(Store.I.kvList('test.list').map((m) => m['n']).toList(), <int>[1, 2]);
    });

    test('kv is per account', () {
      signUpFresh();
      Store.I.setKv('test.private', 'mine');
      signUpFresh();
      expect(Store.I.kv<String>('test.private'), isNull);
    });

    test('tasks and notifications', () {
      signUpFresh();
      final today = DateTime.now();
      Store.I.addTask(<String, dynamic>{'title': 'B', 'date': Store.dateKey(today), 'time': '19:30'});
      Store.I.addTask(<String, dynamic>{'title': 'A', 'date': Store.dateKey(today), 'time': '08:00'});
      final list = Store.I.tasksOn(today);
      expect(list.map((t) => t['title']).toList(), <String>['A', 'B']);
      final id = list.first['id'] as String;
      Store.I.toggleTask(id);
      expect(Store.I.tasksOn(today).first['done'], isTrue);
      Store.I.removeTask(id);
      expect(Store.I.tasksOn(today).length, 1);

      Store.I.addNotification(<String, dynamic>{'type': 'system', 'title': 'Hi'});
      expect(Store.I.unreadNotifications, 2);
      Store.I.markNotificationRead(Store.I.notifications.first['id'] as String);
      expect(Store.I.unreadNotifications, 1);
      Store.I.markAllNotificationsRead();
      expect(Store.I.unreadNotifications, 0);
    });

    test('resetProgress empties a normal account', () async {
      signUpFresh();
      Store.I.addAttempt(attempt(Skill.listening, 7.0));
      await Store.I.resetProgress();
      expect(Store.I.attempts, isEmpty);
      expect(Store.I.skillBand(Skill.listening), isNull);
    });
  });

  group('phone & password helpers', () {
    test('normalizePhone', () {
      expect(Store.normalizePhone('01734519208'), '1734519208');
      expect(Store.normalizePhone('01734-519208'), '1734519208');
      expect(Store.normalizePhone('+8801734519208'), '1734519208');
      expect(Store.normalizePhone('+880 1734 519208'), '1734519208');
      expect(Store.normalizePhone('8801734519208'), '1734519208');
      expect(Store.normalizePhone('1734 519208'), '1734519208');
      expect(Store.normalizePhone('(017) 3451-9208'), '1734519208');
      expect(Store.normalizePhone(''), '');
      expect(Store.normalizePhone('abc'), '');
    });

    test('isValidPhone', () {
      for (final ok in <String>[
        '01734519208',
        '+8801734519208',
        '1734519208',
        '01334519208',
        '01934519208',
        '017 3451 9208',
      ]) {
        expect(Store.isValidPhone(ok), isTrue, reason: ok);
      }
      for (final bad in <String>[
        '',
        'abc',
        '0173451920', // 9 digits
        '017345192089', // 11 digits
        '01234519208', // operator digit 2
        '01034519208', // operator digit 0
        '02734519208', // landline
        '+4407734519208',
      ]) {
        expect(Store.isValidPhone(bad), isFalse, reason: bad);
      }
    });

    test('isStrongPassword / passwordStrength', () {
      expect(Store.isStrongPassword('Demo@1234'), isTrue);
      expect(Store.isStrongPassword('abc@1234'), isTrue);
      expect(Store.isStrongPassword('password'), isFalse);
      expect(Store.isStrongPassword('Pass1234'), isFalse); // no symbol
      expect(Store.isStrongPassword('Pass@word'), isFalse); // no number
      expect(Store.isStrongPassword('Pa@1'), isFalse); // too short
      expect(Store.passwordStrength(''), 0);
      expect(Store.passwordStrength('abcdefgh'), 1);
      expect(Store.passwordStrength('Demo@1234'), 3);
      expect(Store.passwordStrength('Demo@12345'), 4);
    });

    test('authMessage covers every result', () {
      for (final r in AuthResult.values) {
        final m = Store.authMessage(r);
        if (r == AuthResult.ok) {
          expect(m, isEmpty);
        } else {
          expect(m, isNotEmpty, reason: '$r');
        }
      }
      expect(Store.authMessage(AuthResult.invalidOtp), contains(kDemoOtp));
    });
  });

  group('formatting utils', () {
    test('dateKey', () {
      expect(Store.dateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(Store.dateKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });
    test('relativeDay / shortDate / weekdayDate', () {
      final now = DateTime.now();
      expect(Store.relativeDay(now), 'Today');
      expect(Store.relativeDay(DateUtils.dateOnly(now).subtract(const Duration(days: 1))), 'Yesterday');
      expect(Store.shortDate(DateTime(2026, 9, 21)), '21 Sep');
      expect(Store.weekdayDate(DateTime(2026, 11, 14)), 'Sat 14 Nov');
    });
    test('timeAgo', () {
      final now = DateTime.now();
      expect(Store.timeAgo(now), 'Just now');
      expect(Store.timeAgo(now.subtract(const Duration(minutes: 5))), '5 min ago');
      expect(Store.timeAgo(now.subtract(const Duration(hours: 3))), '3 h ago');
    });
    test('hoursMinutes / greeting', () {
      expect(Store.hoursMinutes(135), (2, 15));
      expect(Store.hoursMinutes(0), (0, 0));
      expect(Store.greeting(DateTime(2026, 1, 1, 9)), 'Good morning');
      expect(Store.greeting(DateTime(2026, 1, 1, 13)), 'Good afternoon');
      expect(Store.greeting(DateTime(2026, 1, 1, 19)), 'Good evening');
    });
  });
}
