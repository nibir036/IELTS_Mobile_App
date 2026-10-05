import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/services/audio_clip.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Listening audio: real playback of a bundled asset through AudioClip
// (seconds-based adapter). Falls back to a Timer-driven simulation when the
// audio can't be loaded (unsupported platform, missing file).
// ─────────────────────────────────────────────────────────────────────────────

class SimAudio {
  /// [asset] is the bundled mp3 (a set's `Content.setAudio(set)`); [duration]
  /// is only used by the fallback simulation - real playback takes its
  /// duration from the file.
  SimAudio({
    required double duration,
    double start = 0,
    required this.onTick,
    String asset = kListeningPlaceholderAsset,
  })  : _simDuration = duration > 0 ? duration : 60,
        _simPos = start < 0 ? 0.0 : start {
    try {
      final c = AudioClip();
      c.addListener(_onClip);
      _clip = c;
    } catch (_) {
      _clip = null;
    }
    _load(asset.isEmpty ? kListeningPlaceholderAsset : asset);
  }

  final VoidCallback onTick;
  AudioClip? _clip;
  final double _simDuration;
  double _simPos;
  double _speed = 1.0;
  bool _wantPlay = false;
  bool _real = false;
  bool _sim = false;
  bool _simPlaying = false;
  bool _disposed = false;
  Timer? _timer;
  double? _seekPos;
  DateTime _seekAt = DateTime.now();
  final Completer<void> _ready = Completer<void>();

  /// True while the audio file is loading (show a loading state).
  bool get loading => !_real && !_sim;

  /// Ready to play (real audio or the fallback simulation).
  bool get loaded => _real || _sim;

  /// True when playing the timer simulation (audio failed to load).
  bool get simulated => _sim;

  /// Completes once loading finished (successfully or not).
  Future<void> get ready => _ready.future;

  double get duration {
    if (_real) {
      final d = _clip!.durationSec;
      return d > 0 ? d : _simDuration;
    }
    if (_sim) return _simDuration;
    return 0;
  }

  double get position {
    if (_real) {
      final pending = _seekPos;
      final actual = _clip!.positionSec;
      if (pending != null) {
        final settled = (actual - pending).abs() < 0.6 ||
            DateTime.now().difference(_seekAt).inMilliseconds > 1200;
        if (!settled) return pending;
        _seekPos = null;
      }
      final d = duration;
      return actual > d ? d : actual;
    }
    return _simPos;
  }

  set position(double v) => seek(v);

  double get progress {
    final d = duration;
    if (d <= 0) return 0;
    final v = position / d;
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  bool get playing {
    if (_real) return _clip!.playing;
    if (_sim) return _simPlaying;
    return false;
  }

  /// Reached the end of the audio (and stopped).
  bool get completed {
    if (_real) return _clip!.completed;
    if (_sim) return !_simPlaying && _simPos >= _simDuration && _simDuration > 0;
    return false;
  }

  double get speed => _speed;

  set speed(double v) {
    _speed = v;
    if (_real) _clip!.setSpeed(v);
  }

  Future<void> _load(String asset) async {
    // Never notify synchronously from the constructor (initState).
    await Future<void>.delayed(Duration.zero);
    var ok = false;
    final clip = _clip;
    if (clip != null && !_disposed) {
      ok = await clip
          .loadAsset(asset)
          .timeout(const Duration(seconds: 15), onTimeout: () => false);
    }
    if (_disposed) return;
    if (ok && clip != null) {
      _real = true;
      if (_speed != 1.0) await clip.setSpeed(_speed);
      if (_disposed) return;
      if (_simPos > 0) {
        final d = duration;
        final to = d > 0 && _simPos > d ? d : _simPos;
        _seekPos = to;
        _seekAt = DateTime.now();
        await clip.seek(Duration(milliseconds: (to * 1000).round()));
        if (_disposed) return;
      }
      if (_wantPlay) clip.play();
    } else {
      _sim = true;
      if (_simPos > _simDuration) _simPos = _simDuration;
      if (_wantPlay) _startSim();
    }
    if (!_ready.isCompleted) _ready.complete();
    onTick();
  }

  void _onClip() {
    if (_disposed || !_real) return;
    onTick();
  }

  void _startSim() {
    if (_simPlaying) return;
    if (_simPos >= _simDuration) _simPos = 0;
    _simPlaying = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _simPos += 0.25 * _speed;
      if (_simPos >= _simDuration) {
        _simPos = _simDuration;
        _simPlaying = false;
        _timer?.cancel();
        _timer = null;
      }
      if (!_disposed) onTick();
    });
  }

  /// Starts playback (queued until the audio has loaded). Pass
  /// `notify: false` from `initState`.
  void play({bool notify = true}) {
    if (_disposed) return;
    _wantPlay = true;
    if (_real) {
      if (!_clip!.playing) _clip!.play();
      return;
    }
    if (_sim) {
      _startSim();
      if (notify) onTick();
    }
  }

  void pause() {
    _wantPlay = false;
    if (_real) {
      _clip!.pause();
      return;
    }
    if (_sim) {
      _simPlaying = false;
      _timer?.cancel();
      _timer = null;
      if (!_disposed) onTick();
    }
  }

  void toggle() {
    if (playing) {
      pause();
    } else {
      play();
    }
  }

  void seek(double to) {
    if (_disposed) return;
    var t = to < 0 ? 0.0 : to;
    if (_real) {
      final d = duration;
      if (d > 0 && t > d) t = d;
      _seekPos = t;
      _seekAt = DateTime.now();
      _clip!.seek(Duration(milliseconds: (t * 1000).round()));
      onTick();
      return;
    }
    if (_sim && t > _simDuration) t = _simDuration;
    _simPos = t;
    if (_sim) onTick();
  }

  void skip(double delta) => seek(position + delta);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    final c = _clip;
    _clip = null;
    _real = false;
    if (c != null) {
      c.removeListener(_onClip);
      c.dispose();
    }
    if (!_ready.isCompleted) _ready.complete();
  }
}
