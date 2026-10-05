import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';

/// Icon for a lesson JSON `icon` key.
IconData lessonIcon(String key) => switch (key) {
      'target' => AppIcons.target,
      'link' => AppIcons.link,
      'book' => AppIcons.reading,
      'settings' => AppIcons.settings,
      'check' => AppIcons.check,
      'layers' => AppIcons.layers,
      'swap' => AppIcons.swap,
      'play' => AppIcons.play,
      'add' => AppIcons.add,
      'list' => AppIcons.list,
      'doc' => AppIcons.doc,
      'chat' => AppIcons.chat,
      'forward' => AppIcons.forward,
      'clock' => AppIcons.clock,
      'flag' => AppIcons.flag,
      _ => AppIcons.sparkle,
    };

/// Soft numbered-badge colours (background, text). Day: pastel peach / blue
/// with dark ink. Night: a translucent peach / blue tint with bright text, so
/// the number never disappears into the dark card.
(Color, Color) tintBadge(AppTokens t, {bool alt = false}) {
  if (!t.isNight) return (alt ? t.accentSoft2 : t.accentSoft, const Color(0xFF151515));
  final c = alt ? t.blue : t.peach;
  return (c.withValues(alpha: 0.18), c);
}

/// Page background for the dark "hero" lesson screens: deep navy with a
/// faint peach and blue glow.
class DarkBackdrop extends StatelessWidget {
  const DarkBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget glow(Color c, Alignment a) => Align(
          alignment: a,
          child: FractionalTranslation(
            translation: Offset(a.x * 0.4, a.y * 0.3),
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [c.withValues(alpha: 0.28), c.withValues(alpha: 0)]),
              ),
            ),
          ),
        );
    return IgnorePointer(
      child: ColoredBox(
        color: t.heroDark,
        child: Stack(
          children: [
            glow(const Color(0xFFFF9C82), Alignment.topLeft),
            glow(const Color(0xFF5B7CF0), Alignment.bottomRight),
          ],
        ),
      ),
    );
  }
}

/// Frosted panel on a dark lesson screen.
class DarkGlass extends StatelessWidget {
  const DarkGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? const Color(0x14FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: Color(0x1FFFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Peach pill button used on dark lesson screens.
class PeachButton extends StatelessWidget {
  const PeachButton({super.key, required this.label, this.onTap, this.icon = AppIcons.forward, this.height = 54});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          height: height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFFFB8A3), Color(0xFFFF9C82)]),
          ),
          child: InkWell(
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF151515))),
                if (icon != null) Icon(icon, size: 18, color: const Color(0xFF151515)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin peach progress bar on a soft track.
class PeachBar extends StatelessWidget {
  const PeachBar({super.key, required this.value, this.height = 6, this.track});

  final double value;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track ?? t.track)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFFB8A3), Color(0xFFFF7E67)]),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded chip: icon + text.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tk.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        Icon(icon, size: 15, color: c),
        Text(text, style: TextStyle(fontSize: 12.5, color: c)),
      ],
    );
  }
}
