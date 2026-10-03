import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../guides/study_guide_screen.dart';

/// IELTS Grammar Course (assets/content/grammar_guide.json): 11 chapters in
/// 4 modules, each with a practice chapter of exercises.
class GrammarCourseScreen extends StatelessWidget {
  const GrammarCourseScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyGuideScreen(module: 'grammar', route: Routes.grammarGuide, name: 'Grammar');
}
