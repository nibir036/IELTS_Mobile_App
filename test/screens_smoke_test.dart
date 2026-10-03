// Smoke test: pumps every screen inside the real app shell (IeltsAiApp →
// MaterialApp with the app's own onGenerateRoute) in Day and Night, at two
// phone sizes, and collects every error per screen instead of stopping at
// the first one.
//
// • Signed in as the demo student for the full pass; a second pass renders
//   key screens for a brand-new (empty) account; a third renders the public
//   access screens signed out; a fourth opens some screens with real route
//   args from the content bank.
// • Plugin noise (MissingPluginException / PlatformException from record,
//   just_audio, audio_session, image_picker, share_plus, path_provider) and
//   google_fonts loading errors are ignored. RenderFlex overflows and every
//   other exception are kept.
// • Each case is its own testWidgets, so a Timer left running after the
//   screen is disposed fails THAT case ("A Timer is still pending even after
//   the widget tree was disposed") — that is a real bug in the screen.
// • The last test fails with the full list: screen · theme · size · first
//   error line(s).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexted_ielts_app/app/app.dart';
import 'package:nexted_ielts_app/app/data/demo.dart';
import 'package:nexted_ielts_app/app/data/store.dart';
import 'package:nexted_ielts_app/app/routes.dart';
import 'package:nexted_ielts_app/app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String demoPhone = '01734519208';
const String demoPassword = 'Demo@1234';
const String blankPhone = '01911000001';
const String blankPassword = 'Blank@1234';

enum Who { demo, blank, signedOut }

class SmokeCase {
  const SmokeCase({
    required this.route,
    required this.label,
    required this.night,
    required this.size,
    this.who = Who.demo,
    this.args,
  });

  final String route;
  final String label;
  final bool night;
  final Size size;
  final Who who;
  final Map<String, dynamic>? args;

  String get name {
    final theme = night ? 'night' : 'day';
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    final user = switch (who) {
      Who.demo => 'demo',
      Who.blank => 'NEW account',
      Who.signedOut => 'signed out',
    };
    final a = args == null ? '' : ' args=$args';
    return '$label $route [$theme $s · $user]$a';
  }
}

const List<Size> kSizes = <Size>[Size(360, 740), Size(412, 915)];

/// The extra (non-canvas) routes built in Phase 3/4.
const Map<String, String> kExtraRoutes = <String, String>{
  Routes.phrasalVerbs: 'X-phrasal',
  Routes.idioms: 'X-idioms',
  Routes.topicVocab: 'X-topicVocab',
  Routes.certificates: 'X-certificates',
  Routes.legal: 'X-legal',
  Routes.diagnosticTest: 'X-diagnosticTest',
  Routes.diagnosticResult: 'X-diagnosticResult',
  Routes.mockAnswers: 'X-mockAnswers',
  Routes.plans: 'X-plans',
  Routes.readingBank: 'X-readingBank',
  Routes.readingType: 'X-readingType',
  Routes.readingTypeLesson: 'X-readingTypeLesson',
  Routes.readingPracticeTests: 'X-readingPracticeTests',
  Routes.readingGuide: 'X-readingGuide',
  Routes.writingGuide: 'X-writingGuide',
  Routes.speakingGuide: 'X-speakingGuide',
  Routes.grammarGuide: 'X-grammarGuide',
  Routes.listeningGuide: 'X-listeningGuide',
  Routes.vocabGuide: 'X-vocabGuide',
  Routes.writingTests: 'X-writingTests',
  Routes.speakingTests: 'X-speakingTests',
  Routes.writingQuestions: 'X-writingQuestions',
  Routes.speakingQuestions: 'X-speakingQuestions',
};

/// Screens that show user data: rendered again for a brand-new account.
const Map<String, String> kBlankRoutes = <String, String>{
  Routes.dashboard: 'B1',
  Routes.dashboardEmpty: 'B2',
  Routes.analytics: 'B4',
  Routes.moduleHub: 'B3',
  Routes.schedule: 'B5',
  Routes.notifications: 'B6',
  Routes.profile: 'B7',
  Routes.search: 'B8',
  Routes.mockLibrary: 'G1',
  Routes.certificates: 'X-certificates',
  Routes.essayHistory: 'C9',
  Routes.myRecordings: 'D10',
  Routes.writingBandReport: 'C5',
  Routes.speakingEvaluation: 'D6',
  Routes.readingSolution: 'E4',
  Routes.listeningResults: 'F8',
  Routes.mockResults: 'G9',
  Routes.improvementPlan: 'G10',
  Routes.mockAnswers: 'X-mockAnswers',
  Routes.vocabQuizScore: 'H6',
  Routes.diagnosticResult: 'X-diagnosticResult',
  Routes.plans: 'X-plans',
};

