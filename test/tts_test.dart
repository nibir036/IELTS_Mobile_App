import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/services/tts.dart';
import 'package:nexted_ielts_app/app/widgets/speak_button.dart';

void main() {
  test('dictionary entries are read naturally', () {
    expect(Tts.spoken('ubiquitous'), 'ubiquitous');
    expect(Tts.spoken('be, was/were, been'), 'be, was, were, been');
    expect(Tts.spoken('look up (sth)'), 'look up something');
    expect(Tts.spoken('take sb on'), 'take somebody on');
    expect(Tts.spoken('  '), '');
  });

  testWidgets('speak button plays and stops without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SpeakButton(text: 'cohesion')))));
    await tester.tap(find.byType(SpeakButton));
    await tester.pump();
    // No real speech engine in tests: whatever the engine does, nothing throws
    // and the button can always be stopped.
    expect(tester.takeException(), isNull);
    await Tts.I.stop();
    await tester.pump();
    expect(Tts.I.speaking.value, isNull);
    expect(tester.takeException(), isNull);
  });
}
