import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../tests/full_tests_screens.dart';
import '../tests/question_lists_screens.dart';
import 'cue_card_screen.dart';
import 'cue_card_vault_screen.dart';
import 'my_recordings_screen.dart';
import 'pronunciation_screen.dart';
import 'speaking_evaluation_screen.dart';
import 'speaking_guide_screen.dart';
import 'speaking_hub_screen.dart';
import 'speaking_library_screen.dart';
import 'speaking_part13_screen.dart';
import 'speaking_recording_screen.dart';
import 'speaking_samples_screen.dart';
import 'speaking_transcript_screen.dart';
import 'upload_failed_screen.dart';

/// D · Speaking routes.
final Map<String, WidgetBuilder> speakingRoutes = {
  Routes.speakingHub: (_) => const SpeakingHubScreen(),
  Routes.speakingTests: (_) => const SpeakingTestsScreen(),
  Routes.speakingQuestions: (_) => const SpeakingQuestionsScreen(),
  Routes.speakingPart13: (_) => const SpeakingPart13Screen(),
  Routes.cueCard: (_) => const CueCardScreen(),
  Routes.speakingRecording: (_) => const SpeakingRecordingScreen(),
  Routes.speakingTranscript: (_) => const SpeakingTranscriptScreen(),
  Routes.speakingEvaluation: (_) => const SpeakingEvaluationScreen(),
  Routes.pronunciation: (_) => const PronunciationScreen(),
  Routes.cueCardVault: (_) => const CueCardVaultScreen(),
  Routes.uploadFailed: (_) => const UploadFailedScreen(),
  Routes.myRecordings: (_) => const MyRecordingsScreen(),
  Routes.speakingLibrary: (_) => const SpeakingLibraryScreen(),
  Routes.speakingSamples: (_) => const SpeakingSamplesScreen(),
  Routes.speakingGuide: (_) => const SpeakingGuideScreen(),
};