/// Public screens, rendered signed out.
const Map<String, String> kPublicRoutes = <String, String>{
  Routes.splash: 'A1',
  Routes.login: 'A2',
  Routes.signup: 'A3',
  Routes.otp: 'A4',
  Routes.resetPassword: 'A5',
  Routes.legal: 'X-legal',
};

/// Screens opened with real ids from the content bank.
final List<(String, String, Map<String, dynamic>)> kArgRoutes = <(String, String, Map<String, dynamic>)>[
  (Routes.legal, 'X-legal', <String, dynamic>{'doc': 'privacy'}),
  (Routes.writingQuestions, 'X-writingQuestions', <String, dynamic>{'task': 2}),
  (Routes.speakingQuestions, 'X-speakingQuestions', <String, dynamic>{'part': 2}),
  (Routes.speakingQuestions, 'X-speakingQuestions', <String, dynamic>{'part': 3}),
  (Routes.cueCardVault, 'D8', <String, dynamic>{'part': 1}),
  (Routes.cueCardVault, 'D8', <String, dynamic>{'part': 3}),
  (Routes.speakingPart13, 'D2', <String, dynamic>{'part': 3, 'part3TopicId': 'sp3_people_01'}),
  (Routes.listeningPlayer, 'F2', <String, dynamic>{'setId': 'ls_01'}),
  (Routes.listeningAnswerSheet, 'F3', <String, dynamic>{'testId': 'lt_01', 'fresh': true}),
  (Routes.listeningTranscript, 'F4', <String, dynamic>{'testId': 'lt_02', 'part': 2}),
  (Routes.listeningLesson, 'F6', <String, dynamic>{'lessonId': 'll_07'}),
  (Routes.readingPassage, 'E2', <String, dynamic>{'testId': 'rt_02'}),
  (Routes.readingLesson, 'E6', <String, dynamic>{'lessonId': 'rl_04'}),
  (Routes.cueCard, 'D3', <String, dynamic>{'cardId': 'cc14'}),
  (Routes.speakingPart13, 'D2', <String, dynamic>{'mock': true}),
  (Routes.mockSystemCheck, 'G2', <String, dynamic>{'mockId': 'mt_b'}),
  (Routes.mockSystemCheck, 'G2', <String, dynamic>{'mockId': 'mt_02'}),
  (Routes.listeningAnswerSheet, 'F3', <String, dynamic>{'testId': 'lt_w01', 'fresh': true}),
  (Routes.listeningTranscript, 'F4', <String, dynamic>{'testId': 'lt_w02', 'part': 2}),
  (Routes.readingPassage, 'E2', <String, dynamic>{'testId': 'rt_w03'}),
  (Routes.writingTask1Editor, 'C2', <String, dynamic>{'promptId': 'wt_03_t1'}),
  (Routes.cueCard, 'D3', <String, dynamic>{'cardId': 'st_02_cc'}),
  (Routes.speakingPart13, 'D2', <String, dynamic>{'part': 1, 'topicId': 'st_02_p1'}),
  (Routes.home, 'shell', <String, dynamic>{'tab': 3}),
  // Reading question bank: every exhibit / option layout.
  (Routes.readingType, 'X-readingType', <String, dynamic>{'type': 'diagram_label'}),
  (Routes.readingTypeLesson, 'X-readingTypeLesson', <String, dynamic>{'type': 'table_completion'}),
  (Routes.readingTypeLesson, 'X-readingTypeLesson', <String, dynamic>{'type': 'diagram_label'}),
  (Routes.readingPassage, 'E2', <String, dynamic>{'passageId': 'rb_matching_features_04'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_mcq_05'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_headings_07'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_matching_features_01'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_sentence_endings_01'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_summary_completion_01'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_note_completion_01'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_table_completion_01'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_flowchart_completion_07'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_flowchart_completion_03'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_diagram_label_05'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'passageId': 'rb_short_answer_01'}),
  (Routes.readingQuestions, 'E3', <String, dynamic>{'testId': 'rpt_01'}),
  // Listening question bank: every group type on the player and the sheet.
  for (final code in <String>['p1_fn', 'p3_mc', 'p1_ma', 'p4_pm', 'p2_sc', 'p2_tc', 'p1_sm', 'p4_sa'])
    (Routes.listeningPlayer, 'F2', <String, dynamic>{'setId': 'lb_$code', 'fresh': true}),
  for (final code in <String>['p1_fn', 'p3_mc', 'p3_ma', 'p1_pm', 'p4_tc', 'p3_sm', 'p2_sa'])
    (Routes.listeningAnswerSheet, 'F3', <String, dynamic>{'setId': 'lb_$code', 'fresh': true}),
  (Routes.listeningTranscript, 'F4', <String, dynamic>{'setId': 'lb_p1_fn'}),
  // Writing question bank: rendered visuals and Band 6 / 7 / 8 samples.
  (Routes.writingTask1Editor, 'C2', <String, dynamic>{'promptId': 'wb1_map_01'}),
  (Routes.writingEditor, 'C3', <String, dynamic>{'promptId': 'wb2_positive-negative_01'}),
  (Routes.writingSampleAnswer, 'C13', <String, dynamic>{'promptId': 'wb1_mixed_02'}),
  (Routes.writingSampleAnswer, 'C13', <String, dynamic>{'promptId': 'wb2_two-part_07'}),
  // Speaking question bank: samples, library tabs, bank sessions and words.
  (Routes.speakingSamples, 'D12', <String, dynamic>{'part': 1, 'topicId': 'sp1_hometown'}),
  (Routes.speakingSamples, 'D12', <String, dynamic>{'part': 2, 'cardId': 'sp2_people_01'}),
  (Routes.speakingSamples, 'D12', <String, dynamic>{'part': 3, 'topicId': 'sp3_society_03'}),
  for (final tab in <int>[1, 2, 3]) (Routes.speakingLibrary, 'D11', <String, dynamic>{'tab': tab}),
  (Routes.speakingPart13, 'D2', <String, dynamic>{'part': 1, 'topicId': 'sp1_music'}),
  (Routes.speakingPart13, 'D2', <String, dynamic>{'part': 3, 'part3TopicId': 'sp3_technology_02'}),
  (Routes.speakingPart13, 'D2', <String, dynamic>{'part': 3, 'cardId': 'sp2_places_08'}),
  (Routes.cueCard, 'D3', <String, dynamic>{'cardId': 'sp2_activities_40'}),
  (Routes.pronunciation, 'D7', <String, dynamic>{'vocab': <String>['tranquillity', 'packed to the rafters']}),
];

