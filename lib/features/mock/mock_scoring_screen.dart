import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G8 · Mock - Scoring in Progress. Steps tick through, then the screen
/// replaces itself with the results (G9).
class MockScoringScreen extends StatefulWidget {
  const MockScoringScreen({super.key});

  @override
  State<MockScoringScreen> createState() => _MockScoringScreenState();
}

class _MockScoringScreenState extends State<MockScoringScreen> {
  final Map<String, dynamic> _mock = mockContent;
  late final Map<String, dynamic> _data = _mock.m('scoring');
  late final List<Map<String, dynamic>> _steps = _data.l('steps');
  final String _title = MockSession.title;
  late final bool _noSession = !MockSession.active;
  Attempt? _attempt;
  int _step = 0;
  int _ticks = 0;
  int _endTick = -1;
  bool _notify = true;
  bool _notified = false;
  bool _leaving = false;
  Timer? _timer;

  /// Rule-based Listening/Reading, known before the AI finishes.
  Map<String, dynamic> _objective = <String, dynamic>{};

  /// Async results per G8 step index (0 W1 · 1 W2 · 2 Speaking).
  final Map<int, Map<String, dynamic>> _results = <int, Map<String, dynamic>>{};

  static const int _ticksPerStep = 5;

  @override
  void initState() {
    super.initState();
    if (_noSession) return;
    _objective = MockSession.scoreObjective();
    // Start scoring after the first frame (the store changes when it's done).
    WidgetsBinding.instance.addPostFrameCallback((_) => _score());
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted || _leaving || !mockIsTop(context)) return;
      setState(() {
        _ticks++;
        if (_ticks % _ticksPerStep == 0 &&
            _step < _steps.length &&
            _stepDone(_step)) {
          _step++;
        }
        if (_endTick < 0 && _step >= _steps.length && _attempt != null) {
          _endTick = _ticks;
        }
      });
      if (_endTick >= 0 && _ticks >= _endTick + 3) _done();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// A step may tick to done once its result is in; the last step waits for
  /// the recorded attempt.
  bool _stepDone(int i) {
    if (i >= _steps.length - 1) return _attempt != null;
    return _results.containsKey(i) || _attempt != null;
  }

  Future<void> _score() async {
    if (!MockSession.active) return;
    Attempt? a;
    try {
      a = await MockSession.finishAsync(
        onStep: (int step, Map<String, dynamic> result) {
          _results[step] = result;
          if (mounted) setState(() {});
        },
      );
    } catch (_) {
      a = MockSession.active ? MockSession.finishOffline() : null;
    }
    if (a == null) return;
    _attempt = a;
    if (!mounted) {
      // The student left G8 while scoring: still tell them when it's ready.
      _notifyOnce();
      return;
    }
    setState(() {});
  }

  void _notifyOnce() {
    final a = _attempt;
    if (a == null || !_notify || _notified) return;
    _notified = true;
    Store.I.addNotification(<String, dynamic>{
      'type': 'score',
      'skill': Skill.mock,
      'title': 'Mock scored · Band ${Store.formatBand(a.band)}',
      'body': a.title,
      'attemptId': a.id,
    });
  }

  void _done() {
    final a = _attempt;
    if (_leaving || a == null) return;
    _leaving = true;
    _timer?.cancel();
    _notifyOnce();
    context.replace(Routes.mockResults, args: {'attemptId': a.id});
  }

  double? _band(String key) {
    final a = _attempt;
    if (a != null) return mockSectionBand(a, key);
    switch (key) {
      case 'listening':
        return _objective.containsKey('listeningBand') ? _objective.d('listeningBand') : null;
      case 'reading':
        return _objective.containsKey('readingBand') ? _objective.d('readingBand') : null;
      case 'writing':
        final w1 = _results[0];
        final w2 = _results[1];
        if (w1 == null || w2 == null) return null;
        return Store.roundBand((w1.d('band') + 2 * w2.d('band')) / 3);
      case 'speaking':
        final sp = _results[2];
        return sp?.d('band');
    }
    return null;
  }

