import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// White text/icons sitting on the always-dark (#151515) pills inside hero /
/// cream cards. Same hex in Day and Night.
const Color kOnDarkPill = Color(0xFFFFFFFF);

/// Formats a band score as "7.5" / "8.0".
String bandLabel(double v) => v.toStringAsFixed(1);

/// Onboarding step dots (28×6 bars) used by A6 / A7.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.filled});

  final int count;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 28,
            height: 6,
            decoration: BoxDecoration(
              color: i < filled
                  ? t.primary
                  : (t.isNight ? t.surface : const Color(0xFFE3D6DE)),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Onboarding page title (30px / 500) with a 15px muted subtitle.
class OnboardingTitle extends StatelessWidget {
  const OnboardingTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            height: 1.1,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 15, color: t.textMuted),
        ),
      ],
    );
  }
}

/// Password rule checks shared by Sign-up (strength meter) and Reset.
class PasswordRules {
  const PasswordRules(this.value);

  final String value;

  bool get longEnough => value.length >= 8;
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(value);
  bool get hasSymbol => RegExp(r'[^A-Za-z0-9\s]').hasMatch(value);
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(value);

  /// 0..4 strength score.
  int get score {
    if (value.isEmpty) return 0;
    var s = 0;
    if (longEnough) s++;
    if (hasNumber) s++;
    if (hasSymbol) s++;
    if (hasUpper) s++;
    return s;
  }
}

/// Small inline error line shown under a form field.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key, this.action, this.onAction});

  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final text = Text(
      message,
      style: TextStyle(fontSize: 12, height: 1.35, color: t.dangerText),
    );
    if (action == null) {
      return Padding(padding: const EdgeInsets.only(left: 4), child: text);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          text,
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.text,
                decoration: TextDecoration.underline,
                decorationColor: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted demo hint line ("Demo build: use code 123456").
class DemoHint extends StatelessWidget {
  const DemoHint(this.text, {super.key, this.align = TextAlign.center});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Text(
      text,
      textAlign: align,
      style: TextStyle(fontSize: 12, color: t.textMuted),
    );
  }
}
