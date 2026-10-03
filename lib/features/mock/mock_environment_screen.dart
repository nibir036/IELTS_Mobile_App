import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_exit_warning_screen.dart';
import 'mock_questions.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G5 · Full Simulation Test Environment (Reading section of the mock).
class MockEnvironmentScreen extends StatefulWidget {
  const MockEnvironmentScreen({super.key});

  @override
  State<MockEnvironmentScreen> createState() => _MockEnvironmentScreenState();
}

class _MockEnvironmentScreenState extends State<MockEnvironmentScreen> {
  late final Map<String, dynamic> _mock;
  late final List<(Map<String, dynamic>, int)> _passages;
  late final List<MockGroup> _groups;
  late final int _duration;
  final Set<int> _flagged = <int>{};
  late int _seconds;
  int _passage = 0;
  int _current = 1;
  int _tab = 1;
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    MockSession.ensure();
    _mock = MockSession.mock;
    _passages = mockReadingPassages(_mock);
    _groups = mockReadingGroups(_mock);
    final configured = mockContent.m('timing').i('readingSeconds');
    _duration = configured > 0 ? configured : 3600;
    _seconds = _duration;
    _current = _first;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _leaving) return;
      setState(() {
        if (_seconds > 0) _seconds--;
      });
      if (_seconds <= 0) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _p =>
      _passages.isEmpty ? <String, dynamic>{} : _passages[_passage].$1;

  String get _label => 'Passage ${_passage + 1}';

  List<MockGroup> get _passageGroups =>
      _groups.where((g) => g.unitIndex == _passage).toList();

  int get _first => _passages.isEmpty ? 1 : _passages[_passage].$2 + 1;
  int get _count => _passages.isEmpty ? 0 : Content.passageQuestionCount(_p);
  int get _last => _first + _count - 1;

  Set<int> get _answered => mockAnsweredNumbers(_groups, MockSession.reading);

  void _finish() {
    if (_leaving || !mockIsTop(context)) return;
    _leaving = true;
    _timer?.cancel();
    context.replace(Routes.mockTransition, args: {'next': 'writing'});
  }

  void _selectPassage(int i) {
    FocusScope.of(context).unfocus();
    setState(() {
      _passage = i;
      _current = _first;
    });
  }

  void _jump(int n) {
    FocusScope.of(context).unfocus();
    setState(() {
      _current = n;
      _tab = 1;
    });
  }

  void _next() {
    if (_current < _last) {
      _jump(_current + 1);
    } else if (_passage < _passages.length - 1) {
      _selectPassage(_passage + 1);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_current > _first) {
      _jump(_current - 1);
    } else if (_passage > 0) {
      FocusScope.of(context).unfocus();
      setState(() {
        _passage--;
        _current = _last;
      });
    }
  }

  void _toggleFlag() {
    setState(() {
      if (_flagged.contains(_current)) {
        _flagged.remove(_current);
      } else {
        _flagged.add(_current);
      }
    });
  }

  void _answer(int n, String v) {
    setState(() {
      if (v.trim().isEmpty) {
        MockSession.reading.remove(n);
      } else {
        MockSession.reading[n] = v;
      }
    });
  }

  Future<void> _exit() async {
    await confirmMockExit(context, sectionName: 'Reading', secondsLeft: _seconds);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final total = _duration;
    final answered = _answered;
    final answeredHere = answered.where((n) => n >= _first && n <= _last).length;
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
                  title: 'Reading · $_label',
                  subtitle: MockSession.title,
                  seconds: _seconds,
                  low: _seconds <= 300,
                  onExit: _exit,
                ),
                ProgressBar(
                  value: 1 - _seconds / total,
                  height: 4,
                  track: t.isNight ? t.surface : t.border,
                ),
                _TwoTabs(
                  labels: ['Passage', 'Questions $_first–$_last'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: _tab == 0 ? _passageCard() : _questionsCard(),
                  ),
                ),
                if (!typing)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: mockSheetDecoration(t),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: t.isNight ? t.surfaceAlt2 : t.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Quick jump · $_label',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '$answeredHere of $_count answered',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: t.textMuted),
                            ),
                          ),
                        ],
                      ),
                      _grid(answered),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _Legend(color: t.primary, label: 'Answered'),
                          const _Legend(color: kMockFlagPink, label: 'Flagged'),
                          _Legend(
                            color: t.surfaceAlt2,
                            border: t.border,
                            label: 'Unanswered',
                          ),
                        ],
                      ),
                      Row(
                        spacing: 6,
                        children: [
                          for (var i = 0; i < _passages.length; i++)
                            Expanded(
                              child: Material(
                                color: i == _passage ? t.primary : t.surfaceAlt2,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _selectPassage(i),
                                  child: SizedBox(
                                    height: 36,
                                    child: Center(
                                      child: Text(
                                        'Passage ${i + 1}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: i == _passage
                                              ? FontWeight.w500
                                              : FontWeight.w400,
                                          color: i == _passage
                                              ? t.onPrimary
                                              : t.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        spacing: 8,
                        children: [
                          MockSquareButton(
                            icon: AppIcons.chevronLeft,
                            tooltip: 'Previous',
                            onTap: (_passage == 0 && _current <= _first) ? null : _prev,
                          ),
                          Expanded(
                            child: MockWideButton(
                              label: _flagged.contains(_current)
                                  ? 'Unflag Q$_current'
                                  : 'Flag Q$_current',
                              icon: AppIcons.flag,
                              bg: kMockFlagPink,
                              fg: kMockInk,
                              onTap: _toggleFlag,
                            ),
                          ),
                          MockSquareButton(
                            icon: AppIcons.chevronRight,
                            tooltip: 'Next',
                            primary: true,
                            onTap: _next,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(Set<int> answered) {
    final rows = <Widget>[];
    for (var r = 0; r * 7 < _count; r++) {
      rows.add(
        Row(
          spacing: 6,
          children: [
            for (var c = 0; c < 7; c++)
              Expanded(
                child: (r * 7 + c) < _count
                    ? _GridCell(
                        number: _first + r * 7 + c,
                        answered: answered.contains(_first + r * 7 + c),
                        flagged: _flagged.contains(_first + r * 7 + c),
                        current: _current == _first + r * 7 + c,
                        onTap: () => _jump(_first + r * 7 + c),
                      )
                    : const SizedBox(height: 40),
              ),
          ],
        ),
      );
    }
    return Column(spacing: 6, children: rows);
  }

  Widget _passageCard() {
    final t = context.tk;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(
            _p.s('title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          for (final para in _p.l('paragraphs'))
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: t.isNight ? t.text : t.textSoft,
                ),
                children: [
                  if (para.s('letter').isNotEmpty)
                    TextSpan(
                      text: '${para.s('letter')}  ',
                      style: TextStyle(fontWeight: FontWeight.w600, color: t.text),
                    ),
                  TextSpan(text: para.s('text')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _questionsCard() {
    final groups = _passageGroups;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 22,
        children: [
          for (final g in groups)
            MockGroupView(
              key: ValueKey<String>(g.id),
              group: g,
              answers: MockSession.reading,
              current: _current,
              flagged: _flagged,
              onChanged: _answer,
              onCurrent: (n) {
                if (_current != n) setState(() => _current = n);
              },
            ),
        ],
      ),
    );
  }
}

class _TwoTabs extends StatelessWidget {
  const _TwoTabs({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: mockTrackTint(t),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == index ? mockRaisedTint(t) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: i == index ? FontWeight.w500 : FontWeight.w400,
                          color: i == index ? t.text : t.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.number,
    required this.answered,
    required this.flagged,
    required this.current,
    required this.onTap,
  });

  final int number;
  final bool answered;
  final bool flagged;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;
    if (current) {
      bg = mockRaisedTint(t);
      fg = t.text;
      side = BorderSide(color: t.text, width: 1.5);
    } else if (flagged) {
      bg = kMockFlagPink;
      fg = kMockInk;
    } else if (answered) {
      bg = t.primary;
      fg = t.onPrimary;
    } else {
      bg = t.surfaceAlt2;
      fg = t.textMuted;
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    color: fg,
                  ),
                ),
              ),
              if (flagged && !current)
                Positioned(
                  top: 4,
                  right: 5,
                  child: Icon(
                    AppIcons.flag,
                    size: 10,
                    color: t.isNight ? const Color(0xFFB63A26) : t.alert,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
      ],
    );
  }
}
