import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C8 · Paragraph Structuring Masterclass (lesson player).
///
/// Progress is user data: kv `writing.lessons.done` (finished lesson ids)
/// and `writing.lessons.pos` ({lessonId: seconds played}).
class MasterclassScreen extends StatefulWidget {
  const MasterclassScreen({super.key});

  @override
  State<MasterclassScreen> createState() => _MasterclassScreenState();
}

class _MasterclassScreenState extends State<MasterclassScreen> {
  late final List<Map<String, dynamic>> _lessons =
      WritingContent.all.m('masterclass').l('lessons');
  late int _index = _firstOpen();
  late int _elapsed = _savedPos(_index);
  Timer? _timer;
  bool _playing = false;

  Set<String> get _done => Store.I.kvSet(WritingKeys.lessonsDone);

  int _firstOpen() {
    final done = _done;
    final i = _lessons.indexWhere((l) => !done.contains(l.s('id')));
    return i < 0 ? (_lessons.isEmpty ? 0 : _lessons.length - 1) : i;
  }

  Map<String, dynamic> get _lesson =>
      _lessons.isEmpty ? <String, dynamic>{} : _lessons[_index];

  int get _duration {
    final m = _lesson.i('minutes');
    return m <= 0 ? 1 : m * 60;
  }

  int _savedPos(int index) {
    if (index >= _lessons.length) return 0;
    final pos = kvMap(Store.I, WritingKeys.lessonsPos);
    final v = pos[_lessons[index].s('id')];
    return v is num ? v.toInt() : 0;
  }

  void _savePos() {
    if (_lessons.isEmpty) return;
    final pos = Map<String, dynamic>.from(kvMap(Store.I, WritingKeys.lessonsPos));
    pos[_lesson.s('id')] = _elapsed;
    Store.I.setKv(WritingKeys.lessonsPos, pos);
  }

