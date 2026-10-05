import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds Material themes from [AppTokens]. Font: Outfit (as in the canvas).
class AppTheme {
  AppTheme._();

  /// Set to false in tests BEFORE [day]/[night] are first read: google_fonts
  /// would otherwise try to download Outfit over HTTP. Falls back to the
  /// platform default font.
  static bool useGoogleFonts = true;

  /// Fonts for Bangla, Nepali (Devanagari) and Arabic text inside Outfit
  /// (Latin only). Loaded on first use by google_fonts; the platform's own
  /// Noto fonts cover the gap until then (and offline).
  static List<String> get scriptFallback => <String>[
        for (final w in const <FontWeight>[FontWeight.w400, FontWeight.w600]) ...<String?>[
          GoogleFonts.notoSansBengali(fontWeight: w).fontFamily,
          GoogleFonts.notoSansDevanagari(fontWeight: w).fontFamily,
          GoogleFonts.notoNaskhArabic(fontWeight: w).fontFamily,
        ].whereType<String>(),
      ];

  static final ThemeData day = _build(AppTokens.day, Brightness.light);
  static final ThemeData night = _build(AppTokens.night, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    );
    final fonts = useGoogleFonts;
    final textTheme = (fonts ? GoogleFonts.outfitTextTheme(base.textTheme) : base.textTheme).apply(
      bodyColor: t.text,
      displayColor: t.text,
      fontFamilyFallback: fonts ? scriptFallback : null,
    );
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      secondary: t.accentStrong,
      onSecondary: t.heroText,
      error: t.danger,
      onError: t.onAlert,
      surface: t.surface,
      onSurface: t.text,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[t],
      // InkRipple: InkSparkle's shader is heavy on budget GPUs.
      splashFactory: InkRipple.splashFactory,
      // Pushed screens fade + slide in; iOS keeps its swipe-back gesture.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      highlightColor: Colors.transparent,
      dividerColor: t.divider,
      iconTheme: IconThemeData(color: t.text, size: 22),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.alert,
        selectionColor: t.accentStrong.withValues(alpha: 0.5),
        selectionHandleColor: t.alert,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.primary,
        contentTextStyle: fonts
            ? GoogleFonts.outfit(color: t.onPrimary, fontSize: 14)
            : TextStyle(color: t.onPrimary, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.sheet,
        modalBackgroundColor: t.sheet,
        showDragHandle: true,
        dragHandleColor: t.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
    );
  }
}

/// Page transition for pushed screens (Android, web, desktop): the new page
/// fades in while sliding from the right; the page underneath drifts left.
/// iOS keeps the native swipe-back transition.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static final Animatable<Offset> _inSlide = Tween<Offset>(
    begin: const Offset(0.12, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));
  static final Animatable<double> _inFade = CurveTween(curve: const Interval(0, 0.7, curve: Curves.easeOut));
  static final Animatable<Offset> _outSlide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.06, 0),
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: secondaryAnimation.drive(_outSlide),
      child: FadeTransition(
        opacity: animation.drive(_inFade),
        child: SlideTransition(position: animation.drive(_inSlide), child: child),
      ),
    );
  }
}
