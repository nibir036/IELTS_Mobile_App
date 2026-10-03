import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Full Writing / Speaking tests (assets/content/tests_bank.json, website tests
// renumbered 1–10). A test is opened as a sheet with its parts; each part
// starts the existing practice screen with that test's prompt:
//   Writing  Task 1 → C2 editor, Task 2 → C3 editor   (args {'promptId'})
//   Speaking Part 1 → D2 {'part': 1, 'topicId'} · Part 2 → D3 {'cardId'} ·
//            Part 3 → D2 {'part': 3, 'cardId'}
// ─────────────────────────────────────────────────────────────────────────────

/// True when the student has an attempt on any of [refIds] in [skill].
bool fullTestPartDone(Store store, String skill, String refId) =>
    store.attemptsFor(skill: skill).any((a) => a.refId == refId);

/// Writing Test 1–10 list.
class WritingTestsScreen extends StatelessWidget {
  const WritingTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final tests = Content.writingTests;
    return AppScreen(
      children: [
        TopBar(title: 'Writing full tests', subtitle: '${tests.length} tests · Task 1 + Task 2 · 60 min'),
        if (tests.isEmpty)
          const EmptyState(icon: AppIcons.writing, title: 'No writing tests yet', message: 'Full tests will appear here.'),
        for (final t in tests)
          _TestCard(
            number: t.i('number'),
            title: t.s('title'),
            lines: <String>[
              _taskLine(1, Content.writingPrompt(t.s('task1'))),
              _taskLine(2, Content.writingPrompt(t.s('task2'))),
            ],
            done: <bool>[
              fullTestPartDone(store, Skill.writing, t.s('task1')),
              fullTestPartDone(store, Skill.writing, t.s('task2')),
            ],
            onTap: () => showWritingTestSheet(context, t),
          ),
      ],
    );
  }

  static String _taskLine(int task, Map<String, dynamic> p) {
    final title = p.s('title');
    return 'Task $task · ${p.s('typeLabel')}${title.isEmpty ? '' : ' · $title'}';
  }
}

/// The two tasks of a writing test; each opens its editor.
Future<void> showWritingTestSheet(BuildContext context, Map<String, dynamic> test) {
  final t1 = Content.writingPrompt(test.s('task1'));
  final t2 = Content.writingPrompt(test.s('task2'));
  return showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) {
        final store = ctx.store;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Text(test.s('title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            Text('Do Task 1 first (20 min), then Task 2 (40 min).',
                style: TextStyle(fontSize: 13, color: ctx.tk.textMuted)),
            const SizedBox(height: 6),
            _PartRow(
              icon: AppIcons.chart,
              title: 'Task 1 · ${t1.s('typeLabel')}',
              subtitle: '${t1.s('title')} · 20 min · 150+ words',
              done: fullTestPartDone(store, Skill.writing, t1.s('id')),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(Routes.writingTask1Editor, args: <String, dynamic>{'promptId': t1.s('id')});
              },
            ),
            _PartRow(
              icon: AppIcons.pen,
              divider: true,
              title: 'Task 2 · ${t2.s('typeLabel')}',
              subtitle: '${t2.s('title').isEmpty ? 'Essay' : t2.s('title')} · 40 min · 250+ words',
              done: fullTestPartDone(store, Skill.writing, t2.s('id')),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(Routes.writingEditor, args: <String, dynamic>{'promptId': t2.s('id')});
              },
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    ),
  );
}

/// Speaking Test 1–10 list.
class SpeakingTestsScreen extends StatelessWidget {
  const SpeakingTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final tests = Content.speakingTests;
    return AppScreen(
      children: [
        TopBar(title: 'Speaking full tests', subtitle: '${tests.length} tests · Parts 1, 2 and 3 · 11–14 min'),
        if (tests.isEmpty)
          const EmptyState(icon: AppIcons.speaking, title: 'No speaking tests yet', message: 'Full tests will appear here.'),
        for (final t in tests)
          _TestCard(
            number: t.i('number'),
            title: t.s('title'),
            lines: <String>[
              'Part 1 · ${Content.part1Topic(t.s('part1')).s('topic')}',
              'Part 2 · ${Content.cueCard(t.s('cueCard')).s('title')}',
              'Part 3 · ${<String>[for (final id in t.ls('part3')) Content.part3Topic(id).s('topic')].join(' · ')}',
            ],
            done: <bool>[
              fullTestPartDone(store, Skill.speaking, t.s('part1')),
              fullTestPartDone(store, Skill.speaking, t.s('cueCard')),
            ],
            onTap: () => showSpeakingTestSheet(context, t),
          ),
      ],
    );
  }
}

/// The three parts of a speaking test; each opens its practice screen.
Future<void> showSpeakingTestSheet(BuildContext context, Map<String, dynamic> test) {
  final p1 = Content.part1Topic(test.s('part1'));
  final card = Content.cueCard(test.s('cueCard'));
  final p3 = <Map<String, dynamic>>[for (final id in test.ls('part3')) Content.part3Topic(id)];
  return showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) {
        final store = ctx.store;
        void go(String route, Map<String, dynamic> args) {
          Navigator.of(ctx).pop();
          context.push(route, args: args);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Text(test.s('title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            Text('Take the parts in order, like the real interview.',
                style: TextStyle(fontSize: 13, color: ctx.tk.textMuted)),
            const SizedBox(height: 6),
            _PartRow(
              icon: AppIcons.chat,
              title: 'Part 1 · Interview',
              subtitle: '${p1.s('topic')} · ${p1.ls('questions').length} questions · 4–5 min',
              done: fullTestPartDone(store, Skill.speaking, p1.s('id')),
              onTap: () => go(Routes.speakingPart13, <String, dynamic>{'part': 1, 'topicId': p1.s('id')}),
            ),
            _PartRow(
              icon: AppIcons.mic,
              divider: true,
              title: 'Part 2 · Cue card',
              subtitle: '${card.s('title')} · 1 min to prepare, 2 min to speak',
              done: fullTestPartDone(store, Skill.speaking, card.s('id')),
              onTap: () => go(Routes.cueCard, <String, dynamic>{'cardId': card.s('id')}),
            ),
            _PartRow(
              icon: AppIcons.forum,
              divider: true,
              title: 'Part 3 · Discussion',
              subtitle: '${p3.map((x) => x.s('topic')).join(' · ')} · 4–5 min',
              done: false,
              onTap: () => go(Routes.speakingPart13, <String, dynamic>{'part': 3, 'cardId': card.s('id')}),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    ),
  );
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.number,
    required this.title,
    required this.lines,
    required this.done,
    required this.onTap,
  });

  final int number;
  final String title;
  final List<String> lines;
  final List<bool> done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final finished = done.isNotEmpty && done.every((d) => d);
    final started = done.any((d) => d);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          LetterBadge('$number'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                    if (finished)
                      const Tag('Done', tone: TagTone.primary, height: 22, fontSize: 11)
                    else if (started)
                      const Tag('Started', height: 22, fontSize: 11),
                  ],
                ),
                for (final l in lines)
                  Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: t.textMuted)),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
    this.divider = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ListRow(
      divider: divider,
      title: title,
      subtitle: subtitle,
      leading: IconCircle(icon, size: 40, iconSize: 16),
      trailing: done
          ? Icon(AppIcons.checkCircle, size: 20, color: t.success)
          : Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
      onTap: onTap,
    );
  }
}