  @override
  void initState() {
    super.initState();
    if (_elapsed < _duration) {
      _playing = true;
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_elapsed + 1 >= _duration) {
        _timer?.cancel();
        setState(() {
          _elapsed = _duration;
          _playing = false;
        });
        _complete();
        return;
      }
      setState(() => _elapsed++);
    });
  }

  void _complete() {
    final id = _lesson.s('id');
    if (!_done.contains(id)) {
      Store.I.setKv(WritingKeys.lessonsDone, <String>[..._done, id]);
      context.toast('Lesson complete');
    }
    _savePos();
  }

  void _toggle() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      _savePos();
    } else {
      if (_elapsed >= _duration) _elapsed = 0;
      setState(() => _playing = true);
      _start();
    }
  }

  void _open(int i) {
    if (i == _index) {
      _toggle();
      return;
    }
    final done = _done;
    final unlocked = done.contains(_lessons[i].s('id')) ||
        i == 0 ||
        done.contains(_lessons[i - 1].s('id'));
    if (!unlocked) {
      context.toast('Finish the previous lesson first');
      return;
    }
    _timer?.cancel();
    if (_playing) _savePos();
    setState(() {
      _index = i;
      _elapsed = _savedPos(i);
      if (_elapsed >= _duration) _elapsed = 0;
      _playing = true;
    });
    _start();
  }

  String _statusOf(int i, Set<String> done) {
    if (i == _index) return 'current';
    if (done.contains(_lessons[i].s('id'))) return 'done';
    if (i == 0 || done.contains(_lessons[i - 1].s('id'))) return 'open';
    return 'locked';
  }

  void _openMenu() {
    final t = context.tk;
    final done = _done;
    final learned = _lessons.where((l) => done.contains(l.s('id'))).length;
    showAppSheet<void>(
      context,
      Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Builder(
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Masterclass lessons',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '$learned of ${_lessons.length} done',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
              if (_lessons.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No lessons available yet.',
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _lessons.length; i++)
                        _MenuRow(
                          lesson: _lessons[i],
                          number: i + 1,
                          status: _statusOf(i, done),
                          last: i == _lessons.length - 1,
                          onTap: () {
                            final status = _statusOf(i, done);
                            if (status == 'locked') {
                              ctx.toast('Finish the previous lesson first');
                              return;
                            }
                            Navigator.of(ctx).pop();
                            if (i != _index) _open(i);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_lessons.isNotEmpty) {
      final id = _lesson.s('id');
      final secs = _elapsed;
      Future<void>.microtask(() {
        final pos =
            Map<String, dynamic>.from(kvMap(Store.I, WritingKeys.lessonsPos));
        pos[id] = secs;
        Store.I.setKv(WritingKeys.lessonsPos, pos);
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final done = store.kvSet(WritingKeys.lessonsDone);
    final formula = _lesson.ls('formula');
    final points = _lesson.ls('keyPoints');
    final progress = _elapsed / _duration;
    final activeStep = formula.isEmpty
        ? 0
        : (progress * formula.length).floor().clamp(0, formula.length - 1);
    final learned =
        _lessons.where((l) => done.contains(l.s('id'))).length;

    String statusOf(int i) {
      if (i == _index) return 'current';
      final id = _lessons[i].s('id');
      if (done.contains(id)) return 'done';
      if (i == 0 || done.contains(_lessons[i - 1].s('id'))) return 'open';
      return 'locked';
    }

    final rows = <Widget>[];
    for (var i = 0; i < _lessons.length; i += 3) {
      rows.add(
        Row(
          spacing: 10,
          children: [
            for (var j = i; j < i + 3; j++)
              Expanded(
                child: j < _lessons.length
                    ? GestureDetector(
                        onTap: () => _open(j),
                        child: _LessonPill(
                          lesson: _lessons[j],
                          status: statusOf(j),
                          timeLabel: '${mmss(_elapsed)}/${mmss(_duration)}',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Row(
                    children: [
                      IconBox(
                        icon: AppIcons.back,
                        size: 56,
                        radius: 20,
                        tooltip: 'Back',
                        onTap: () => context.back(),
                      ),
                      const Spacer(),
                      IconBox(
                        icon: AppIcons.grid,
                        size: 56,
                        radius: 20,
                        tooltip: 'Lesson menu',
                        onTap: _openMenu,
                      ),
                    ],
                  ),
                  Text(
                    _lesson.s('title'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _PlayerCard(
                    label: _lesson.s('lessonLabel'),
                    formula: formula,
                    activeStep: activeStep,
                    playing: _playing,
                    elapsed: _elapsed,
                    duration: _duration,
                    onToggle: _toggle,
                  ),
                  ...rows,
                  AppCard(
                    radius: 26,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: [
                        Text(
                          'Key points',
                          style: TextStyle(fontSize: 14, color: t.textMuted),
                        ),
                        for (var i = 0; i < points.length; i++)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 12,
                            children: [
                              Text(
                                (i + 1).toString().padLeft(2, '0'),
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: t.iconAccent,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  points[i],
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 16,
              child: Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: t.raised,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.border),
                ),
                child: LayoutBuilder(
                  builder: (context, box) => Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.primary,
                        shape: BoxShape.circle,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '$learned'),
                            TextSpan(
                              text: '/${_lessons.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: wc(t, 0xFF9A9A9A, 0xFF5A5446),
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: t.onPrimary,
                        ),
                      ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'lessons learned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ),
                    ConstrainedBox(
                      // Leaves the badge + a sliver of label room; the button
                      // only scales down when the bar is too narrow.
                      constraints: BoxConstraints(
                        maxWidth: (box.maxWidth - 124).clamp(0.0, double.infinity).toDouble(),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: SoftButton(
                          label: 'Try exercise',
                          trailing: AppIcons.forward,
                          height: 60,
                          fontSize: 15,
                          onTap: () => context.push(Routes.sentenceBuilder),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.lesson,
    required this.number,
    required this.status,
    required this.last,
    required this.onTap,
  });

  final Map<String, dynamic> lesson;
  final int number;
  final String status;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final locked = status == 'locked';
    final IconData icon = switch (status) {
      'done' => AppIcons.check,
      'current' => AppIcons.play,
      'locked' => AppIcons.lock,
      _ => AppIcons.playCircle,
    };
    final Widget tag = switch (status) {
      'done' => const Tag('Done', tone: TagTone.success),
      'current' => const Tag('Current', tone: TagTone.primary),
      'locked' => const Tag('Locked', tone: TagTone.outline),
      _ => const Tag('Up next', tone: TagTone.soft),
    };
    final subtitle = <String>[
      if (lesson.s('label').isNotEmpty) lesson.s('label'),
      '${lesson.i('minutes')} min',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: t.divider)),
        ),
        child: Row(
          spacing: 12,
          children: [
            IconCircle(
              icon,
              size: 40,
              iconSize: 18,
              bg: status == 'current' ? t.primary : t.surfaceAlt,
              fg: status == 'current'
                  ? t.onPrimary
                  : (locked ? t.textMuted : t.iconAccent),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    '$number. ${lesson.s('title')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: locked ? t.textMuted : t.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            tag,
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.label,
    required this.formula,
    required this.activeStep,
    required this.playing,
    required this.elapsed,
    required this.duration,
    required this.onToggle,
  });

  final String label;
  final List<String> formula;
  final int activeStep;
  final bool playing;
  final int elapsed;
  final int duration;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final chips = <Widget>[];
    for (var i = 0; i < formula.length; i++) {
      if (i > 0) {
        chips.add(Icon(AppIcons.forward, size: 16, color: t.textMuted));
      }
      chips.add(
        WPill(
          formula[i],
          bg: i == activeStep ? t.primary : t.surfaceAlt,
          fg: i == activeStep ? t.onPrimary : t.text,
          fontSize: 13,
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      );
    }
    return Container(
      height: 196,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              Material(
                color: t.isNight
                    ? const Color(0x4D000000)
                    : const Color(0xB3FFFFFF),
                shape: CircleBorder(side: BorderSide(color: t.text, width: 1.5)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onToggle,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(
                      playing ? AppIcons.pause : AppIcons.play,
                      size: 22,
                      color: t.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(spacing: 8, children: chips),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                mmss(elapsed),
                style: TextStyle(
                  fontSize: 12,
                  color: t.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                mmss(duration),
                style: TextStyle(
                  fontSize: 12,
                  color: t.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(
            value: elapsed / duration,
            height: 6,
            track: wc(t, 0xFFF5EEF2, 0xFF2B2B2B),
          ),
        ],
      ),
    );
  }
}

class _LessonPill extends StatelessWidget {
  const _LessonPill({
    required this.lesson,
    required this.status,
    required this.timeLabel,
  });

  final Map<String, dynamic> lesson;
  final String status;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final minutes = lesson.i('minutes').toString().padLeft(2, '0');

    Widget minutesText() => Text.rich(
          TextSpan(
            children: [
              TextSpan(text: minutes),
              TextSpan(
                text: ' min',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          ),
          style: TextStyle(fontSize: 22, color: t.text),
        );

    if (status == 'current') {
      return Container(
        height: 76,
        decoration: BoxDecoration(
          color: wc(t, 0xFFFFFFFF, 0xFF1F1F1F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: wc(t, 0xFFEADFE6, 0xFF3A3A3A),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              lesson.s('label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: t.isNight ? t.primary : t.text,
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'done') {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.primary, width: 1.5),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  minutesText(),
                  Text(
                    lesson.s('label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: 6,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: t.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.check, size: 13, color: t.onPrimary),
            ),
          ),
        ],
      );
    }

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          minutesText(),
          Text(
            lesson.s('label'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}
