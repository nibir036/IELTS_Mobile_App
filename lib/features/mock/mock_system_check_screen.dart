import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/audio_clip.dart';
import '../../app/services/entitlements.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../home/upgrade_sheet.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G2 · Mock Exam Instructions & System Check.
class MockSystemCheckScreen extends StatefulWidget {
  const MockSystemCheckScreen({super.key});

  @override
  State<MockSystemCheckScreen> createState() => _MockSystemCheckScreenState();
}

class _MockSystemCheckScreenState extends State<MockSystemCheckScreen> {
  final Map<String, dynamic> _data = mockContent;
  final DateTime _now = DateTime.now();
  String _mockId = '';
  bool _argsRead = false;
  late final List<Map<String, dynamic>> _checks = _data.l('systemChecks');
  final Set<String> _passed = <String>{};
  Timer? _checkTimer;
  int _level = 0;

  /// Live microphone check: `null` starting, true listening, false blocked.
  bool? _micOk;
  VoiceRecorder? _recorder;
  AudioClip? _sound;
  bool _stickyTimer = true;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    // The microphone check passes only when a real voice is heard.
    final order = List<Map<String, dynamic>>.from(_checks)
      ..removeWhere((c) => c.s('control') == 'level')
      ..sort((a, b) => a.i('passOrder').compareTo(b.i('passOrder')));
    var step = 0;
    _checkTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) return;
      if (step >= order.length) {
        timer.cancel();
        return;
      }
      setState(() => _passed.add(order[step].s('id')));
      step++;
    });
    _startMic();
  }

  String get _micId {
    for (final c in _checks) {
      if (c.s('control') == 'level') return c.s('id');
    }
    return 'microphone';
  }

  Future<void> _startMic() async {
    setState(() => _micOk = null);
    final rec = _recorder ?? VoiceRecorder();
    _recorder = rec;
    rec.level.removeListener(_onLevel);
    final ok = await rec.start();
    if (!mounted) return;
    if (ok) rec.level.addListener(_onLevel);
    setState(() => _micOk = ok);
  }

  /// Quietest recent input level - the room's noise floor.
  double _floor = 1;
  int _voiceTicks = 0;

  void _onLevel() {
    final v = _recorder?.level.value ?? 0;
    if (v <= 0) return; // paused / no reading yet
    // Track the noise floor: drop to quieter readings at once, creep up slowly
    // so a long sentence isn't mistaken for background noise.
    _floor = v < _floor ? v : _floor + (v - _floor) * 0.02;
    final above = v - _floor;
    // Light the bars relative to the floor (≈ 30 dB range above it).
    final bars = ((above / 0.5) * 9).round().clamp(0, 9).toInt();
    // A voice is ~8 dB+ above the room; count voiced readings (120 ms each).
    if (above > 0.13 || v > 0.6) _voiceTicks++;
    final heard = _voiceTicks >= 4 && !_passed.contains(_micId);
    if (bars != _level || heard) {
      setState(() {
        _level = bars;
        if (heard) _passed.add(_micId);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    // Free plan: one Full Mock Test.
    if (Entitlements.I.mockUsedUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showUpgradeSheet(context, feature: 'mock');
        if (mounted) context.back();
      });
    }
    final args = context.routeArgs;
    final arg = args['mockId'] ?? args['testId'];
    _mockId = arg is String && Content.mockTest(arg).isNotEmpty ? arg : mockDefaultId();
  }

  Future<void> _tryStart() async {
    if (_passed.contains(_micId)) {
      _start();
      return;
    }
    final go = await showAppDialog<bool>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text(
            'Microphone not confirmed',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          Text(
            _micOk == false
                ? 'Your microphone is blocked, so the Speaking section can\'t be '
                    'recorded. You can still take Listening, Reading and Writing.'
                : 'We didn\'t hear your voice yet. Say “Hello, my name is…” out '
                    'loud, or start anyway and check the mic before Speaking.',
            style: TextStyle(fontSize: 14, height: 1.4, color: context.tk.textMuted),
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Start anyway',
            height: 50,
            radius: 999,
            onTap: () => Navigator.of(context).pop(true),
          ),
          OutlineButtonX(
            label: 'Check again',
            height: 50,
            radius: 999,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (go == true && mounted) _start();
  }

  void _start() {
    _recorder?.level.removeListener(_onLevel);
    _recorder?.cancel();
    MockSession.start(_mockId);
    context.replace(Routes.mockListening);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _recorder?.level.removeListener(_onLevel);
    _recorder?.cancel();
    _recorder?.dispose();
    _sound?.dispose();
    super.dispose();
  }

  Future<void> _testSound() async {
    setState(() => _playing = true);
    // Pause the mic so the browser/OS doesn't duck or echo-cancel playback.
    await _recorder?.pause();
    final clip = _sound ?? AudioClip();
    _sound = clip;
    if (!clip.loaded) await clip.loadAsset('assets/audio/sound_check.mp3');
    if (!mounted) return;
    if (clip.loaded) {
      await clip.seek(Duration.zero);
      clip.play();
      if (!mounted) return;
      context.toast('You should hear “left”, then “right”');
      final ms = clip.duration.inMilliseconds > 0 ? clip.duration.inMilliseconds + 300 : 6500;
      await Future<void>.delayed(Duration(milliseconds: ms));
    } else {
      context.toast('Couldn’t play the test sound: ${clip.error ?? 'unknown error'}');
    }
    if (!mounted) return;
    clip.pause();
    await _recorder?.resume();
    if (!mounted) return;
    setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    context.store;
    final test = mockTest(_mockId);
    final meta = _data.m('meta');
    final sections = _data.l('sections');
    // The mic check never locks the student out: once the automatic checks
    // pass, Start works and asks to confirm if no voice was heard yet.
    final allPassed = _checks
        .where((c) => c.s('control') != 'level')
        .every((c) => _passed.contains(c.s('id')));

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      gap: 14,
      footer: PrimaryButton(
        label: 'Start mock test',
        height: 56,
        radius: 999,
        fontSize: 17,
        trailing: AppIcons.forward,
        enabled: allPassed,
        onTap: _tryStart,
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              size: 56,
              radius: 20,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: MockOutlinePill(
                    '${Store.weekdayDate(_now)} · '
                    '${mockTimeLabel('${_now.hour}:${_now.minute.toString().padLeft(2, '0')}')}',
                  ),
                ),
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              mockNextTitle(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                height: 1.05,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              '${mockTestName(test)} · ${meta.s('durationLabel')} · '
              '${_passed.length} of ${_checks.length} checks passed',
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            for (final c in _checks) _checkRow(c),
          ],
        ),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Section order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: t.heroText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'No pause between sections',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 12, color: t.heroMuted),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < sections.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.heroDivider)),
                  ),
                  child: Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.peach,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kOnPeach,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sections[i].s('name'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: t.heroText,
                              ),
                            ),
                            Text(
                              mockSectionNote(sections[i], test),
                              style: TextStyle(fontSize: 12, color: t.heroMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        mockSectionTime(sections[i], test),
                        style: TextStyle(fontSize: 14, color: t.heroText),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            spacing: 10,
            children: [
              Icon(AppIcons.lock, size: 16, color: t.alert),
              Expanded(
                child: Text(
                  'Timers can’t be paused. Nav and chat stay hidden until results.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _checkRow(Map<String, dynamic> c) {
    final t = context.tk;
    final id = c.s('id');
    final passed = _passed.contains(id);
    final control = c.s('control');

    Widget trailing;
    if (control == 'level' && _micOk == false) {
      trailing = SoftButton(
        label: 'Retry',
        height: 32,
        fontSize: 12,
        leading: AppIcons.refresh,
        onTap: _startMic,
      );
    } else if (control == 'level' && passed) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          _LevelBars(active: _level),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: t.peach, shape: BoxShape.circle),
            child: const Icon(AppIcons.check, size: 16, color: kOnPeach),
          ),
        ],
      );
    } else if (control == 'level') {
      trailing = _LevelBars(active: _level);
    } else if (!passed) {
      trailing = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.textMuted),
      );
    } else if (control == 'testSound') {
      trailing = Material(
        color: Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: t.isNight ? const Color(0xFF3A3A3A) : t.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _playing ? null : _testSound,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                Icon(
                  _playing ? AppIcons.waveform : AppIcons.volume,
                  size: 14,
                  color: t.text,
                ),
                Text(
                  _playing ? 'Playing…' : 'Test sound',
                  style: TextStyle(fontSize: 12, color: t.text),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (control == 'toggle') {
      trailing = MockToggle(
        value: _stickyTimer,
        onChanged: (v) => setState(() => _stickyTimer = v),
      );
    } else {
      trailing = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: t.peach, shape: BoxShape.circle),
        child: const Icon(AppIcons.check, size: 16, color: kOnPeach),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(8, 7, 14, 7),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.surfaceAlt2,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(mockIcon(c.s('icon')), size: 20, color: t.text),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.s('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
                Text(
                  control == 'level'
                      ? (_micOk == false
                          ? 'Microphone blocked - allow it, then Retry'
                          : passed
                              ? 'Voice detected · mic OK'
                              : _micOk == null
                                  ? 'Starting microphone…'
                                  : c.s('subtitle'))
                      : (passed ? c.s('subtitle') : 'Checking…'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// Microphone input meter (9 bars, first [active] lit).
class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.active});

  final int active;

  static const _heights = <double>[6, 9, 13, 17, 20, 14, 10, 16, 8];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 3,
        children: [
          for (var i = 0; i < _heights.length; i++)
            Container(
              width: 4,
              height: _heights[i],
              decoration: BoxDecoration(
                color: i < active ? t.fill : (t.isNight ? t.border : t.surfaceAlt),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
