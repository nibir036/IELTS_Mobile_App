import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../features/access/access_routes.dart';
import '../features/course/course_routes.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/home/home_routes.dart';
import '../features/listening/listening_routes.dart';
import '../features/mock/mock_routes.dart';
import '../features/nexted/nexted_routes.dart';
import '../features/reading/reading_routes.dart';
import '../features/resources/resources_routes.dart';
import '../features/shell/main_shell.dart';
import '../features/speaking/speaking_routes.dart';
import '../features/writing/writing_routes.dart';
import 'data/store.dart';
import 'nav.dart';
import 'routes.dart';
import 'data/packs/content_packs.dart';
import 'services/connection_gate.dart';
import 'services/content_gate.dart';
import 'services/nexted_api.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/readable_text.dart';
import 'theme/theme_controller.dart';
import 'widgets/cross_nudge.dart';

/// Root widget: nextED (IELTS AI + Study abroad).
class IeltsAiApp extends StatefulWidget {
  const IeltsAiApp({
    super.key,
    this.initialRoute,
    this.initialArguments,
    this.themeMode,
  });

  /// Start screen override (tests). Default: home when signed in, else splash.
  final String? initialRoute;

  /// Route arguments for [initialRoute] (tests).
  final Object? initialArguments;

  /// Day/Night override (tests). Default: the stored preference.
  final ThemeMode? themeMode;

  @override
  State<IeltsAiApp> createState() => _IeltsAiAppState();
}

class _IeltsAiAppState extends State<IeltsAiApp> with WidgetsBindingObserver {
  late final ThemeController _theme = ThemeController(
    widget.themeMode ?? (Store.I.nightMode ? ThemeMode.dark : ThemeMode.light),
  );

  /// Screens reachable without signing in.
  static const _public = <String>{
    Routes.launch,
    Routes.splash,
    Routes.login,
    Routes.signup,
    Routes.otp,
    Routes.resetPassword,
    Routes.gallery,
    Routes.legal,
  };

  @override
  void initState() {
    super.initState();
    _theme.addListener(_saveTheme);
    WidgetsBinding.instance.addObserver(this);
    // Does this student get the nexted.app button? (Hidden until we know.)
    unawaited(NextedAccess.I.refresh());
    // Signed out by the server (account opened on the other device, device
    // removed): straight to Login, which says why.
    Store.onSignedOutByServer = () {
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(Routes.login, (_) => false);
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saves are batched; write them out before the OS can kill the app,
    // and send unsynced progress to the server. Back in front: fetch changes.
    if (state == AppLifecycleState.resumed) {
      unawaited(SyncService.I.syncNow());
      // Newer content packs (checked at most every 10 minutes).
      unawaited(PackStore.I.refresh());
      NotificationService.I.refresh();
      // Whether this student may open the nexted.app module (25.1).
      unawaited(NextedAccess.I.refresh());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      Store.I.flush();
      unawaited(SyncService.I.flush());
    } else {
      Store.I.flush();
    }
  }

  void _saveTheme() => Store.I.setNightMode(_theme.isNight);

  late final Map<String, WidgetBuilder> _routes = <String, WidgetBuilder>{
    ...accessRoutes,
    ...homeRoutes,
    ...writingRoutes,
    ...speakingRoutes,
    ...readingRoutes,
    ...listeningRoutes,
    ...mockRoutes,
    ...resourcesRoutes,
    ...courseRoutes,
    ...nextedRoutes,
    // Screen gallery is a developer tool: debug builds only.
    if (kDebugMode) Routes.gallery: (_) => const GalleryScreen(),
  };

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _theme.removeListener(_saveTheme);
    _theme.dispose();
    super.dispose();
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    var name = settings.name ?? Routes.splash;
    if (!Store.I.isLoggedIn && !_public.contains(name)) {
      name = Routes.login;
      settings = RouteSettings(name: name, arguments: settings.arguments);
    }
    final tab = Routes.tabRoutes[name];
    WidgetBuilder builder;
    if (tab != null) {
      final argTab = settings.arguments is Map
          ? (settings.arguments as Map)['tab']
          : null;
      final index = argTab is int ? argTab : tab;
      builder = (_) => MainShell(initialIndex: index);
    } else {
      builder = _routes[name] ??
          (_) => const MainShell();
    }
    return MaterialPageRoute<dynamic>(builder: builder, settings: settings);
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      child: ThemeScope(
      controller: _theme,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _theme,
        builder: (context, mode, _) => MaterialApp(
          navigatorKey: appNavigatorKey,
          // IELTS results offer Study abroad (widgets/cross_nudge.dart).
          navigatorObservers: <NavigatorObserver>[CrossNudge.observer],
          title: 'nextED',
          debugShowCheckedModeBanner: false,
          // Small text a little larger on phones (see ReadableTextScaler).
          // Needs the internet: a "turn on mobile data" screen covers the app while offline,
          // and a "getting your lessons ready" screen on the first open after signing in.
          builder: (context, child) => readableText(
            context,
            ConnectionGate(child: ContentGate(child: child ?? const SizedBox.shrink())),
          ),
          theme: AppTheme.day,
          darkTheme: AppTheme.night,
          themeMode: mode,
          // The nextED launch splash first; it moves on to the start screen
          // (signed in) or the welcome screen (signed out).
          initialRoute: widget.initialRoute ?? Routes.launch,
          onGenerateRoute: _onGenerateRoute,
          // Only the one start screen (not '/' underneath '/home').
          onGenerateInitialRoutes: (initial) => <Route<dynamic>>[
            _onGenerateRoute(
              RouteSettings(name: initial, arguments: widget.initialArguments),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
