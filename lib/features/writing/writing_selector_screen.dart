import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C1 · Writing Task Selector.
class WritingSelectorScreen extends StatelessWidget {
  const WritingSelectorScreen({super.key});

  static String? _routeFor(String target) {
    switch (target) {
      case 'writingGuide':
        return Routes.writingGuide;
      case 'masterclass':
        return Routes.masterclass;
      case 'sentenceBuilder':
        return Routes.sentenceBuilder;
      case 'writingTemplate':
        return Routes.writingTemplate;
      case 'ideasTopics':
        return Routes.ideasTopics;
      case 'articleTips':
        return Routes.articleTips;
      case 'writingSampleAnswer':
        return Routes.writingSampleAnswer;
      case 'essayHistory':
        return Routes.essayHistory;
    }
    return null;
  }

  static IconData _iconFor(String key) {
    switch (key) {
      case 'guide':
        return AppIcons.school;
      case 'lessons':
        return AppIcons.reading;
      case 'booster':
        return AppIcons.layers;
      case 'template':
        return AppIcons.doc;
      case 'ideas':
        return AppIcons.hash;
      case 'tips':
        return AppIcons.bulb;
    }
    return AppIcons.writing;
  }

  static const Map<String, String> _shortTypes = <String, String>{
    'line': 'Line',
    'bar': 'Bar',
    'pie': 'Pie',
    'table': 'Table',
    'process': 'Process',
    'map': 'Map',
    'mixed': 'Mixed',
    'opinion': 'Opinion',
    'discussion': 'Discussion',
    'advantages': 'Advantages',
    'problem': 'Problem–solution',
    'two-part': 'Two-part',
    'positive-negative': 'Positive / negative',
  };

  /// The bank's prompt types for a task card (JSON copy as fallback).
  static List<String> _typesFor(Map<String, dynamic> task, int n) {
    final keys = WritingContent.types(n);
    if (keys.isEmpty) return task.ls('types');
    return <String>[for (final k in keys) _shortTypes[k] ?? WritingContent.typeName(n, k)];
  }

