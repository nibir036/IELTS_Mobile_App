import 'package:flutter/material.dart';

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
