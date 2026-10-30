import 'package:flutter/material.dart';

/// Nexy, the nextED cat (`assets/mascot/nexi_<pose>.png`).
/// The picture files keep their old `nexi_` names: drop the new Nexy art in
/// over them (same names) and nothing else has to change.
/// wave = full body pointing right (towards a speech bubble), point = pointing left.
enum NexyPose { wave, point, grad, thumbs, writing, reading, speaking, listening }

/// Pose that fits a module ('writing' → [NexyPose.writing], …).
NexyPose nexyFor(String module) => switch (module) {
      'writing' => NexyPose.writing,
      'reading' => NexyPose.reading,
      'speaking' => NexyPose.speaking,
      'listening' => NexyPose.listening,
      'grammar' || 'vocab' => NexyPose.reading,
      _ => NexyPose.wave,
    };

class Nexy extends StatelessWidget {
  const Nexy(this.pose, {super.key, this.height = 120});

  final NexyPose pose;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/mascot/nexi_${pose.name}.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => SizedBox(height: height),
      ),
    );
  }
}

/// Nexy with a speech bubble to his right.
class NexySays extends StatelessWidget {
  const NexySays({
    super.key,
    required this.text,
    this.pose = NexyPose.wave,
    this.height = 110,
    this.bubble,
    this.textColor,
  });

  final String text;
  final NexyPose pose;
  final double height;
  final Color? bubble;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Nexy(pose, height: height),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: height * 0.25),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: bubble ?? Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(fontSize: 13.5, height: 1.4, color: textColor ?? const Color(0xFF151515)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
