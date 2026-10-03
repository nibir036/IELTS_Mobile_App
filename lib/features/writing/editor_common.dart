import 'dart:async';

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

/// Shared behaviour of the C2 / C3 editors: prompt selection from route
/// args, draft restore + debounced autosave, elapsed timer, submit.
mixin WritingEditorLogic<T extends StatefulWidget> on State<T> {
  /// 1 or 2 — set by the screen.
  int get editorTask;

  /// Builds the text controller (C2 uses a highlighting controller).
  TextEditingController createController(String text);

  Map<String, dynamic> prompt = <String, dynamic>{};
  TextEditingController? _controller;
  TextEditingController get controller => _controller!;

  int words = 0;
  bool saved = true;
  int _priorElapsed = 0;
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  Timer? _debounce;
  bool _inited = false;
  bool _submitted = false;

  int get elapsedSec => _priorElapsed + _watch.elapsed.inSeconds;

  int get secondsLeft {
    final total = prompt.i('timeSeconds') <= 0
        ? (editorTask == 1 ? 1200 : 2400)
        : prompt.i('timeSeconds');
    final left = total - elapsedSec;
    return left < 0 ? 0 : left;
  }

  int get minWords => prompt.i('minWords') <= 0
      ? (editorTask == 1 ? 150 : 250)
      : prompt.i('minWords');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    _setup(context.routeArgs);
  }

  void _setup(Map<String, dynamic> args) {
    final store = Store.I;
    final draft = WritingDrafts.read(store, editorTask);
    final argId = args['promptId'] is String ? args['promptId'] as String : '';
    Map<String, dynamic>? p = WritingContent.prompt(argId);
    if (p != null && p.i('task') != editorTask) p = null;
    if (p == null && draft != null) {
      p = WritingContent.prompt(draft.s('promptId'));
    }
    p ??= WritingContent.nextPrompt(store, editorTask);
    prompt = p;

    var text = '';
    final argText = args['text'];
    if (argText is String && argText.trim().isNotEmpty) {
      text = argText;
    } else if (draft != null && draft.s('promptId') == prompt.s('id')) {
      text = draft.s('text');
      _priorElapsed = draft.i('elapsedSec');
    }
    _controller = createController(text);
    words = countWords(text);
    controller.addListener(_onEditorText);
    _watch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onEditorText() {
    final w = countWords(controller.text);
    if (!mounted) return;
    setState(() {
      words = w;
      saved = false;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), saveDraft);
  }

  /// Saves the draft now (also used by "Save draft").
  void saveDraft() {
    _debounce?.cancel();
    if (_submitted || _controller == null) return;
    WritingDrafts.save(
      editorTask,
      prompt.s('id'),
      controller.text,
      elapsedSec,
    );
    if (mounted) setState(() => saved = true);
  }

  /// Opens the prompt picker; switching clears the editor (after confirm).
  Future<void> pickPrompt() async {
    final id = await showAppSheet<String>(
      context,
      PromptPickerSheet(task: editorTask, selectedId: prompt.s('id')),
    );
    if (!mounted || id == null || id == prompt.s('id')) return;
    final next = WritingContent.prompt(id);
    if (next == null) return;
    if (controller.text.trim().isNotEmpty) {
      final ok = await showAppDialog<bool>(
        context,
        const ConfirmDialog(
          title: 'Switch prompt?',
          message: 'Your current text will be cleared. Save it somewhere first if you want to keep it.',
          confirmLabel: 'Switch',
          cancelLabel: 'Keep writing',
        ),
      );
      if (!mounted || ok != true) return;
    }
    _debounce?.cancel();
    final draft = WritingDrafts.read(Store.I, editorTask);
    final Map<String, dynamic>? restore =
        (draft != null && draft.s('promptId') == id) ? draft : null;
    controller.removeListener(_onEditorText);
    controller.text = restore == null ? '' : restore.s('text');
    controller.addListener(_onEditorText);
    _priorElapsed = restore == null ? 0 : restore.i('elapsedSec');
    _watch
      ..reset()
      ..start();
    setState(() {
      prompt = next;
      words = countWords(controller.text);
      saved = true;
    });
  }

  /// Scores the essay, stores the attempt and opens the AI feedback screen.
  Future<void> submitEssay() async {
    if (_submitted) return;
    final text = controller.text.trim();
    final n = countWords(text);
    if (n < 20) {
      context.toast('Write at least 20 words to get AI feedback');
      return;
    }
    if (n < minWords) {
      final ok = await showAppDialog<bool>(
        context,
        ConfirmDialog(
          title: 'Submit $n words?',
          message: 'IELTS asks for at least $minWords words. Shorter answers lose marks for ${editorTask == 1 ? 'Task Achievement' : 'Task Response'}.',
          confirmLabel: 'Submit anyway',
          cancelLabel: 'Keep writing',
        ),
      );
      if (!mounted || ok != true) return;
    }
    _debounce?.cancel();
    _submitted = true;
    final essay = <String, dynamic>{
      'prompt': prompt,
      'text': text,
      'elapsedSec': elapsedSec,
    };
    WritingService.pending = essay;
    if (!mounted) return;
    context.replace(
      Routes.writingFeedbackLoading,
      args: <String, dynamic>{'essay': essay},
    );
  }

  /// Call from the screen's dispose() BEFORE super.dispose().
  void disposeEditor() {
    _ticker?.cancel();
    _debounce?.cancel();
    final c = _controller;
    if (c == null) return;
    c.removeListener(_onEditorText);
    if (!_submitted) {
      final task = editorTask;
      final id = prompt.s('id');
      final text = c.text;
      final secs = elapsedSec;
      // Deferred: the store notifies listeners, which must not happen while
      // the widget tree is being torn down.
      Future<void>.microtask(() => WritingDrafts.save(task, id, text, secs));
    }
    c.dispose();
  }
}

