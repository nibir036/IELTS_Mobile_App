import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../guides/module_guides.dart';
import 'academic_words_screen.dart';
import 'article_tips_screen.dart';
import 'grammar_course_screen.dart';
import 'irregular_verbs_screen.dart';
import 'phrase_list_screen.dart';
import 'resources_hub_screen.dart';
import 'scoring_criteria_screen.dart';
import 'speaking_room_chat_screen.dart';
import 'vocab_quiz_score_screen.dart';
import 'vocab_quiz_screen.dart';
import 'vocab_vault_screen.dart';

/// Section H routes. H3 (Community) is a bottom-nav tab and lives in the shell.
final Map<String, WidgetBuilder> resourcesRoutes = <String, WidgetBuilder>{
  Routes.resourcesHub: (_) => const ResourcesHubScreen(),
  Routes.vocabVault: (_) => const VocabVaultScreen(),
  Routes.speakingRoomChat: (_) => const SpeakingRoomChatScreen(),
  Routes.vocabQuiz: (_) => const VocabQuizScreen(),
  Routes.vocabQuizScore: (_) => const VocabQuizScoreScreen(),
  Routes.academicWords: (_) => const AcademicWordsScreen(),
  Routes.irregularVerbs: (_) => const IrregularVerbsScreen(),
  Routes.scoringCriteria: (_) => const ScoringCriteriaScreen(),
  Routes.articleTips: (_) => const ArticleTipsScreen(),
  Routes.phrasalVerbs: (_) => const PhraseListScreen(kind: 'phrasalVerbs'),
  Routes.idioms: (_) => const PhraseListScreen(kind: 'idioms'),
  Routes.topicVocab: (_) => const PhraseListScreen(kind: 'topicVocab'),
  Routes.vocabGuide: (_) => const VocabGuideScreen(),
  Routes.grammarGuide: (_) => const GrammarCourseScreen(),
};
