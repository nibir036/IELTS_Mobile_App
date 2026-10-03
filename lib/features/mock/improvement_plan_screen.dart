import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G10 · AI Actionable Improvement Plan — generated from the weakest
/// sections of a mock attempt (`routeArgs['attemptId']` or the latest mock).
/// Checkbox state lives in kv `mock.plan.<attemptId>`.
class ImprovementPlanScreen extends StatelessWidget {
  const ImprovementPlanScreen({super.key});

  /// Tie-break order when two sections have the same band.
  static const _priority = <String>['writing', 'speaking', 'reading', 'listening'];

  static String _fill(String tpl, Map<String, String> v) {
    var out = tpl;
    v.forEach((k, val) => out = out.replaceAll('{$k}', val));
    return out;
  }

  /// Weakest criterion of a criteria map → (key, band).
  static (String, double)? _weakest(Map<String, dynamic> m) {
    (String, double)? w;
    for (final e in m.entries) {
      final v = e.value;
      if (v is! num) continue;
      if (w == null || v.toDouble() < w.$2) w = (e.key, v.toDouble());
    }
    return w;
  }

  static Map<String, dynamic> _weakestPart(Attempt a) {
    Map<String, dynamic> out = <String, dynamic>{};
    var ratio = 2.0;
    for (final p in a.data.l('listeningByPart')) {
      final total = p.i('total') == 0 ? 1 : p.i('total');
      final r = p.i('correct') / total;
      if (r < ratio) {
        ratio = r;
        out = p;
      }
    }
    return out;
  }

  /// Plan built from the attempt: gains, weeks with items.
  static _Plan _build(Attempt a) {
    final plan = mockContent.m('plan');
    final templates = plan.m('templates');
    final labels = plan.m('criteriaLabels');
    final skills = List<String>.from(_priority)
      ..sort((x, y) {
        final bx = mockSectionBand(a, x) ?? 9.0;
        final by = mockSectionBand(a, y) ?? 9.0;
        final c = bx.compareTo(by);
        return c != 0 ? c : _priority.indexOf(x).compareTo(_priority.indexOf(y));
      });
    final weakest = skills.take(3).toList();
    final part = _weakestPart(a);
    final partLabel = part.isEmpty ? 'Part 4' : part.s('label');

    final gains = <Map<String, dynamic>>[];
    for (final skill in weakest) {
      final tpl = templates.m(skill);
      String focus = tpl.s('focus');
      String score = Store.formatBand(mockSectionBand(a, skill));
      if (skill == 'listening') {
        focus = _fill(focus, {'part': partLabel});
        if (part.isNotEmpty) score = '${part.i('correct')}/${part.i('total')}';
      } else if (skill == 'reading') {
        final r = a.data.m('readingScore');
        if (r.isNotEmpty) score = '${r.i('correct')}/${r.i('total')}';
      } else {
        final w = _weakest(a.data.m(skill == 'writing' ? 'writingCriteria' : 'speakingCriteria'));
        if (w != null) {
          focus = _fill(focus, {'criterion': labels.s(w.$1).isEmpty ? w.$1 : labels.s(w.$1)});
          score = Store.formatBand(w.$2);
        } else {
          focus = tpl.s('skillName');
        }
      }
      gains.add(<String, dynamic>{
        'skill': skill,
        'letter': Skill.letter(skill),
        'title': focus,
        'skillName': tpl.s('skillName'),
        'score': score,
      });
    }

    // Weeks start on the Monday after the mock.
    final day = DateUtils.dateOnly(a.createdAt);
    final monday = day.add(Duration(days: 8 - day.weekday));
    final tints = plan.ls('weekTints');
    final nextMock = plan.m('nextMock');
    final nextTitle = mockTitleFor(int.tryParse(mockNumberLabel(a)) == null
        ? mockAttempts().length + 1
        : int.parse(mockNumberLabel(a)) + 1);
    final weeks = <Map<String, dynamic>>[];
    for (var w = 0; w < weakest.length; w++) {
      final start = monday.add(Duration(days: 7 * w));
      final end = start.add(const Duration(days: 6));
      final dates = start.month == end.month
          ? '${start.day}–${end.day} ${Store.monthShort(end.month)}'
          : '${Store.shortDate(start)} – ${Store.shortDate(end)}';
      final tplItems = templates.m(weakest[w]).l('items');
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < tplItems.length; i++) {
        if (w == weakest.length - 1 && i > 0) break;
        final it = tplItems[i];
        items.add(<String, dynamic>{
          'id': it.s('id'),
          'skill': weakest[w],
          'title': _fill(it.s('title'), {'part': partLabel}),
          'detail': _fill(it.s('detail'), {'part': partLabel}),
          'durationMin': it.i('durationMin'),
          'target': it.s('target'),
          'date': start.add(Duration(days: i * 3)),
          'time': '19:00',
        });
      }
      if (w == weakest.length - 1) {
        final sat = start.add(const Duration(days: 5));
        items.add(<String, dynamic>{
          'id': 'next_mock',
          'skill': Skill.mock,
          'title': _fill(nextMock.s('title'), {'mock': nextTitle}),
          'detail': _fill(nextMock.s('detail'), {'date': Store.weekdayDate(sat)}),
          'durationMin': nextMock.i('durationMin'),
          'target': nextMock.s('target'),
          'date': sat,
          'time': nextMock.s('time'),
        });
      }
      weeks.add(<String, dynamic>{
        'label': 'Week ${w + 1}',
        'dates': dates,
        'tint': w < tints.length ? tints[w] : 'none',
        'items': items,
      });
    }
    return _Plan(gains: gains, weeks: weeks);
  }

  void _schedule(BuildContext context, Attempt a, _Plan plan) {
    final store = Store.I;
    if (store.kvSetHas('mock.planScheduled', a.id)) {
      context.toast('This plan is already in your schedule');
      return;
    }
    for (final w in plan.weeks) {
      for (final it in w.l('items')) {
        final date = it['date'];
        store.addTask(<String, dynamic>{
          'title': it.s('title'),
          'skill': it.s('skill'),
          'date': Store.dateKey(date is DateTime ? date : DateTime.now()),
          'time': it.s('time'),
          'durationMin': it.i('durationMin'),
          'target': it.s('target'),
        });
      }
    }
    store.kvSetToggle('mock.planScheduled', a.id);
    context.toast('Plan added to your schedule');
  }

  Widget _empty(BuildContext context) {
    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 16,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              iconSize: 18,
              bg: context.tk.surface,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
          ],
        ),
        EmptyState(
          icon: AppIcons.sparkle,
          title: 'No plan yet',
          message: 'Your improvement plan is built from your weakest sections after a full mock test.',
          actionLabel: 'Start a mock test',
          onAction: () => context.push(Routes.mockSystemCheck),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final a = store.resolveAttempt(context.routeArgs, skill: Skill.mock, kind: 'mock');
    if (a == null) return _empty(context);
    final plan = _build(a);
    final content = mockContent.m('plan');
    final target = store.current?.targetBand ?? 7.0;
    final key = 'mock.plan.${a.id}';
    final done = store.kvSet(key);
    final gains = plan.gains;
    final weeks = plan.weeks;

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      gap: 10,
      footer: PrimaryButton(
        label: 'Add plan to schedule',
        leading: AppIcons.calendarMonth,
        onTap: () => _schedule(context, a, plan),
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              iconSize: 18,
              bg: t.surface,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            const Spacer(),
            IconBox(
              icon: AppIcons.calendar,
              bg: t.surface,
              tooltip: 'Schedule',
              onTap: () => context.push(Routes.schedule),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              _fill(content.s('titleTemplate'), {'target': Store.formatBand(target)}),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                height: 1.1,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              _fill(content.s('subtitleTemplate'), {'mock': a.title}),
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
        if (mockHasAiNotes(a.data)) MockAiNotes(data: a.data),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(
                  spacing: 6,
                  children: [
                    Icon(AppIcons.sparkle, size: 16, color: t.iconAccent),
                    const Flexible(
                      child: Text(
                        'Biggest gains for you',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < gains.length; i++) ...[
                if (i > 0)
                  Container(
                    height: 1,
                    color: t.isNight ? t.surfaceAlt2 : const Color(0xFFF1E8ED),
                  ),
                _GainRow(row: gains[i]),
              ],
            ],
          ),
        ),
        for (var i = 0; i < weeks.length; i++)
          _WeekCard(
            week: weeks[i],
            done: done,
            onToggle: (id) => Store.I.kvSetToggle(key, id),
          ),
      ],
    );
  }
}

