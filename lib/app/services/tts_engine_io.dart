import 'package:flutter_tts/flutter_tts.dart';

/// Device speech engine (Android, iOS, Windows, macOS) through flutter_tts.
///
/// The engine is only stopped when something is still being read (stopping an
/// idle engine and speaking straight away can swallow the start of the next
/// word on some engines), and a finish/cancel event that arrives for an older
/// word is ignored.
class TtsEngine {
  FlutterTts? _tts;
  Future<bool>? _ready;
  bool _busy = false;
  int _turn = 0;
  void Function()? _onDone;

  Future<bool> _init(double rate) async {
    try {
      final tts = FlutterTts();
      void done() {
        _busy = false;
        final cb = _onDone;
        _onDone = null;
        cb?.call();
      }

      tts.setCompletionHandler(done);
      tts.setCancelHandler(done);
      tts.setErrorHandler((_) => done());
      final gb = await _try(() => tts.isLanguageAvailable('en-GB'));
      await _try(() => tts.setLanguage(gb == false ? 'en-US' : 'en-GB'));
      await _try(() => tts.setSpeechRate(rate));
      await _try(() => tts.setPitch(1.0));
      await _try(() => tts.setVolume(1.0));
      _tts = tts;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Object?> _try(Future<dynamic> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  Future<bool> speak(String text, {required double rate, required void Function() onDone}) async {
    if (!await (_ready ??= _init(rate))) return false;
    final tts = _tts!;
    final turn = ++_turn;
    if (_busy) {
      _onDone = null; // the old word's cancel event must not end this one
      await _try(tts.stop);
      if (turn != _turn) return true;
    }
    _onDone = onDone;
    _busy = true;
    try {
      await tts.speak(text.endsWith('.') ? text : '$text.');
      return true;
    } catch (_) {
      _busy = false;
      _onDone = null;
      return false;
    }
  }

  Future<void> stop() async {
    _onDone = null;
    _turn++;
    if (!_busy) return;
    _busy = false;
    await _try(() => _tts?.stop() ?? Future<void>.value());
  }
}
