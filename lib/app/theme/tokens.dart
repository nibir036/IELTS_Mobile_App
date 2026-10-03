import 'package:flutter/material.dart';

/// Design tokens ported from the "IELTS Platform — Day & Night" canvas.
///
/// Every screen reads colours through `context.tk` so the same widget tree
/// renders the Day (pink / lavender, black buttons) and Night (black, cream
/// buttons) looks. Never hard-code a canvas hex in a screen when a token
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
  });

  final bool isNight;

  /// Page background. Day #F5EEF2 · Night #0A0A0A
  final Color bg;

  /// Cards. Day #FFFFFF · Night #151515
  final Color surface;

  /// Icon circles, chips, soft buttons and inputs inside cards.
  /// Day #F5EEF2 · Night #262626
  final Color surfaceAlt;

  /// Secondary soft fill (small buttons / letter badges inside cards).
  /// Day #F5EEF2 · Night #1F1F1F
  final Color surfaceAlt2;

  /// Header icon buttons, bottom nav, raised pills. Day #FFFFFF · Night #1A1A1A
  final Color raised;

  /// Outline of inputs / nav / outlined cards. Day #EADFE6 · Night #2B2B2B
  final Color border;

  /// Hairlines between list rows inside cards. Day #EADFE6 · Night #262626
  final Color divider;

  /// Main text. Day #151515 · Night #FFFFFF
  final Color text;

  /// Secondary text. Day #625C66 · Night #9A9A9A
  final Color textMuted;

  /// Body copy one step softer than [text]. Day #3A353D · Night #D8D8D8
  final Color textSoft;

  /// Disabled / placeholder. Day #B8AEB5 · Night #6A6A6A
  final Color textFaint;

  /// Primary buttons, active tab, selected chip. Day #151515 · Night #F6ECC8
  final Color primary;

  /// Text / icons on [primary]. Day #FFFFFF · Night #151515
  final Color onPrimary;

  /// Icon colour inside [surfaceAlt] circles. Day #151515 · Night #F6ECC8
  final Color iconAccent;

  /// Notification dots, badges, live/recording marks. Day #E0527A · Night #FF7A5C
  final Color alert;
  final Color onAlert;

  /// Progress track / fill on normal cards.
  /// Day #F5EEF2 / #151515 · Night #262626 / #F6ECC8
  final Color track;
  final Color fill;

  /// Hero card: Day gradient #F9D6E2 → #DCDDFA · Night solid cream #F6ECC8.
  final Gradient heroGradient;

  /// Text on hero cards (always dark). #151515
  final Color heroText;

  /// Muted text on hero. Day #625C66 · Night #5A5446
  final Color heroMuted;

  /// Divider on hero. Day rgba(21,21,21,.14) · Night #E0D3A6
  final Color heroDivider;

  /// Progress on hero cards: black fill on a semi-transparent track.
  final Color heroTrack;
  final Color heroFill;

  /// Chips / inner tiles sitting on a hero card.
  /// Day rgba(255,255,255,.6) · Night #FFF8E2
  final Color heroChip;

  /// Accent tints used for tags, highlighted rows, selected answers.
  /// Day pink #F9D6E2 · Night #262626 (with cream text)
  final Color accentSoft;

  /// Second tint. Day lavender #DCDDFA · Night #1F1F1F
  final Color accentSoft2;

  /// Strong accent. Day #F4B8CB · Night #F6ECC8
  final Color accentStrong;

  /// Errors / wrong answers. Day #B63A26 · Night #FF7A5C
  final Color danger;

  /// Error background. Day #FCE0DA · Night #2A1512
  final Color dangerSoft;

  /// Error text on [dangerSoft]. Day #B63A26 · Night #FF9A80
  final Color dangerText;

  /// Correct answers / good. Day #3B3C6B · Night #F6ECC8
  final Color success;

  /// Correct background. Day #EEEFFD · Night #262626
  final Color successSoft;

  /// Warnings / timers running low. Day #B23A5E · Night #F2A14A
  final Color warning;

  /// Diagonal stripe pattern (highlighted bar). Day #151515/#EADFE6 · Night #F6ECC8/#3A372C
  final Color stripeA;
  final Color stripeB;

  static const AppTokens day = AppTokens(
    isNight: false,
    bg: Color(0xFFF5EEF2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5EEF2),
    surfaceAlt2: Color(0xFFF5EEF2),
    raised: Color(0xFFFFFFFF),
    border: Color(0xFFEADFE6),
    divider: Color(0xFFEADFE6),
    text: Color(0xFF151515),
    textMuted: Color(0xFF625C66),
    textSoft: Color(0xFF3A353D),
    textFaint: Color(0xFFB8AEB5),
    primary: Color(0xFF151515),
    onPrimary: Color(0xFFFFFFFF),
    iconAccent: Color(0xFF151515),
    alert: Color(0xFFE0527A),
    onAlert: Color(0xFFFFFFFF),
    track: Color(0xFFF5EEF2),
    fill: Color(0xFF151515),
    heroGradient: LinearGradient(
      begin: Alignment(-0.64, -0.77),
      end: Alignment(0.64, 0.77),
      colors: [Color(0xFFF9D6E2), Color(0xFFDCDDFA)],
    ),
    heroText: Color(0xFF151515),
    heroMuted: Color(0xFF625C66),
    heroDivider: Color(0x24151515),
    heroTrack: Color(0x24151515),
    heroFill: Color(0xFF151515),
    heroChip: Color(0x99FFFFFF),
    accentSoft: Color(0xFFF9D6E2),
    accentSoft2: Color(0xFFDCDDFA),
    accentStrong: Color(0xFFF4B8CB),
    danger: Color(0xFFB63A26),
    dangerSoft: Color(0xFFFCE0DA),
    dangerText: Color(0xFFB63A26),
    success: Color(0xFF3B3C6B),
    successSoft: Color(0xFFEEEFFD),
    warning: Color(0xFFB23A5E),
    stripeA: Color(0xFF151515),
    stripeB: Color(0xFFEADFE6),
  );

  static const AppTokens night = AppTokens(
    isNight: true,
    bg: Color(0xFF0A0A0A),
    surface: Color(0xFF151515),
    surfaceAlt: Color(0xFF262626),
    surfaceAlt2: Color(0xFF1F1F1F),
    raised: Color(0xFF1A1A1A),
    border: Color(0xFF2B2B2B),
    divider: Color(0xFF262626),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFF9A9A9A),
    textSoft: Color(0xFFD8D8D8),
    textFaint: Color(0xFF6A6A6A),
    primary: Color(0xFFF6ECC8),
    onPrimary: Color(0xFF151515),
    iconAccent: Color(0xFFF6ECC8),
    alert: Color(0xFFFF7A5C),
    onAlert: Color(0xFF151515),
    track: Color(0xFF262626),
    fill: Color(0xFFF6ECC8),
    heroGradient: LinearGradient(
      colors: [Color(0xFFF6ECC8), Color(0xFFF6ECC8)],
    ),
    heroText: Color(0xFF151515),
    heroMuted: Color(0xFF5A5446),
    heroDivider: Color(0xFFE0D3A6),
    heroTrack: Color(0x4D5A5446),
    heroFill: Color(0xFF151515),
    heroChip: Color(0xFFFFF8E2),
    accentSoft: Color(0xFF262626),
    accentSoft2: Color(0xFF1F1F1F),
    accentStrong: Color(0xFFF6ECC8),
    danger: Color(0xFFFF7A5C),
    dangerSoft: Color(0xFF2A1512),
    dangerText: Color(0xFFFF9A80),
    success: Color(0xFFF6ECC8),
    successSoft: Color(0xFF262626),
    warning: Color(0xFFF2A14A),
    stripeA: Color(0xFFF6ECC8),
    stripeB: Color(0xFF3A372C),
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
