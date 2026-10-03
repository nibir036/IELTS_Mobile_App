import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../guides/study_guide_screen.dart';

/// IELTS Reading Complete Guide (assets/content/reading_guide.json).
class ReadingGuideScreen extends StatelessWidget {
  const ReadingGuideScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyGuideScreen(module: 'reading', route: Routes.readingGuide, name: 'Reading Guide');
}
