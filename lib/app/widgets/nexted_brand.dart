import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The nextED wordmark: "next" regular, "ED" bold, and the peach dot.
/// Takes the theme's text colour, so it reads in Day and Night.
class NextedWordmark extends StatelessWidget {
  const NextedWordmark({super.key, this.size = 28, this.color});

  /// Font size of the letters; the dot scales with it.
  final double size;

  /// Overrides the theme's text colour.
  final Color? color;

  static const Color dot = Color(0xFFFF9C82);

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.tk.text;
    final dotSize = size * 0.23;
    return Semantics(
      label: 'nextED',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'next', style: TextStyle(fontWeight: FontWeight.w500)),
                const TextSpan(text: 'ED', style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            style: TextStyle(fontSize: size, height: 1, letterSpacing: -size * 0.025, color: ink),
          ),
          Padding(
            padding: EdgeInsets.only(left: size * 0.09, bottom: size * 0.1),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: const BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}
