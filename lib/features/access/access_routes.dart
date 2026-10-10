import 'package:flutter/widgets.dart';

import '../../app/routes.dart';
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
  Routes.micPermission: (_) => const MicPermissionScreen(),
  Routes.legal: (_) => const LegalScreen(),
};