class _Plan {
  const _Plan({required this.gains, required this.weeks});

  final List<Map<String, dynamic>> gains;
  final List<Map<String, dynamic>> weeks;
}

class _GainRow extends StatelessWidget {
  const _GainRow({required this.row});

  final Map<String, dynamic> row;

  static Color _tint(String skill) {
    switch (skill) {
      case 'writing':
        return const Color(0xFFF9D6E2);
      case 'listening':
        return const Color(0xFFDCDDFA);
      case 'speaking':
        return const Color(0xFFF7C6D6);
      default:
        return const Color(0xFFEEEFFD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        spacing: 10,
        children: [
          LetterBadge(
            row.s('letter'),
            size: 36,
            radius: 13,
            bg: _tint(row.s('skill')),
            fg: kMockInk,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.s('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  row.s('skillName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          Text(
            row.s('score'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.done,
    required this.onToggle,
  });

  final Map<String, dynamic> week;
  final Set<String> done;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tint = week.s('tint');
    final onHero = tint == 'lavender' || tint == 'pink';
    final text = onHero ? t.heroText : t.text;
    final muted = onHero ? t.heroMuted : t.textMuted;
    final boxBorder = t.isNight
        ? (onHero ? const Color(0xFFDCCFA5) : t.border)
        : const Color(0xFFCFC2CA);
    final doneBg = onHero ? kMockInk : t.primary;
    final doneFg = onHero ? kMockCream : t.onPrimary;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                week.s('label'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: text),
              ),
            ),
            Text(week.s('dates'), style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
        for (final item in week.l('items'))
          InkWell(
            onTap: () => onToggle(item.s('id')),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              spacing: 10,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: done.contains(item.s('id')) ? doneBg : null,
                    borderRadius: BorderRadius.circular(7),
                    border: done.contains(item.s('id'))
                        ? null
                        : Border.all(color: boxBorder, width: 1.5),
                  ),
                  child: done.contains(item.s('id'))
                      ? Icon(AppIcons.check, size: 14, color: doneFg)
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.s('title'),
                        style: TextStyle(fontSize: 14, color: text),
                      ),
                      Text(
                        item.s('detail'),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (!onHero) {
      return AppCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: content,
      );
    }
    final Gradient dayGradient = tint == 'lavender'
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEEFFD), Color(0xFFDCDDFA)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFBE5ED), Color(0xFFF9D6E2)],
          );
    return HeroCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      gradient: t.isNight ? null : dayGradient,
      child: content,
    );
  }
}
