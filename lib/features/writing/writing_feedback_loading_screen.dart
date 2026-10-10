import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/ai_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../home/upgrade_sheet.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C12 · Writing AI Feedback Loading. Scores the pending essay
/// (`args['essay']` / [WritingService.pending]) with the AI while walking
/// through the four criteria, then replaces itself with the band report of
/// the new attempt. If it can't be scored (offline, free allowance used, AI
/// error) it says so - no made-up score - and keeps the essay. With
/// `args['attemptId']` it just animates and opens that report.
class WritingFeedbackLoadingScreen extends StatefulWidget {
  const WritingFeedbackLoadingScreen({super.key});

  @override
  State<WritingFeedbackLoadingScreen> createState() =>
      _WritingFeedbackLoadingScreenState();
}

class _WritingFeedbackLoadingScreenState
    extends State<WritingFeedbackLoadingScreen> {
  static const int _minMillis = 2500;

  late final Map<String, dynamic> _data =
      WritingContent.all.m('loading');
  late final List<Map<String, dynamic>> _steps = _data.l('steps');
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;
  Timer? _finish;
  int _done = 0;
  bool _started = false;
  bool _leaving = false;

  /// The essay being scored ({prompt, text, elapsedSec}) or null.
  Map<String, dynamic>? _essay;

  /// Id of the finished attempt (null while the AI is still working).
  String? _resultId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _watch.start();
    final args = context.routeArgs;
    final existing = args['attemptId'];
    if (existing is String && existing.isNotEmpty) {
      _resultId = existing;
    } else {
      final e = args['essay'];
      final essay = e is Map ? e.cast<String, dynamic>() : WritingService.pending;
      WritingService.pending = null;
      if (essay != null && essay.s('text').trim().isNotEmpty) {
        _essay = essay;
        _score(essay);
      }
    }
    final ms = _data.i('stepMillis') <= 0 ? 1400 : _data.i('stepMillis');
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) => _tick());
  }

  /// Why the essay couldn't be scored (shown instead of a report).
  ScoringFailed? _failure;

  Future<void> _score(Map<String, dynamic> essay) async {
    Attempt a;
    try {
      a = await WritingService.evaluate(
        prompt: essay.m('prompt'),
        text: essay.s('text').trim(),
        elapsedSec: essay.i('elapsedSec'),
      );
    } on ScoringFailed catch (e) {
      _fail(e);
      return;
    } catch (_) {
      _fail(AiService.failure('We couldn’t score your essay right now. Please try again.'));
      return;
    }
    if (!mounted) return;
    setState(() => _resultId = a.id);
    _maybeFinish();
  }

  void _fail(ScoringFailed e) {
    if (!mounted) return;
    _timer?.cancel();
    _finish?.cancel();
    setState(() => _failure = e);
  }

  void _retry() {
    final essay = _essay;
    if (essay == null) return;
    setState(() {
      _failure = null;
      _done = 0;
    });
    _watch
      ..reset()
      ..start();
    final ms = _data.i('stepMillis') <= 0 ? 1400 : _data.i('stepMillis');
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) => _tick());
    _score(essay);
  }

  /// Back to the editor with the essay in it (nothing is lost).
  void _backToEditor() {
    final essay = _essay;
    if (essay == null) {
      context.back();
      return;
    }
    final prompt = essay.m('prompt');
    WritingDrafts.save(prompt.i('task') == 1 ? 1 : 2, prompt.s('id'), essay.s('text'), essay.i('elapsedSec'));
    context.replace(
      prompt.i('task') == 1 ? Routes.writingTask1Editor : Routes.writingEditor,
      args: <String, dynamic>{'promptId': prompt.s('id'), 'text': essay.s('text')},
    );
  }

  /// Steps advance on the timer; the last one completes only once the
  /// result is in.
  void _tick() {
    if (!mounted) return;
    final last = _steps.isEmpty ? 0 : _steps.length - 1;
    final noResult = _resultId == null && _essay != null;
    if (_done < last || (_done < _steps.length && !noResult)) {
      setState(() => _done++);
    }
    _maybeFinish();
  }

  void _maybeFinish() {
    if (!mounted || _leaving) return;
    final noEssay = _essay == null && _resultId == null;
    if (_resultId == null && !noEssay) return;
    // Existing attempt: let the whole walk-through play.
    if (_essay == null && !noEssay && _done < _steps.length) return;
    final wait = _minMillis - _watch.elapsedMilliseconds;
    if (wait > 0) {
      _finish?.cancel();
      _finish = Timer(Duration(milliseconds: wait), _maybeFinish);
      return;
    }
    _leaving = true;
    _timer?.cancel();
    setState(() => _done = _steps.length);
    _finish?.cancel();
    _finish = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final id = _resultId;
      context.replace(
        Routes.writingBandReport,
        args: <String, dynamic>{'attemptId': ?id},
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _finish?.cancel();
    _watch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final total = _steps.isEmpty ? 1 : _steps.length;
    final progress = ((_done + (_done < total ? 0.4 : 0)) / total)
        .clamp(0.0, 1.0);
    final essay = _essay;
    final a = essay != null
        ? null
        : context.store.resolveAttempt(
            context.routeArgs,
            skill: Skill.writing,
            kindPrefix: 'task',
          );
    var meta = 'Usually 10–30 seconds';
    if (essay != null) {
      final task = essay.m('prompt').i('task') == 1 ? 1 : 2;
      meta = '$meta · Task $task · ${essayWords(essay.s('text'))} words';
    } else if (a != null) {
      meta = '$meta · Task ${WritingService.taskOf(a)} · ${a.data.i('words')} words';
    }

    final failure = _failure;
    if (failure != null) {
      return AppScreen(
        fill: true,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        gap: 16,
        children: [
          Row(
            children: [
              IconBox(
                icon: AppIcons.close,
                size: 56,
                radius: 20,
                iconSize: 22,
                tooltip: 'Close',
                onTap: () => context.back(),
              ),
            ],
          ),
          const Spacer(),
          ScoringFailedPanel(
            failure: failure,
            onRetry: _retry,
            backLabel: 'Back to my essay',
            onBack: _backToEditor,
            note: 'Your essay is saved as a draft.',
          ),
          const Spacer(),
        ],
      );
    }

    return AppScreen(
      fill: true,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      gap: 16,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.close,
              size: 56,
              radius: 20,
              iconSize: 22,
              tooltip: 'Close',
              onTap: () => context.back(),
            ),
            const Expanded(
              child: Text(
                'AI feedback',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: RingProgress(
              value: progress,
              size: 140,
              stroke: 10,
              track: wc(t, 0xFFF0E2DD, 0xFF1C2030),
              fill: t.fill,
              child: Icon(AppIcons.sparkle, size: 40, color: t.iconAccent),
            ),
          ),
        ),
        Column(
          spacing: 6,
          children: [
            const Text(
              'Scoring your essay…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              meta,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: Column(
            children: [
              for (var i = 0; i < _steps.length; i++)
                _StepRow(
                  step: _steps[i],
                  state: i < _done ? 2 : (i == _done ? 1 : 0),
                ),
            ],
          ),
        ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Icon(AppIcons.sparkle, size: 18, color: t.iconAccent),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: _data.s('tipBefore')),
                      TextSpan(
                        text: _data.s('tipEmphasis'),
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      TextSpan(text: _data.s('tipAfter')),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: t.isNight ? t.textSoft : t.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'Your essay is saved. You can leave - we’ll notify you when it’s ready.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: t.textMuted),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.state});

  final Map<String, dynamic> step;

  /// 0 pending · 1 active · 2 done
  final int state;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget mark;
    if (state == 2) {
      mark = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
        child: Icon(AppIcons.check, size: 14, color: t.onPrimary),
      );
    } else if (state == 1) {
      mark = SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: t.fill,
          backgroundColor: wc(t, 0xFFF0E2DD, 0xFF333333),
        ),
      );
    } else {
      mark = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: wc(t, 0xFFF0E2DD, 0xFF333333),
            width: 1.5,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        spacing: 12,
        children: [
          mark,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step.s('title'),
                  style: TextStyle(
                    fontSize: 14,
                    color: state == 0 ? t.textMuted : t.text,
                  ),
                ),
                Text(
                  step.s('detail'),
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
