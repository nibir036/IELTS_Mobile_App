import 'package:flutter/material.dart';

import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';

/// Maps a `target` key from home.json to a route name. Empty string when the
/// destination does not exist.
String homeRouteFor(String key) {
  switch (key) {
    case 'readingPassage':
      return Routes.readingPassage;
    case 'readingSolution':
      return Routes.readingSolution;
    case 'readingLanding':
      return Routes.readingLanding;
    case 'readingLesson':
      return Routes.readingLesson;
    case 'listeningLanding':
      return Routes.listeningLanding;
    case 'listeningResults':
      return Routes.listeningResults;
    case 'listeningLesson':
      return Routes.listeningLesson;
    case 'writingSelector':
      return Routes.writingSelector;
    case 'writingGuide':
      return Routes.writingGuide;
    case 'writingCourse':
      return Routes.writingCourse;
    case 'speakingCourse':
      return Routes.speakingCourse;
    case 'readingCourse':
      return Routes.readingCourse;
    case 'listeningCourse':
      return Routes.listeningCourse;
    case 'grammarCourse':
      return Routes.grammarCourse;
    case 'vocabCourse':
      return Routes.vocabCourse;
    case 'readingGuide':
      return Routes.readingGuide;
    case 'speakingGuide':
      return Routes.speakingGuide;
    case 'grammarGuide':
      return Routes.grammarGuide;
    case 'writingTask1Editor':
      return Routes.writingTask1Editor;
    case 'writingEditor':
      return Routes.writingEditor;
    case 'writingBandReport':
      return Routes.writingBandReport;
    case 'writingTemplate':
      return Routes.writingTemplate;
    case 'sentenceBuilder':
      return Routes.sentenceBuilder;
    case 'masterclass':
      return Routes.masterclass;
    case 'speakingHub':
      return Routes.speakingHub;
    case 'speakingEvaluation':
      return Routes.speakingEvaluation;
    case 'pronunciation':
      return Routes.pronunciation;
    case 'myRecordings':
      return Routes.myRecordings;
    case 'mockResults':
      return Routes.mockResults;
    case 'mockSystemCheck':
      return Routes.mockSystemCheck;
    // The onboarding diagnostic was removed: older links open the plan set-up.
    case 'diagnosticTest':
    case 'diagnostic':
    case 'studyPlanSetup':
      return Routes.studyPlanSetup;
    case 'vocabVault':
      return Routes.vocabVault;
    case 'vocabQuiz':
      return Routes.vocabQuiz;
    case 'articleTips':
      return Routes.articleTips;
    case 'scoringCriteria':
      return Routes.scoringCriteria;
    case 'speakingRoomChat':
      return Routes.speakingRoomChat;
    case 'resourcesHub':
      return Routes.resourcesHub;
    case 'targetBand':
      return Routes.targetBand;
    case 'micPermission':
      return Routes.micPermission;
    case 'mockLibrary':
      return Routes.mockLibrary;
    case 'schedule':
      return Routes.schedule;
    case 'analytics':
      return Routes.analytics;
    case 'notifications':
      return Routes.notifications;
    case 'listeningLibrary':
      return Routes.listeningLibrary;
    case 'listeningMiniList':
      return Routes.listeningMiniList;
    case 'readingLibrary':
      return Routes.readingLibrary;
    case 'readingBank':
      return Routes.readingBank;
    case 'readingPracticeTests':
      return Routes.readingPracticeTests;
    case 'cueCardVault':
      return Routes.cueCardVault;
    case 'speakingPart13':
      return Routes.speakingPart13;
    case 'academicWords':
      return Routes.academicWords;
    case 'irregularVerbs':
      return Routes.irregularVerbs;
    case 'phrasalVerbs':
      return Routes.phrasalVerbs;
    case 'idioms':
      return Routes.idioms;
    case 'topicVocab':
      return Routes.topicVocab;
    case 'vocabGuide':
      return Routes.vocabGuide;
    case 'listeningGuide':
      return Routes.listeningGuide;
    case 'writingTests':
      return Routes.writingTests;
    case 'speakingTests':
      return Routes.speakingTests;
    case 'writingQuestions':
      return Routes.writingQuestions;
    case 'speakingQuestions':
      return Routes.speakingQuestions;
    case 'ideasTopics':
      return Routes.ideasTopics;
    case 'writingSampleAnswer':
      return Routes.writingSampleAnswer;
    case 'certificates':
      return Routes.certificates;
    case 'plans':
      return Routes.plans;
    default:
      return '';
  }
}

/// Pushes the route for a home.json `target` key, or toasts "Not available".
void openHomeTarget(BuildContext context, String key) {
  final route = homeRouteFor(key);
  if (route.isEmpty) {
    context.toast('Not available in this version');
  } else {
    context.push(route);
  }
}

