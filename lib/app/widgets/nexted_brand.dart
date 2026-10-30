import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The nextED logo (assets/branding/nexted_logo_*.png): navy letters on
/// Day, white letters on Night, always with the peach dot.
class NextedWordmark extends StatelessWidget {
  const NextedWordmark({super.key, this.size = 28, this.color});

  /// Size of the letters, as a font size; the picture is scaled to match.
  final double size;

  /// Forces the light (white) or dark (navy) logo for a background that
  /// isn't the page's own: a light colour picks the white logo.
  final Color? color;

  static const Color dot = Color(0xFFFF9C82);

  static const String white = 'assets/branding/nexted_logo_white.png';
  static const String navy = 'assets/branding/nexted_logo_navy.png';

  @override
  Widget build(BuildContext context) {
    final light = color != null ? color!.computeLuminance() > 0.5 : context.tk.isNight;
    return Semantics(
      label: 'nextED',
      image: true,
      excludeSemantics: true,
      child: Image.asset(
        light ? white : navy,
        height: size * 0.82,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}
