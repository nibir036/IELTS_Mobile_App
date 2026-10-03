import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/ai_service.dart';
import '../../app/services/voice_recorder.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'speaking_ai.dart';
import 'widgets.dart';

/// Lets a fixed-size control shrink (never grow) when the row is too narrow;
/// [flex] is proportional to the control's natural width.
Widget _shrink(int flex, Widget child) => Flexible(
      flex: flex,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );

/// D4 · Live audio recording (real microphone, simulated if the mic is off).
/// Route args: `{'id': '<cue card id>'}`. Stop & save uploads, transcribes and
/// scores the answer (AI or demo), saves an Attempt (kind part2) and opens D5;
/// a failed upload queues it and opens D9.
class SpeakingRecordingScreen extends StatefulWidget {
  const SpeakingRecordingScreen({super.key});

  @override
  State<SpeakingRecordingScreen> createState() =>
      _SpeakingRecordingScreenState();
}

class _SpeakingRecordingScreenState extends State<SpeakingRecordingScreen> {
  static const int _bars = 38;

  Timer? _timer;
  Map<String, dynamic>? _card;
  int _limit = 120;
  int _elapsed = 0;
  bool _paused = false;
  bool _blink = true;
  bool _done = false;
  DateTime _startedAt = DateTime.now();

  final VoiceRecorder _rec = VoiceRecorder();

  /// True once the microphone is recording (false = simulated timer).
  bool _live = false;

  /// True after "Practise without recording" or before the mic started.
  bool _simulated = false;
  bool _starting = true;
  bool _busy = false;
  String? _stage;
  List<double> _levels = List<double>.filled(_bars, 0);

  @override
  void initState() {
    super.initState();
    _rec.level.addListener(_onLevel);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (tick) {
      if (!mounted) return;
      setState(() {
        _blink = !_blink;
        if (_live) {
          _elapsed = _rec.elapsed.inSeconds;
        } else if (_simulated && !_paused && tick.tick.isEven) {
          _elapsed++;
        }
      });
      if (_elapsed >= _limit) _stop();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMic());
  }

  void _onLevel() {
    if (!_live || _paused) return;
    pushLevel(_levels, _rec.elapsed.inMilliseconds / 1000 / _limit, _rec.level.value);
  }

  Future<void> _startMic() async {
    if (!mounted) return;
    _starting = true;
    final ok = await _rec.start();
    _starting = false;
    if (!mounted) return;
    if (ok) {
      setState(() {
        _live = true;
        _simulated = false;
        _paused = false;
        _elapsed = 0;
        _startedAt = DateTime.now();
        _levels = List<double>.filled(_bars, 0);
      });
      return;
    }
    final practise = await showMicOffDialog(context);
    if (!mounted) return;
    if (!practise) {
      context.back();
      return;
    }
    setState(() {
      _simulated = true;
      _startedAt = DateTime.now();
      _elapsed = 0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_card != null) return;
    _card = findCueCard(cueCardArg(context));
    final limit = speakingData().m('recording').i('limitSeconds');
    _limit = limit > 0 ? limit : 120;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rec.level.removeListener(_onLevel);
    final rec = _rec;
    rec.cancel().whenComplete(rec.dispose);
    super.dispose();
  }

  Future<void> _stop() async {
    if (_done || _starting || _busy) return;
    _done = true;
    _timer?.cancel();
    final card = _card ?? <String, dynamic>{};
    final short = card.s('shortTitle').isNotEmpty ? card.s('shortTitle') : card.s('title');
    var spoken = _elapsed;
    final clips = <SpeakingClip>[];
    if (_live) {
      _live = false;
      final r = await _rec.stop();
      if (r != null) {
        spoken = r.durationSec;
        final bytes = r.bytes;
        if (bytes != null) speakingAudioCache[r.path] = bytes;
        clips.add(SpeakingClip(path: r.path, durationSec: r.durationSec, bytes: bytes));
      }
    }
    if (!mounted) return;
    final job = SpeakingJob(
      kind: 'part2',
      title: 'Part 2 · $short',
      refId: card.s('id'),
      part: 2,
      questions: <Map<String, dynamic>>[
        <String, dynamic>{'q': card.s('title'), 'spokenSec': spoken},
      ],
      clips: clips,
      spokenSec: spoken,
      expectedSec: 120,
      seed: card.i('number'),
      durationSec: DateTime.now().difference(_startedAt).inSeconds,
      cueCard: <String>[card.s('title'), ...card.ls('prompts')].join('\n'),
      cardTitle: card.s('title'),
    );
    if (AiService.available && clips.isNotEmpty) {
      setState(() => _stage = 'Uploading…');
    }
    final out = await processSpeaking(
      job,
      onStage: (stage, _) {
        if (mounted) setState(() => _stage = stage);
      },
    );
    if (!mounted) return;
    if (out.pending) {
      context.replace(Routes.uploadFailed);
      return;
    }
    final a = out.attempt;
    if (a == null) return;
    context.toast(
      AiService.available && clips.isNotEmpty && a.data.s('source') != 'ai'
          ? offlineScoreReason('Recording saved · scored offline (demo)')
          : 'Recording saved',
    );
    context.replace(Routes.speakingTranscript, args: {'attemptId': a.id});
  }

  Future<void> _restart() async {
    if (_done || _starting || _busy) return;
    if (_live) {
      _busy = true;
      _live = false;
      await _rec.cancel();
      _busy = false;
      if (!mounted) return;
      await _startMic();
      return;
    }
    setState(() {
      _startedAt = DateTime.now();
      _elapsed = 0;
      _paused = false;
    });
  }

  Future<void> _togglePause() async {
    if (_done || _starting || _busy) return;
    if (_live) {
      _busy = true;
      if (_paused) {
        await _rec.resume();
      } else {
        await _rec.pause();
      }
      _busy = false;
    }
    if (mounted) setState(() => _paused = !_paused);
  }

  void _showCard() {
    final t = context.tk;
    final card = _card ?? <String, dynamic>{};
    showAppSheet<void>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            card.s('title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          Text('You should say:', style: TextStyle(fontSize: 14, color: t.textMuted)),
          for (final p in card.ls('prompts'))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Dot(size: 6, color: t.text),
                ),
                Expanded(child: Text(p, style: const TextStyle(fontSize: 16))),
              ],
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final card = _card ?? <String, dynamic>{};
    final badge = speakingData().m('recording').s('partBadge');
    final progress = (_elapsed / _limit).clamp(0.0, 1.0).toDouble();
    final recBg = t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12);
    final recFg = t.isNight ? t.dangerText : t.alert;

