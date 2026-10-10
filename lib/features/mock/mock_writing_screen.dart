import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/media.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/zoom_image.dart';
import 'mock_chart.dart';
import 'mock_exit_warning_screen.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G6 · Mock - Writing Section (Task 1 + Task 2 on one timer).
class MockWritingScreen extends StatefulWidget {
  const MockWritingScreen({super.key});

  @override
  State<MockWritingScreen> createState() => _MockWritingScreenState();
}

class _MockWritingScreenState extends State<MockWritingScreen> {
  late final List<Map<String, dynamic>> _tasks = _buildTasks();
  late final List<TextEditingController> _controllers = [
    for (var i = 0; i < _tasks.length; i++)
      TextEditingController(text: MockSession.writing[i] ?? ''),
  ];
  late int _seconds = mockContent.m('timing').i('writingSeconds') > 0
      ? mockContent.m('timing').i('writingSeconds')
      : 3600;
  bool _showChart = true;
  int _savedAgo = 0;
  int _task = 0;
  Timer? _timer;
  bool _leaving = false;

  /// Task 1 + Task 2 of the mock: UI config (label, min words, editor label,
  /// requirement) merged with the bank prompt (+ Task 1 chart).
  static List<Map<String, dynamic>> _buildTasks() {
    MockSession.ensure();
    final mock = MockSession.mock;
    final config = mockContent.l('writingTasks');
    final prompts = <Map<String, dynamic>>[mockTask1(mock), mockTask2(mock)];
    return <Map<String, dynamic>>[
      for (var i = 0; i < prompts.length; i++)
        <String, dynamic>{
          if (i < config.length) ...config[i],
          'label': i < config.length && config[i].s('label').isNotEmpty ? config[i].s('label') : 'Task ${i + 1}',
          'prompt': prompts[i].s('prompt'),
          'type': prompts[i].s('type'),
          'chart': prompts[i].m('chart'),
          'image': prompts[i].s('image'),
        },
    ];
  }

  @override
  void initState() {
    super.initState();
    MockSession.ensure();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _leaving) return;
      setState(() {
        if (_seconds > 0) _seconds--;
        _savedAgo++;
      });
      if (_seconds <= 0) _submit();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_leaving || !mockIsTop(context)) return;
    _leaving = true;
    _timer?.cancel();
    context.replace(Routes.mockTransition, args: {'next': 'speaking'});
  }

  Future<void> _exit() async {
    await confirmMockExit(context, sectionName: 'Writing', secondsLeft: _seconds);
  }

  String get _savedLabel =>
      _savedAgo < 2 ? 'autosaved just now' : 'autosaved $_savedAgo s ago';

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final task = _tasks.isEmpty ? <String, dynamic>{} : _tasks[_task];
    final body = t.isNight ? t.text : t.textSoft;
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                MockExamHeader(
                  title: 'Writing · ${task.s('label')}',
                  subtitle: MockSession.title,
                  seconds: _seconds,
                  low: _seconds <= 300,
                  onExit: _exit,
                ),
                const MockSectionTabs(current: 2),
                Row(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < _tasks.length; i++)
                      Expanded(
                        child: _TaskCard(
                          label: _tasks[i].s('label'),
                          words: mockWordCount(_controllers[i].text),
                          minWords: _tasks[i].i('minWords'),
                          selected: i == _task,
                          onTap: () => setState(() => _task = i),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // The prompt scroll area gives up height before the
                      // editor does (250 on a normal phone).
                      // While typing the question stays (smaller, scrollable).
                      final promptMax = typing
                          ? (box.maxHeight * 0.3).clamp(48.0, 170.0).toDouble()
                          : (box.maxHeight - 200).clamp(60.0, 250.0).toDouble();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 10,
                        children: [
                          AppCard(
                          radius: 24,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 6,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: promptMax),
                                child: SingleChildScrollView(
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    spacing: 10,
                                    children: [
                                      Text(
                                        task.s('prompt'),
                                        style: TextStyle(fontSize: 14, height: 1.5, color: body),
                                      ),
                                      if (_task == 0 && task.m('chart').isNotEmpty && _showChart)
                                        MockTask1Chart(type: task.s('type'), chart: task.m('chart'))
                                      else if (_task == 0 && task.s('image').isNotEmpty && _showChart)
                                        Semantics(
                                          image: true,
                                          label: 'Task 1 picture. Tap or pinch to enlarge.',
                                          child: PinchToZoomImage(
                                            image: task.s('image'),
                                            title: 'Writing Task 1',
                                            child: Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Container(
                                                    color: Colors.white,
                                                    width: double.infinity,
                                                    child: MediaImage(
                                                      task.s('image'),
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 6,
                                                  bottom: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(5),
                                                    decoration: BoxDecoration(
                                                      color: t.surface.withValues(alpha: 0.9),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(AppIcons.zoomIn, size: 16, color: t.textMuted),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                spacing: 8,
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.s('requirement'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: t.textMuted),
                                    ),
                                  ),
                                  if (_task == 0 && (task.m('chart').isNotEmpty || task.s('image').isNotEmpty))
                                    GestureDetector(
                                      onTap: () => setState(() => _showChart = !_showChart),
                                      child: Text(
                                        _showChart ? 'Hide chart' : 'Show chart',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: t.text,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 8,
                              children: [
                                Text(
                                  '${task.s('editorLabel')} · $_savedLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: t.textMuted),
                                ),
                                Expanded(
                                  child: _controllers.isEmpty
                                      ? const SizedBox()
                                      : TextField(
                                          key: ValueKey<int>(_task),
                                          controller: _controllers[_task],
                                          expands: true,
                                          maxLines: null,
                                          minLines: null,
                                          keyboardType: TextInputType.multiline,
                                          textAlignVertical: TextAlignVertical.top,
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          spellCheckConfiguration:
                                              const SpellCheckConfiguration.disabled(),
                                          cursorColor: t.alert,
                                          cursorWidth: 1.5,
                                          onChanged: (v) => setState(() {
                                            MockSession.writing[_task] = v;
                                            _savedAgo = 0;
                                          }),
                                          style: TextStyle(fontSize: 15, height: 1.6, color: t.text),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            hintText: 'Start writing…',
                                            hintStyle: TextStyle(color: t.textFaint),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        'Spell-check and AI hints are off during the mock.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.35, color: t.textMuted),
                      ),
                    ),
                    PrimaryButton(
                      label: 'Submit writing',
                      height: 54,
                      radius: 18,
                      fontSize: 15,
                      expand: false,
                      onTap: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.label,
    required this.words,
    required this.minWords,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int words;
  final int minWords;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final done = minWords > 0 && words >= minWords;
    final fg = selected ? t.onPrimary : t.text;
    final sub = selected
        ? (t.isNight ? const Color(0xFF5E5056) : const Color(0xFFB5B5B5))
        : t.textMuted;
    Widget box;
    if (done) {
      box = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? t.onPrimary : t.primary,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          AppIcons.check,
          size: 14,
          color: selected ? t.primary : t.onPrimary,
        ),
      );
    } else {
      box = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: fg, width: 1.5),
        ),
      );
    }
    return Material(
      color: selected ? t.primary : t.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            spacing: 8,
            children: [
              box,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                    Text(
                      done ? '$words words · done' : '$words / $minWords words',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