  /// Real counts for the "More in Writing" rows (JSON meta as fallback).
  static String _metaFor(Map<String, dynamic> row) {
    int n;
    String unit;
    switch (row.s('target')) {
      case 'writingGuide':
        n = Demo.guide('writing').l('chapters').length;
        unit = 'chapter';
      case 'masterclass':
        n = WritingContent.all.m('masterclass').l('lessons').length;
        unit = 'lesson';
      case 'sentenceBuilder':
        n = WritingContent.all.m('sentenceBuilder').l('drills').length;
        unit = 'drill';
      case 'writingTemplate':
        n = WritingContent.all.m('templates').l('items').length;
        unit = 'template';
      case 'ideasTopics':
        n = WritingContent.topics().length;
        unit = 'topic';
      case 'writingSampleAnswer':
        n = WritingContent.withModelAnswer().length;
        unit = 'answer';
      default:
        return row.s('meta');
    }
    if (n <= 0) return row.s('meta');
    return '$n $unit${n == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final data = WritingContent.all.m('selector');
    final tasks = data.l('tasks');
    final drafts = WritingDrafts.all(store);
    final draft = drafts.isEmpty ? null : drafts.first;
    final draftPrompt =
        draft == null ? null : WritingContent.prompt(draft.s('promptId'));
    final mock = data.m('fullMock');
    final more = data.l('more');

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      gap: 16,
      children: [
        WHeader(
          title: 'Writing',
          trailing: IconBox(
            icon: AppIcons.history,
            tooltip: 'Essay history',
            onTap: () => context.push(Routes.essayHistory),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            const Text(
              'Pick a task',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              data.s('subtitle'),
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
        for (final task in tasks)
          _TaskCard(
            task: task,
            types: _typesFor(task, task.s('id') == 'task1' ? 1 : 2),
            written: WritingContent.attemptedCount(
              store,
              task.s('id') == 'task1' ? 1 : 2,
            ),
            promptCount: WritingContent.prompts(
              task: task.s('id') == 'task1' ? 1 : 2,
            ).length,
            essays: store.attemptsFor(skill: Skill.writing, kind: task.s('id')),
            // Every question of the task: pick one or a random one.
            onTap: () => context.push(
              Routes.writingQuestions,
              args: <String, dynamic>{'task': task.s('id') == 'task1' ? 1 : 2},
            ),
          ),
        if (draft != null)
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: () => context.push(
            draft.i('task') == 1
                ? Routes.writingTask1Editor
                : Routes.writingEditor,
            args: <String, dynamic>{'promptId': draft.s('promptId')},
          ),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.surfaceAlt2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  AppIcons.pen,
                  size: 18,
                  color: t.isNight ? t.textMuted : t.text,
                ),
              ),
              Expanded(
                child: _TwoLine(
                  title: 'Continue draft',
                  subtitle: 'Task ${draft.i('task')} · ${draftPrompt?.s('shortTitle') ?? 'Draft'} · ${countWords(draft.s('text'))} words',
                  titleColor: t.text,
                  subtitleColor: t.textMuted,
                ),
              ),
              Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
            ],
          ),
        ),
        AppCard(
          radius: 22,
          color: t.primary,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: () => context.push(Routes.mockWriting),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: wc(t, 0xFF2A2A2A, 0xFF151515),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  AppIcons.clock,
                  size: 18,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              Expanded(
                child: _TwoLine(
                  title: mock.s('title'),
                  subtitle: mock.s('subtitle'),
                  titleColor: t.onPrimary,
                  subtitleColor: wc(t, 0xFFBDB6BB, 0xFF5A5446),
                ),
              ),
              Icon(AppIcons.chevronRight, size: 20, color: t.onPrimary),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: Text(
                  'More in Writing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${data.i('sectionCount')} sections',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          ),
        ),
        Column(
          spacing: 8,
          children: [
            // Rows whose target has no screen are hidden, never dead ends.
            for (final row in more)
              if (_routeFor(row.s('target')) != null)
              _MoreRow(
                row: row,
                meta: _metaFor(row),
                icon: _iconFor(row.s('icon')),
                onTap: () {
                  final target = row.s('target');
                  context.push(
                    _routeFor(target)!,
                    args: target == 'articleTips'
                        ? <String, dynamic>{'series': 'writing'}
                        : null,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: titleColor,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: subtitleColor),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.types,
    required this.written,
    required this.promptCount,
    required this.essays,
    required this.onTap,
  });

  final Map<String, dynamic> task;
  final List<String> types;

  /// Distinct bank prompts of this task the student has written.
  final int written;
  final int promptCount;

  /// The student's attempts for this task, newest first.
  final List<Attempt> essays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isTask1 = task.s('id') == 'task1';
    final muted = t.heroMuted;
    final bars = task.ld('previewBars');
    final hi = task.i('highlightBar');

    Widget stat(String n, String unit) => Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: n,
                style: TextStyle(color: t.heroText, fontWeight: FontWeight.w500),
              ),
              TextSpan(text: ' $unit'),
            ],
          ),
          style: TextStyle(fontSize: 13, color: muted),
        );

    final stats = [
      stat('${task.i('minutes')}', 'min'),
      stat('${task.i('words')}', 'words'),
      stat('$promptCount', 'prompts'),
    ];
    final bands = essays.map((a) => a.band).whereType<double>().toList();
    final best = bands.isEmpty ? null : bands.reduce((x, y) => x > y ? x : y);
    final progress = essays.isEmpty
        ? 'No essays yet · $promptCount prompts to try'
        : '$written of $promptCount prompts · best ${Store.formatBand(best)} · last ${Store.formatBand(essays.first.band)}';

    return HeroCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      gradient: t.isNight
          ? null
          : (isTask1
              ? wGradient(0xFFD6D8FA, 0xFFEEEFFD)
              : wGradient(0xFFF7C6D6, 0xFFFCEBF1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      task.s('label'),
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                    Text(
                      task.s('title'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: t.heroText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.heroText,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  AppIcons.northEast,
                  size: 18,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
          if (isTask1)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 12,
              children: [
                Expanded(
                  child: Container(
                    height: 86,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: t.isNight
                          ? const Color(0x14151515)
                          : const Color(0xBFFFFFFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 8,
                      children: [
                        for (var i = 0; i < bars.length; i++)
                          Expanded(
                            child: FractionallySizedBox(
                              heightFactor: bars[i].clamp(0.05, 1.0),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == hi
                                      ? const Color(0xFF151515)
                                      : const Color(0xFFB9BAF2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: stats,
                  ),
                ),
              ],
            )
          else
            Wrap(spacing: 16, runSpacing: 4, children: stats),
          Text(
            progress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in types)
                WPill(
                  type,
                  bg: t.isNight ? t.heroChip : const Color(0xFFFFFFFF),
                  fg: t.isNight ? t.heroMuted : t.heroText,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.row,
    required this.meta,
    required this.icon,
    required this.onTap,
  });

  final Map<String, dynamic> row;
  final String meta;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tone = row.s('tone');
    Color bg;
    Color fg = const Color(0xFF151515);
    switch (tone) {
      case 'lavender':
        bg = const Color(0xFFDCDDFA);
      case 'rose':
        bg = const Color(0xFFF7C6D6);
      case 'mist':
        bg = wc(t, 0xFFEEEFFD, 0xFF1F1F1F);
        fg = t.text;
      default:
        bg = const Color(0xFFF9D6E2);
    }
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      onTap: onTap,
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
          Expanded(
            child: _TwoLine(
              title: row.s('title'),
              subtitle: row.s('subtitle'),
              titleColor: t.text,
              subtitleColor: t.textMuted,
            ),
          ),
          Text(
            meta,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          Icon(AppIcons.chevronRight, size: 16, color: t.textMuted),
        ],
      ),
    );
  }
}