List<SmokeCase> buildCases() {
  final out = <SmokeCase>[];
  final routes = <String, String>{
    for (final s in ScreenCatalog.all) s.route: s.code,
    ...kExtraRoutes,
  };
  for (final e in routes.entries) {
    for (final night in <bool>[false, true]) {
      for (final size in kSizes) {
        out.add(SmokeCase(route: e.key, label: e.value, night: night, size: size));
      }
    }
  }
  for (final e in kBlankRoutes.entries) {
    for (final night in <bool>[false, true]) {
      for (final size in kSizes) {
        out.add(SmokeCase(route: e.key, label: e.value, night: night, size: size, who: Who.blank));
      }
    }
  }
  for (final e in kPublicRoutes.entries) {
    for (final night in <bool>[false, true]) {
      out.add(SmokeCase(route: e.key, label: e.value, night: night, size: kSizes.first, who: Who.signedOut));
    }
  }
  for (final (route, label, args) in kArgRoutes) {
    for (final night in <bool>[false, true]) {
      out.add(SmokeCase(route: route, label: label, night: night, size: kSizes.first, args: args));
    }
  }
  return out;
}

/// Plugin / font noise that only happens because tests have no platform.
bool isNoise(Object error, String text) {
  if (error is MissingPluginException) return true;
  if (error is PlatformException) return true;
  const needles = <String>[
    'MissingPluginException',
    'No implementation found for method',
    'google_fonts',
    'GoogleFonts',
    'allowRuntimeFetching',
    'Failed to load font',
    'com.ryanheise', // just_audio / audio_session
    'just_audio',
    'audio_session',
    'com.llfbandit.record',
    'plugins.flutter.io/path_provider',
    'plugins.flutter.io/image_picker',
    'dev.fluttercommunity.plus/share',
  ];
  for (final n in needles) {
    if (text.contains(n)) return true;
  }
  return false;
}

