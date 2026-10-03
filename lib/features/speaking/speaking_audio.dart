import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/data/demo.dart';
import '../../app/services/api_client.dart';
import '../../app/services/audio_clip.dart';
import '../../app/services/config.dart';

/// Plays an attempt's recordings (`data.audio: [{path, key, durationSec}]`)
/// back to back as one track: this device's file first, then the uploaded
/// copy (R2 key) when the backend is configured. With nothing playable it
/// falls back to a simulated timer of [fallbackSec] seconds.
class AnswerPlayer extends ChangeNotifier {
  AnswerPlayer(List<Map<String, dynamic>> audio, {required int fallbackSec})
      : _fallbackSec = fallbackSec <= 0 ? 1 : fallbackSec {
    for (final a in audio) {
      final path = a.s('path');
      final key = a.s('key');
      if (path.isEmpty && key.isEmpty) continue;
      _srcs.add(_Src(path, key, a.i('durationSec')));
    }
    _real = _srcs.isNotEmpty;
    _clip.addListener(_onClip);
  }

  final AudioClip _clip = AudioClip();
  final List<_Src> _srcs = <_Src>[];
  final int _fallbackSec;
  bool _real = false;
  int _cur = -1;
  bool _loading = false;
  bool _advancing = false;
  bool _disposed = false;
  Timer? _sim;
  double _simPos = 0;

  /// True while real audio is used (false = simulated playback).
  bool get isReal => _real;

  double get durationSec {
    if (!_real) return _fallbackSec.toDouble();
    var total = 0.0;
    for (var i = 0; i < _srcs.length; i++) {
      total += _lenOf(i);
    }
    return total <= 0 ? 1 : total;
  }

  double get positionSec {
    if (!_real) return _simPos;
    if (_cur < 0) return 0;
    var p = 0.0;
    for (var i = 0; i < _cur; i++) {
      p += _lenOf(i);
    }
    return p + _clip.positionSec;
  }

  double get progress {
    final d = durationSec;
    if (d <= 0) return 0;
    return (positionSec / d).clamp(0.0, 1.0).toDouble();
  }

  bool get playing => _real ? (_clip.playing || _loading || _advancing) : _sim != null;

  double _lenOf(int i) {
    if (i == _cur && _clip.durationSec > 0) return _clip.durationSec;
    final s = _srcs[i];
    return s.durationSec > 0 ? s.durationSec.toDouble() : 0;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onClip() {
    if (_disposed) return;
    if (_clip.completed && !_advancing && _cur >= 0 && _cur < _srcs.length - 1) {
      _advancing = true;
      final next = _cur + 1;
      _load(next).then((ok) {
        _advancing = false;
        if (_disposed) return;
        if (ok) _clip.play();
        _notify();
      });
    }
    _notify();
  }

  Future<bool> _load(int i) async {
    if (i < 0 || i >= _srcs.length) return false;
    final s = _srcs[i];
    var ok = false;
    if (s.path.isNotEmpty) ok = await _clip.loadRecording(s.path);
    if (!ok && s.key.isNotEmpty && AppConfig.hasApi) {
      ok = await _clip.loadUrl(ApiClient.uploadUrl(s.key), headers: ApiClient.headers);
    }
    if (ok) _cur = i;
    return ok;
  }

  /// Loads the first playable source (or switches to simulated playback).
  Future<bool> _ensureLoaded() async {
    if (!_real) return false;
    if (_cur >= 0) return true;
    _loading = true;
    _notify();
    var ok = false;
    for (var i = 0; i < _srcs.length && !ok; i++) {
      ok = await _load(i);
    }
    _loading = false;
    if (!ok) _real = false;
    _notify();
    return ok;
  }

  Future<void> toggle() async {
    if (_real) {
      if (_clip.playing) {
        _clip.pause();
        return;
      }
      final ok = await _ensureLoaded();
      if (_disposed) return;
      if (ok) {
        if (_clip.completed && _cur == _srcs.length - 1 && _srcs.length > 1) {
          await _load(0);
        }
        _clip.play();
        return;
      }
    }
    _toggleSim();
  }

  void pause() {
    if (_real) {
      _clip.pause();
    } else {
      _sim?.cancel();
      _sim = null;
      _notify();
    }
  }

  void _toggleSim() {
    if (_sim != null) {
      _sim?.cancel();
      _sim = null;
      _notify();
      return;
    }
    if (_simPos >= _fallbackSec) _simPos = 0;
    _sim = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      _simPos += 0.25;
      if (_simPos >= _fallbackSec) {
        _simPos = _fallbackSec.toDouble();
        timer.cancel();
        _sim = null;
      }
      _notify();
    });
    _notify();
  }

  /// Seek to a fraction 0..1 of the whole answer.
  Future<void> seekFraction(double f) async {
    final target = durationSec * f.clamp(0.0, 1.0);
    if (!_real) {
      _simPos = target;
      _notify();
      return;
    }
    final ok = await _ensureLoaded();
    if (_disposed) return;
    if (!ok) {
      _simPos = target;
      _notify();
      return;
    }
    var offset = 0.0;
    var idx = _srcs.length - 1;
    for (var i = 0; i < _srcs.length; i++) {
      final len = _lenOf(i);
      if (target < offset + len || i == _srcs.length - 1) {
        idx = i;
        break;
      }
      offset += len;
    }
    final wasPlaying = _clip.playing;
    if (idx != _cur) {
      final loaded = await _load(idx);
      if (_disposed || !loaded) return;
    }
    await _clip.seek(Duration(milliseconds: ((target - offset) * 1000).round()));
    if (wasPlaying && !_clip.playing) _clip.play();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _sim?.cancel();
    _clip.removeListener(_onClip);
    _clip.dispose();
    super.dispose();
  }
}

class _Src {
  _Src(this.path, this.key, this.durationSec);
  final String path;
  final String key;
  final int durationSec;
}
