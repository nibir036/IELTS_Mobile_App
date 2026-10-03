import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../guides/study_guide_screen.dart';

/// IELTS Speaking Complete Guide — sir's book (assets/content/speaking_guide.json).
class SpeakingGuideScreen extends StatelessWidget {
  const SpeakingGuideScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyGuideScreen(module: 'speaking', route: Routes.speakingGuide, name: 'Speaking Guide');
}
