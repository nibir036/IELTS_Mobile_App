import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../guides/study_guide_screen.dart';

/// IELTS Academic Writing Complete Guide — sir's book (assets/content/writing_guide.json).
class WritingGuideScreen extends StatelessWidget {
  const WritingGuideScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyGuideScreen(module: 'writing', route: Routes.writingGuide, name: 'Writing Guide');
}
