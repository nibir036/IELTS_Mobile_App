import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'lessons.dart';
import 'widgets.dart';

/// E5 · Reading Section Landing.
class ReadingLandingScreen extends StatelessWidget {
  const ReadingLandingScreen({super.key});

  /// Share of each module the student has completed (0..1).
  double _moduleProgress(Store store, String id) {
    double ratio(int done, int total) =>
        total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();
    switch (id) {
      case 'lessons':
        final lessons = ReadingLessons.all;
        final done = ReadingLessons.doneIds(store);
        return ratio(lessons.where((l) => done.contains(l.s('id'))).length, lessons.length);
      case 'type':
        final types = Content.bankQuestionTypes;
        final seen = ReadingStats.bankTypesPractised(store);
        return ratio(types.where(seen.contains).length, types.length);
      case 'passage':
        return ratio(ReadingStats.doneIds(store, tests: false).length, Content.readingPassages.length);
      case 'test':
        return ratio(ReadingStats.doneIds(store, tests: true).length, Content.readingTests.length);
      default:
        return 0;
    }
  }

  /// Count label computed from the bank ('' keeps the copy from JSON).
  String _count(Map<String, dynamic> m) {
    int n;
    String unit;
    switch (m.s('id')) {
      case 'lessons':
        n = ReadingLessons.all.length;
        unit = 'lesson';
      case 'tips':
        n = Demo.section('resources')
            .l('articles')
            .where((a) => a.s('series') == 'reading')
            .length;
        unit = 'guide';
      case 'guide':
        n = Demo.guide('reading').l('chapters').length;
        unit = 'chapter';
      case 'type':
        n = Content.bankQuestionTypes.length;
        unit = 'type';
      case 'passage':
        n = Content.readingPassages.length;
        unit = 'passage';
      case 'test':
        n = Content.readingTests.length;
        unit = 'test';
      default:
        return m.s('count');
    }
    return '$n ${n == 1 ? unit : '${unit}s'}';
  }

  void _open(BuildContext context, String id) {
    switch (id) {
      case 'lessons':
        context.push(Routes.readingLesson);
      case 'guide':
        context.push(Routes.readingGuide);
      case 'type':
        context.push(Routes.readingBank);
      case 'passage':
        context.push(Routes.readingLibrary, args: {'filter': 'passage'});
      case 'test':
        context.push(Routes.readingLibrary, args: {'filter': 'full'});
      case 'tips':
        context.push(Routes.articleTips, args: {'series': 'reading'});
      default:
        // Unknown module ids fall back to the library.
        context.push(Routes.readingLibrary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final data = Demo.section('reading').m('landing');
    final modules = <Map<String, dynamic>>[
      for (final m in data.l('modules'))
        <String, dynamic>{
          ...m,
          'count': _count(m),
          'progress': _moduleProgress(store, m.s('id')),
        },
    ];
    final tracked = modules.where((m) => m.s('id') != 'tips').toList();
    final avg = tracked.isEmpty
        ? 0.0
        : tracked.map((m) => m.d('progress')).reduce((a, b) => a + b) / tracked.length;
    final progress = (avg * 100).round();
    final band = Store.formatBand(store.skillBand(Skill.reading));
    final target = Store.formatBand(store.current?.targetBand);
    final labelColor = t.isNight ? t.heroText : t.textSoft;

    return AppScreen(
      gap: 12,
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              bg: t.surface,
              onTap: () => context.back(),
            ),
            const Expanded(
              child: Text(
                'Reading',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
            IconBox(
              icon: AppIcons.search,
              tooltip: 'Search reading',
              bg: t.surface,
              onTap: () => context.push(Routes.search),
            ),
          ],
        ),
        Text('Home / Reading', style: TextStyle(fontSize: 12, color: t.textMuted)),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.all(18),
          gradient: t.isNight
              ? null
              : const LinearGradient(
                  begin: Alignment(-0.64, -0.77),
                  end: Alignment(0.64, 0.77),
                  colors: [kLavender, kPink],
                ),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Section progress',
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
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
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: t.isNight ? t.heroChip : t.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Weakest type',
                      style: TextStyle(fontSize: 11, color: t.heroMuted),
                    ),
                    Text(
                      ReadingStats.weakestType(store),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.heroText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Column(
          spacing: 8,
          children: [
            for (final m in modules)
              ModuleRow(item: m, onTap: () => _open(context, m.s('id'))),
          ],
        ),
      ],
    );
  }
}
