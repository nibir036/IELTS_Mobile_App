import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import 'course_screen.dart';
import 'lesson_screen.dart';

/// Bite-sized courses: one course map per module, and the lesson player.
final Map<String, WidgetBuilder> courseRoutes = <String, WidgetBuilder>{
  Routes.course: (_) => const CourseScreen(),
  Routes.writingCourse: (_) => const CourseScreen(module: 'writing'),
  Routes.speakingCourse: (_) => const CourseScreen(module: 'speaking'),
  Routes.readingCourse: (_) => const CourseScreen(module: 'reading'),
  Routes.listeningCourse: (_) => const CourseScreen(module: 'listening'),
  Routes.grammarCourse: (_) => const CourseScreen(module: 'grammar'),
  Routes.vocabCourse: (_) => const CourseScreen(module: 'vocab'),
  Routes.lesson: (_) => const LessonScreen(),
};
