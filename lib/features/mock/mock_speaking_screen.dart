import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_exit_warning_screen.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G7 · Mock - Speaking Section (Parts 1–3, recorded, no pause).
class MockSpeakingScreen extends StatefulWidget {
  const MockSpeakingScreen({super.key});

  @override
  State<MockSpeakingScreen> createState() => _MockSpeakingScreenState();
}

/// 0 prep · 1 speak · 2 follow-up.
class _MockSpeakingScreenState extends State<MockSpeakingScreen> {
  late final List<Map<String, dynamic>> _parts = mockContent.m('speaking').l('parts');

  /// Bank content of the mock: Part 1 topic, Part 2 cue card (+ its Part 3).
  late final Map<String, dynamic> _topic = mockPart1Topic(_mockTest);
  late final Map<String, dynamic> _cue = mockCueCard(_mockTest);
  late final Map<String, dynamic> _mockTest = _sessionMock();

  static Map<String, dynamic> _sessionMock() {
    MockSession.ensure();
    return MockSession.mock;
  }

  /// Examiner questions of the current part (Part 1 topic / Part 3 list).
  List<String> get _questions {
    switch (_p.i('part')) {
      case 1:
        return _topic.ls('questions');
      case 3:
        return _cue.ls('part3');
      default:
        return const <String>[];
    }
  }

  /// The question being asked now: the part's speaking time is shared
  /// evenly between its questions.
  int get _questionIndex {
    final n = _questions.length;
    if (n <= 1 || _phase != 1) return 0;
    final speak = _p.i('speakSeconds');
    if (speak <= 0) return 0;
    final i = _elapsed * n ~/ speak;
    return i >= n ? n - 1 : i;
  }
  int _part = 0;
  late int _phase = _p.i('prepSeconds') > 0 ? 0 : 1;
  int _elapsed = 0;
  Timer? _timer;
  bool _leaving = false;

  static const _bars = <double>[
    8, 37, 45, 49, 52, 29, 25, 29, 40, 55, 42, 44, 27, 21, 44, 43, 53, 45, 26, 24, 30, 49, 53,
    41, 40, 15, 32, 47, 44, 53, 36, 24, 30, 34, 54, 48, 42, 32, 13, 42, 46, 50, 49, 24, 21, 33,
  ];

  /// Live microphone for the current part (null while preparing, between
  /// parts, or when the student continues without recording).
  VoiceRecorder? _rec;
  bool _starting = false;

  /// True once the student chose "Continue without recording": the rest of
  /// the section uses the simulated timer.
  bool _micOff = false;

  /// Ticking pauses while the mic dialog is open.
  bool _blocked = false;

  /// Rolling live input levels (0..1) for the waveform.
  final List<double> _levels = <double>[];

  @override
  void initState() {
    super.initState();
    MockSession.ensure();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_phase == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    final rec = _rec;
    _rec = null;
    if (rec != null) {
      rec.level.removeListener(_onLevel);
      rec.cancel().whenComplete(rec.dispose);
    }
    super.dispose();
  }

  Map<String, dynamic> get _p =>
      _parts.isEmpty ? <String, dynamic>{} : _parts[_part];

  int get _phaseLimit {
    switch (_phase) {
      case 0:
        return _p.i('prepSeconds');
      case 2:
        return _p.i('followUpSeconds');
      default:
        return _p.i('speakSeconds');
    }
  }

  void _tick() {
    if (!mounted || _leaving || _blocked) return;
    setState(() {
      _elapsed++;
      if (_phase > 0 && _rec == null) {
        // Simulated flow (no microphone): count seconds spoken.
        final part = _p.i('part');
        MockSession.speakingSec[part] = (MockSession.speakingSec[part] ?? 0) + 1;
      }
    });
    if (_phaseLimit > 0 && _elapsed >= _phaseLimit) _advance();
  }

  void _onLevel() {
    final rec = _rec;
    if (rec == null || !mounted) return;
    setState(() {
      _levels.add(rec.level.value);
      while (_levels.length > _bars.length) {
        _levels.removeAt(0);
      }
    });
  }

