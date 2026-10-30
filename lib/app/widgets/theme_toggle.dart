import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_controller.dart';
import 'app_icons.dart';

/// Day / Night switch: a small pill with a sliding sun / moon knob.
/// Flips the whole app at once (ThemeScope) and the choice is saved.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  static const double width = 58;
  static const double height = 30;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final night = theme.isNight;
    const knob = height - 6;
    const dur = Duration(milliseconds: 320);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final d = reduce ? Duration.zero : dur;

    return Semantics(
      button: true,
      toggled: night,
      label: night ? 'Night mode on. Switch to day mode' : 'Day mode on. Switch to night mode',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          theme.toggle();
        },
        // A slightly larger tap area than the pill itself.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: AnimatedContainer(
            duration: d,
            curve: Curves.easeOutCubic,
            width: width,
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: night
                    ? const <Color>[Color(0xFF1B2A6B), Color(0xFF0B1030)]
                    : const <Color>[Color(0xFFCFE6FF), Color(0xFFFFE3D9)],
              ),
              border: Border.all(
                color: night ? const Color(0x33FFFFFF) : const Color(0x1A0B3AC3),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: night ? const Color(0x664FA3FF) : const Color(0x26FF9C82),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The other mode's icon, faint, on the empty side of the track.
                Align(
                  alignment: night ? Alignment.centerLeft : Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      night ? AppIcons.sun : AppIcons.moon,
                      size: 14,
                      color: night ? const Color(0x99FFD2C4) : const Color(0x800B3AC3),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: d,
                  curve: Curves.easeOutBack,
                  alignment: night ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: d,
                    width: knob,
                    height: knob,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: night ? const Color(0xFFE3EBFF) : Colors.white,
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: d,
                      transitionBuilder: (child, a) => RotationTransition(
                        turns: Tween<double>(begin: 0.75, end: 1).animate(a),
                        child: FadeTransition(opacity: a, child: child),
                      ),
                      child: Icon(
                        night ? AppIcons.moon : AppIcons.sun,
                        key: ValueKey<bool>(night),
                        size: 15,
                        color: night ? const Color(0xFF0B3AC3) : const Color(0xFFFF8A6B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the [ThemeToggle] at the top-right of every screen.
///
/// Wraps the whole navigator (MaterialApp.builder). It adds [height] to the
/// top safe-area inset the screens see, so every screen's own SafeArea
/// leaves a slim band under the status bar, and the toggle floats in that
/// band. The screens' backgrounds still run to the top edge, so the band
/// has no colour of its own and nothing on a screen sits under the toggle.
class ThemeToggleStrip extends StatelessWidget {
  const ThemeToggleStrip({super.key, required this.child});

  final Widget child;

  /// Extra top inset given to every screen.
  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top;
    return Stack(
      children: [
        MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(top: top + height),
            viewPadding: mq.viewPadding.copyWith(top: mq.viewPadding.top + height),
          ),
          child: child,
        ),
        Positioned(
          top: top,
          right: 12,
          height: height,
          child: const Center(child: ThemeToggle()),
        ),
      ],
    );
  }
}
