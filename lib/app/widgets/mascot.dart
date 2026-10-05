import 'package:flutter/material.dart';

/// Nexi, the IELTS AI cat (assets/mascot/nexi_<pose>.png).
/// wave = full body pointing right (towards a speech bubble), point = pointing left.
enum NexiPose { wave, point, grad, thumbs, writing, reading, speaking, listening }

/// Pose that fits a module ('writing' → [NexiPose.writing], …).
NexiPose nexiFor(String module) => switch (module) {
      'writing' => NexiPose.writing,
      'reading' => NexiPose.reading,
      'speaking' => NexiPose.speaking,
      'listening' => NexiPose.listening,
      'grammar' || 'vocab' => NexiPose.reading,
      _ => NexiPose.wave,
    };

class Nexi extends StatelessWidget {
  const Nexi(this.pose, {super.key, this.height = 120});

  final NexiPose pose;
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

/// Nexi with a speech bubble to his right.
class NexiSays extends StatelessWidget {
  const NexiSays({
    super.key,
    required this.text,
    this.pose = NexiPose.wave,
    this.height = 110,
    this.bubble,
    this.textColor,
  });

  final String text;
  final NexiPose pose;
  final double height;
  final Color? bubble;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Nexi(pose, height: height),
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