final RegExp _libLocation =
    RegExp(r'((?:lib/|package:nexted_ielts_app/)[A-Za-z0-9_/]+\.dart[: ]\d+(?::\d+)?)');

/// First line of the error plus where it points in lib/ (widget creation
/// location for overflows, first app frame for exceptions).
String describe(Object error, StackTrace? stack, FlutterErrorDetails? details) {
  String text;
  try {
    text = details != null ? details.exceptionAsString() : '$error';
  } catch (_) {
    text = '$error';
  }
  final first = text.trim().split('\n').first.trim();
  String full = '';
  try {
    full = details != null ? details.toString() : '';
  } catch (_) {
    full = '';
  }
  final where = _libLocation.firstMatch(full)?.group(1) ??
      _libLocation.firstMatch('${stack ?? details?.stack ?? ''}')?.group(1);
  return where == null ? first : '$first  @ $where';
}

final List<String> failures = <String>[];

Future<void> runCase(WidgetTester tester, SmokeCase c) async {
  tester.view.physicalSize = Size(c.size.width * 3, c.size.height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  switch (c.who) {
    case Who.demo:
      expect(Store.I.login(demoPhone, demoPassword), AuthResult.ok);
    case Who.blank:
      expect(Store.I.login(blankPhone, blankPassword), AuthResult.ok);
      expect(Store.I.attempts, isEmpty, reason: 'blank account got attempts');
    case Who.signedOut:
      Store.I.logout();
  }

  final errors = <String>[];
  void record(Object error, StackTrace? stack, [FlutterErrorDetails? details]) {
    String text;
    try {
      text = '$error\n${details?.toString() ?? ''}';
    } catch (_) {
      text = '$error';
    }
    if (isNoise(error, text)) return;
    errors.add(describe(error, stack, details));
  }

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) => record(d.exception, d.stack, d);

  final done = Completer<void>();
  // Plugins fail asynchronously (unawaited futures); catch those here so
  // they don't abort the test, and filter them like the rest.
  runZonedGuarded(() async {
    try {
      await tester.pumpWidget(IeltsAiApp(
        initialRoute: c.route,
        initialArguments: c.args,
        themeMode: c.night ? ThemeMode.dark : ThemeMode.light,
      ));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    } catch (e, st) {
      record(e, st);
    }
    try {
      // Dispose the screen, then let debounced saves (Store: 600 ms) run.
      await tester.pumpWidget(const SizedBox());
      // Let load timeouts (e.g. SimAudio's 15 s audio-load guard) expire;
      // fake time, so this is instant.
      await tester.pump(const Duration(seconds: 20));
    } catch (e, st) {
      record(e, st);
    }
    if (!done.isCompleted) done.complete();
  }, (Object e, StackTrace st) {
    // Async errors land here while the body keeps pumping; the body itself
    // completes [done] (all its awaits are inside try/catch).
    record(e, st);
  });
  await done.future;

  FlutterError.onError = previousOnError;

  if (errors.isNotEmpty) {
    final distinct = errors.toSet().toList();
    final shown = distinct.take(3).join('  |  ');
    final more = errors.length > 1 ? ' (${errors.length} errors)' : '';
    failures.add('${c.name}$more: $shown');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Must be set before AppTheme.day / night are first read.
  AppTheme.useGoogleFonts = false;
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Demo.load();
    await Store.I.load();
    // A brand-new student for the empty-state pass.
    Store.I.logout();
    final signup = Store.I.startSignup(name: 'New Student', phone: blankPhone, password: blankPassword);
    if (signup != AuthResult.ok) throw StateError('blank signup failed: $signup');
    final otp = Store.I.verifySignupOtp(kDemoOtp);
    if (otp != AuthResult.ok) throw StateError('blank OTP failed: $otp');
    Store.I.logout();
  });

  test('route list: 76 canvas screens + ${kExtraRoutes.length} extra routes', () {
    final routes = <String>{for (final s in ScreenCatalog.all) s.route, ...kExtraRoutes.keys};
    expect(routes.length, ScreenCatalog.all.length + kExtraRoutes.length);
    expect(ScreenCatalog.all.length, 76);
  });

  for (final c in buildCases()) {
    testWidgets(c.name, (WidgetTester tester) async {
      await runCase(tester, c);
    });
  }

  test('SUMMARY: every screen renders without errors', () {
    expect(
      failures,
      isEmpty,
      reason: '${failures.length} screen case(s) reported errors:\n${failures.join('\n')}',
    );
  });
}
