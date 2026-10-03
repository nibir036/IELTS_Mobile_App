import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import 'reading_bank_screen.dart';
import 'reading_guide_screen.dart';
import 'reading_landing_screen.dart';
import 'reading_lesson_screen.dart';
import 'reading_library_screen.dart';
import 'reading_passage_screen.dart';
import 'reading_questions_screen.dart';
import 'reading_solution_screen.dart';
import 'reading_type_lesson_screen.dart';

/// E · Reading screens.
final Map<String, WidgetBuilder> readingRoutes = <String, WidgetBuilder>{
  Routes.readingLibrary: (_) => const ReadingLibraryScreen(),
  Routes.readingPassage: (_) => const ReadingPassageScreen(),
  Routes.readingQuestions: (_) => const ReadingQuestionsScreen(),
  Routes.readingSolution: (_) => const ReadingSolutionScreen(),
  Routes.readingLanding: (_) => const ReadingLandingScreen(),
  Routes.readingLesson: (_) => const ReadingLessonScreen(),
  Routes.readingBank: (_) => const ReadingBankScreen(),
  Routes.readingType: (_) => const ReadingTypeScreen(),
  Routes.readingTypeLesson: (_) => const ReadingTypeLessonScreen(),
  Routes.readingPracticeTests: (_) => const ReadingPracticeTestsScreen(),
  Routes.readingGuide: (_) => const ReadingGuideScreen(),
};
