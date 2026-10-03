import 'package:flutter/foundation.dart';

import 'tts_engine_io.dart' if (dart.library.js_interop) 'tts_engine_web.dart';

/// Text-to-speech for word pronunciations (the device's own voices: the
/// browser's speech synthesis on web, the system TTS engine on Android, iOS
/// and Windows). British English when the device has it, else any English.
///
/// `Tts.I.speak('ubiquitous')` reads a word aloud; [speaking] holds the text
/// being read (null when silent) so buttons can show a playing state. Every
/// call is safe to make when no engine is available (tests, a device without
/// voices): it simply does nothing.
class Tts {
  Tts._();

  static final Tts I = Tts._();

  /// The text being read aloud, or null.
  final ValueNotifier<String?> speaking = ValueNotifier<String?>(null);

  TtsEngine? _engine;

  /// Normal speaking rate differs by platform (web 1.0, mobile 0.5); a
  /// little slower than normal so learners hear each syllable.
  static double get _rate => kIsWeb ? 0.85 : 0.42;

  /// What the engine should say for a dictionary-style entry:
  /// "was/were" → "was, were", "look up (sth)" → "look up something".
  @visibleForTesting
  static String spoken(String text) => text
      .replaceAll(RegExp(r'\bsth\b'), 'something')
      .replaceAll(RegExp(r'\bsb\b'), 'somebody')
      .replaceAll('/', ', ')
      .replaceAll(RegExp(r'[()\[\]*_]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Reads [text] aloud from the start (tapping again while it plays replays
  /// it rather than stopping it, so a quick second tap never cuts a word off).
  Future<void> speak(String text) async {
    final say = spoken(text);
    if (say.isEmpty) return;
    speaking.value = text;
    bool ok;
    try {
      ok = await (_engine ??= TtsEngine()).speak(say, rate: _rate, onDone: () {
        if (speaking.value == text) speaking.value = null;
      });
    } catch (_) {
      ok = false;
    }
    if (!ok && speaking.value == text) speaking.value = null;
  }

  Future<void> stop() async {
    speaking.value = null;
    try {
      await _engine?.stop();
    } catch (_) {}
  }
}
