import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// A7 · Diagnostic Assessment Selector.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final Map<String, dynamic> _data = Demo.section('access').m('diagnostic');

  /// 0 = diagnostic test (recommended), 1 = build my own plan.
  int _choice = 0;
  final Set<String> _skills = <String>{};
  int? _minutes;

  @override
  void initState() {
    super.initState();
    final profile = Store.I.current?.profile ?? <String, dynamic>{};
    if (profile['diagnostic'] == 'custom') _choice = 1;
    final focus = profile['focusSkills'];
    if (focus is List) {
      for (final f in focus) {
        if (f is String) _skills.add(f);
      }
    }
    final mins = profile['dailyMinutes'];
    if (mins is num) _minutes = mins.round();
  }

  void _continue() {
    final order = _data
        .m('customPlan')
        .l('skills')
        .map((e) => e.s('id'))
        .toList();
    final focus = <String>[
      for (final id in order)
        if (_skills.contains(id)) id,
    ];
    final options = _data.m('customPlan').ld('dailyMinuteOptions');
    final fallback = options.isNotEmpty ? options.first.round() : 30;
    Store.I.updateProfile(<String, dynamic>{
      'diagnostic': _choice == 0 ? 'diagnostic' : 'custom',
      'focusSkills': focus,
      'dailyMinutes': _minutes ?? fallback,
    });
    // The diagnostic runs after the mic step (A8 needs the mic for Speaking);
    // the custom plan goes straight Home from A8.
    if (_choice == 0) {
      context.push(
        Routes.micPermission,
        args: <String, dynamic>{'next': Routes.diagnosticTest},
      );
    } else {
      context.push(Routes.micPermission);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final test = _data.m('diagnosticTest');
    final plan = _data.m('customPlan');
    final sections = test.l('sections');
    final planSkills = plan.l('skills');
    final minuteOptions = plan.ld('dailyMinuteOptions');

    return AppScreen(
      gap: 18,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      footer: PrimaryButton(
        label: _choice == 0 ? 'Start diagnostic' : 'Continue with my plan',
        trailing: AppIcons.forward,
        fontSize: 17,
        onTap: _continue,
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              onTap: () => context.back(),
            ),
            const Expanded(
              child: Center(child: StepDots(count: 3, filled: 2)),
            ),
            const SizedBox(width: 44),
          ],
        ),
        const OnboardingTitle(
          title: 'How do you want\nto start?',
          subtitle: 'Find your level first, or build a plan yourself.',
        ),
        _ChoiceCard(
          selected: _choice == 0,
          onTap: () => setState(() => _choice = 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: kPeachGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Recommended',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnPeach),
                    ),
                  ),
                  const Spacer(),
                  _Radio(selected: _choice == 0),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text(
                    'Take a diagnostic test',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: t.heroText,
                    ),
                  ),
                  Text(
                    test.s('summary'),
                    style: TextStyle(fontSize: 14, color: t.heroMuted),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  for (var r = 0; r < sections.length; r += 2)
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: _SectionTile(section: sections[r])),
                        Expanded(
                          child: r + 1 < sections.length
                              ? _SectionTile(section: sections[r + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        _ChoiceCard(
          selected: _choice == 1,
          onTap: () => setState(() => _choice = 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Text(
                          'Build my own plan',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                          ),
                        ),
                        Text(
                          'Pick skills and daily study time',
                          style: TextStyle(fontSize: 14, color: t.heroMuted),
                        ),
                      ],
                    ),
                  ),
                  _Radio(selected: _choice == 1),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in planSkills)
                    _PlanChip(
                      label: s.s('label'),
                      selected: _skills.contains(s.s('id')),
                      filled: true,
                      onTap: () => setState(() {
                        _choice = 1;
                        final id = s.s('id');
                        if (!_skills.remove(id)) _skills.add(id);
                      }),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Daily',
                    style: TextStyle(fontSize: 13, color: t.heroMuted),
                  ),
                  for (final m in minuteOptions)
                    _PlanChip(
                      label: '${m.round()} min',
                      selected: _minutes == m.round(),
                      filled: false,
                      onTap: () => setState(() {
                        _choice = 1;
                        _minutes = m.round();
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            spacing: 10,
            children: [
              Icon(AppIcons.info, size: 18, color: t.textMuted),
              Expanded(
                child: Text(
                  'You can retake the diagnostic any time from Profile.',
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(
        gradient: t.heroGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: selected ? t.peach : const Color(0x1FFFFFFF),
          width: 2,
        ),
        boxShadow: t.isNight
            ? null
            : const [BoxShadow(color: Color(0x2E151827), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned.fill(child: HeroGlow()),
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: t.heroText),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (selected) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: t.peach, shape: BoxShape.circle),
        child: const Icon(AppIcons.check, size: 14, color: kOnPeach),
      );
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: t.heroMuted,
          width: 2,
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.heroChip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            section.s('skill'),
            style: TextStyle(fontSize: 12, color: t.heroMuted),
          ),
          Text(
            '${section.i('minutes')} min',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: t.heroText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip inside the "Build my own plan" card. [filled] chips sit on a light
/// fill (skills); outline chips are the daily-minutes options.
class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.label,
    required this.selected,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final Color bg;
    if (selected) {
      bg = t.peach;
    } else if (filled) {
      bg = t.heroChip;
    } else {
      bg = Colors.transparent;
    }
    final BorderSide side = selected || filled
        ? BorderSide.none
        : BorderSide(
            color: t.heroMuted.withValues(alpha: 0.5),
          );
    return Material(
      color: bg,
      shape: StadiumBorder(side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? kOnPeach : t.heroText,
            ),
          ),
        ),
      ),
    );
  }
}