  Widget _empty(BuildContext context) {
    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      gap: 16,
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
          ],
        ),
        EmptyState(
          icon: AppIcons.timer,
          title: 'No mock in progress',
          message: 'Scores appear here after you finish all four sections of a mock test.',
          actionLabel: 'Start a mock test',
          onAction: () => context.replace(Routes.mockSystemCheck),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_noSession && _attempt == null) return _empty(context);
    final t = context.tk;
    final tiles = _data.l('provisional');
    final allDone = _step >= _steps.length;

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      gap: 16,
      footer: PrimaryButton(
        label: 'Review Listening answers',
        radius: 999,
        bg: t.raised,
        fg: t.text,
        onTap: () {
          final a = _attempt;
          if (a != null) {
            context.push(Routes.mockAnswers, args: {'attemptId': a.id});
          } else if (MockSession.active) {
            context.push(Routes.mockAnswers, args: {'session': true});
          } else {
            context.push(Routes.mockAnswers);
          }
        },
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
              onTap: () {
                _notifyOnce();
                context.back();
              },
            ),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Score report',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _attempt?.title ?? _title,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
        HeroCard(
          padding: const EdgeInsets.all(20),
          radius: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(
                          'Overall band'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                            color: t.peach,
                          ),
                        ),
                        Text(
                          allDone ? 'Ready' : 'Almost ready…',
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.15,
                            color: t.heroText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MockInkBadge(allDone ? 'Done' : _data.s('etaLabel')),
                ],
              ),
              for (var r = 0; r * 2 < tiles.length; r++)
                Row(
                  spacing: 8,
                  children: [
                    for (var c = 0; c < 2; c++)
                      Expanded(
                        child: (r * 2 + c) < tiles.length
                            ? _BandTile(
                                row: tiles[r * 2 + c],
                                band: _band(tiles[r * 2 + c].s('key')),
                                ready: _band(tiles[r * 2 + c].s('key')) != null &&
                                    _step >= tiles[r * 2 + c].i('readyAfterStep'),
                                phase: _ticks % 3,
                              )
                            : const SizedBox(),
                      ),
                  ],
                ),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'What the AI is doing',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              for (var i = 0; i < _steps.length; i++)
                _StepRow(
                  row: _steps[i],
                  state: i < _step ? 0 : (i == _step ? 1 : 2),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            spacing: 12,
            children: [
              Icon(AppIcons.bell, size: 20, color: t.text),
              const Expanded(
                child: Text(
                  'Notify me when it’s ready',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              MockToggle(
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandTile extends StatelessWidget {
  const _BandTile({
    required this.row,
    required this.band,
    required this.ready,
    required this.phase,
  });

  final Map<String, dynamic> row;
  final double? band;
  final bool ready;
  final int phase;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (ready) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.heroChip,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(
              row.s('name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.heroMuted),
            ),
            Text(
              Store.formatBand(band),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: t.heroText,
              ),
            ),
          ],
        ),
      );
    }
    const opacities = <double>[1, 0.5, 0.25];
    return DashedBorderBox(
      color: t.peach.withValues(alpha: 0.7),
      radius: 20,
      strokeWidth: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              row.s('name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.heroMuted),
            ),
            SizedBox(
              height: 26,
              child: Row(
                spacing: 4,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.heroText.withValues(
                          alpha: opacities[(i + 3 - phase) % 3],
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Scoring',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.heroMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.row, required this.state});

  final Map<String, dynamic> row;

  /// 0 done · 1 running · 2 queued.
  final int state;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget mark;
    if (state == 0) {
      mark = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: t.peach, shape: BoxShape.circle),
        child: const Icon(AppIcons.check, size: 16, color: kOnPeach),
      );
    } else if (state == 1) {
      mark = SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: t.fill),
      );
    } else {
      mark = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: t.isNight ? const Color(0xFF333333) : t.border,
            width: 1.5,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        spacing: 12,
        children: [
          mark,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state == 0 ? row.s('doneTitle') : row.s('title'),
                  style: TextStyle(
                    fontSize: 14,
                    color: state == 2 ? t.textMuted : t.text,
                  ),
                ),
                Text(
                  state == 0 ? row.s('doneDetail') : row.s('detail'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
