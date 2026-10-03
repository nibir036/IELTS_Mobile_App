// Writing question list (/writing/questions): tapping a question opens the
// editor on THAT question, for Task 1 and Task 2.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexted_ielts_app/app/app.dart';
import 'package:nexted_ielts_app/app/data/demo.dart';
import 'package:nexted_ielts_app/app/data/store.dart';
import 'package:nexted_ielts_app/app/routes.dart';
import 'package:nexted_ielts_app/features/writing/writing_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Demo.load();
    await Store.I.load();
    expect(Store.I.login('01734519208', 'Demo@1234'), AuthResult.ok);
  });

  Future<void> openFromList(WidgetTester tester, int task, int index) async {
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final prompts = WritingContent.prompts(task: task);
    final want = prompts[index];
    await tester.pumpWidget(IeltsAiApp(
      initialRoute: Routes.writingQuestions,
      initialArguments: <String, dynamic>{'task': task},
      themeMode: ThemeMode.light,
    ));
    await tester.pump(const Duration(milliseconds: 500));
    final row = find.text(want.s('title'));
    expect(row, findsWidgets, reason: 'row for ${want.s('id')}');
    await tester.tap(row.first);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // The editor shows the chosen question's prompt, not the first one.
    expect(find.textContaining(want.s('prompt').substring(0, 40)), findsWidgets,
        reason: 'editor did not open ${want.s('id')}');
    if (index > 0) {
      expect(find.textContaining(prompts.first.s('prompt').substring(0, 40)), findsNothing,
          reason: 'editor opened the first question instead of ${want.s('id')}');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('Task 1: third question opens itself', (tester) => openFromList(tester, 1, 2));
  testWidgets('Task 2: third question opens itself', (tester) => openFromList(tester, 2, 2));
}
