import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'lesson_menu.dart';
import 'widgets.dart';

/// F6 · Listening Bite-size Lesson (lesson note + audio + gap-fill exercise).
class ListeningLessonScreen extends StatefulWidget {
  const ListeningLessonScreen({super.key});

  @override
  State<ListeningLessonScreen> createState() => _ListeningLessonScreenState();
}

class _ListeningLessonScreenState extends State<ListeningLessonScreen> {
  Map<String, dynamic> _lesson = <String, dynamic>{};
  List<Map<String, dynamic>> _rows = <Map<String, dynamic>>[];
  final Map<int, String> _answers = <int, String>{};
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};
  SimAudio? _audioOrNull;
  bool _opened = false;
  int _current = 0;
  bool _checked = false;
  bool _finished = false;
  int _correct = 0;
  final DateTime _openedAt = DateTime.now();

  SimAudio get _audio => _audioOrNull!;

  String get _key => ListeningLessons.savedKey(_lesson.s('id'));

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
    _lesson = ListeningLessons.byId(want) ??
        ListeningLessons.byId(ListeningLessons.defaultId(Store.I)) ??
        <String, dynamic>{};
    _rows = _lesson.l('rows');
    _current = _rows.isEmpty ? 0 : _rows.first.i('number');
    // The student's unfinished answers for this lesson (none for new users).
    final saved = Store.I.kv<Map>(_key);
    if (saved != null) {
      final m = saved.cast<String, dynamic>();
      m.m('answers').forEach((k, v) {
        final n = int.tryParse(k);
        if (n != null && v != null) _answers[n] = '$v';
      });
      final cur = m.i('current');
      if (_rows.any((r) => r.i('number') == cur)) _current = cur;
    }
    // Each lesson plays a clip of a real recording (assets/audio/listening/ll_…mp3).
    final audio = SimAudio(
      duration: _lesson.d('audioDurationSeconds'),
      asset: _lesson.s('audio'),
      onTick: () {
        if (mounted) setState(() {});
      },
    );
    _audioOrNull = audio;
    audio.play(notify: false);
  }

  @override
  void dispose() {
    if (!_finished && !_checked) {
      final given = <String, dynamic>{
        for (final e in _answers.entries)
          if (e.value.trim().isNotEmpty) '${e.key}': e.value.trim(),
      };
      persistListeningKv(<String, Object?>{
        _key: given.isEmpty ? null : <String, dynamic>{'answers': given, 'current': _current},
      });
    }
    _audioOrNull?.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int n) => _controllers.putIfAbsent(
        n,
        () => TextEditingController(text: _answers[n] ?? ''),
      );

  void _advance() {
    final nums = <int>[for (final r in _rows) r.i('number')];
    final idx = nums.indexOf(_current);
    setState(() {
      _current = idx >= 0 && idx < nums.length - 1 ? nums[idx + 1] : 0;
    });
  }

  bool _isCorrect(Map<String, dynamic> r) =>
      Scoring.matches(_answers[r.i('number')] ?? '', r['accepted'] ?? r['answer']);

  void _check() {
    FocusScope.of(context).unfocus();
    var correct = 0;
    for (final r in _rows) {
      if (_isCorrect(r)) correct++;
    }
    setState(() {
      _checked = true;
      _current = 0;
      _correct = correct;
    });
    context.toast('$correct / ${_rows.length} correct');
  }

  int get _number => ListeningLessons.numberOf(_lesson.s('id'));

  /// Records the lesson as done. [marked] = "Mark as done" from the menu:
  /// scores what has been answered so far and moves on to the next lesson.
  void _finish({bool marked = false}) {
    if (_lesson.isEmpty) return;
    _finished = true;
    if (marked) {
      var correct = 0;
      for (final r in _rows) {
        if (_isCorrect(r)) correct++;
      }
      _correct = correct;
    }
    final secs = DateTime.now().difference(_openedAt).inSeconds;
    final a = Attempt(
      id: Store.newId('att'),
      skill: Skill.listening,
      kind: 'lesson',
      title: 'Lesson $_number · ${_lesson.s('title')}',
      refId: _lesson.s('id'),
      score: _correct,
      total: _rows.length,
      durationSec: secs < 60 ? 60 : secs,
      createdAt: DateTime.now(),
      data: <String, dynamic>{
        'lessonId': _lesson.s('id'),
        'answers': <String, dynamic>{
          for (final e in _answers.entries) '${e.key}': e.value,
        },
        if (marked) 'markedDone': true,
      },
    );
    Store.I.data.kv.remove(_key);
    Store.I.addAttempt(a);
    if (!marked) {
      context.toast('Lesson complete');
      context.back();
      return;
    }
    final lessons = ListeningLessons.all;
    final i = ListeningLessons.indexOf(_lesson.s('id'));
    if (i >= 0 && i + 1 < lessons.length) {
      context.toast('Marked as done · on to Lesson ${i + 2}');
      context.replace(
        Routes.listeningLesson,
        args: <String, dynamic>{'lessonId': lessons[i + 1].s('id')},
      );
    } else {
      context.toast('Marked as done · that was the last lesson');
      context.back();
    }
  }

  void _replay() {
    if (!_audio.loaded) return;
    _audio.seek(0);
    _audio.play();
  }

  /// Clears this lesson's answers and starts it again from the audio.
  void _restart() {
    FocusScope.of(context).unfocus();
    Store.I.setKv(_key, null);
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() {
      _answers.clear();
      _checked = false;
      _correct = 0;
      _current = _rows.isEmpty ? 0 : _rows.first.i('number');
    });
    _replay();
    context.toast('Lesson restarted');
  }

  Future<void> _openMenu() async {
    final id = _lesson.s('id');
    final store = Store.I;
    final action = await showLessonMenu(
      context,
      entries: ListeningLessons.menu(store, id),
      currentDone: ListeningLessons.doneIds(store).contains(id),
    );
    if (!mounted || action == null) return;
    switch (action.kind) {
      case 'open':
        if (action.lessonId != id) {
          context.replace(
            Routes.listeningLesson,
            args: <String, dynamic>{'lessonId': action.lessonId},
          );
        }
      case 'restart':
        _restart();
      case 'done':
        _finish(marked: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Replay',
              height: 56,
              fontSize: 15,
              expand: true,
              bg: t.raised,
              onTap: _replay,
            ),
          ),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _checked ? 'Finish lesson' : 'Check answers',
              height: 56,
              radius: 999,
              fontSize: 15,
              onTap: _checked ? _finish : _check,
            ),
          ),
        ],
      ),
      children: [
        ListeningHeader(
          overline: 'Bite-size · Lesson $_number of ${ListeningLessons.all.length}',
          title: _lesson.s('title'),
          onLeading: () => context.back(),
          trailingIcon: AppIcons.more,
          trailingTooltip: 'More',
          onTrailing: _openMenu,
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(AppIcons.school, size: 16, color: t.iconAccent),
                  Text('Lesson', style: TextStyle(fontSize: 13, color: t.iconAccent)),
                ],
              ),
              Text.rich(
                TextSpan(children: boldSpans(_lesson.s('body'))),
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
          ),
        ),
        HeroCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            spacing: 12,
            children: [
              DarkPlayButton(
                playing: _audio.playing,
                loading: _audio.loading,
                onTap: _audio.toggle,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    WaveformBars(
                      count: 36,
                      height: 24,
                      seed: 3,
                      progress: _audio.progress,
                      color: t.heroTrack,
                      playedColor: t.heroFill,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            timeLabel(_audio.position, pad: false),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: t.heroText,
                            ),
                          ),
                        ),
                        Text(
                          timeLabel(_audio.duration, pad: false),
                          style: TextStyle(fontSize: 12, color: t.heroMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SpeedPill(
                speed: _audio.speed,
                onTap: () => setState(() => _audio.speed = nextSpeed(_audio.speed)),
              ),
            ],
          ),
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _lesson.s('instruction'),
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              for (final r in _rows) _row(r, t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> r, AppTokens t) {
    final n = r.i('number');
    final value = (_answers[n] ?? '').trim();
    GapState state;
    if (_checked) {
      state = _isCorrect(r) ? GapState.correct : GapState.wrong;
    } else if (_current == n) {
      state = GapState.active;
    } else {
      state = value.isEmpty ? GapState.empty : GapState.filled;
    }
    return GapLine(
      before: r.s('before'),
      after: r.s('after'),
      gap: GapBox(
        number: n,
        value: _checked && value.isEmpty ? '—' : value,
        state: state,
        height: 32,
        minWidth: 96,
        filledColor: t.surfaceAlt,
        activeBorder: t.primary,
        dashColor: t.isNight ? const Color(0xFF3A3A3A) : t.border,
        correction: r.s('answer'),
        onTap: _checked || _current == n ? null : () => setState(() => _current = n),
        editor: GapEditor(
          key: ValueKey<int>(n),
          width: 100,
          controller: _controllerFor(n),
          onChanged: (v) => _answers[n] = v,
          onSubmitted: (_) => _advance(),
        ),
      ),
    );
  }
}
