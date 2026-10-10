import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../features/access/access_routes.dart';
import '../features/course/course_routes.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/home/home_routes.dart';
import '../features/listening/listening_routes.dart';
import '../features/mock/mock_routes.dart';
import '../features/reading/reading_routes.dart';
import '../features/resources/resources_routes.dart';
import '../features/shell/main_shell.dart';
import '../features/speaking/speaking_routes.dart';
import '../features/writing/writing_routes.dart';
import 'data/store.dart';
import 'nav.dart';
import 'routes.dart';
import 'services/connection_gate.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/readable_text.dart';
import 'theme/theme_controller.dart';

/// Root widget: IELTS AI by nextED.
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saves are batched; write them out before the OS can kill the app,
    // and send unsynced progress to the server. Back in front: fetch changes.
    if (state == AppLifecycleState.resumed) {
      unawaited(SyncService.I.syncNow());
      NotificationService.I.refresh();
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
          title: 'IELTS AI by nextED',
          debugShowCheckedModeBanner: false,
          // Small text a little larger on phones (see ReadableTextScaler).
          // Needs the internet: a "turn on mobile data" screen covers the app while offline.
          builder: (context, child) => readableText(context, ConnectionGate(child: child ?? const SizedBox.shrink())),
          theme: AppTheme.day,
          darkTheme: AppTheme.night,
          themeMode: mode,
          initialRoute: widget.initialRoute ??
              (Store.I.isLoggedIn ? Routes.home : Routes.splash),
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
