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
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        showDragHandle: true,
        dragHandleColor: t.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
    );
  }
}
