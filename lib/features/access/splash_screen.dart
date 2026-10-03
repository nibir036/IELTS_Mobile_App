import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// A1 · Splash & Welcome.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final data = Demo.section('access').m('splash');
    final feature = data.m('featureCard');

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      gap: 28,
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
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
                      style: TextStyle(
                        color: t.text,
                        fontWeight: FontWeight.w500,
                      ),
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
            const BrandMark(size: 40),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'IELTS AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const ThemeToggle(),
          ],
        ),
        SizedBox(
          height: 330,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: _TargetCard(data: data),
              ),
              Positioned(
                right: 0,
                top: 150,
                child: Container(
                  width: 150,
                  height: 150,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: t.raised,
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const IconCircle(AppIcons.speaking, size: 44, iconSize: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            feature.s('eyebrow'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: t.textMuted),
                          ),
                          Text(
                            feature.s('title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 36,
                top: 292,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                  decoration: BoxDecoration(
                    color: t.raised,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: t.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(AppIcons.check, size: 13, color: t.onPrimary),
                      ),
                      Text(
                        data.s('featurePill'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            const Text(
              'Practice smarter.\nScore higher.',
              style: TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w300,
                height: 1.02,
                letterSpacing: -1.4,
              ),
            ),
            Text(
              'Listening, Reading, Writing and Speaking with AI feedback, in one study flow.',
              style: TextStyle(fontSize: 16, height: 1.45, color: t.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bars = data.l('skillBars');
    return HeroCard(
      width: 272,
      height: 272,
      radius: 40,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Target band',
                  style: TextStyle(fontSize: 14, color: t.heroMuted),
                ),
              ),
              Icon(AppIcons.northEast, size: 22, color: t.heroText),
            ],
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: BigNumber(
                data.s('targetBand'),
                size: 104,
                color: t.heroText,
              ),
            ),
          ),
          Row(
            spacing: 8,
            children: [
              for (final b in bars)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      _bar(context, b.s('status')),
                      Text(
                        b.s('short'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.heroText),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, String status) {
    final t = context.tk;
    if (status == 'inProgress') {
      return StripedBox(
        height: 6,
        radius: 3,
        a: t.heroFill,
        b: t.heroTrack,
        stripe: 2,
        gap: 3,
      );
    }
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: status == 'done' ? t.heroFill : t.heroTrack,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
