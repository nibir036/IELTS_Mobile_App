import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import 'nexted_applications_screen.dart';
import 'nexted_counsellor_screen.dart';
import 'nexted_courses_screen.dart';
import 'nexted_documents_screen.dart';
import 'nexted_shell.dart';
import 'nexted_profile_screen.dart';
import 'nexted_scholarships_screen.dart';

/// Screens of the nexted.app study-abroad module (the app-inside-an-app):
/// the module home, the student profile and documents, the four AI features
/// and the applications with their status tracker.
final Map<String, WidgetBuilder> nextedRoutes = <String, WidgetBuilder>{
  // The study-abroad side opens in its shell (bottom nav): Home tab.
  Routes.nexted: (_) => const NextedShell(),
  Routes.nextedJourney: (_) => const NextedShell(initialIndex: NextedShell.journeyTab),
  Routes.nextedProfile: (_) => const NextedProfileScreen(),
  Routes.nextedDocuments: (_) => const NextedDocumentsScreen(),
  Routes.nextedCounsellor: (_) => const NextedCounsellorScreen(),
  Routes.nextedCourses: (_) => const NextedCoursesScreen(),
  Routes.nextedScholarships: (_) => const NextedScholarshipsScreen(),
  Routes.nextedApplications: (_) => const NextedApplicationsScreen(),
  Routes.nextedApplication: (_) => const NextedApplicationScreen(),
};
