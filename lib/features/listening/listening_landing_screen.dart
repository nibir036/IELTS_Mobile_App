import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/lessons.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import 'lesson_menu.dart';
import 'widgets.dart';

/// Number of Listening tip guides in the H11 article series.
int listeningTipCount() => Demo.section('resources')
    .l('articles')
    .where((a) => a.s('series') == 'listening')
    .length;

/// F5 · Listening Section Landing.
class ListeningLandingScreen extends StatelessWidget {
  const ListeningLandingScreen({super.key});

  /// Share of each module the student has completed (0..1).
  double _moduleProgress(Store store, String id) {
    double ratio(int done, int total) =>
        total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();
    switch (id) {
      case 'lessons':
        final lessons = ListeningLessons.all;
        final done = ListeningLessons.doneIds(store);
        return ratio(lessons.where((l) => done.contains(l.s('id'))).length, lessons.length);
      case 'mini':
        return ratio(ListeningStats.doneSets(store).length, Content.listeningSets.length);
      case 'parts':
        final done = ListeningStats.doneSets(store);
        final parts = <int>{
          for (final s in Content.listeningSets)
            if (done.contains(s.s('id'))) s.i('part'),
        };
        return ratio(parts.length, 4);
      case 'tests':
        return ratio(ListeningStats.doneTests(store).length, Content.listeningTests.length);
      default:
        return 0.0;
    }
  }

  /// Count label / subtitle computed from the bank (null = keep the copy).
  (String?, String?) _moduleCopy(String id) {
    switch (id) {
      case 'lessons':
        final n = ListeningLessons.all.length;
        return ('$n ${n == 1 ? 'lesson' : 'lessons'}', null);
      case 'guide':
        final n = Lessons.all('listening').length;
        return (n == 0 ? null : '$n lessons', null);
      case 'tips':
        final n = listeningTipCount();
        return ('$n ${n == 1 ? 'guide' : 'guides'}', null);
      case 'mini':
        final n = Content.listeningSets.length;
        return ('$n ${n == 1 ? 'set' : 'sets'}', null);
      case 'parts':
        final parts = <int>{for (final s in Content.listeningSets) s.i('part')};
        return ('${parts.length} parts', null);
      case 'tests':
        final tests = Content.listeningTests;
        final n = tests.length;
        if (tests.isEmpty) return ('0 tests', null);
        final id0 = tests.first.s('id');
        final q = listeningTestQuestions(id0);
        final sec = listeningTestSeconds(id0);
        return (
          '$n ${n == 1 ? 'test' : 'tests'}',
          '$q questions · ${approxMinutes(sec)} audio · plays once',
        );
      default:
        return (null, null);
    }
  }

  void _open(BuildContext context, String id) {
    switch (id) {
      case 'lessons':
        context.push(Routes.listeningLesson);
      case 'mini':
        context.push(Routes.listeningMiniList);
      case 'parts':
        context.push(Routes.listeningMiniList);
      case 'tests':
        context.push(Routes.listeningLibrary, args: {'filter': 0});
      case 'tips':
        context.push(Routes.articleTips, args: {'series': 'listening'});
      case 'guide':
        context.push(Routes.listeningCourse);
      default:
        // Unknown module ids fall back to the mini practice list.
        context.push(Routes.listeningMiniList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final data = Demo.section('listening').m('landing');
    final modules = <Map<String, dynamic>>[
      for (final m in data.l('modules'))
        <String, dynamic>{
          ...m,
          if (_moduleCopy(m.s('id')).$1 != null) 'count': _moduleCopy(m.s('id')).$1,
          if (_moduleCopy(m.s('id')).$2 != null) 'subtitle': _moduleCopy(m.s('id')).$2,
          'progress': _moduleProgress(store, m.s('id')),
        },
    ];
    final tracked = modules.where((m) => m.s('id') != 'tips').toList();
    final avg = tracked.isEmpty
        ? 0.0
        : tracked.map((m) => m.d('progress')).reduce((a, b) => a + b) / tracked.length;
    final progress = (avg * 100).round();
    final band = Store.formatBand(store.skillBand(Skill.listening));
    final target = Store.formatBand(store.current?.targetBand);
    final weakest = ListeningStats.weakestPart(store);

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        ListeningHeader(
          title: 'Listening',
          titleSize: 16,
          onLeading: () => context.back(),
          trailingIcon: AppIcons.search,
          trailingTooltip: 'Search listening',
          onTrailing: () => context.push(Routes.search),
        ),
        Text(
          'Home / Listening',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: t.textMuted),
        ),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Section progress'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                        color: t.peach,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$progress%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.8,
                        height: 1.1,
                        color: t.heroText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Est. band $band · target $target',
                      style: TextStyle(fontSize: 13, color: t.heroMuted),
                    ),
                    const SizedBox(height: 10),
                    ProgressBar(value: avg, height: 6, onHero: true),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.heroChip,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Weakest part  ',
                              style: TextStyle(color: t.heroMuted),
                            ),
                            TextSpan(
                              text: weakest == null ? '–' : 'Part $weakest',
                              style: TextStyle(fontWeight: FontWeight.w600, color: t.heroText),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const Nexi(NexiPose.listening, height: 110),
            ],
          ),
        ),
        Column(
          spacing: 8,
          children: [
            for (final m in modules)
              ListeningModuleRow(item: m, onTap: () => _open(context, m.s('id'))),
          ],
        ),
      ],
    );
  }
}
