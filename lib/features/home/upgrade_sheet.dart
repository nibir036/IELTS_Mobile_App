import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/ai_service.dart';
import '../../app/services/entitlements.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// Title per used-up free allowance (server `feature` codes).
String upgradeTitle(String feature) => switch (feature) {
      'writing_task1' => 'Your free Writing Task 1 is used',
      'writing_task2' => 'Your free Writing Task 2 is used',
      'writing_test' => 'Your free Writing Test is used',
      'speaking_part1' => 'Your free Speaking Part 1 is used',
      'speaking_part2' => 'Your free Speaking Part 2 is used',
      'speaking_part3' => 'Your free Speaking Part 3 is used',
      'speaking_test' => 'Your free Speaking Test is used',
      'mock' => 'Your free Full Mock Test is used',
      'diagnostic' => 'Your free level test is used',
      'pronunciation' => 'Your 5 free pronunciation checks are used',
      'rewrite' => 'Your free Band 8 rewrite is used',
      'quick_check' => 'The quick check is part of Pro',
      'plan' => 'Your 3-day free plan is over',
      _ => 'This is part of Pro',
    };

/// Upgrade sheet: what ran out, what Pro gives, "See Pro plans".
Future<void> showUpgradeSheet(BuildContext context, {String feature = '', String? message}) {
  // The numbers changed (or were stale): fetch them again.
  Entitlements.I.refresh();
  return showAppSheet<void>(context, _UpgradeSheet(feature: feature, message: message));
}

/// Shows the upgrade sheet when [blocked] names a used-up feature.
/// Returns true when the student may go on.
Future<bool> allowedOrUpgrade(BuildContext context, String? blocked) async {
  if (blocked == null) return true;
  await showUpgradeSheet(context, feature: blocked);
  return false;
}

class _UpgradeSheet extends StatelessWidget {
  const _UpgradeSheet({required this.feature, this.message});

  final String feature;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    const perks = <String>[
      'Unlimited AI feedback on writing and speaking',
      'Unlimited full mock tests with band reports',
      'A study plan that adapts every week, with the quick check',
      'Unlimited pronunciation checks and Band 8 rewrites',
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const SizedBox(height: 4),
          Center(child: IconCircle(AppIcons.medal, size: 56)),
          Text(
            upgradeTitle(feature),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500, height: 1.25),
          ),
          Text(
            (message ?? '').isNotEmpty
                ? message!
                : 'The free plan gives you one of each test with AI feedback. Upgrade to Pro to keep practising.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.45, color: t.textSoft),
          ),
          AppCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                for (final p in perks)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Icon(AppIcons.check, size: 18, color: t.success),
                      Expanded(child: Text(p, style: const TextStyle(fontSize: 14, height: 1.35))),
                    ],
                  ),
              ],
            ),
          ),
          PrimaryButton(
            label: 'See Pro plans',
            trailing: AppIcons.forward,
            onTap: () {
              Navigator.of(context).pop();
              context.push(Routes.plans);
            },
          ),
          OutlineButtonX(
            label: 'Not now',
            height: 50,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Shown where a score would be when the AI couldn't score the answer: a
/// used-up free allowance (with "See Pro plans") or an error (with "Try
/// again"). Never a made-up score.
class ScoringFailedPanel extends StatelessWidget {
  const ScoringFailedPanel({
    super.key,
    required this.failure,
    this.onRetry,
    required this.backLabel,
    required this.onBack,
    this.note,
  });

  final ScoringFailed failure;
  final VoidCallback? onRetry;
  final String backLabel;
  final VoidCallback onBack;

  /// e.g. "Your essay is saved as a draft."
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final upgrade = failure.upgrade;
    final offline = failure.code == 'network';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 14,
      children: [
        Center(
          child: IconCircle(
            upgrade ? AppIcons.medal : (offline ? AppIcons.wifiOff : AppIcons.error),
            size: 64,
          ),
        ),
        Text(
          upgrade
              ? upgradeTitle(failure.feature)
              : (offline ? 'You’re offline' : 'We couldn’t score this'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, height: 1.25),
        ),
        Text(
          upgrade
              ? 'The free plan gives you one of each test with AI feedback. Upgrade to Pro to keep practising with feedback.'
              : failure.message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.45, color: t.textSoft),
        ),
        if ((note ?? '').isNotEmpty)
          Text(
            note!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: t.textMuted),
          ),
        const SizedBox(height: 4),
        if (upgrade)
          PrimaryButton(
            label: 'See Pro plans',
            trailing: AppIcons.forward,
            onTap: () => context.push(Routes.plans),
          )
        else if (onRetry != null)
          PrimaryButton(label: 'Try again', leading: AppIcons.refresh, onTap: onRetry),
        OutlineButtonX(label: backLabel, height: 50, onTap: onBack),
      ],
    );
  }
}
