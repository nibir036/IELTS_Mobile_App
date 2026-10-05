import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_exit_warning_screen.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G4 · Mock - Section Transition. Reads `routeArgs['next']`
/// ('reading' | 'writing' | 'speaking'; defaults to 'reading').
class MockTransitionScreen extends StatefulWidget {
  const MockTransitionScreen({super.key});

  @override
  State<MockTransitionScreen> createState() => _MockTransitionScreenState();
}

class _MockTransitionScreenState extends State<MockTransitionScreen> {
  final Map<String, dynamic> _mock = mockContent;
  String _next = 'reading';
  Map<String, dynamic> _copy = <String, dynamic>{};
  int _total = 30;
  int _left = 24;
  bool _started = false;
  bool _leaving = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    MockSession.ensure();
    final arg = context.routeArgs['next'];
    final transitions = _mock.m('transitions');
    if (arg is String && transitions.containsKey(arg)) _next = arg;
    _copy = transitions.m(_next);
    _total = _copy.i('countdownSeconds') > 0 ? _copy.i('countdownSeconds') : 30;
    _left = _copy.i('startSeconds') > 0 ? _copy.i('startSeconds') : _total;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _leaving) return;
      setState(() {
        if (_left > 0) _left--;
      });
      if (_left <= 0) _go();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _route {
    switch (_next) {
      case 'writing':
        return Routes.mockWriting;
      case 'speaking':
        return Routes.mockSpeaking;
      default:
        return Routes.mockEnvironment;
    }
  }

  void _go() {
    if (_leaving || !mockIsTop(context)) return;
    _leaving = true;
    _timer?.cancel();
    context.replace(_route);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final sections = _mock.l('sections');
    final done = _copy.i('doneCount');
    final value = _total == 0 ? 0.0 : _left / _total;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) confirmMockExit(context);
      },
      child: AppScreen(
      scrollBack: false,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        gap: 16,
        footer: PrimaryButton(
          label: _copy.s('cta'),
          radius: 999,
          trailing: AppIcons.forward,
          onTap: _go,
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconBox(
                icon: AppIcons.close,
                tooltip: 'Exit test',
                iconSize: 18,
                onTap: () => confirmMockExit(context),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MockOutlinePill(MockSession.title),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  'Section $done of ${sections.length} done',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              spacing: 6,
              children: [
                Text(
                  _copy.s('completedLine'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: t.textMuted),
                ),
                Text(
                  _copy.s('headline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Center(
                child: RingProgress(
                  value: value,
                  size: 134,
                  stroke: 10,
                  track: t.isNight ? t.surfaceAlt2 : t.border,
                  fill: t.fill,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mockShortClock(_left),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'seconds',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AppCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++)
                  _SectionRow(
                    index: i,
                    name: sections[i].s('name'),
                    time: mockSectionTime(sections[i], MockSession.mock, short: true),
                    state: i < done ? 0 : (i == done ? 1 : 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _copy.s('note'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.index,
    required this.name,
    required this.time,
    required this.state,
  });

  final int index;
  final String name;
  final String time;

  /// 0 done · 1 next · 2 later.
  final int state;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final laterText = t.isNight ? t.textFaint : t.textMuted;
    Widget badge;
    if (state == 0) {
      badge = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: t.peach,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(AppIcons.check, size: 16, color: kOnPeach),
      );
    } else if (state == 1) {
      badge = Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.text,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: t.surface,
          ),
        ),
      );
    } else {
      badge = Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: t.isNight ? const Color(0xFF333333) : t.border,
          ),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(fontSize: 13, color: laterText),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Row(
        spacing: 12,
        children: [
          badge,
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                color: state == 0 ? t.textMuted : (state == 1 ? t.text : laterText),
              ),
            ),
          ),
          Text(time, style: TextStyle(fontSize: 13, color: t.textMuted)),
        ],
      ),
    );
  }
}
