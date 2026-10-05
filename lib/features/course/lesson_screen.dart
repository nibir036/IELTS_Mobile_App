import 'dart:math' as math;

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
import 'lesson_steps.dart';

/// One lesson as a row of short screens: cover → steps (hook, roadmap,
/// concept cards, checks, examples, reading cards, practice …) →
/// completion with XP. Args `{'lesson': id}`.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with ContentLangListener {
  LessonRef? _ref;
  bool _argsRead = false;

  /// 0 = cover, 1…n = steps, n + 1 = completion.
  int _at = 0;
  bool _forward = true;

  /// Chosen option per step index (choice steps).
  final Map<int, int> _answers = <int, int>{};
  final Stopwatch _watch = Stopwatch();
  bool _wasDone = false;
  bool _recorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final id = context.routeArgs['lesson'];
    if (id is String) _ref = Lessons.find(id);
    if (_ref != null) _wasDone = Lessons.isDone(Store.I, _ref!.id);
  }

  List<Map<String, dynamic>> get _steps => _ref?.lesson.l('steps') ?? const <Map<String, dynamic>>[];

  int get _last => _steps.length + 1;

  bool _isDark(int at) {
    if (at == 0 || at == _last) return true;
    final type = _steps[at - 1].s('type');
    return type == 'concepts' || type == 'sampleFeedback';
  }

  bool get _canNext {
    if (_at == 0 || _at == _last) return true;
    final step = _steps[_at - 1];
    return step.s('type') != 'choice' || _answers.containsKey(_at - 1);
  }

  void _go(int to) {
    if (to < 0 || to > _last) return;
    if (to > 0 && !_watch.isRunning) _watch.start();
    if (to == _last && !_recorded) {
      _recorded = true;
      _watch.stop();
      Lessons.complete(_ref!, minutes: (_watch.elapsed.inSeconds / 60).ceil());
    }
    setState(() {
      _forward = to > _at;
      _at = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ref = _ref;
    if (ref == null) {
      return AppScreen(
        children: [
          TopBar(title: 'Lesson', onBack: () => context.back()),
          const EmptyState(title: 'Lesson not found', message: 'Go back to the course and pick a lesson.', icon: AppIcons.school),
        ],
      );
    }
    final dark = _isDark(_at);
    final n = _steps.length;
    final body = KeyedSubtree(
      key: ValueKey<int>(_at),
      child: _at == 0
          ? LessonCover(ref: ref, steps: _steps, onStart: () => _go(1))
          : _at == _last
              ? LessonComplete(
                  ref: ref,
                  minutes: (_watch.elapsed.inSeconds / 60).ceil().clamp(1, 999).toInt(),
                  firstTime: !_wasDone,
                  correct: _correct(),
                  asked: _asked(),
                  onReview: () => _go(1),
                )
              : LessonStep(
                  module: ref.module,
                  step: _steps[_at - 1],
                  picked: _answers[_at - 1],
                  onPick: (i) => setState(() => _answers[_at - 1] = i),
                ),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 4),
      child: Row(
        spacing: 10,
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => context.back(),
            icon: Icon(AppIcons.back, size: 20, color: dark ? t.onHeroDark : t.text),
          ),
          if (_at > 0 && _at < _last) ...[
            Expanded(child: PeachBar(value: _at / n, track: dark ? const Color(0x26FFFFFF) : null)),
            Text('$_at/$n', style: TextStyle(fontSize: 13, color: dark ? t.onHeroDarkMuted : t.textMuted)),
          ] else
            const Spacer(),
        ],
      ),
    );

    Widget? footer;
    if (_at > 0 && _at < _last) {
      final type = _steps[_at - 1].s('type');
      final label = _at == n
          ? 'Finish'
          : type == 'roadmap'
              ? "Let's start"
              : 'Next';
      footer = Row(
        spacing: 10,
        children: [
          if (_at > 1)
            SizedBox(
              width: 56,
              height: 56,
              child: dark
                  ? DarkGlass(
                      padding: EdgeInsets.zero,
                      radius: 999,
                      onTap: () => _go(_at - 1),
                      child: Icon(AppIcons.chevronLeft, color: t.onHeroDark),
                    )
                  : IconBox(icon: AppIcons.chevronLeft, size: 56, radius: 999, tooltip: 'Previous', onTap: () => _go(_at - 1)),
            ),
          Expanded(
            child: dark
                ? PeachButton(label: label, onTap: _canNext ? () => _go(_at + 1) : null)
                : PrimaryButton(
                    label: label,
                    trailing: AppIcons.forward,
                    height: 56,
                    radius: 999,
                    enabled: _canNext,
                    onTap: () => _go(_at + 1),
                  ),
          ),
        ],
      );
    }

    return PopScope<Object?>(
      canPop: true,
      child: Scaffold(
        backgroundColor: dark ? t.heroDark : t.bg,
        body: Stack(
          children: [
            Positioned.fill(child: dark ? const DarkBackdrop() : const GlassBackdrop(flip: true)),
            SafeArea(
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        final incoming = child.key == ValueKey<int>(_at);
                        final dx = (_forward == incoming ? 0.08 : -0.08);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: SingleChildScrollView(
                        key: ValueKey<int>(_at),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                        child: body,
                      ),
                    ),
                  ),
                  if (footer != null) Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 14), child: footer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _asked() => _steps.where((s) => s.s('type') == 'choice').length;

  int _correct() {
    var n = 0;
    for (final e in _answers.entries) {
      if (e.key < _steps.length && _steps[e.key].i('answer') == e.value) n++;
    }
    return n;
  }
}

/// Screen 1 · Lesson overview: module tile, stage/lesson position, title,
/// what it gives you, time / concepts / practice, Start, and Nexi.
class LessonCover extends StatelessWidget {
  const LessonCover({super.key, required this.ref, required this.steps, required this.onStart});

  final LessonRef ref;
  final List<Map<String, dynamic>> steps;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l = ref.lesson;
    final module = ref.module;
    final concepts = countConcepts(steps);
    final practice = steps.where((s) => s.s('type') == 'choice' || s.s('type') == 'practice').length;
    final intro = lessonText(l['intro'], module: module).isNotEmpty
        ? lessonText(l['intro'], module: module)
        : lessonText(ref.stage['subtitle'], module: module);
    final title = lessonText(l['title'], module: module);
    final english = lessonText((l['title'] is Map) ? <String, dynamic>{'en': (l['title'] as Map)['en'], 'part': (l['title'] as Map)['part']} : l['title']);
    final name = Store.I.current?.firstName ?? '';
    final greeting = lessonText(l['greeting'], module: module);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 12,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFB8A3), Color(0xFFFF8F7A)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(homeModuleIcon(module), color: const Color(0xFF151515), size: 22),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${Lessons.name(module)} · Stage ${ref.stageIndex + 1}',
                      style: TextStyle(fontSize: 13, color: t.onHeroDark, fontWeight: FontWeight.w500)),
                  Text('Lesson ${ref.lessonIndex + 1} of ${ref.stageLessons}',
                      style: TextStyle(fontSize: 12.5, color: t.onHeroDarkMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(title, style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w600, color: t.onHeroDark, letterSpacing: -0.5)),
        if (english != title && english.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(english, style: TextStyle(fontSize: 20, height: 1.2, color: t.onHeroDark.withValues(alpha: 0.85))),
        ],
        const SizedBox(height: 12),
        Text(intro, style: TextStyle(fontSize: 14.5, height: 1.5, color: t.onHeroDarkMuted)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            InfoChip(icon: AppIcons.clock, text: '${l.i('minutes')} min', color: t.onHeroDark),
            InfoChip(icon: AppIcons.bulb, text: '$concepts ${concepts == 1 ? 'concept' : 'concepts'}', color: t.onHeroDark),
            if (practice > 0) InfoChip(icon: AppIcons.pen, text: '$practice practice', color: t.onHeroDark),
            InfoChip(icon: AppIcons.star, text: '+${l.i('xp')} XP', color: t.onHeroDark),
          ],
        ),
        const SizedBox(height: 16),
        // Explanation language for the whole lesson (English / বাংলা / नेपाली / العربية / Indonesia).
        ContentLangSwitch(module: module),
        const SizedBox(height: 16),
        PeachButton(label: Lessons.isDone(Store.I, ref.id) ? 'Review lesson' : 'Start lesson', onTap: onStart),
        const SizedBox(height: 26),
        NexiSays(
          pose: nexiFor(module),
          height: 130,
          text: [
            if (name.isNotEmpty) 'Hi $name!',
            greeting.isNotEmpty ? greeting : "Let's go through this one step at a time.",
          ].join(' '),
        ),
      ],
    );
  }
}

