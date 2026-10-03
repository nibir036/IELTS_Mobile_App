import 'dart:async';
import 'dart:js_interop';

/// Web speech engine: the browser's `speechSynthesis`, used directly.
///
/// Written against the browser API (not flutter_tts's web plugin) because of
/// how Chrome/Edge behave, which made words cut off:
/// * `speak()` right after `cancel()` can be cancelled too, so after a
///   cancel we wait a moment before speaking;
/// * one utterance object reused for every word gets the previous word's late
///   "end"/"interrupted" events, so each word gets a fresh utterance, and
///   events from an older one are ignored;
/// * an utterance with no live Dart reference can be garbage-collected while
///   it is speaking (audio stops mid-word), so the current one is kept;
/// * the online "Natural" voices clip the tail of a bare word, so the text
///   ends with a full stop (natural falling tone, full final syllable).
class TtsEngine {
  TtsEngine() {
    // Ask early so the voice list is ready by the first tap.
    try {
      _synth?.getVoices();
    } catch (_) {}
  }

  _Utterance? _current;
  _Voice? _voice;
  int _turn = 0;

  static _Synth? get _synth {
    try {
      return _speechSynthesis;
    } catch (_) {
      return null;
    }
  }

  /// A British English voice if the browser has one, else any English voice:
  /// Edge's "Natural" voices first (closest to a real speaker), then installed
  /// ones, then other online ones. Voices load lazily in Chrome/Edge (the list
  /// is empty at first), so this is retried until one is found.
  _Voice? _pickVoice(_Synth synth) {
    if (_voice != null) return _voice;
    final voices = synth.getVoices().toDart;
    int rank(_Voice v) {
      final lang = v.lang.replaceAll('_', '-').toLowerCase();
      if (!lang.startsWith('en')) return 99;
      final kind = v.name.contains('Natural') ? 0 : (v.localService ? 1 : 2);
      return (lang == 'en-gb' ? 0 : 10) + kind;
    }

    _Voice? best;
    for (final v in voices) {
      if (rank(v) < 99 && (best == null || rank(v) < rank(best))) best = v;
    }
    return _voice = best;
  }

  static String _withStop(String text) => RegExp(r'[.!?]$').hasMatch(text) ? text : '$text.';

  Future<bool> speak(String text, {required double rate, required void Function() onDone}) async {
    final synth = _synth;
    if (synth == null) return false;
    final turn = ++_turn;
    if (synth.speaking || synth.pending) {
      _current = null;
      synth.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (turn != _turn) return true; // a newer word was tapped meanwhile
    }
    if (synth.paused) synth.resume();
    final u = _Utterance(_withStop(text));
    final voice = _pickVoice(synth);
    if (voice != null) {
      u.voice = voice;
      u.lang = voice.lang;
    } else {
      u.lang = 'en-GB';
    }
    u.rate = rate;
    u.pitch = 1;
    u.volume = 1;
    void end(JSAny? _) {
      if (identical(_current, u)) {
        _current = null;
        onDone();
      }
    }

    u.onend = end.toJS;
    u.onerror = end.toJS;
    _current = u;
    synth.speak(u);
    return true;
  }

  Future<void> stop() async {
    _current = null;
    _turn++;
    final synth = _synth;
    if (synth != null && (synth.speaking || synth.pending)) synth.cancel();
  }
}

@JS('speechSynthesis')
external _Synth get _speechSynthesis;

extension type _Synth._(JSObject _) implements JSObject {
  external void speak(_Utterance u);
  external void cancel();
  external void resume();
  external bool get speaking;
  external bool get pending;
  external bool get paused;
  external JSArray<_Voice> getVoices();
}

@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external _Utterance(String text);
  external set lang(String v);
  external set rate(double v);
  external set pitch(double v);
  external set volume(double v);
  external set voice(_Voice? v);
  external set onend(JSFunction? f);
  external set onerror(JSFunction? f);
}

extension type _Voice._(JSObject _) implements JSObject {
  external String get lang;
  external String get name;
  external bool get localService;
}
