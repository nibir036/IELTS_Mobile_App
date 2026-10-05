import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import 'study_guide_screen.dart';

/// IELTS Listening Guide (assets/content/listening_guide.json): the nextED
/// "Zero to Band 9" Listening module - 7 files as 15 chapters, with drills.
class ListeningGuideScreen extends StatelessWidget {
  const ListeningGuideScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyGuideScreen(module: 'listening', route: Routes.listeningGuide, name: 'Listening');
}

/// Vocabulary Lessons (assets/content/vocab_guide.json): the full nextED
/// vocabulary book *Zero to Band 9* - 49 lessons in 6 chapters, with exercises.
class VocabGuideScreen extends StatelessWidget {
  const VocabGuideScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyGuideScreen(module: 'vocab', route: Routes.vocabGuide, name: 'Vocabulary');
}