/// Two-button confirm dialog → pops true / false.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        Text(
          message,
          style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted),
        ),
        const SizedBox(height: 4),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: WFlatButton(
                label: cancelLabel,
                height: 52,
                bg: t.surfaceAlt,
                fg: t.text,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: PrimaryButton(
                label: confirmLabel,
                height: 52,
                radius: 18,
                fontSize: 15,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet listing the whole prompt bank of one task, grouped by type
/// (Task 1, and Task 2 of the question bank) or topic (demo Task 2), with
/// search and a difficulty filter (Task 2 bank) → pops the prompt id.
class PromptPickerSheet extends StatefulWidget {
  const PromptPickerSheet({
    super.key,
    required this.task,
    required this.selectedId,
  });

  final int task;
  final String selectedId;

  @override
  State<PromptPickerSheet> createState() => _PromptPickerSheetState();
}

class _PromptPickerSheetState extends State<PromptPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  /// '' = every difficulty.
  String _level = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _groupOf(Map<String, dynamic> p) {
    if (widget.task == 1 || p.b('bank')) return p.s('typeName');
    return p.s('topic').isEmpty ? 'Other' : p.s('topic');
  }

  bool _matches(Map<String, dynamic> p, String q) {
    if (_level.isNotEmpty && p.s('difficulty') != _level) return false;
    if (q.isEmpty) return true;
    return p.s('title').toLowerCase().contains(q) ||
        p.s('prompt').toLowerCase().contains(q) ||
        p.s('topic').toLowerCase().contains(q) ||
        p.s('difficulty').toLowerCase().contains(q) ||
        p.s('typeName').toLowerCase().contains(q);
  }

  /// "Education · Moderate" (bank Task 2) / the essay type (demo Task 2).
  String _detailOf(Map<String, dynamic> p) {
    if (widget.task == 1) return '';
    if (p.b('bank')) {
      return <String>[p.s('topic'), p.s('difficulty')].where((e) => e.isNotEmpty).join(' · ');
    }
    return p.s('typeName');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final task = widget.task;
    final all = WritingContent.prompts(task: task);
    final q = _query.trim().toLowerCase();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in all) {
      if (!_matches(p, q)) continue;
      groups.putIfAbsent(_groupOf(p), () => <Map<String, dynamic>>[]).add(p);
    }
    final written = WritingContent.attemptedCount(store, task);
    final levels = WritingContent.difficulties(task);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  task == 1 ? 'Task 1 prompts' : 'Task 2 prompts',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$written of ${all.length} written',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              spacing: 8,
              children: [
                Icon(AppIcons.search, size: 16, color: t.textMuted),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: TextStyle(fontSize: 14, color: t.text),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: task == 1
                          ? 'Search a chart type or title'
                          : 'Search a topic or question',
                      hintStyle: TextStyle(fontSize: 14, color: t.textFaint),
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
                    child: Icon(AppIcons.close, size: 16, color: t.textMuted),
                  ),
              ],
            ),
          ),
          if (levels.isNotEmpty)
            ChipRow(
              labels: <String>['All levels', ...levels],
              selected: _level.isEmpty ? 0 : levels.indexOf(_level) + 1,
              onChanged: (i) => setState(() => _level = i == 0 ? '' : levels[i - 1]),
            ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        _query.trim().isEmpty
                            ? 'No prompts at this level'
                            : 'No prompts match “${_query.trim()}”',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: t.textMuted),
                      ),
                    ),
                  for (final g in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        '${g.key} · ${g.value.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                    for (final p in g.value)
                      _PromptRow(
                        prompt: p,
                        selected: p.s('id') == widget.selectedId,
                        attempt: _latestFor(store, p.s('id')),
                        detail: _detailOf(p),
                        onTap: () => Navigator.of(context).pop(p.s('id')),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Text(
            'Switching prompt clears the editor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ),
    );
  }

  static Attempt? _latestFor(Store store, String promptId) {
    for (final a in store.attemptsFor(skill: Skill.writing)) {
      if (a.refId == promptId) return a;
    }
    return null;
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.prompt,
    required this.selected,
    required this.attempt,
    required this.onTap,
    this.detail = '',
  });

  final Map<String, dynamic> prompt;
  final bool selected;
  final Attempt? attempt;
  final VoidCallback onTap;

  /// Shown before the status (e.g. the essay type); empty = none.
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final a = attempt;
    final status = a == null
        ? 'Not started'
        : 'Band ${Store.formatBand(a.band)} · ${Store.shortDate(a.createdAt)}';
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      color: selected ? t.surfaceAlt : null,
      onTap: onTap,
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  prompt.s('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  detail.isEmpty ? status : '$detail · $status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          Icon(
            selected ? AppIcons.check : AppIcons.chevronRight,
            size: 18,
            color: selected ? t.text : t.textMuted,
          ),
        ],
      ),
    );
  }
}

/// Full-screen empty state for result screens without an essay.
class WritingNoEssay extends StatelessWidget {
  const WritingNoEssay({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      gap: 20,
      children: [
        WHeader(title: title),
        EmptyState(
          title: 'No essays yet',
          message: 'Write a Task 1 report or a Task 2 essay to get your band score and line-by-line AI feedback.',
          icon: AppIcons.writing,
          actionLabel: 'Start writing',
          onAction: () => context.replace(Routes.writingSelector),
        ),
      ],
    );
  }
}
