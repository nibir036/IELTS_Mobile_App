import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'diagnostic_data.dart';

/// Diagnostic result: estimated overall band, per-skill bands against the
/// target, strongest / weakest skill, next steps and an answer review.
/// Args: `{'diagnosticId': …}` (defaults to the newest diagnostic).
class DiagnosticResultScreen extends StatefulWidget {
  const DiagnosticResultScreen({super.key});

  @override
  State<DiagnosticResultScreen> createState() => _DiagnosticResultScreenState();
}

class _DiagnosticResultScreenState extends State<DiagnosticResultScreen> {
  bool _review = false;

  static IconData _icon(String skill) => switch (skill) {
        Skill.listening => AppIcons.listening,
        Skill.reading => AppIcons.reading,
        Skill.writing => AppIcons.writing,
        _ => AppIcons.speaking,
      };

  static String _detail(Attempt? a) {
    if (a == null) return 'Not assessed';
    switch (a.skill) {
      case Skill.listening:
      case Skill.reading:
        return '${a.score ?? 0}/${a.total ?? 0} correct';
      case Skill.writing:
        return '${a.data.i('words')} words';
      default:
        final sec = a.data.i('spokenSec');
        return sec > 0 ? '$sec s spoken' : 'Recorded';
    }
  }

  void _open(String route, [Map<String, dynamic>? args]) {
    if (args == null) {
      context.push(route);
    } else {
      context.push(route, args: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final summary = Diagnostic.load(context.routeArgs);
    final copy = Diagnostic.resultCopy;

    final header = TopBar(
      title: 'Diagnostic result',
      onBack: () => context.back(),
    );

    if (summary == null) {
      return AppScreen(
        children: [
          header,
          EmptyState(
            title: 'No diagnostic yet',
            message: 'Take the ${Diagnostic.totalMinutes}-min diagnostic to get '
                'your estimated band for all four skills.',
            icon: AppIcons.target,
            actionLabel: 'Take the diagnostic',
            onAction: () => context.replace(Routes.diagnosticTest),
          ),
        ],
      );
    }

    final target = store.current?.targetBand;
    final overall = summary.overall;
    final assessed = <String>[
      for (final s in Skill.core)
        if (summary.band(s) != null) s,
    ];
    // Strongest / weakest (ties: first in L-R-W-S order).
    String? strongest;
    String? weakest;
    for (final s in assessed) {
      final b = summary.band(s)!;
      if (strongest == null || b > summary.band(strongest)!) strongest = s;
      if (weakest == null || b < summary.band(weakest)!) weakest = s;
    }
    final byWeakness = List<String>.from(assessed)
      ..sort((a, b) => summary.band(a)!.compareTo(summary.band(b)!));

    // Three next steps: weakest skill, then speaking if it wasn't assessed
    // (else the next weakest), then a full mock test.
    final practice = copy.m('practice');
    final steps = <Map<String, dynamic>>[];
    void addSkill(String skill, String why) {
      if (steps.any((s) => s.s('skill') == skill)) return;
      final p = practice.m(skill);
      steps.add(<String, dynamic>{
        'skill': skill,
        'title': p.s('title').isEmpty ? '${Skill.label(skill)} practice' : p.s('title'),
        'subtitle': why.isEmpty ? p.s('subtitle') : '$why · ${p.s('subtitle')}',
        'route': Diagnostic.routeFor(p.s('route').isEmpty ? skill : p.s('route')),
      });
    }

    if (byWeakness.isNotEmpty) {
      final w = byWeakness.first;
      addSkill(w, 'Band ${Store.formatBand(summary.band(w))}');
    }
    if (summary.band(Skill.speaking) == null) {
      addSkill(Skill.speaking, 'Not assessed yet');
    } else if (byWeakness.length > 1) {
      final w = byWeakness[1];
      addSkill(w, 'Band ${Store.formatBand(summary.band(w))}');
    }
    for (final extra in <String>['mockStep', 'scheduleStep']) {
      if (steps.length >= 3) break;
      final m = copy.m(extra);
      if (m.isEmpty) continue;
      steps.add(<String, dynamic>{
        'skill': '',
        'title': m.s('title'),
        'subtitle': m.s('subtitle'),
        'route': Diagnostic.routeFor(m.s('route')),
      });
    }

    final offline = summary.attempts.values.any(
      (a) => (a.skill == Skill.writing || a.skill == Skill.speaking) && a.data.s('source') != 'ai',
    );
    final gap = (target != null && overall != null) ? target - overall : null;
    final String targetLine;
    if (target == null) {
      targetLine = 'Set a target band in your profile';
    } else if (gap != null && gap <= 0) {
      targetLine = 'Target ${Store.formatBand(target)} · you’re already there';
    } else {
      targetLine = 'Target ${Store.formatBand(target)} · ${Store.formatBand(gap)} to go';
    }

    return AppScreen(
      gap: 16,
      footer: PrimaryButton(
        label: 'Go to my dashboard',
        trailing: AppIcons.forward,
        onTap: () => context.resetTo(Routes.home),
      ),
      children: [
        header,
        Headline(
          copy.s('title').isEmpty ? 'Your diagnostic result' : copy.s('title'),
          size: 28,
          subtitle: copy.s('subtitle'),
        ),
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estimated overall band',
                      style: TextStyle(fontSize: 14, color: t.heroMuted),
                    ),
                  ),
                  Tag(Store.relativeDay(summary.date), tone: TagTone.hero),
                ],
              ),
              BigNumber(Store.formatBand(overall), size: 88, color: t.heroText),
              Text(
                targetLine,
                style: TextStyle(fontSize: 14, color: t.heroText),
              ),
              if (target != null && overall != null)
                ProgressBar(value: overall / target, height: 6, onHero: true),
              Text(
                '${assessed.length} of 4 skills assessed',
                style: TextStyle(fontSize: 12, color: t.heroMuted),
              ),
            ],
          ),
        ),
        const SectionTitle('Your skills'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(
            children: [
              for (var i = 0; i < Skill.core.length; i++)
                _SkillRow(
                  icon: _icon(Skill.core[i]),
                  label: Skill.label(Skill.core[i]),
                  detail: _detail(summary.attempts[Skill.core[i]]),
                  band: summary.band(Skill.core[i]),
                  target: target,
                  divider: i > 0,
                  onTap: summary.attempts[Skill.core[i]] == null
                      ? null
                      : () {
                          final a = summary.attempts[Skill.core[i]]!;
                          _open(resultRouteFor(a), <String, dynamic>{'attemptId': a.id});
                        },
                ),
            ],
          ),
        ),
        if (strongest != null && weakest != null && strongest != weakest)
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: _HighlightCard(
                  label: 'Strongest',
                  skill: Skill.label(strongest),
                  band: summary.band(strongest),
                  icon: AppIcons.trophy,
                ),
              ),
              Expanded(
                child: _HighlightCard(
                  label: 'Focus first',
                  skill: Skill.label(weakest),
                  band: summary.band(weakest),
                  icon: AppIcons.target,
                ),
              ),
            ],
          ),
        const SectionTitle('Recommended next steps'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                ListRow(
                  divider: i > 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  leading: LetterBadge('${i + 1}', size: 34, radius: 11),
                  title: steps[i].s('title'),
                  subtitle: steps[i].s('subtitle'),
                  trailing: Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
                  onTap: () => _open(steps[i].s('route')),
                ),
            ],
          ),
        ),
        if (summary.attempts[Skill.listening] != null || summary.attempts[Skill.reading] != null)
          OutlineButtonX(
            label: _review ? 'Hide answers' : 'Review answers',
            leading: AppIcons.checklist,
            height: 52,
            onTap: () => setState(() => _review = !_review),
          ),
        if (_review)
          for (final s in <String>[Skill.listening, Skill.reading])
            if (summary.attempts[s] != null) _ReviewCard(attempt: summary.attempts[s]!),
        if (offline)
          Text(
            'Writing / speaking estimated offline — AI scoring was unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.band,
    required this.target,
    required this.divider,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final double? band;
  final double? target;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final b = band;
    final tg = target ?? 9.0;
    String delta = '';
    if (b != null && target != null) {
      final d = b - target!;
      delta = d >= 0 ? 'On target' : '${Store.formatBand(-d)} below target';
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: divider ? Border(top: BorderSide(color: t.divider)) : null,
        ),
        child: Row(
          spacing: 12,
          children: [
            IconCircle(icon, size: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        b == null ? 'Not assessed' : Store.formatBand(b),
                        style: TextStyle(
                          fontSize: b == null ? 13 : 18,
                          fontWeight: b == null ? FontWeight.w400 : FontWeight.w500,
                          color: b == null ? t.textMuted : t.text,
                        ),
                      ),
                    ],
                  ),
                  ProgressBar(value: b == null ? 0.0 : b / tg, height: 5),
                  Text(
                    delta.isEmpty ? detail : '$detail · $delta',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            if (onTap != null) Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.label,
    required this.skill,
    required this.band,
    required this.icon,
  });

  final String label;
  final String skill;
  final double? band;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          IconCircle(icon, size: 36),
          Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
          Text(
            skill,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            'Band ${Store.formatBand(band)}',
            style: TextStyle(fontSize: 13, color: t.textSoft),
          ),
        ],
      ),
    );
  }
}

/// Listening / reading answers against the key.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.attempt});

  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final rows = attempt.data.l('review');
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Skill.label(attempt.skill),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${attempt.score ?? 0}/${attempt.total ?? 0}',
                  style: TextStyle(fontSize: 14, color: t.textMuted),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Text('No answers saved.', style: TextStyle(fontSize: 13, color: t.textMuted)),
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
              child: Row(
                spacing: 10,
                children: [
                  LetterBadge('${r.i('n')}', size: 28, radius: 9, fontSize: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        Text(
                          r.s('given').isEmpty ? 'No answer' : r.s('given'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: r.b('ok') ? t.text : t.dangerText,
                          ),
                        ),
                        if (!r.b('ok'))
                          Text(
                            'Answer: ${r.s('answer')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: t.textMuted),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    r.b('ok') ? AppIcons.checkCircle : AppIcons.error,
                    size: 20,
                    color: r.b('ok') ? t.success : t.danger,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
