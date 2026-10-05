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

/// C11 · IELTS Ideas & Topics Library, built from the Task 2 bank: topics
/// are the prompts' `topic`s; each prompt's `ideas` (for / against /
/// vocabulary) open in a sheet with "Write this essay". The featured card is
/// the topic's combined idea set. Bookmarks are prompt ids in kv
/// `writing.ideas.bookmarks`.
class IdeasTopicsScreen extends StatefulWidget {
  const IdeasTopicsScreen({super.key});

  @override
  State<IdeasTopicsScreen> createState() => _IdeasTopicsScreenState();
}

/// Reading time of an idea set.
int ideaMinutes(Map<String, dynamic> ideas) {
  final n = ideas.ls('for').length + ideas.ls('against').length;
  final v = ideas.ls('vocabulary').length;
  final m = 2 + (n + 1) ~/ 2 + v ~/ 6;
  return m < 3 ? 3 : m;
}

class _IdeasTopicsScreenState extends State<IdeasTopicsScreen> {
  late final List<String> _topics = WritingContent.topics();
  late final List<Map<String, dynamic>> _prompts = WritingContent.ideaPrompts();
  /// Index into [_topics]; -1 = All topics (the default).
  late int _selected = _initial();
  final TextEditingController _search = TextEditingController();
  String _query = '';

  int _initial() => -1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _inTopic(String topic) =>
      _prompts.where((p) => p.s('topic') == topic).toList();

  bool _matches(Map<String, dynamic> p, String q) {
    if (p.s('title').toLowerCase().contains(q) ||
        p.s('prompt').toLowerCase().contains(q) ||
        p.s('topic').toLowerCase().contains(q)) {
      return true;
    }
    final ideas = p.m('ideas');
    for (final k in const <String>['for', 'against', 'vocabulary']) {
      for (final s in ideas.ls(k)) {
        if (s.toLowerCase().contains(q)) return true;
      }
    }
    return false;
  }

  /// The topic's ideas merged across its prompts (duplicates dropped).
  Map<String, dynamic> _topicIdeas(List<Map<String, dynamic>> prompts) {
    final out = <String, List<String>>{
      'for': <String>[],
      'against': <String>[],
      'vocabulary': <String>[],
    };
    for (final p in prompts) {
      final ideas = p.m('ideas');
      for (final k in out.keys) {
        for (final s in ideas.ls(k)) {
          if (!out[k]!.contains(s)) out[k]!.add(s);
        }
      }
    }
    return out;
  }

