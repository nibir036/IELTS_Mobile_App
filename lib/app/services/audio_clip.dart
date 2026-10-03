import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'media.dart';

/// Placeholder listening audio bundled with the app (replace with the real
/// test audio from R2 later).
const String kListeningPlaceholderAsset = 'assets/audio/listening_placeholder.mp3';

/// A small ChangeNotifier around `just_audio` for screens: position,
/// duration, playing, speed. Rebuild with `ListenableBuilder(listenable: clip)`.
///
/// ```dart
/// final clip = AudioClip();
/// await clip.loadAsset(kListeningPlaceholderAsset);
/// clip.toggle();  clip.seekBy(10);  clip.setSpeed(1.25);
/// clip.dispose();
/// ```
class AudioClip extends ChangeNotifier {
  AudioClip() {
    _subs.add(_player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    }));
    _subs.add(_player.durationStream.listen((d) {
      if (d != null) _duration = d;
      notifyListeners();
    }));
    _subs.add(_player.playerStateStream.listen((s) {
      _playing = s.playing && s.processingState != ProcessingState.completed;
      if (s.processingState == ProcessingState.completed) {
        _completed = true;
        _player.pause();
      }
      notifyListeners();
    }));
  }

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _completed = false;
  bool _loaded = false;
  bool _disposed = false;
  String? error;

  Duration get position => _position;
  Duration get duration => _duration;
  bool get playing => _playing;
  bool get completed => _completed;
  bool get loaded => _loaded;
  double get speed => _player.speed;

  double get positionSec => _position.inMilliseconds / 1000.0;
  double get durationSec => _duration.inMilliseconds / 1000.0;

  /// 0..1
  double get progress {
    final d = _duration.inMilliseconds;
    if (d <= 0) return 0;
    return (_position.inMilliseconds / d).clamp(0.0, 1.0).toDouble();
  }

  Future<bool> _load(Future<Duration?> Function() loader) async {
    try {
      final d = await loader();
      if (d != null) _duration = d;
      _loaded = true;
      _completed = false;
      error = null;
    } catch (e) {
      _loaded = false;
      error = '$e';
    }
    if (!_disposed) notifyListeners();
    return _loaded;
  }

  /// A bundled asset, or — for listening audio kept in R2 — its download
  /// link (see [Media]).
  Future<bool> loadAsset(String asset) {
    final url = Media.url(asset);
    return _load(() => url == null ? _player.setAsset(asset) : _player.setUrl(url));
  }

  Future<bool> loadUrl(String url, {Map<String, String>? headers}) =>
      _load(() => _player.setUrl(url, headers: headers));

  /// A [Recording.path]: a file path on mobile/desktop, a blob URL on web.
  Future<bool> loadRecording(String path) => _load(() {
        if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
          return _player.setUrl(path);
        }
        return _player.setFilePath(path);
      });

  void play() {
    if (!_loaded) return;
    if (_completed) {
      _completed = false;
      _player.seek(Duration.zero);
    }
    _player.play();
  }

  void pause() => _player.pause();

  void toggle() => _playing ? pause() : play();

  Future<void> stop() async {
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  Future<void> seek(Duration to) async {
    var t = to;
    if (t < Duration.zero) t = Duration.zero;
    if (_duration > Duration.zero && t > _duration) t = _duration;
    _completed = false;
    await _player.seek(t);
  }

  /// Relative seek in seconds (±10 buttons).
  Future<void> seekBy(double seconds) =>
      seek(_position + Duration(milliseconds: (seconds * 1000).round()));

  /// Seek to a fraction 0..1 of the track.
  Future<void> seekFraction(double f) => seek(
        Duration(milliseconds: (_duration.inMilliseconds * f.clamp(0.0, 1.0)).round()),
      );

  Future<void> setSpeed(double s) async {
    await _player.setSpeed(s);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