    final screen = AppScreen(
      fill: true,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      gap: 20,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              size: 56,
              radius: 20,
              iconSize: 20,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            const Spacer(),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: recBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Opacity(
                    opacity: _paused || _blink ? 1 : 0.25,
                    child: Dot(size: 8, color: t.alert),
                  ),
                  Text(
                    _paused ? 'PAUSED' : 'REC',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                      color: recFg,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconBox(
              icon: AppIcons.article,
              size: 56,
              radius: 20,
              iconSize: 22,
              tooltip: 'Show cue card',
              onTap: _showCard,
            ),
          ],
        ),
        AppCard(
          radius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            spacing: 12,
            children: [
              LetterBadge(
                badge.isEmpty ? 'P2' : badge,
                size: 40,
                radius: 14,
                fontSize: 13,
                bg: t.primary,
                fg: t.onPrimary,
              ),
              Expanded(
                child: Text(
                  card.s('title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            spacing: 4,
            children: [
              Text(
                clockLong(_elapsed),
                style: const TextStyle(
                  fontSize: 84,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -3,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'of ${clockLong(_limit)} speaking time',
                style: TextStyle(fontSize: 14, color: t.textMuted),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: Stack(
            children: [
              Positioned.fill(
                child: _live
                    ? LevelWave(
                        levels: _levels,
                        height: 150,
                        color: t.isNight ? const Color(0xFF333333) : t.border,
                      )
                    : WaveformBars(
                        count: _bars,
                        height: 150,
                        progress: progress,
                        seed: 11,
                        color: t.isNight ? const Color(0xFF333333) : t.border,
                      ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment(progress * 2 - 1, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Dot(size: 8, color: t.text),
                      Container(width: 1.5, height: 138, color: t.text),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 28,
          children: [
            _shrink(
              2,
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: CaptionedButton(
                  size: 64,
                  bg: t.raised,
                  caption: 'Restart',
                  semanticLabel: 'Restart recording',
                  onTap: _restart,
                  child: Icon(AppIcons.replay, size: 22, color: t.text),
                ),
              ),
            ),
            _shrink(
              3,
              CaptionedButton(
                size: 96,
                bg: t.primary,
                caption: 'Stop & save',
                captionColor: t.text,
                semanticLabel: 'Stop recording',
                shadow: const [
                  BoxShadow(color: Color(0x14F6ECC8), spreadRadius: 10),
                ],
                onTap: _stop,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: t.onPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            _shrink(
              2,
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: CaptionedButton(
                  size: 64,
                  bg: t.raised,
                  caption: _paused ? 'Resume' : 'Pause',
                  semanticLabel: _paused ? 'Resume recording' : 'Pause recording',
                  onTap: _togglePause,
                  child: Icon(
                    _paused ? AppIcons.play : AppIcons.pause,
                    size: 22,
                    color: t.text,
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          'Keep going until the timer ends, like the real test.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: t.textMuted),
        ),
      ],
    );
    final stage = _stage;
    return PopScope(
      canPop: stage == null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          screen,
          if (stage != null)
            Positioned.fill(child: SpeakingProcessingOverlay(stage: stage)),
        ],
      ),
    );
  }
}