/// Concepts in a lesson: concept cards, contrasts and reading cards.
int countConcepts(List<Map<String, dynamic>> steps) {
  var n = 0;
  for (final s in steps) {
    switch (s.s('type')) {
      case 'concepts':
        n += s.l('cards').length;
      case 'contrast' || 'read':
        n += 1;
    }
  }
  return n;
}

IconData homeModuleIcon(String module) => switch (module) {
      'writing' => AppIcons.pen,
      'speaking' => AppIcons.mic,
      'reading' => AppIcons.reading,
      'listening' => AppIcons.headsetMic,
      'vocab' => AppIcons.translate,
      _ => AppIcons.school,
    };

/// Screen 10 · Completion: Nexi, stats, what you learned, next up.
class LessonComplete extends StatelessWidget {
  const LessonComplete({
    super.key,
    required this.ref,
    required this.minutes,
    required this.firstTime,
    required this.correct,
    required this.asked,
    required this.onReview,
  });

  final LessonRef ref;
  final int minutes;
  final bool firstTime;
  final int correct;
  final int asked;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final module = ref.module;
    final l = ref.lesson;
    final steps = l.l('steps');
    final concepts = countConcepts(steps);
    final learned = <String>[
      for (final x in (l['learned'] as List? ?? const <Object>[])) lessonText(x, module: module),
    ];
    if (learned.isEmpty) {
      for (final s in steps) {
        final title = lessonText(s['title'], module: module);
        if (title.isNotEmpty && !learned.contains(title)) learned.add(title);
      }
    }
    final next = Lessons.next(ref.id);
    final stageDone = Lessons.stageDone(Store.I, ref.stage);
    final pill = TextStyle(fontSize: 12, color: t.onHeroDarkMuted);
    Widget stat(IconData icon, Color c, String value, String label) => Expanded(
          child: DarkGlass(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              spacing: 4,
              children: [
                Icon(icon, color: c, size: 24),
                Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: t.onHeroDark)),
                Text(label, style: pill, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        const Center(child: _Confetti(child: Nexi(NexiPose.grad, height: 150))),
        Text(stageDone && next?.stage.s('id') != ref.stage.s('id') ? 'Stage complete! 🎉' : 'Lesson complete! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: t.onHeroDark)),
        Text(lessonText(l['title'], module: module),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: t.onHeroDarkMuted)),
        Row(
          spacing: 10,
          children: [
            stat(AppIcons.clock, t.onHeroDark, '$minutes min', 'Study time'),
            stat(AppIcons.star, const Color(0xFFFFC857), firstTime ? '+${l.i('xp')}' : '${l.i('xp')}',
                firstTime ? 'XP earned' : 'XP (already earned)'),
            asked > 0
                ? stat(AppIcons.check, t.blue, '$correct/$asked', 'Correct')
                : stat(AppIcons.reading, t.blue, '$concepts/$concepts', 'Concepts'),
          ],
        ),
        if (learned.isNotEmpty)
          DarkGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text("What you've learned", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.onHeroDark)),
                for (final x in learned.take(6))
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(color: t.blue, shape: BoxShape.circle),
                        child: const Icon(AppIcons.check, size: 14, color: Colors.white),
                      ),
                      Expanded(child: Text(x, style: TextStyle(fontSize: 13.5, height: 1.4, color: t.onHeroDark))),
                    ],
                  ),
              ],
            ),
          ),
        if (next != null)
          DarkGlass(
            color: const Color(0x26FFB8A3),
            onTap: () => context.replace(Routes.lesson, args: <String, dynamic>{'lesson': next.id}),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: t.peach, shape: BoxShape.circle),
                  child: const Icon(AppIcons.play, color: Color(0xFF151515)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text('Next up', style: pill),
                      Text(lessonText(next.lesson['title'], module: module),
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.onHeroDark)),
                      Text('Stage ${next.stageIndex + 1} · Lesson ${next.lessonIndex + 1} of ${next.stageLessons} · ~${next.lesson.i('minutes')} min',
                          style: pill),
                    ],
                  ),
                ),
                Icon(AppIcons.chevronRight, color: t.onHeroDark),
              ],
            ),
          ),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: DarkGlass(
                  padding: EdgeInsets.zero,
                  radius: 999,
                  onTap: onReview,
                  child: Center(
                    child: Text('Review lesson', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.onHeroDark)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PeachButton(
                label: next == null ? 'Back to course' : 'Next lesson',
                height: 52,
                onTap: next == null
                    ? () => context.back()
                    : () => context.replace(Routes.lesson, args: <String, dynamic>{'lesson': next.id}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Colour bits falling behind [child], on a loop (still when the system
/// asks for reduced motion).
class _Confetti extends StatefulWidget {
  const _Confetti({required this.child});

  final Widget child;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 0.35;
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_c.value)),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const _colors = <Color>[
    Color(0xFFFF9C82), Color(0xFF5B7CF0), Color(0xFFFFC857), Color(0xFFFFB8A3), Color(0xFF8DA6FF), Color(0xFF7FD1A6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var i = 0; i < 30; i++) {
      final seed = (i * 7919) % 1000 / 1000;
      // Whole-number speeds (1×, 2×) so the loop joins up seamlessly.
      final speed = i.isEven ? 1.0 : 2.0;
      final fall = (t * speed + seed) % 1.0;
      final x = size.width * ((i * 37 % 100) / 100) + math.sin((fall + seed) * math.pi * 4) * 8;
      final y = -12 + (size.height + 24) * fall;
      // Fade in at the top and out at the bottom so pieces don't pop.
      final edge = math.min(1.0, math.min(fall, 1 - fall) * 8);
      p.color = _colors[i % _colors.length].withValues(alpha: edge);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((seed + t * speed) * math.pi * 2);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2, 8, 4), const Radius.circular(1.5)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
