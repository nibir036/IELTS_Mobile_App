import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import '../plan/plan_preview_screen.dart';
import '../plan/plan_setup_screen.dart';
import '../plan/quick_check_screen.dart';
import '../plan/study_plan_screen.dart';
import 'analytics_screen.dart';
import 'certificates_screen.dart';
import 'dashboard_empty_screen.dart';
import 'notification_settings_screen.dart';
import 'notifications_screen.dart';
import 'plans_screen.dart';
import 'schedule_screen.dart';
import 'search_screen.dart';

/// Pushed (non-tab) screens of the Home & Account section. Tab screens
/// B1 Dashboard, B3 Module hub and B7 Profile live in the shell.
final Map<String, WidgetBuilder> homeRoutes = <String, WidgetBuilder>{
  Routes.dashboardEmpty: (_) => const DashboardEmptyScreen(),
  Routes.analytics: (_) => const AnalyticsScreen(),
  Routes.schedule: (_) => const ScheduleScreen(),
  Routes.notifications: (_) => const NotificationsScreen(),
  Routes.notificationSettings: (_) => const NotificationSettingsScreen(),
  Routes.search: (_) => const SearchScreen(),
  Routes.certificates: (_) => const CertificatesScreen(),
  Routes.plans: (_) => const PlansScreen(),
  Routes.studyPlan: (_) => const StudyPlanScreen(),
  Routes.studyPlanSetup: (_) => const PlanSetupScreen(),
  Routes.studyPlanPreview: (_) => const PlanPreviewScreen(),
  Routes.studyPlanQuickCheck: (_) => const QuickCheckScreen(),
};
