import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
import 'diagnostic_result_screen.dart';
import 'diagnostic_screen.dart';
import 'diagnostic_test_screen.dart';
import 'legal_screen.dart';
import 'login_screen.dart';
import 'mic_permission_screen.dart';
import 'otp_screen.dart';
import 'reset_password_screen.dart';
import 'signup_screen.dart';
import 'splash_screen.dart';
import 'target_band_screen.dart';

/// A · Access & Onboarding routes.
final Map<String, WidgetBuilder> accessRoutes = <String, WidgetBuilder>{
  Routes.splash: (_) => const SplashScreen(),
  Routes.login: (_) => const LoginScreen(),
  Routes.signup: (_) => const SignUpScreen(),
  Routes.otp: (_) => const OtpScreen(),
  Routes.resetPassword: (_) => const ResetPasswordScreen(),
  Routes.targetBand: (_) => const TargetBandScreen(),
  Routes.diagnostic: (_) => const DiagnosticScreen(),
  Routes.micPermission: (_) => const MicPermissionScreen(),
  Routes.legal: (_) => const LegalScreen(),
  Routes.diagnosticTest: (_) => const DiagnosticTestScreen(),
  Routes.diagnosticResult: (_) => const DiagnosticResultScreen(),
};
