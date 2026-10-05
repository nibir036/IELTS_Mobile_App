import 'package:flutter/material.dart';

/// Design tokens: frosted peach (Nexi's fur) and frosted blue (his hoodie).
///
/// Every screen reads colours through `context.tk` so the same widget tree
/// renders the Day (warm white, glass cards, black buttons) and Night (deep
/// navy, glass cards, peach buttons) looks. Never hard-code a canvas hex in a screen when a token
/// below covers it.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.isNight,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceAlt2,
    required this.raised,
    required this.border,
    required this.divider,
    required this.text,
    required this.textMuted,
    required this.textSoft,
    required this.textFaint,
    required this.primary,
    required this.onPrimary,
    required this.iconAccent,
    required this.alert,
    required this.onAlert,
    required this.track,
    required this.fill,
    required this.heroGradient,
    required this.heroText,
    required this.heroMuted,
    required this.heroDivider,
    required this.heroTrack,
    required this.heroFill,
    required this.heroChip,
    required this.accentSoft,
    required this.accentSoft2,
    required this.accentStrong,
    required this.danger,
    required this.dangerSoft,
    required this.dangerText,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.stripeA,
    required this.stripeB,
    required this.peach,
    required this.blue,
    required this.blobA,
    required this.blobB,
    required this.glassBorder,
    required this.glassFill,
    required this.sheet,
    required this.heroDark,
    required this.onHeroDark,
    required this.onHeroDarkMuted,
  });

  final bool isNight;

  /// Page background
  final Color bg;

  /// Cards
  final Color surface;

  /// Icon circles, chips, soft buttons and inputs inside cards.
  ///
  final Color surfaceAlt;

  /// Secondary soft fill (small buttons / letter badges inside cards).
  ///
  final Color surfaceAlt2;

  /// Header icon buttons, bottom nav, raised pills
  final Color raised;

  /// Outline of inputs / nav / outlined cards
  final Color border;

  /// Hairlines between list rows inside cards
  final Color divider;

  /// Main text
  final Color text;

  /// Secondary text
  final Color textMuted;

  /// Body copy one step softer than [text]
  final Color textSoft;

  /// Disabled / placeholder
  final Color textFaint;

  /// Primary buttons, active tab, selected chip
  final Color primary;

  /// Text / icons on [primary]
  final Color onPrimary;

  /// Icon colour inside [surfaceAlt] circles
  final Color iconAccent;

  /// Notification dots, badges, live/recording marks
  final Color alert;
  final Color onAlert;

  /// Progress track / fill on normal cards.
  ///
  final Color track;
  final Color fill;

  /// Hero card: dark navy with a peach and blue glow (the course style).
  final Gradient heroGradient;

  /// Text on hero cards (always light).
  final Color heroText;

  /// Muted text on hero
  final Color heroMuted;

  /// Divider on hero
  final Color heroDivider;

  /// Progress on hero cards: peach fill on a translucent white track.
  final Color heroTrack;
  final Color heroFill;

  /// Chips / inner tiles sitting on a hero card.
  ///
  final Color heroChip;

  /// Accent tints used for tags, highlighted rows, selected answers.
  ///
  final Color accentSoft;

  /// Second tint
  final Color accentSoft2;

  /// Strong accent
  final Color accentStrong;

  /// Errors / wrong answers
  final Color danger;

  /// Error background
  final Color dangerSoft;

  /// Error text on [dangerSoft]
  final Color dangerText;

  /// Correct answers / good
  final Color success;

  /// Correct background
  final Color successSoft;

  /// Warnings / timers running low
  final Color warning;

  /// Diagonal stripe pattern (highlighted bar)
  final Color stripeA;
  final Color stripeB;

  /// Brand peach (frosted orange / baby pink) and brand blue - Nexi's fur
  /// and hoodie. Use for accents, progress and glass tints.
  final Color peach;
  final Color blue;

  /// Soft colour blobs painted behind every page so the frosted cards
  /// have something to blur over.
  final Color blobA;
  final Color blobB;

  /// Hairline highlight around glass cards, and their frosted fill.
  final Color glassBorder;
  final Color glassFill;

  /// Opaque surface for sheets, dialogs and menus (glass would show the
  /// page through them).
  final Color sheet;

  /// Dark frosted "hero" screens (lesson cover, key concepts, AI feedback,
  /// completion) in both Day and Night, and the text on them.
  final Color heroDark;
  final Color onHeroDark;
  final Color onHeroDarkMuted;

  static const AppTokens day = AppTokens(
    isNight: false,
    bg: Color(0xFFFBF5F3),
    surface: Color(0xF2FFFFFF),
    surfaceAlt: Color(0xFFFFF1EC),
    surfaceAlt2: Color(0xFFEEF3FF),
    raised: Color(0xD9FFFFFF),
    border: Color(0xFFF0E2DD),
    divider: Color(0xFFF2E6E2),
    text: Color(0xFF151515),
    textMuted: Color(0xFF6B6270),
    textSoft: Color(0xFF3A353D),
    textFaint: Color(0xFFBBB0B4),
    primary: Color(0xFF151515),
    onPrimary: Color(0xFFFFFFFF),
    iconAccent: Color(0xFF151515),
    alert: Color(0xFFFF6B57),
    onAlert: Color(0xFFFFFFFF),
    track: Color(0xFFF6E8E4),
    fill: Color(0xFFFF7E67),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C2036), Color(0xFF131624)],
    ),
    heroText: Color(0xFFFFFFFF),
    heroMuted: Color(0xFFB3B7C9),
    heroDivider: Color(0x24FFFFFF),
    heroTrack: Color(0x26FFFFFF),
    heroFill: Color(0xFFFF9C82),
    heroChip: Color(0x1AFFFFFF),
    accentSoft: Color(0xFFFFE2D8),
    accentSoft2: Color(0xFFDCE6FF),
    accentStrong: Color(0xFFFFB8A3),
    danger: Color(0xFFC2412D),
    dangerSoft: Color(0xFFFFE1DB),
    dangerText: Color(0xFFC2412D),
    success: Color(0xFF2F4FC2),
    successSoft: Color(0xFFE6EDFF),
    warning: Color(0xFFD9573B),
    stripeA: Color(0xFF151515),
    stripeB: Color(0xFFF0E2DD),
    peach: Color(0xFFFF9C82),
    blue: Color(0xFF5B7CF0),
    blobA: Color(0xFFFFCDBD),
    blobB: Color(0xFFC6D6FF),
    glassBorder: Color(0xCCFFFFFF),
    glassFill: Color(0xB8FFFFFF),
    sheet: Color(0xFFFFFBFA),
    heroDark: Color(0xFF151827),
    onHeroDark: Color(0xFFFFFFFF),
    onHeroDarkMuted: Color(0xFFB3B7C9),
  );

  static const AppTokens night = AppTokens(
    isNight: true,
    bg: Color(0xFF0D0F1A),
    surface: Color(0xFF1A1D2C),
    surfaceAlt: Color(0xFF22263A),
    surfaceAlt2: Color(0xFF1A1E30),
    raised: Color(0xE61A1D2C),
    border: Color(0xFF2A2E44),
    divider: Color(0xFF23273A),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF9AA0B4),
    textSoft: Color(0xFFD9DBE6),
    textFaint: Color(0xFF5F6478),
    primary: Color(0xFFFFB4A0),
    onPrimary: Color(0xFF151515),
    iconAccent: Color(0xFFFFB4A0),
    alert: Color(0xFFFF8A6B),
    onAlert: Color(0xFF151515),
    track: Color(0xFF23273A),
    fill: Color(0xFFFF9C85),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C2036), Color(0xFF131624)],
    ),
    heroText: Color(0xFFFFFFFF),
    heroMuted: Color(0xFFB3B7C9),
    heroDivider: Color(0x24FFFFFF),
    heroTrack: Color(0x26FFFFFF),
    heroFill: Color(0xFFFF9C82),
    heroChip: Color(0x1AFFFFFF),
    accentSoft: Color(0xFF2E2433),
    accentSoft2: Color(0xFF1E2640),
    accentStrong: Color(0xFFFFB4A0),
    danger: Color(0xFFFF8A6B),
    dangerSoft: Color(0xFF33191A),
    dangerText: Color(0xFFFFA08A),
    success: Color(0xFF9DB8FF),
    successSoft: Color(0xFF1E2640),
    warning: Color(0xFFF2A14A),
    stripeA: Color(0xFFFFB4A0),
    stripeB: Color(0xFF2A2E44),
    peach: Color(0xFFFFB4A0),
    blue: Color(0xFF8DA6FF),
    blobA: Color(0xFF5A2E2E),
    blobB: Color(0xFF1E2E66),
    glassBorder: Color(0x24FFFFFF),
    glassFill: Color(0x14FFFFFF),
    sheet: Color(0xFF171A28),
    heroDark: Color(0xFF181B2B),
    onHeroDark: Color(0xFFFFFFFF),
    onHeroDarkMuted: Color(0xFFA9AEC2),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppTokensContext on BuildContext {
  /// Current Day/Night design tokens.
  AppTokens get tk =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.day;
}