/// Pushes a stored route string (tasks, notifications, resume links), or
/// toasts "Not available" when it is empty.
void openStoredRoute(
  BuildContext context,
  String route, [
  Map<String, dynamic>? args,
]) {
  if (route.isEmpty) {
    context.toast('Not available in this version');
    return;
  }
  if (args == null || args.isEmpty) {
    context.push(route);
  } else {
    context.push(route, args: args);
  }
}

/// Opens the result screen of one of the student's attempts.
void openAttempt(BuildContext context, Attempt a) {
  context.push(resultRouteFor(a), args: <String, dynamic>{'attemptId': a.id});
}

/// Landing screen of a skill.
String skillLandingRoute(String skill) {
  switch (skill) {
    case Skill.listening:
      return Routes.listeningLanding;
    case Skill.reading:
      return Routes.readingLanding;
    case Skill.writing:
      return Routes.writingSelector;
    case Skill.speaking:
      return Routes.speakingHub;
    case Skill.mock:
      return Routes.mockSystemCheck;
    case Skill.vocab:
      return Routes.vocabVault;
    default:
      return '';
  }
}

/// Attempts that are real practice (not the "Study session" time filler).
List<Attempt> practiceAttempts(Store store, {String? skill, String? kind}) =>
    store
        .attemptsFor(skill: skill, kind: kind)
        .where((a) => a.kind != 'session')
        .toList();

/// 2300 → "38h 20m".
String studyTimeLabel(int minutes) {
  final hm = Store.hoursMinutes(minutes);
  return '${hm.$1}h ${hm.$2.toString().padLeft(2, '0')}m';
}

/// "+0.5", "0.0", "-0.5".
String signedBand(double v) {
  if (v > 0) return '+${v.toStringAsFixed(1)}';
  if (v < 0) return v.toStringAsFixed(1);
  return '0.0';
}

/// Maps an `icon` key from home.json to an [AppIcons] glyph.
IconData homeIconFor(String key) {
  switch (key) {
    case 'listening':
      return AppIcons.listening;
    case 'reading':
      return AppIcons.reading;
    case 'writing':
      return AppIcons.writing;
    case 'speaking':
      return AppIcons.speaking;
    case 'mic':
      return AppIcons.mic;
    case 'check':
      return AppIcons.check;
    case 'chart':
      return AppIcons.chart;
    case 'doc':
      return AppIcons.doc;
    case 'pen':
      return AppIcons.pen;
    case 'article':
      return AppIcons.article;
    case 'sparkle':
      return AppIcons.sparkle;
    case 'clock':
      return AppIcons.clock;
    case 'chat':
      return AppIcons.chat;
    case 'bookmark':
      return AppIcons.bookmark;
    case 'calendar':
      return AppIcons.calendarMonth;
    case 'medal':
      return AppIcons.medal;
    case 'school':
      return AppIcons.school;
    case 'mock':
      return AppIcons.mock;
    case 'vocab':
      return AppIcons.translate;
    case 'bell':
      return AppIcons.bell;
    default:
      return AppIcons.info;
  }
}

/// Pastel tiles the canvas keeps in both Day and Night.
const Color kPastelLavender = Color(0xFFDCE6FF);
const Color kPastelPink = Color(0xFFFFE2D8);
const Color kInk = Color(0xFF151515);

/// Tinted circle used for schedule tasks / profile stats: Day uses a pink
/// alert tint, Night uses the per-item dark tints from the artboard.
class TintCircle extends StatelessWidget {
  const TintCircle({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

/// Rounded rectangle with a dashed outline (streak "today" cell).
class DashedRRect extends StatelessWidget {
  const DashedRRect({
    super.key,
    required this.color,
    this.height = 34,
    this.radius = 12,
    this.strokeWidth = 2,
  });

  final Color color;
  final double height;
  final double radius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: color,
          radius: radius,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + 5) < metric.length ? d + 5 : metric.length;
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

/// Dashed circle (empty-state band ring).
class DashedRing extends StatelessWidget {
  const DashedRing({
    super.key,
    required this.color,
    this.size = 96,
    this.stroke = 8,
    this.child,
  });

  final Color color;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DashedRingPainter(color: color, stroke: stroke),
        child: Center(child: child),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color, required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final path = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: r,
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + 4) < metric.length ? d + 4 : metric.length;
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) =>
      old.color != color || old.stroke != stroke;
}

/// Simple on/off switch drawn like the canvas (48×28 pill, 22px knob).
class PillSwitch extends StatelessWidget {
  const PillSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? t.primary : t.border,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? t.onPrimary : t.surface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
