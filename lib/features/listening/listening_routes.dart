import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../guides/module_guides.dart';
import 'listening_answer_sheet_screen.dart';
import 'listening_landing_screen.dart';
import 'listening_lesson_screen.dart';
import 'listening_library_screen.dart';
import 'listening_mini_list_screen.dart';
import 'listening_player_screen.dart';
import 'listening_results_screen.dart';
import 'listening_transcript_screen.dart';

/// F · Listening screens.
final Map<String, WidgetBuilder> listeningRoutes = <String, WidgetBuilder>{
  Routes.listeningLibrary: (_) => const ListeningLibraryScreen(),
  Routes.listeningPlayer: (_) => const ListeningPlayerScreen(),
  Routes.listeningAnswerSheet: (_) => const ListeningAnswerSheetScreen(),
  Routes.listeningTranscript: (_) => const ListeningTranscriptScreen(),
  Routes.listeningLanding: (_) => const ListeningLandingScreen(),
  Routes.listeningLesson: (_) => const ListeningLessonScreen(),
  Routes.listeningMiniList: (_) => const ListeningMiniListScreen(),
  Routes.listeningResults: (_) => const ListeningResultsScreen(),
  Routes.listeningGuide: (_) => const ListeningGuideScreen(),
};
