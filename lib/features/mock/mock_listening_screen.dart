import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/audio_clip.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_exit_warning_screen.dart';
import 'mock_questions.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G3 · Mock — Listening Section.
class MockListeningScreen extends StatefulWidget {
  const MockListeningScreen({super.key});

  @override
  State<MockListeningScreen> createState() => _MockListeningScreenState();
}

class _MockListeningScreenState extends State<MockListeningScreen> {
  late final Map<String, dynamic> _mock;
  late final List<(Map<String, dynamic>, int)> _sets;
  late final List<MockGroup> _groups;
  late final int _total;
  late final List<double> _setSeconds;
  late int _seconds;
  final Set<int> _flagged = <int>{};
  int _group = 0;

  /// The question the flag button acts on: the one last tapped / typed in,
  /// else the first question of the group on screen.
  int _current = 1;
  Timer? _timer;
  bool _leaving = false;

  /// The section recording: the 4 parts back to back, each played once,
  /// no seeking (exam rules).
  final AudioClip _clip = AudioClip();
  int _audioIndex = 0;
  bool _switching = false;
  bool _audioDone = false;

  /// Simulated playback, only used if a part's audio can't be loaded.
  bool _audioFailed = false;
  double _simulated = 0;

  @override
  void initState() {
    super.initState();
    MockSession.ensure();
    _mock = MockSession.mock;
    _sets = mockListeningSets(_mock);
    _groups = mockListeningGroups(_mock);
    if (_groups.isNotEmpty) _current = _groups.first.first;
    _total = mockQuestionTotal(_groups);
    _setSeconds = <double>[
      for (final e in _sets) (e.$1.i('durationSeconds') > 0 ? e.$1.i('durationSeconds') : 180).toDouble(),
    ];
    _seconds = mockListeningSeconds(_mock);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _clip.addListener(_onClip);
    _playSet(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clip.removeListener(_onClip);
    _clip.dispose();
    super.dispose();
  }

  /// Loads and plays part [i]; past the last part the audio is over.
  Future<void> _playSet(int i) async {
    if (i >= _sets.length) {
      if (mounted) setState(() => _audioDone = true);
      return;
    }
    _switching = true;
    final ok = await _clip.loadAsset(Content.setAudio(_sets[i].$1));
    _switching = false;
    if (!mounted || _leaving) return;
    setState(() {
      _audioIndex = i;
      if (!ok) {
        _audioFailed = true;
        _simulated = 0;
      }
    });
    if (ok) _clip.play();
  }

  void _onClip() {
    if (_audioFailed || _switching || _audioDone || _leaving) return;
    if (_clip.completed) _playSet(_audioIndex + 1);
  }

  void _tick() {
    if (!mounted || _leaving) return;
    setState(() {
      if (_seconds > 0) _seconds--;
      if (_audioFailed && !_audioDone && _sets.isNotEmpty) {
        _simulated++;
        if (_simulated >= _setSeconds[_audioIndex]) {
          if (_audioIndex >= _sets.length - 1) {
            _audioDone = true;
          } else {
            _audioIndex++;
            _simulated = 0;
          }
        }
      }
    });
    if (_seconds <= 0) _finish();
  }

  /// Whole-section audio progress 0..1 across the 4 parts.
  double get _audioProgress {
    if (_sets.isEmpty) return 0;
    if (_audioDone) return 1;
    final total = _setSeconds.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return 0;
    var before = 0.0;
    for (var i = 0; i < _audioIndex && i < _setSeconds.length; i++) {
      before += _setSeconds[i];
    }
    final inPart = _audioFailed ? _simulated : _clip.progress * _setSeconds[_audioIndex];
    return ((before + inPart) / total).clamp(0.0, 1.0).toDouble();
  }

  String get _audioPart {
    if (_sets.isEmpty) return '';
    final set = _sets[_audioIndex].$1;
    return 'Part ${set.i('part') > 0 ? set.i('part') : _audioIndex + 1}';
  }

  void _answer(int n, String v) {
    setState(() {
      if (v.trim().isEmpty) {
        MockSession.listening.remove(n);
      } else {
        MockSession.listening[n] = v;
      }
    });
  }

  void _finish() {
    if (_leaving || !mockIsTop(context)) return;
    _leaving = true;
    _timer?.cancel();
    _clip.pause();
    context.replace(Routes.mockTransition, args: {'next': 'reading'});
  }

  /// Shows group [index]; [question] (a number in that group) becomes the
  /// current question, else the group's first.
  void _go(int index, {int? question}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _group = index;
      final g = _groups[index];
      _current = question != null && g.contains(question) ? question : g.first;
    });
  }

  void _next() {
    if (_group >= _groups.length - 1) {
      _finish();
      return;
    }
    _go(_group + 1);
  }

  void _prev() {
    if (_group == 0) return;
    _go(_group - 1);
  }

  void _toggleFlag() {
    if (_groups.isEmpty) return;
    setState(() {
      if (!_flagged.remove(_current)) _flagged.add(_current);
    });
  }

  Future<void> _exit() async {
    await confirmMockExit(context, sectionName: 'Listening', secondsLeft: _seconds);
  }

  void _openAll() {
    final t = context.tk;
    final total = _total;
    final answered = mockAnsweredNumbers(_groups, MockSession.listening);
    final current = _groups.isEmpty ? null : _groups[_group];
    showAppSheet<void>(
      context,
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Builder(
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(
                'All questions · ${answered.length} of $total answered',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var n = 1; n <= total; n++)
                    _QuestionChip(
                      number: n,
                      answered: answered.contains(n),
                      flagged: _flagged.contains(n),
                      current: current != null && n == _current,
                      onTap: () {
                        final idx = _groups.indexWhere((g) => g.contains(n));
                        Navigator.of(ctx).pop();
                        if (idx >= 0) _go(idx, question: n);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final g = _groups.isEmpty ? null : _groups[_group];
    final total = _total;
    final answered = mockAnsweredNumbers(_groups, MockSession.listening);
    final flaggedLabel = _flagged.isEmpty
        ? 'No flags'
        : '${(_flagged.toList()..sort()).map((n) => 'Q$n').join(', ')} flagged';

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                MockExamHeader(
                  title: g == null ? 'Listening' : 'Listening · ${g.heading}',
                  subtitle: MockSession.title,
                  seconds: _seconds,
                  low: _seconds <= 300,
                  onExit: _exit,
                ),
                const MockSectionTabs(current: 0),
                ListenableBuilder(
                  listenable: _clip,
                  builder: (context, _) => _AudioBar(
                    part: _audioPart,
                    progress: _audioProgress,
                    done: _audioDone,
                    loading: !_audioFailed && !_audioDone && (_switching || !_clip.loaded),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: AppCard(
                      radius: 24,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: g == null
                          ? Text(
                              'This mock has no listening questions.',
                              style: TextStyle(fontSize: 14, color: t.textMuted),
                            )
                          : MockGroupView(
                              key: ValueKey<String>(g.id),
                              group: g,
                              answers: MockSession.listening,
                              current: _current,
                              flagged: _flagged,
                              onChanged: _answer,
                              onCurrent: (n) {
                                if (_current != n) setState(() => _current = n);
                              },
                            ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: mockSheetDecoration(t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${answered.length} of $total answered',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              flaggedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: t.textMuted),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        spacing: 2,
                        children: [
                          for (var n = 1; n <= total; n++)
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: g != null && n == _current
                                      ? t.alert
                                      : _flagged.contains(n)
                                          ? kMockFlagStrong
                                          : answered.contains(n)
                                              ? t.fill
                                              : g != null && g.contains(n)
                                                  ? t.alert.withValues(alpha: 0.35)
                                                  : (t.isNight ? t.surfaceAlt2 : t.border),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        spacing: 8,
                        children: [
                          MockSquareButton(
                            icon: AppIcons.chevronLeft,
                            tooltip: 'Previous',
                            onTap: _group == 0 ? null : _prev,
                          ),
                          Expanded(
                            child: MockWideButton(
                              label: 'All questions',
                              icon: AppIcons.grid,
                              onTap: _openAll,
                            ),
                          ),
                          MockSquareButton(
                            icon: AppIcons.flag,
                            tooltip: _flagged.contains(_current) ? 'Unflag Q$_current' : 'Flag Q$_current',
                            flagged: _flagged.contains(_current),
                            onTap: g == null ? null : _toggleFlag,
                          ),
                          MockSquareButton(
                            icon: AppIcons.chevronRight,
                            tooltip: 'Next',
                            primary: true,
                            onTap: _next,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({
    required this.part,
    required this.progress,
    required this.done,
    this.loading = false,
  });

  final String part;
  final double progress;
  final bool done;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final accent = t.isNight ? const Color(0xFF151515) : const Color(0xFFF7C6D6);
    final track = t.isNight
        ? const Color(0xFF151515).withValues(alpha: 0.15)
        : const Color(0xFF3A3A3A);
    final muted = t.isNight ? const Color(0xFF5A5446) : const Color(0xFFB5B5B5);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              done
                  ? 'Audio ended'
                  : '${part.isEmpty ? '' : '$part · '}${loading ? 'loading' : 'playing'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: t.onPrimary),
            ),
          ),
          Expanded(
            child: ProgressBar(value: progress, height: 4, track: track, fill: accent),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              'Plays once',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({
    required this.number,
    required this.answered,
    required this.flagged,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool answered;
  final bool flagged;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg;
    Color fg;
    if (current) {
      bg = t.alert;
      fg = t.onAlert;
    } else if (flagged) {
      bg = kMockFlagPink;
      fg = kMockInk;
    } else if (answered) {
      bg = t.primary;
      fg = t.onPrimary;
    } else {
      bg = t.surfaceAlt2;
      fg = t.textMuted;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text('$number', style: TextStyle(fontSize: 13, color: fg)),
          ),
        ),
      ),
    );
  }
}
