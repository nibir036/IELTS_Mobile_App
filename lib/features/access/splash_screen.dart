import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/nexted_brand.dart';

/// A1 · Welcome (signed out): nextED, both halves of the app side by side,
/// Get started / Log in. Day and Night from the theme tokens.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // The second line of the headline: peach on Night, deep coral on Day
    // (peach on the light ground is too faint to read).
    final accent = t.isNight ? t.primary : t.warning;

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      gap: 0,
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          PillCta(
            label: 'Get started',
            onTap: () => context.push(Routes.signup),
          ),
          InkWell(
            onTap: () => context.push(Routes.login),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text.rich(
                TextSpan(
                  text: 'I already have an account · ',
                  style: TextStyle(fontSize: 15, color: t.textMuted),
                  children: [
                    TextSpan(
                      text: 'Log in',
                      style: TextStyle(color: t.text, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            const NextedWordmark(size: 28),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.border),
              ),
              child: Text('IELTS · Study abroad', style: TextStyle(fontSize: 12, color: t.textMuted)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Nexi in a soft circle.
        SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 26,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.isNight ? t.surfaceAlt2 : t.surface,
                    border: Border.all(color: t.border),
                  ),
                ),
              ),
              const FloatY(child: Nexi(NexiPose.grad, height: 240)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Ace IELTS.\n'),
              TextSpan(text: 'Study abroad.', style: TextStyle(color: accent)),
            ],
          ),
          style: TextStyle(
            fontSize: 36,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: t.text,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'One app from your first practice test to your offer letter.',
          style: TextStyle(fontSize: 16, height: 1.45, color: t.textSoft),
        ),
        const SizedBox(height: 22),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(
              child: _HalfCard(
                icon: AppIcons.reading,
                title: 'IELTS AI',
                body: 'Practice, mock tests and instant band scores',
              ),
            ),
            Expanded(
              child: _HalfCard(
                icon: AppIcons.flight,
                title: 'Study abroad',
                body: 'Courses, scholarships and applications',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One half of the app: icon, name, one line.
class _HalfCard extends StatelessWidget {
  const _HalfCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.surfaceAlt, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: t.isNight ? t.iconAccent : t.danger),
          ),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.text)),
          Text(body, style: TextStyle(fontSize: 13, height: 1.35, color: t.textMuted)),
        ],
      ),
    );
  }
}
