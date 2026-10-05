import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/lessons.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../../app/widgets/mascot.dart';
import 'course_widgets.dart';

/// A module's course map: stages → lessons, with progress, XP and a
/// "continue" card. Args `{'module': 'writing'}` (default writing).
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, this.module});

  /// Module to show; null = from route args (default writing).
  final String? module;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> with ContentLangListener {
  String _module = 'writing';
  bool _argsRead = false;

  /// Stages the student opened or closed (null = default: the current one
  /// is open).
  final Map<String, bool> _open = <String, bool>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final m = widget.module ?? context.routeArgs['module'];
    if (m is String && Lessons.has(m)) _module = m;
  }

  void _openLesson(String id) => context.push(Routes.lesson, args: <String, dynamic>{'lesson': id});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final stages = Lessons.stages(_module);
    if (stages.isEmpty) {
      return AppScreen(
        children: [
          TopBar(title: 'Course', onBack: () => context.back()),
          const EmptyState(
            title: 'Course not available',
            message: 'The lessons could not be loaded. Restart the app and try again.',
            icon: AppIcons.school,
          ),
        ],
      );
    }
    final all = Lessons.all(_module);
    final done = Lessons.doneCount(store, module: _module);
    final resume = Lessons.resume(store, _module);
    final current = resume?.stage.s('id') ?? '';
    final name = '${Lessons.name(_module)} Course';

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: name,
          subtitle: '${stages.length} stages · ${all.length} lessons',
          onBack: () => context.back(),
          actions: [_XpPill(xp: Lessons.xp(store), streak: store.streakDays)],
        ),
        _ContinueCard(
          module: _module,
          resume: resume,
          done: done,
          total: all.length,
          onTap: resume == null ? null : () => _openLesson(resume.id),
        ),
        ContentLangSwitch(module: _module),
        for (var i = 0; i < stages.length; i++)
          _StageCard(
            module: _module,
            index: i,
            stage: stages[i],
            open: _open[stages[i].s('id')] ?? (stages[i].s('id') == current || (resume == null && i == 0)),
            currentLesson: resume?.id ?? '',
            onToggle: () => setState(() {
              final id = stages[i].s('id');
              _open[id] = !(_open[id] ?? (id == current || (resume == null && i == 0)));
            }),
            onLesson: _openLesson,
          ),
        Center(
          child: TextButton.icon(
            onPressed: () => context.push(Lessons.guideRoute(_module)),
            icon: Icon(AppIcons.article, size: 18, color: t.textMuted),
            label: Text('Read the full ${Lessons.name(_module)} guide', style: TextStyle(color: t.textMuted)),
          ),
        ),
      ],
    );
  }
}

class _XpPill extends StatelessWidget {
  const _XpPill({required this.xp, required this.streak});

  final int xp;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.glassFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [
            Icon(AppIcons.star, size: 16, color: t.peach),
            Text('$xp XP', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
          Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: [
            Icon(AppIcons.fire, size: 16, color: t.alert),
            Text('$streak', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.module,
    required this.resume,
    required this.done,
    required this.total,
    required this.onTap,
  });

  final String module;
  final LessonRef? resume;
  final int done;
  final int total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final r = resume;
    final finished = r == null;
    final overline = finished
        ? 'Course complete'
        : done == 0
            ? 'Start here'
            : 'Continue';
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          const Positioned.fill(child: DarkBackdrop()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      Text(overline.toUpperCase(),
                          style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: t.peach, fontWeight: FontWeight.w600)),
                      Text(
                        r == null ? 'You finished every lesson' : lessonText(r.lesson['title'], module: module),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w600, color: t.onHeroDark),
                      ),
                      Text(
                        r == null
                            ? '$total lessons · ${Lessons.xp(context.store)} XP earned'
                            : 'Stage ${r.stageIndex + 1} · Lesson ${r.lessonIndex + 1} of ${r.stageLessons}',
                        style: TextStyle(fontSize: 12.5, color: t.onHeroDarkMuted),
                      ),
                      PeachBar(value: total == 0 ? 0 : done / total, track: const Color(0x26FFFFFF)),
                      Text('$done of $total lessons done', style: TextStyle(fontSize: 12, color: t.onHeroDarkMuted)),
                      if (!finished)
                        SizedBox(
                          width: 170,
                          child: PeachButton(label: done == 0 ? 'Start' : 'Continue', height: 44, onTap: onTap),
                        ),
                    ],
                  ),
                ),
                Nexi(finished ? NexiPose.grad : nexiFor(module), height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.module,
    required this.index,
    required this.stage,
    required this.open,
    required this.currentLesson,
    required this.onToggle,
    required this.onLesson,
  });

  final String module;
  final int index;
  final Map<String, dynamic> stage;
  final bool open;
  final String currentLesson;
  final VoidCallback onToggle;
  final ValueChanged<String> onLesson;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final lessons = stage.l('lessons');
    final done = Lessons.doneIn(store, stage);
    final complete = done == lessons.length && lessons.isNotEmpty;
    final (badgeBg, badgeFg) = tintBadge(t, alt: index.isOdd);
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: complete ? t.peach : badgeBg,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: complete
                        ? const Icon(AppIcons.check, size: 22, color: Color(0xFF151515))
                        : Text('${index + 1}',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: badgeFg)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text('Stage ${index + 1} · $done/${lessons.length}',
                            style: TextStyle(fontSize: 11.5, color: t.textMuted, letterSpacing: 0.3)),
                        Text(lessonText(stage['title'], module: module),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25)),
                        if (lessonText(stage['subtitle'], module: module).isNotEmpty)
                          Text(lessonText(stage['subtitle'], module: module),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: t.textMuted, height: 1.3)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: Icon(AppIcons.chevronDown, size: 20, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: PeachBar(value: lessons.isEmpty ? 0 : done / lessons.length, height: 4),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity, height: 4)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        for (var i = 0; i < lessons.length; i++)
                          _LessonRow(
                            module: module,
                            number: i + 1,
                            lesson: lessons[i],
                            done: Lessons.isDone(store, lessons[i].s('id')),
                            current: lessons[i].s('id') == currentLesson,
                            onTap: () => onLesson(lessons[i].s('id')),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.module,
    required this.number,
    required this.lesson,
    required this.done,
    required this.current,
    required this.onTap,
  });

  final String module;
  final int number;
  final Map<String, dynamic> lesson;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final steps = lesson.l('steps').length;
    final interactive = !lesson.b('auto');
    return Material(
      color: current ? t.accentSoft.withValues(alpha: t.isNight ? 1 : 0.7) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? t.peach : Colors.transparent,
                  border: done ? null : Border.all(color: current ? t.blue : t.border, width: current ? 2 : 1.5),
                ),
                child: done
                    ? const Icon(AppIcons.check, size: 17, color: Color(0xFF151515))
                    : Text('$number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textSoft)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(lessonText(lesson['title'], module: module),
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.3)),
                    Text(
                      '${lesson.i('minutes')} min · $steps ${interactive ? 'steps' : 'cards'}'
                      '${interactive ? ' · interactive' : ''}',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(current ? AppIcons.play : AppIcons.chevronRight, size: 18, color: current ? t.text : t.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
