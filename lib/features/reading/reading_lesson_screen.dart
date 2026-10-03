import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../listening/lesson_menu.dart' show showLessonMenu;
import 'lessons.dart';
import 'widgets.dart';

/// E6 · Reading Lesson & Exercise (inline exercise with answer checking).
class ReadingLessonScreen extends StatefulWidget {
  const ReadingLessonScreen({super.key});

  @override
  State<ReadingLessonScreen> createState() => _ReadingLessonScreenState();
}

class _ReadingLessonScreenState extends State<ReadingLessonScreen> with ContentLangListener {
  Map<String, dynamic> _lesson = <String, dynamic>{};
  List<Map<String, dynamic>> _exercises = <Map<String, dynamic>>[];
  bool _opened = false;
  int _index = 0;
  String? _selected;
  bool _checked = false;
  int _secondsLeft = 0;
  int _correct = 0;
  int _elapsedBefore = 0;
  bool _finished = false;
  DateTime _openedAt = DateTime.now();
  Timer? _timer;

  static const _progressKey = ReadingLessons.progressKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    // Lesson from args ({'lessonId'} or a lesson {'attemptId'}), else the
    // one in progress / next up.
    final args = context.routeArgs;
    var want = args['lessonId'] is String ? args['lessonId'] as String : '';
    if (want.isEmpty && args['attemptId'] is String) {
      want = Store.I.attemptById(args['attemptId'] as String)?.refId ?? '';
    }
    _lesson = ReadingLessons.byId(want) ??
        ReadingLessons.byId(ReadingLessons.defaultId(Store.I)) ??
        <String, dynamic>{};
    _exercises = _lesson.l('exercises');
    // Resume where the student left this lesson (new students start at 1).
    final saved = Store.I.kv<Map>(_progressKey);
    if (saved != null) {
      final p = saved.cast<String, dynamic>();
      if (p.s('lessonId') == _lesson.s('id')) {
        final start = p.i('index');
        _index = start >= 0 && start < _exercises.length ? start : 0;
        _correct = p.i('correct');
        _elapsedBefore = p.i('elapsedSec');
      }
    }
    _startExercise();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_finished && (_index > 0 || _checked)) _saveProgress();
    super.dispose();
  }

  int get _elapsed => _elapsedBefore + DateTime.now().difference(_openedAt).inSeconds;

  /// Remembers the next exercise to do (safe to call from dispose).
  void _saveProgress() {
    final next = _checked ? _index + 1 : _index;
    if (next >= _exercises.length) return;
    persistKv(<String, Object?>{
      _progressKey: <String, dynamic>{
        'lessonId': _lesson.s('id'),
        'index': next,
        'correct': _correct,
        'elapsedSec': _elapsed,
      },
    });
  }

  int get _number => ReadingLessons.numberOf(_lesson.s('id'));

  /// Records the lesson as done. [marked] = "Mark as done" from the menu:
  /// keeps the score so far and moves on to the next lesson.
  void _finish({bool marked = false}) {
    if (_lesson.isEmpty) return;
    _finished = true;
    _timer?.cancel();
    final total = _exercises.length;
    final a = Attempt(
      id: Store.newId('att'),
      skill: Skill.reading,
      kind: 'lesson',
      title: 'Lesson $_number · ${_lesson.s('title')}',
      refId: _lesson.s('id'),
      score: _correct,
      total: total,
      durationSec: _elapsed < 60 ? 60 : _elapsed,
      createdAt: DateTime.now(),
      data: <String, dynamic>{
        'lessonId': _lesson.s('id'),
        if (marked) 'markedDone': true,
      },
    );
    if (ReadingLessons.inProgressId(Store.I) == _lesson.s('id')) {
      Store.I.data.kv.remove(_progressKey);
    }
    Store.I.addAttempt(a);
    if (!marked) {
      context.toast('Lesson complete · $_correct of $total correct');
      context.back();
      return;
    }
    final lessons = ReadingLessons.all;
    final i = ReadingLessons.indexOf(_lesson.s('id'));
    if (i >= 0 && i + 1 < lessons.length) {
      context.toast('Marked as done · on to Lesson ${i + 2}');
      context.replace(
        Routes.readingLesson,
        args: <String, dynamic>{'lessonId': lessons[i + 1].s('id')},
      );
    } else {
      context.toast('Marked as done · that was the last lesson');
      context.back();
    }
  }

  /// Starts this lesson again from exercise 1.
  void _restart() {
    if (ReadingLessons.inProgressId(Store.I) == _lesson.s('id')) {
      Store.I.setKv(_progressKey, null);
    }
    setState(() {
      _index = 0;
      _correct = 0;
      _elapsedBefore = 0;
      _openedAt = DateTime.now();
      _startExercise();
    });
    context.toast('Lesson restarted');
  }

  Future<void> _openMenu() async {
    final id = _lesson.s('id');
    final store = Store.I;
    final action = await showLessonMenu(
      context,
      entries: ReadingLessons.menu(store, id),
      currentDone: ReadingLessons.doneIds(store).contains(id),
    );
    if (!mounted || action == null) return;
    switch (action.kind) {
      case 'open':
        if (action.lessonId != id) {
          context.replace(
            Routes.readingLesson,
            args: <String, dynamic>{'lessonId': action.lessonId},
          );
        }
      case 'restart':
        _restart();
      case 'done':
        _finish(marked: true);
    }
  }

  void _startExercise() {
    _timer?.cancel();
    _selected = null;
    _checked = false;
    _secondsLeft = _exercises.isEmpty ? 0 : _exercises[_index].i('seconds');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
        if (_secondsLeft == 0 && !_checked) {
          _timer?.cancel();
          _checked = true;
        }
      });
    });
  }

  void _check() {
    if (_selected == null) return;
    _timer?.cancel();
    setState(() {
      _checked = true;
      if (_selected == _exercises[_index].s('answer')) _correct++;
    });
  }

  void _next() {
    if (_index < _exercises.length - 1) {
      setState(() {
        _index++;
        _startExercise();
      });
    } else {
      _finish();
    }
  }

  OptionState _stateFor(String key, String answer) {
    if (!_checked) return OptionState.none;
    if (key == answer) return OptionState.correct;
    if (key == _selected) return OptionState.wrong;
    return OptionState.none;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ex = _exercises.isEmpty ? <String, dynamic>{} : _exercises[_index];
    final lesson = ContentL10n.skillLesson(_lesson);
    final isLast = _index >= _exercises.length - 1;

    String label;
    VoidCallback? action;
    if (!_checked) {
      label = 'Check answer';
      action = _selected == null ? null : _check;
    } else {
      label = isLast ? 'Finish lesson' : 'Next exercise';
      action = _next;
    }

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      footer: PrimaryButton(
        label: label,
        height: 56,
        radius: 18,
        enabled: action != null,
        onTap: action,
      ),
      children: [
        ReadingHeader(
          overline: 'Lesson $_number of ${ReadingLessons.all.length}',
          title: lesson.s('title'),
          onBack: () => context.back(),
          trailing: IconBox(
            icon: AppIcons.more,
            tooltip: 'More',
            bg: t.surface,
            onTap: _openMenu,
          ),
        ),
        SegmentBar(
          count: _exercises.length,
          filled: _index + 1,
          height: 5,
          gap: 4,
        ),
        const ContentLangSwitch(),
        ContentDirection(
          child: AppCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kLavender,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _lesson.s('keyIdeaLabel'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kInk,
                      ),
                    ),
                  ),
                ),
                Text.rich(
                  TextSpan(children: boldSpans(lesson.s('keyIdea'))),
                  style: const TextStyle(fontSize: 15, height: 1.55),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    for (final u in lesson.l('uses'))
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: t.surfaceAlt2,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            spacing: 2,
                            children: [
                              Text(u.s('label'), style: TextStyle(fontSize: 12, color: t.textMuted)),
                              Text(
                                u.s('value'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Exercise · ${_index + 1} of ${_exercises.length}',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ),
                  Icon(AppIcons.timer, size: 13, color: t.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    shortClock(_secondsLeft),
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: t.isNight ? t.text : kLavender,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  ex.s('quote'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: t.isNight ? t.text : t.textSoft,
                  ),
                ),
              ),
              Text(
                ex.s('question'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  for (final o in ex.l('options'))
                    OptionTile(
                      label: o.s('text'),
                      leadingText: o.s('key'),
                      selected: _selected == o.s('key'),
                      state: _stateFor(o.s('key'), ex.s('answer')),
                      onTap: _checked
                          ? null
                          : () => setState(() => _selected = o.s('key')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
