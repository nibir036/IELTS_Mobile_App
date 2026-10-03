import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'profile_sheet.dart';
import 'widgets.dart';

/// B2 · Dashboard — first-time empty state (before the diagnostic).
class DashboardEmptyScreen extends StatelessWidget {
  const DashboardEmptyScreen({super.key});

  @override
  Widget build(BuildContext context) => const FirstTimeDashboard();
}

/// Body of the first-time dashboard, shared by the B2 route and the Home tab
/// (B1) while the student has no activity yet.
class FirstTimeDashboard extends StatelessWidget {
  const FirstTimeDashboard({super.key, this.bottomPadding = 32});

  final double bottomPadding;

  static bool _stepDone(Store store, String check) {
    final acc = store.current;
    switch (check) {
      case 'account':
        return acc != null;
      case 'targetBand':
        return acc?.targetBand != null;
      case 'examDate':
        return acc?.examDate != null;
      case 'mic':
        return acc?.profile['micAllowed'] == true;
      case 'practice':
        return store.hasActivity;
      case 'speaking':
        return store.attemptsFor(skill: Skill.speaking).isNotEmpty;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final acc = store.current;
    final data = Demo.section('home').m('firstTime');
    final rawSteps = data.l('checklist');
    final cards = data.l('emptyCards');
    // Length of the short onboarding diagnostic (access.json).
    final diagMinutes =
        Demo.section('access').m('diagnostic').m('diagnosticTest').i('totalMinutes');
    final diagnosticMinutes = diagMinutes > 0 ? diagMinutes : 45;

    final steps = <Map<String, dynamic>>[];
    var foundCurrent = false;
    for (final s in rawSteps) {
      final isDone = _stepDone(store, s.s('check'));
      final isCurrent = !isDone && !foundCurrent;
      if (isCurrent) foundCurrent = true;
      steps.add(<String, dynamic>{...s, 'done': isDone, 'current': isCurrent});
    }
    final doneCount = steps.where((s) => s.b('done')).length;

    final target = acc?.targetBand;
    final exam = acc?.examDate;
    final heroParts = <String>[
      target == null ? 'Set your target band' : 'Target ${Store.formatBand(target)}',
      if (exam != null) 'exam ${Store.weekdayDate(exam)}',
    ];

    return AppScreen(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding),
      gap: 16,
      children: [
        // Greeting + bell
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Store.greeting(),
                    style: TextStyle(fontSize: 14, color: t.textMuted),
                  ),
                  Text(
                    'Hi, ${acc?.firstName ?? 'there'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.bell,
              tooltip: 'Notifications',
              size: 56,
              radius: 20,
              iconSize: 22,
              dot: store.unreadNotifications > 0,
              onTap: () => context.push(Routes.notifications),
            ),
          ],
        ),

        // Hero: band starts here
        HeroCard(
          padding: const EdgeInsets.all(20),
          radius: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                spacing: 16,
                children: [
                  DashedRing(
                    color: t.heroText.withValues(alpha: 0.35),
                    size: 96,
                    stroke: 8,
                    child: Text(
                      '–.–',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: t.heroText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your band score\nstarts here',
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.2,
                            color: t.heroText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => showEditProfileSheet(context),
                          child: Text(
                            heroParts.join(' · '),
                            style: TextStyle(fontSize: 13, color: t.heroMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              PrimaryButton(
                label: 'Take the $diagnosticMinutes-min diagnostic',
                trailing: AppIcons.forward,
                height: 52,
                radius: 999,
                fontSize: 15,
                bg: kInk,
                fg: const Color(0xFFF6ECC8),
                onTap: () => context.push(Routes.diagnosticTest),
              ),
            ],
          ),
        ),

        // Getting started checklist
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Text(
                        'Getting started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$doneCount of ${steps.length}',
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              for (final s in steps) _StepRow(step: s),
            ],
          ),
        ),

        // Empty cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            for (final c in cards) Expanded(child: _EmptyCard(card: c)),
          ],
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final done = step.b('done');
    final current = step.b('current');
    Widget box;
    if (done) {
      box = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: t.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(AppIcons.check, size: 16, color: t.onPrimary),
      );
    } else {
      box = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            width: 1.5,
            color: current
                ? t.primary
                : (t.isNight ? const Color(0xFF3A3A3A) : t.border),
          ),
        ),
      );
    }
    return InkWell(
      onTap: done
          ? null
          : (step.s('check') == 'practice'
              ? () => context.push(Routes.diagnosticTest)
              : () => openHomeTarget(context, step.s('target'))),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 44,
        child: Row(
          spacing: 12,
          children: [
            box,
            Expanded(
              child: Text(
                step.s('title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: current ? t.text : t.textMuted,
                  decoration:
                      done ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: t.textMuted,
                ),
              ),
            ),
            if (current)
              Icon(AppIcons.chevronRight, size: 20, color: t.iconAccent),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.card});

  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: () => openHomeTarget(context, card.s('target')),
      borderRadius: BorderRadius.circular(24),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: t.isNight ? const Color(0xFF333333) : t.border,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 18,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.raised,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  homeIconFor(card.s('icon')),
                  size: 20,
                  color: t.textMuted,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(card.s('title'), style: const TextStyle(fontSize: 15)),
                  Text(
                    card.s('subtitle'),
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + 4) < metric.length ? d + 4 : metric.length;
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}