  void _openIdeas({
    required String label,
    required String title,
    required Map<String, dynamic> ideas,
    Map<String, dynamic>? prompt,
  }) {
    showAppSheet<void>(
      context,
      _IdeasSheet(label: label, title: title, ideas: ideas, prompt: prompt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bookmarks = context.store.kvSet(WritingKeys.ideaBookmarks);
    final all = _selected < 0 || _selected >= _topics.length;
    final topic = all ? 'All topics' : _topics[_selected];
    final inTopic = all ? _prompts : _inTopic(topic);
    final featuredIdeas = _topicIdeas(inTopic);
    final arguments = featuredIdeas.ls('for').length +
        featuredIdeas.ls('against').length;
    final q = _query.trim().toLowerCase();

    final items = q.isEmpty
        ? inTopic
        : _prompts.where((p) => _matches(p, q)).toList();

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gap: 12,
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.back,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            const Expanded(
              child: Text(
                'IELTS Ideas & Topics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            spacing: 10,
            children: [
              Icon(AppIcons.search, size: 18, color: t.textMuted),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 15, color: t.text),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search a topic, question or idea',
                    hintStyle: TextStyle(fontSize: 15, color: t.textFaint),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  child: Icon(AppIcons.close, size: 18, color: t.textMuted),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _CategoryChip(
              name: 'All',
              count: _prompts.length,
              selected: all,
              onTap: () => setState(() => _selected = -1),
            ),
            for (var i = 0; i < _topics.length; i++)
              _CategoryChip(
                name: _topics[i],
                count: _inTopic(_topics[i]).length,
                selected: i == _selected,
                onTap: () => setState(() => _selected = i),
              ),
          ],
        ),
        if (q.isEmpty && !all && arguments > 0)
          HeroCard(
            radius: 28,
            padding: const EdgeInsets.all(18),
            onTap: () => _openIdeas(
              label: '$topic · idea set',
              title: '$topic - $arguments arguments both ways',
              ideas: featuredIdeas,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 12,
                    color: t.heroMuted,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.hash,
                        size: 14,
                        color: t.peach,
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Text(topic)),
                      Text('Idea set · ${ideaMinutes(featuredIdeas)} min'),
                    ],
                  ),
                ),
                Text(
                  '$topic - $arguments arguments both ways',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    letterSpacing: -0.3,
                    color: t.heroText,
                  ),
                ),
                Row(
                  spacing: 8,
                  children: [
                    Text(
                      'Open idea set',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.peach,
                      ),
                    ),
                    Icon(AppIcons.forward, size: 16, color: t.peach),
                  ],
                ),
              ],
            ),
          ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.isEmpty
                            ? '$topic · ${inTopic.length}'
                            : 'Results · ${items.length}',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    Text(
                      'Task 2 questions',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              for (final p in items)
                _IdeaRow(
                  prompt: p,
                  showTopic: q.isNotEmpty || all,
                  saved: bookmarks.contains(p.s('id')),
                  onBookmark: () => Store.I.kvSetToggle(
                    WritingKeys.ideaBookmarks,
                    p.s('id'),
                  ),
                  onTap: () => _openIdeas(
                    label: '${p.s('topic')} · ${p.s('typeName')}',
                    title: p.s('title'),
                    ideas: p.m('ideas'),
                    prompt: p,
                  ),
                ),
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.divider)),
                  ),
                  child: Text(
                    'No matching topics',
                    style: TextStyle(fontSize: 14, color: t.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 38,
      child: Material(
        color: selected ? t.primary : t.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? t.onPrimary : t.text,
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? (t.isNight
                            ? const Color(0xFF5E5056)
                            : const Color(0xFF625C66))
                        : t.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdeaRow extends StatelessWidget {
  const _IdeaRow({
    required this.prompt,
    required this.showTopic,
    required this.saved,
    required this.onBookmark,
    required this.onTap,
  });

  final Map<String, dynamic> prompt;
  final bool showTopic;
  final bool saved;
  final VoidCallback onBookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tags = <String>[
      if (showTopic && prompt.s('topic').isNotEmpty) prompt.s('topic'),
      prompt.s('typeName'),
      if (prompt.s('modelAnswer').isNotEmpty) 'Model answer',
    ];
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.divider)),
        ),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  Text(
                    prompt.s('title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final tag in tags)
                        Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: t.surfaceAlt2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              tag,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${ideaMinutes(prompt.m('ideas'))} min',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onBookmark,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                  size: 18,
                  color: saved ? t.text : t.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Idea set sheet: question (if any), arguments for / against, vocabulary,
/// and - for a single prompt -"Write this essay" / "Sample answer".
class _IdeasSheet extends StatelessWidget {
  const _IdeasSheet({
    required this.label,
    required this.title,
    required this.ideas,
    this.prompt,
  });

  final String label;
  final String title;
  final Map<String, dynamic> ideas;
  final Map<String, dynamic>? prompt;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final p = prompt;
    final vocab = ideas.ls('vocabulary');

    Widget list(String heading, List<String> items, Color dot) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(
            '$heading · ${items.length}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          for (final s in items)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                ),
                Expanded(
                  child: Text(
                    s,
                    style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textSoft),
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  if (p != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        p.s('prompt'),
                        style: TextStyle(fontSize: 13, height: 1.45, color: t.text),
                      ),
                    ),
                  list('Arguments for', ideas.ls('for'), t.text),
                  list('Arguments against', ideas.ls('against'), t.alert),
                  if (vocab.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        Text(
                          'Useful vocabulary · ${vocab.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final v in vocab)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: t.accentSoft2,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  v,
                                  style: TextStyle(fontSize: 12, color: t.text),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (p != null)
            Row(
              spacing: 8,
              children: [
                if (p.s('modelAnswer').isNotEmpty)
                  Expanded(
                    child: WFlatButton(
                      label: 'Sample answer',
                      height: 52,
                      bg: t.surfaceAlt,
                      fg: t.text,
                      onTap: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        nav.pushNamed(
                          Routes.writingSampleAnswer,
                          arguments: <String, dynamic>{'promptId': p.s('id')},
                        );
                      },
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Write this essay',
                    height: 52,
                    radius: 18,
                    fontSize: 15,
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.pushNamed(
                        Routes.writingEditor,
                        arguments: <String, dynamic>{'promptId': p.s('id')},
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
