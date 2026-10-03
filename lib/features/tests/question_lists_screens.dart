import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/widgets/kit.dart';
import '../writing/writing_data.dart';
import 'question_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Question lists for Writing and Speaking practice (like Listening part
// practice / the Reading question bank): every available question, pick one
// or let the app pick a random one you haven't done yet.
//   /writing/questions   {'task': 1|2}      → C2 / C3 editor {'promptId'}
//   /speaking/questions  {'part': 1|2|3}    → D2 {'part': 1, 'topicId'} ·
//                                             D3 {'cardId'} ·
//                                             D2 {'part': 3, 'part3TopicId'}
// ─────────────────────────────────────────────────────────────────────────────

int _argInt(BuildContext context, String key, int fallback, int max) {
  final v = context.routeArgs[key];
  return v is int && v >= 1 && v <= max ? v : fallback;
}

/// Newest attempt per refId of [skill] / [kind].
Map<String, Attempt> _latestByRef(Store store, String skill, String kind) {
  final out = <String, Attempt>{};
  for (final a in store.attemptsFor(skill: skill, kind: kind)) {
    out.putIfAbsent(a.refId, () => a);
  }
  return out;
}

String _statusOf(Attempt? a, String notDone) =>
    a == null ? notDone : 'Band ${Store.formatBand(a.band)} · ${Store.shortDate(a.createdAt)}';

/// Distinct non-empty labels in list order.
List<String> _distinct(Iterable<String> labels) {
  final out = <String>[];
  for (final l in labels) {
    if (l.isNotEmpty && !out.contains(l)) out.add(l);
  }
  return out;
}

// ── Writing ─────────────────────────────────────────────────────────────────

class WritingQuestionsScreen extends StatefulWidget {
  const WritingQuestionsScreen({super.key});

  @override
  State<WritingQuestionsScreen> createState() => _WritingQuestionsScreenState();
}

class _WritingQuestionsScreenState extends State<WritingQuestionsScreen> {
  int? _task;

  @override
  Widget build(BuildContext context) {
    final task = _task ??= _argInt(context, 'task', 1, 2);
    final store = context.store;
    final prompts = WritingContent.prompts(task: task);
    final latest = _latestByRef(store, Skill.writing, 'task$task');
    final items = <QuestionItem>[
      for (final p in prompts)
        QuestionItem(
          id: p.s('id'),
          title: p.s('title').isNotEmpty ? p.s('title') : p.s('prompt'),
          detail: task == 1
              ? p.s('typeName')
              : <String>[p.s('typeName'), p.s('topic'), p.s('difficulty')].where((e) => e.isNotEmpty).join(' · '),
          group: p.s('typeName'),
          done: latest.containsKey(p.s('id')),
          status: _statusOf(latest[p.s('id')], 'Not written'),
          search: '${p.s('prompt')} ${p.s('statement')} ${p.s('topic')}',
        ),
    ];
    final written = items.where((it) => it.done).length;

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: 'Writing questions',
          subtitle: '${items.length} Task $task questions · $written written',
        ),
        SegmentedTabs(
          labels: const <String>['Task 1 · Report', 'Task 2 · Essay'],
          index: task - 1,
          onChanged: (i) => setState(() => _task = i + 1),
        ),
        QuestionBrowser(
          key: ValueKey<int>(task),
          items: items,
          groups: _distinct(items.map((it) => it.group)),
          searchHint: task == 1 ? 'Search a chart type or title' : 'Search a topic or question',
          onOpen: (it) => context.push(
            task == 1 ? Routes.writingTask1Editor : Routes.writingEditor,
            args: <String, dynamic>{'promptId': it.id},
          ),
        ),
      ],
    );
  }
}

// ── Speaking ────────────────────────────────────────────────────────────────

class SpeakingQuestionsScreen extends StatefulWidget {
  const SpeakingQuestionsScreen({super.key});

  @override
  State<SpeakingQuestionsScreen> createState() => _SpeakingQuestionsScreenState();
}

class _SpeakingQuestionsScreenState extends State<SpeakingQuestionsScreen> {
  int? _part;

