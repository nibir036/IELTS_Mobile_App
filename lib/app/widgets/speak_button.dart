import 'package:flutter/material.dart';

import '../services/tts.dart';
import 'app_icons.dart';
import 'kit.dart';

/// Speaker button that reads [text] aloud with [Tts]; shows a waveform while
/// that text is playing (tap again to replay).
class SpeakButton extends StatelessWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.size = 40,
    this.radius = 14,
    this.iconSize = 18,
    this.bg,
    this.fg,
    this.circle = false,
    this.tooltip,
  });

  final String text;
  final double size;
  final double radius;
  final double iconSize;
  final Color? bg;
  final Color? fg;
  final bool circle;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: Tts.I.speaking,
      builder: (context, now, _) {
        final on = now == text;
        return IconBox(
          icon: on ? AppIcons.waveform : AppIcons.volume,
          tooltip: on ? 'Play again' : (tooltip ?? 'Play pronunciation'),
          size: size,
          radius: radius,
          iconSize: iconSize,
          bg: bg,
          fg: fg,
          circle: circle,
          onTap: () => Tts.I.speak(text),
        );
      },
    );
  }
}
