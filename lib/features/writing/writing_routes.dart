import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../tests/full_tests_screens.dart';
import '../tests/question_lists_screens.dart';
import 'essay_history_screen.dart';
import 'ideas_topics_screen.dart';
import 'masterclass_screen.dart';
import 'sentence_bank_screen.dart';
import 'writing_band_report_screen.dart';
import 'writing_editor_screen.dart';
import 'writing_feedback_loading_screen.dart';
import 'writing_guide_screen.dart';
import 'writing_line_review_screen.dart';
import 'writing_rewriter_screen.dart';
import 'writing_sample_answer_screen.dart';
import 'writing_selector_screen.dart';
import 'writing_task1_editor_screen.dart';
import 'writing_template_screen.dart';

/// Section C · Writing.
final Map<String, WidgetBuilder> writingRoutes = <String, WidgetBuilder>{
  Routes.writingSelector: (_) => const WritingSelectorScreen(),
  Routes.writingTests: (_) => const WritingTestsScreen(),
  Routes.writingQuestions: (_) => const WritingQuestionsScreen(),
  Routes.writingTask1Editor: (_) => const WritingTask1EditorScreen(),
  Routes.writingEditor: (_) => const WritingEditorScreen(),
  Routes.writingLineReview: (_) => const WritingLineReviewScreen(),
  Routes.writingBandReport: (_) => const WritingBandReportScreen(),
  Routes.writingRewriter: (_) => const WritingRewriterScreen(),
  Routes.sentenceBuilder: (_) => const SentenceBuilderEntry(),
  Routes.masterclass: (_) => const MasterclassScreen(),
  Routes.essayHistory: (_) => const EssayHistoryScreen(),
  Routes.writingTemplate: (_) => const WritingTemplateScreen(),
  Routes.ideasTopics: (_) => const IdeasTopicsScreen(),
  Routes.writingFeedbackLoading: (_) => const WritingFeedbackLoadingScreen(),
  Routes.writingSampleAnswer: (_) => const WritingSampleAnswerScreen(),
  Routes.writingGuide: (_) => const WritingGuideScreen(),
};
