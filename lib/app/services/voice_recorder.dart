import 'dart:async';
import 'dart:math' as math;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A finished microphone recording.
class Recording {
  Recording({
    required this.path,
    required this.durationMs,
    required this.format,
    this.bytes,
  });

  /// File path (mobile/desktop) or blob URL (web). Playable with
  /// [AudioClip.loadRecording].
  final String path;
  final int durationMs;

  /// 'wav' (default) - what the backend expects.
  final String format;
  final Uint8List? bytes;

  int get durationSec => (durationMs / 1000).round();
}

/// Wraps the `record` plugin: permission, start/pause/stop, live level.
///
/// ```dart
/// final rec = VoiceRecorder();
/// if (await rec.start()) { ... }        // false = no mic permission
/// rec.level  // ValueListenable<double> 0..1 for waveform bars
/// final r = await rec.stop();           // Recording? with bytes
/// rec.dispose();
/// ```
class VoiceRecorder {
  VoiceRecorder();

  final AudioRecorder _rec = AudioRecorder();
  final ValueNotifier<double> level = ValueNotifier<double>(0);
  final ValueNotifier<bool> recording = ValueNotifier<bool>(false);
  StreamSubscription<Amplitude>? _ampSub;
  final Stopwatch _watch = Stopwatch();
  bool _paused = false;

  bool get isPaused => _paused;
  Duration get elapsed => _watch.elapsed;

  /// Asks for microphone permission (shows the OS prompt the first time).
  static Future<bool> requestPermission() async {
    final r = AudioRecorder();
    try {
      return await r.hasPermission();
    } catch (_) {
      return false;
    } finally {
      await r.dispose();
    }
  }

  /// Starts recording 16 kHz mono WAV. Returns false if the mic is not
  /// available or permission was denied.
  Future<bool> start() async {
    try {
      if (!await _rec.hasPermission()) return false;
      var path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      }
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _paused = false;
      _watch
        ..reset()
        ..start();
      recording.value = true;
      _ampSub?.cancel();
      _ampSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((a) {
        // dBFS (-60 quiet … 0 loud) → 0..1
        final db = a.current.isFinite ? a.current : -60.0;
        level.value = math.max(0, math.min(1, (db + 60) / 60));
      });
      return true;
    } catch (_) {
      recording.value = false;
      return false;
    }
  }

  Future<void> pause() async {
    if (!recording.value || _paused) return;
    try {
      await _rec.pause();
      _watch.stop();
      _paused = true;
      level.value = 0;
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!recording.value || !_paused) return;
    try {
      await _rec.resume();
      _watch.start();
      _paused = false;
    } catch (_) {}
  }

  /// Stops and returns the recording (with bytes), or null on failure.
  Future<Recording?> stop() async {
    if (!recording.value) return null;
    _watch.stop();
    await _ampSub?.cancel();
    _ampSub = null;
    level.value = 0;
    recording.value = false;
    _paused = false;
    try {
      final path = await _rec.stop();
      if (path == null || path.isEmpty) return null;
      Uint8List? bytes;
      try {
        bytes = await XFile(path).readAsBytes();
      } catch (_) {
        bytes = null;
      }
      return Recording(
        path: path,
        durationMs: _watch.elapsedMilliseconds,
        format: 'wav',
        bytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }

  /// Stops and throws the audio away.
  Future<void> cancel() async {
    _watch.stop();
    await _ampSub?.cancel();
    _ampSub = null;
    level.value = 0;
    recording.value = false;
    try {
      await _rec.cancel();
    } catch (_) {}
  }

  void dispose() {
    _ampSub?.cancel();
    _rec.dispose();
    level.dispose();
    recording.dispose();
  }
}
