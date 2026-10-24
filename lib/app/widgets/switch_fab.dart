import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../theme/tokens.dart';
import 'kit.dart';

/// The peach pill that jumps straight between the app's two halves: from
/// the IELTS side to Study abroad, and back again.
///
/// It floats over the content in the bottom-right corner, clear of the tab
/// bar, and names **where it goes** - a plane and "STUDY ABROAD" on the
/// IELTS side, a book and "IELTS AI" on the Study abroad side.
///
/// Shown only to students who have study-abroad access; otherwise the second
/// half of the app does not exist for them and the button would be a dead
/// end (see `NextedAccess`).
class AppSwitchFab extends StatelessWidget {
  const AppSwitchFab({
    super.key,
    required this.icon,
    required this.text,
    required this.label,
    required this.onTap,
  });

  /// The IELTS side: tap to go to Study abroad.
  const AppSwitchFab.toStudyAbroad({super.key, required this.onTap})
      : icon = Icons.flight_takeoff_rounded,
        text = 'STUDY ABROAD',
        label = 'Go to Study abroad';

  /// The Study abroad side: tap to go back into IELTS.
  const AppSwitchFab.toIelts({super.key, required this.onTap})
      : icon = Icons.menu_book_rounded,
        text = 'IELTS AI',
        label = 'Go to IELTS AI';

  final IconData icon;

  /// The word(s) on the pill.
  final String text;

  /// Spoken by screen readers and shown on a long press.
  final String label;

  final VoidCallback onTap;

  // The same peach as the main buttons ("Build my study plan"), with the
  // same dark ink on it.
  static const _shadow = Color(0xFFFF9C82);
  static const _sheen = Color(0x66FFFFFF);

  static const double _height = 48;
  static const _radius = BorderRadius.all(Radius.circular(_height / 2));

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: kPeachGradient,
            border: Border.all(color: _sheen),
            boxShadow: [
              BoxShadow(
                color: (t.isNight ? Colors.black : _shadow).withValues(alpha: t.isNight ? 0.5 : 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const RoundedRectangleBorder(borderRadius: _radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: kOnPeach.withValues(alpha: 0.08),
              highlightColor: kOnPeach.withValues(alpha: 0.04),
              child: SizedBox(
                height: _height,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: kOnPeach),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: const TextStyle(
                          color: kOnPeach,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the switch pill is showing. It slides away while the student
/// scrolls down (reading) and comes back on the first scroll up, so it
/// never sits on top of what they're reading.
///
/// Put [onScroll] in a `NotificationListener<UserScrollNotification>`
/// around the tabs, and call [show] when the tab changes.
class SwitchFabVisibility extends ValueNotifier<bool> {
  SwitchFabVisibility() : super(true);

  bool onScroll(UserScrollNotification n) {
    // Only up / down scrolling: not the tab swipe or a sideways carousel.
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse) {
      value = false;
    } else if (n.direction == ScrollDirection.forward || n.metrics.pixels <= n.metrics.minScrollExtent) {
      value = true;
    }
    return false;
  }

  void show() => value = true;
}

/// Slides and fades [child] (the switch pill) out of the way while
/// [visible] is false; it can't be tapped while hidden.
class SwitchFabSlot extends StatelessWidget {
  const SwitchFabSlot({super.key, required this.visible, required this.child});

  final ValueListenable<bool> visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = Duration(milliseconds: reduce ? 0 : 220);
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      child: child,
      builder: (context, shown, child) => IgnorePointer(
        ignoring: !shown,
        child: AnimatedSlide(
          offset: shown ? Offset.zero : const Offset(0, 0.8),
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: duration,
            curve: Curves.easeOut,
            child: ExcludeSemantics(excluding: !shown, child: child),
          ),
        ),
      ),
    );
  }
}