  /// Starts the microphone for the current part (Speak phase).
  Future<void> _startRecording() async {
    if (_micOff || _rec != null || _starting || _leaving || !mounted) return;
    _starting = true;
    final rec = VoiceRecorder();
    final ok = await rec.start();
    _starting = false;
    if (!mounted || _leaving) {
      if (ok) await rec.cancel();
      rec.dispose();
      return;
    }
    if (ok) {
      rec.level.addListener(_onLevel);
      setState(() {
        _levels.clear();
        _rec = rec;
      });
      return;
    }
    rec.dispose();
    setState(() => _blocked = true);
    final retry = await _micDialog();
    if (!mounted) return;
    setState(() {
      _blocked = false;
      if (retry != true) _micOff = true;
    });
    if (retry == true) await _startRecording();
  }

  Future<bool?> _micDialog() {
    return showAppDialog<bool>(
      context,
      Builder(
        builder: (ctx) {
          final t = ctx.tk;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Icon(AppIcons.mic, size: 28, color: t.iconAccent),
              const Text(
                'Microphone is off',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              Text(
                'We couldn’t start the microphone. Allow microphone access for '
                'IELTS AI in your device Settings, then try again - or continue '
                'without recording and your answers will be timed only.',
                style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted),
              ),
              const SizedBox(height: 4),
              PrimaryButton(
                label: 'Continue without recording',
                radius: 999,
                onTap: () => Navigator.of(ctx).pop(false),
              ),
              OutlineButtonX(
                label: 'Try again',
                radius: 999,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Stops the current part's recording and keeps it in the mock session
  /// (spoken seconds = real recording length).
  Future<void> _stopRecording(int part) async {
    final rec = _rec;
    if (rec == null) return;
    _rec = null;
    rec.level.removeListener(_onLevel);
    final elapsed = rec.elapsed.inSeconds;
    final r = await rec.stop();
    if (r != null) {
      MockSession.recordings[part] = r;
      MockSession.speakingSec[part] = r.durationSec;
    } else {
      MockSession.speakingSec[part] = elapsed;
    }
    rec.dispose();
  }

  /// Moves to the next phase, next part, or scoring.
  Future<void> _advance() async {
    if (_leaving || _starting || _blocked || !mockIsTop(context)) return;
    if (_phase == 0) {
      setState(() {
        _phase = 1;
        _elapsed = 0;
      });
      await _startRecording();
      return;
    }
    if (_phase == 1 && _p.i('followUpSeconds') > 0) {
      setState(() {
        _phase = 2;
        _elapsed = 0;
      });
      return;
    }
    final part = _p.i('part');
    if (_part < _parts.length - 1) {
      final stop = _stopRecording(part);
      setState(() {
        _levels.clear();
        _part++;
        _phase = _p.i('prepSeconds') > 0 ? 0 : 1;
        _elapsed = 0;
      });
      await stop;
      if (mounted && _phase == 1) await _startRecording();
      return;
    }
    _leaving = true;
    _timer?.cancel();
    await _stopRecording(part);
    if (!mounted) return;
    context.replace(Routes.mockScoring);
  }

  Future<void> _exit() async {
    await confirmMockExit(
      context,
      sectionName: 'Speaking',
      secondsLeft: _phaseLimit - _elapsed,
    );
  }

  Widget _promptCard() {
    final t = context.tk;
    final muted = t.isNight ? const Color(0xFFB5B5B5) : t.textMuted;
    final part = _p.i('part');
    if (part == 2) {
      final bullets = _cue.ls('bullets');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(_p.s('promptLabel'), style: TextStyle(fontSize: 12, color: t.textMuted)),
          Text(
            _cue.s('title').isNotEmpty ? _cue.s('title') : _cue.s('prompt'),
            style: const TextStyle(fontSize: 18, height: 1.35),
          ),
          if (bullets.isNotEmpty)
            Text('You should say:', style: TextStyle(fontSize: 14, color: muted)),
          for (final b in bullets)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Dot(size: 5, color: t.text),
                ),
                Expanded(
                  child: Text(b, style: TextStyle(fontSize: 14, height: 1.5, color: muted)),
                ),
              ],
            ),
        ],
      );
    }
    final qs = _questions;
    final i = _questionIndex;
    final label = part == 1 && _topic.s('topic').isNotEmpty
        ? '${_p.s('promptLabel')} · ${_topic.s('topic')}'
        : _p.s('promptLabel');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ),
            if (qs.length > 1)
              Text(
                'Question ${i + 1} of ${qs.length}',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
          ],
        ),
        Text(
          qs.isEmpty ? '' : qs[i],
          style: const TextStyle(fontSize: 18, height: 1.35),
        ),
        if (i + 1 < qs.length)
          Text(
            'Next: ${qs[i + 1]}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.5, color: muted),
          ),
        Text(
          _p.s('hint'),
          style: TextStyle(fontSize: 14, height: 1.6, color: muted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final prep = _p.i('prepSeconds');
    final speak = _p.i('speakSeconds');
    final follow = _p.i('followUpSeconds');
    final recording = _phase > 0 && !_micOff;
    final live = _rec != null;
    int played = 0;
    if (_phase == 1 && speak > 0) {
      played = (_bars.length * _elapsed / speak).round();
    } else if (_phase == 2) {
      played = _bars.length;
    }
    // Live waveform: newest level on the right.
    final offset = _bars.length - _levels.length;
    double barHeight(int i) {
      if (!live) return _bars[i];
      final k = i - offset;
      if (k < 0) return 6;
      return 6 + _levels[k] * 50;
    }

    bool barOn(int i) => live ? i >= offset : i < played;

    String prepValue = '-';
    if (prep > 0) {
      prepValue = _phase == 0 ? mockShortClock(prep - _elapsed) : mockShortClock(prep);
    }
    String speakValue = mockShortClock(speak);
    if (_phase == 1) {
      speakValue = '${mockShortClock(_elapsed)} / ${mockShortClock(speak)}';
    }
    String followValue = '-';
    if (_phase == 2) {
      followValue = '${mockShortClock(_elapsed)} / ${mockShortClock(follow)}';
    }

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _exit();
      },
      child: AppScreen(
      scrollBack: false,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        gap: 16,
        footer: PrimaryButton(
          label: _phase == 0 ? 'Start speaking now' : 'I’ve finished speaking',
          leading: _phase == 0 ? AppIcons.mic : AppIcons.stop,
          radius: 999,
          bg: t.raised,
          fg: t.text,
          onTap: () => _advance(),
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MockOutlinePill(
                    MockSession.title,
                    leading: AppIcons.close,
                    onTap: _exit,
                  ),
                ),
              ),
              if (recording) const SizedBox(width: 8),
              if (recording) const _RecordingPill(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                'Speaking · Part ${_p.i('part')} of ${_parts.length}',
                style: TextStyle(fontSize: 14, color: t.textMuted),
              ),
              Text(
                _phase == 0 ? 'Prepare your answer' : 'Speak now',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
            ],
          ),
          Row(
            spacing: 6,
            children: [
              Expanded(
                child: _PhaseTile(
                  label: 'Prep',
                  value: prepValue,
                  icon: AppIcons.timer,
                  state: _phase == 0 ? 1 : 0,
                ),
              ),
              Expanded(
                child: _PhaseTile(
                  label: 'Speak',
                  value: speakValue,
                  dot: true,
                  state: _phase == 1 ? 1 : (_phase > 1 ? 0 : 2),
                ),
              ),
              Expanded(
                child: _PhaseTile(
                  label: 'Follow-up',
                  value: followValue,
                  state: _phase == 2 ? 1 : 2,
                ),
              ),
            ],
          ),
          AppCard(
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: _promptCard(),
          ),
          SizedBox(
            height: 70,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 3,
                children: [
                  for (var i = 0; i < _bars.length; i++)
                    Container(
                      width: 4,
                      height: barHeight(i),
                      decoration: BoxDecoration(
                        color: barOn(i)
                            ? t.text
                            : (t.isNight ? const Color(0xFF333333) : t.surface),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              spacing: 10,
              children: [
                Icon(AppIcons.info, size: 18, color: t.iconAccent),
                Expanded(
                  child: Text(
                    'Like the real test, you can’t pause or re-record. '
                    'The examiner moves on at ${mockShortClock(speak)}.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  const _RecordingPill();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Dot(size: 8, color: t.alert),
          Text(
            'Recording',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: t.alert,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  const _PhaseTile({
    required this.label,
    required this.value,
    required this.state,
    this.icon,
    this.dot = false,
  });

  final String label;
  final String value;

  /// 0 done · 1 active · 2 upcoming.
  final int state;
  final IconData? icon;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color? bg;
    Color fg;
    Border? border;
    if (state == 1) {
      bg = t.primary;
      fg = t.onPrimary;
    } else if (state == 0) {
      bg = t.isNight ? t.surfaceAlt2 : t.surface;
      fg = t.textMuted;
    } else {
      fg = t.isNight ? t.textFaint : t.textMuted;
      border = Border.all(color: t.border);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Row(
            spacing: 6,
            children: [
              if (dot && state == 1) Dot(size: 8, color: t.alert),
              if (icon != null) Icon(icon, size: 14, color: fg),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: fg),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