  /// Part 3: the bank's discussion topics, or the demo cue cards' Part 3
  /// questions when the bank is missing.
  static bool get _part3Topics => Content.part3Topics.isNotEmpty;

  List<QuestionItem> _items(Store store, int part) {
    switch (part) {
      case 1:
        final latest = _latestByRef(store, Skill.speaking, 'part1');
        return <QuestionItem>[
          for (final tp in Content.part1Topics)
            QuestionItem(
              id: tp.s('id'),
              title: tp.s('topic'),
              detail: '${tp.ls('questions').length} questions',
              group: tp.s('categoryLabel'),
              done: latest.containsKey(tp.s('id')),
              status: _statusOf(latest[tp.s('id')], 'Not practised'),
              search: tp.ls('questions').join(' '),
            ),
        ];
      case 2:
        final latest = _latestByRef(store, Skill.speaking, 'part2');
        return <QuestionItem>[
          for (final c in Content.cueCards)
            QuestionItem(
              id: c.s('id'),
              title: c.s('title'),
              detail: c.s('categoryLabel').isNotEmpty ? c.s('categoryLabel') : c.s('topic'),
              group: c.s('categoryLabel').isNotEmpty ? c.s('categoryLabel') : c.s('topic'),
              done: latest.containsKey(c.s('id')),
              status: _statusOf(latest[c.s('id')], 'Not practised'),
              search: c.ls('bullets').join(' '),
            ),
        ];
      default:
        final latest = _latestByRef(store, Skill.speaking, 'part3');
        if (!_part3Topics) {
          return <QuestionItem>[
            for (final c in Content.cueCards)
              if (c.ls('part3').isNotEmpty)
                QuestionItem(
                  id: c.s('id'),
                  title: c.s('title'),
                  detail: '${c.ls('part3').length} questions',
                  group: c.s('topic'),
                  done: latest.containsKey(c.s('id')),
                  status: _statusOf(latest[c.s('id')], 'Not practised'),
                  search: c.ls('part3').join(' '),
                ),
          ];
        }
        return <QuestionItem>[
          for (final tp in Content.part3Topics)
            QuestionItem(
              id: tp.s('id'),
              title: tp.s('topic'),
              detail: '${tp.l('questions').length} questions',
              group: tp.s('categoryLabel'),
              done: latest.containsKey(tp.s('id')),
              status: _statusOf(latest[tp.s('id')], 'Not practised'),
              search: '${tp.s('description')} ${tp.l('questions').map((q) => q.s('q')).join(' ')}',
            ),
        ];
    }
  }

  void _open(int part, QuestionItem it) {
    switch (part) {
      case 1:
        context.push(Routes.speakingPart13, args: <String, dynamic>{'part': 1, 'topicId': it.id});
      case 2:
        context.push(Routes.cueCard, args: <String, dynamic>{'cardId': it.id});
      default:
        context.push(
          Routes.speakingPart13,
          args: _part3Topics
              ? <String, dynamic>{'part': 3, 'part3TopicId': it.id}
              : <String, dynamic>{'part': 3, 'cardId': it.id},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final part = _part ??= _argInt(context, 'part', 1, 3);
    final store = context.store;
    final items = _items(store, part);
    final done = items.where((it) => it.done).length;
    final noun = switch (part) { 2 => 'cue card', _ => 'topic' };

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: 'Speaking questions',
          subtitle: 'Part $part · ${items.length} ${noun}s · $done practised',
        ),
        SegmentedTabs(
          labels: const <String>['Part 1', 'Part 2', 'Part 3'],
          index: part - 1,
          onChanged: (i) => setState(() => _part = i + 1),
        ),
        QuestionBrowser(
          key: ValueKey<int>(part),
          items: items,
          noun: noun,
          groups: _distinct(items.map((it) => it.group)),
          groupAllLabel: 'All categories',
          searchHint: part == 2 ? 'Search a cue card' : 'Search a topic or question',
          onOpen: (it) => _open(part, it),
        ),
      ],
    );
  }
}
