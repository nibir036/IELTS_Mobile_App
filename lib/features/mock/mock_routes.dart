import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import 'improvement_plan_screen.dart';
import 'mock_answers_screen.dart';
import 'mock_environment_screen.dart';
import 'mock_exit_warning_screen.dart';
import 'mock_listening_screen.dart';
import 'mock_results_screen.dart';
import 'mock_scoring_screen.dart';
import 'mock_speaking_screen.dart';
import 'mock_system_check_screen.dart';
import 'mock_transition_screen.dart';
import 'mock_writing_screen.dart';

/// G · Full Mock Exam routes (G1 lives in the bottom-nav shell, tab 2).
final Map<String, WidgetBuilder> mockRoutes = <String, WidgetBuilder>{
  Routes.mockSystemCheck: (_) => const MockSystemCheckScreen(),
  Routes.mockListening: (_) => const MockListeningScreen(),
  Routes.mockTransition: (_) => const MockTransitionScreen(),
  Routes.mockEnvironment: (_) => const MockEnvironmentScreen(),
  Routes.mockWriting: (_) => const MockWritingScreen(),
  Routes.mockSpeaking: (_) => const MockSpeakingScreen(),
  Routes.mockScoring: (_) => const MockScoringScreen(),
  Routes.mockResults: (_) => const MockResultsScreen(),
  Routes.improvementPlan: (_) => const ImprovementPlanScreen(),
  Routes.mockExitWarning: (_) => const MockExitWarningScreen(),
  Routes.mockAnswers: (_) => const MockAnswersScreen(),
};
