import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C13 · Writing Sample Answer. Browses every bank prompt that has a model
/// answer (filter by task and type). Args: `{'promptId'?, 'task'?}`.
/// Question-bank prompts show their Band 6 / 7 / 8 samples; for the demo
/// prompts, the one named in `sampleAnswers.promptId` shows band 6 / 7
/// versions from writing.json next to its model answer.
class WritingSampleAnswerScreen extends StatefulWidget {
  const WritingSampleAnswerScreen({super.key});

  @override
  State<WritingSampleAnswerScreen> createState() =>
      _WritingSampleAnswerScreenState();
}

class _WritingSampleAnswerScreenState extends State<WritingSampleAnswerScreen> {
  late final Map<String, dynamic> _data =
      WritingContent.all.m('sampleAnswers');

  /// 0 = all, 1 = Task 1, 2 = Task 2.
  int _task = 0;

  /// '' = all types.
  String _type = '';
  String _promptId = '';
  int _index = -1;
  bool _promptOpen = false;
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final args = context.routeArgs;
    final argTask = args['task'];
    if (argTask is num && (argTask == 1 || argTask == 2)) _task = argTask.toInt();
    final argId = args['promptId'] is String ? args['promptId'] as String : '';
    final all = WritingContent.withModelAnswer();
    String pick = '';
    for (final id in <String>[argId, _data.s('promptId')]) {
      if (id.isEmpty) continue;
      if (all.any((p) => p.s('id') == id)) {
        pick = id;
        break;
      }
    }
    if (pick.isNotEmpty && argId == pick) {
      _task = WritingContent.prompt(pick)?.i('task') ?? _task;
    }
    final list = _filtered();
    if (pick.isEmpty || !list.any((p) => p.s('id') == pick)) {
      pick = list.isEmpty ? '' : list.first.s('id');
    }
    _promptId = pick;
  }

  List<Map<String, dynamic>> _filtered() => WritingContent.withModelAnswer(
        task: _task == 0 ? null : _task,
      ).where((p) => _type.isEmpty || p.s('type') == _type).toList();

  /// Types (bank keys) that have model answers for the selected task.
  List<String> _typesOfTask() {
    final out = <String>[];
    if (_task == 0) return out;
    for (final p in WritingContent.withModelAnswer(task: _task)) {
      final ty = p.s('type');
      if (ty.isNotEmpty && !out.contains(ty)) out.add(ty);
    }
    return out;
  }

  void _setFilter({int? task, String? type}) {
    setState(() {
      if (task != null) {
        _task = task;
        _type = '';
      }
      if (type != null) _type = type;
      final list = _filtered();
      if (!list.any((p) => p.s('id') == _promptId)) {
        _promptId = list.isEmpty ? '' : list.first.s('id');
        _index = -1;
        _promptOpen = false;
      }
    });
  }

  void _select(String id) {
    setState(() {
      _promptId = id;
      _index = -1;
      _promptOpen = false;
    });
  }

  /// Answers for [p]: curated lower-band versions (if any) then the model
  /// answer. Each: {band, words, paragraphs, why}.
  List<Map<String, dynamic>> _answersFor(Map<String, dynamic> p) {
    // Question bank: Band 6 / 7 / 8 samples with their own "why".
    final samples = p.l('samples');
    if (samples.isNotEmpty) {
      return <Map<String, dynamic>>[
        for (final a in samples)
          <String, dynamic>{
            'band': a.s('label').isNotEmpty ? a.s('label') : 'Band ${a.s('band')}',
            'words': a.i('words') > 0 ? a.i('words') : essayWords(a.s('text')),
            'paragraphs': a['paragraphs'] ??
                EssayAnalysis.paragraphs(a.s('text'), EssayAnalysis.linkerMarks(a.s('text'), 'link')),
            'why': a.s('why'),
            'text': a.s('text'),
          },
      ];
    }
    final out = <Map<String, dynamic>>[];
    if (_data.s('promptId') == p.s('id')) {
      for (final a in _data.l('answers')) {
        out.add(a);
      }
    }
    final text = p.s('modelAnswer');
    if (text.isNotEmpty) {
      final task = p.i('task') == 1 ? 'task1' : 'task2';
      out.add(<String, dynamic>{
        'band': 'Band ${Store.formatBand(p.d('modelBand'))}',
        'words': essayWords(text),
        'paragraphs': EssayAnalysis.paragraphs(
          text,
          EssayAnalysis.linkerMarks(text, 'link'),
        ),
        'why': _data.m('modelWhy').s(task),
        'text': text,
      });
    }
    return out;
  }

  List<List<Map<String, dynamic>>> _paragraphs(Map<String, dynamic> a) {
    final out = <List<Map<String, dynamic>>>[];
    final raw = a['paragraphs'];
    if (raw is List) {
      for (final p in raw) {
        if (p is List) {
          out.add(
            p.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(),
          );
        }
      }
    }
    return out;
  }

  String _plain(Map<String, dynamic> a) {
    if (a.s('text').isNotEmpty) return a.s('text');
    final b = StringBuffer();
    for (final p in _paragraphs(a)) {
      for (final s in p) {
        b.write(s.s('text'));
      }
      b.write('\n\n');
    }
    return b.toString().trim();
  }

  /// Opens the band comparison for the student's latest essay on this
  /// prompt, or the editor if they haven't written it yet.
  void _compare(Map<String, dynamic>? p) {
    if (p == null) return;
    final promptId = p.s('id');
    for (final a in Store.I.attemptsFor(skill: Skill.writing, kindPrefix: 'task')) {
      if (a.refId == promptId) {
        context.push(
          Routes.writingRewriter,
          args: <String, dynamic>{'attemptId': a.id},
        );
        return;
      }
    }
    context.toast('Write this essay first to compare');
    context.push(
      p.i('task') == 1 ? Routes.writingTask1Editor : Routes.writingEditor,
      args: <String, dynamic>{'promptId': promptId},
    );
  }

  Future<void> _openPicker(List<Map<String, dynamic>> list) async {
    final id = await showAppSheet<String>(
      context,
      _SamplePickerSheet(prompts: list, selectedId: _promptId),
    );
    if (!mounted || id == null) return;
    _select(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final list = _filtered();
    final p = WritingContent.prompt(_promptId);
    final answers = p == null ? <Map<String, dynamic>>[] : _answersFor(p);
    final index = answers.isEmpty
        ? 0
        : (_index < 0 ? answers.length - 1 : _index.clamp(0, answers.length - 1));
    final answer = answers.isEmpty ? <String, dynamic>{} : answers[index];
    final paragraphs = _paragraphs(answer);
    final spans = <InlineSpan>[];
    for (var i = 0; i < paragraphs.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n\n'));
      for (final s in paragraphs[i]) {
        if (s.s('mark') == 'link') {
          spans.add(
            TextSpan(
              text: s.s('text'),
              style: const TextStyle(
                backgroundColor: Color(0xFFDCE6FF),
                color: Color(0xFF151515),
              ),
            ),
          );
        } else {
          spans.add(TextSpan(text: s.s('text')));
        }
      }
    }
    final pos = list.indexWhere((e) => e.s('id') == _promptId);
    final types = _typesOfTask();
    final chart = p == null ? <String, dynamic>{} : p.m('chart');

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 12,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      footer: p == null
          ? null
          : PrimaryButton(
              label: 'Compare with my essay',
              height: 56,
              radius: 18,
              fontSize: 15,
              onTap: () => _compare(p),
            ),
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
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: list.isEmpty ? null : () => _openPicker(list),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p == null
                          ? 'Sample answers'
                          : 'Sample answer · Task ${p.i('task')}',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                    Text(
                      p == null ? 'Model answers' : p.s('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconBox(
              icon: AppIcons.doc,
              tooltip: 'Copy',
              onTap: () {
                if (answer.isEmpty) return;
                Clipboard.setData(ClipboardData(text: _plain(answer)));
                context.toast('Sample answer copied');
              },
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (final k in const <int>[0, 1, 2])
                ChipPill(
                  label: k == 0 ? 'All' : 'Task $k',
                  count: '${WritingContent.withModelAnswer(task: k == 0 ? null : k).length}',
                  selected: _task == k,
                  onTap: () => _setFilter(task: k),
                ),
            ],
          ),
        ),
        if (types.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                ChipPill(
                  label: 'All types',
                  height: 32,
                  selected: _type.isEmpty,
                  onTap: () => _setFilter(type: ''),
                ),
                for (final ty in types)
                  ChipPill(
                    label: WritingContent.typeName(_task, ty),
                    height: 32,
                    selected: _type == ty,
                    onTap: () => _setFilter(type: ty),
                  ),
              ],
            ),
          ),
        if (p == null)
          EmptyState(
            title: 'No sample answers here',
            message: 'Try another task or type filter.',
            icon: AppIcons.doc,
            actionLabel: 'Show all',
            onAction: () => _setFilter(task: 0),
          )
        else ...[
          AppCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: Text(
                        '${p.s('typeLabel')} · ${pos + 1} of ${list.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    _SmallIcon(
                      icon: AppIcons.back,
                      enabled: pos > 0,
                      onTap: () => _select(list[pos - 1].s('id')),
                    ),
                    _SmallIcon(
                      icon: AppIcons.forward,
                      enabled: pos >= 0 && pos < list.length - 1,
                      onTap: () => _select(list[pos + 1].s('id')),
                    ),
                  ],
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _promptOpen = !_promptOpen),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      p.s('prompt'),
                      maxLines: _promptOpen ? null : 3,
                      overflow:
                          _promptOpen ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: t.isNight ? t.text : t.textSoft,
                      ),
                    ),
                  ),
                ),
                if (chart.isNotEmpty || p.s('image').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 4),
                    child: WritingVisual(prompt: p, height: 120),
                  ),
              ],
            ),
          ),
          if (answers.length > 1)
            WSegmented(
              labels: [for (final a in answers) a.s('band')],
              index: index,
              height: 40,
              onChanged: (i) => setState(() => _index = i),
            ),
          AppCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        answers.length > 1
                            ? '${answer.i('words')} words'
                            : '${answer.s('band')} · ${answer.i('words')} words',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE6FF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Linking',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(children: spans),
                  style: TextStyle(fontSize: 14.5, height: 1.65, color: t.text),
                ),
              ],
            ),
          ),
          if (answer.s('why').isNotEmpty)
            HeroCard(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      Icon(AppIcons.sparkle, size: 16, color: t.peach),
                      Expanded(
                        child: Text(
                          'Why this is ${answer.s('band').toLowerCase()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.heroText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    answer.s('why'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: t.heroText.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.surfaceAlt2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 15,
            color: enabled ? t.text : t.textFaint,
          ),
        ),
      ),
    );
  }
}

/// Sheet listing the filtered sample-answer prompts → pops the prompt id.
class _SamplePickerSheet extends StatelessWidget {
  const _SamplePickerSheet({required this.prompts, required this.selectedId});

  final List<Map<String, dynamic>> prompts;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          const SizedBox(height: 8),
          Text(
            'Sample answers · ${prompts.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final p in prompts)
                    AppCard(
                      radius: 18,
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      color: p.s('id') == selectedId ? t.surfaceAlt : null,
                      onTap: () => Navigator.of(context).pop(p.s('id')),
                      child: Row(
                        spacing: 10,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 2,
                              children: [
                                Text(
                                  p.s('title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${p.s('typeLabel')} · Band ${Store.formatBand(p.d('modelBand'))}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: t.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            p.s('id') == selectedId
                                ? AppIcons.check
                                : AppIcons.chevronRight,
                            size: 18,
                            color: p.s('id') == selectedId ? t.text : t.textMuted,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
