import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// Shows the "Leave the mock test?" card (G11) as a dialog. Confirming
/// exit resets to the Mock tab and returns true.
Future<bool> confirmMockExit(
  BuildContext context, {
  String sectionName = 'this section',
  int? secondsLeft,
}) async {
  final result = await showAppDialog<bool>(
    context,
    Builder(
      builder: (ctx) => MockExitContent(
        sectionName: sectionName,
        secondsLeft: secondsLeft,
        onKeep: () => Navigator.of(ctx).pop(false),
        onExit: () => Navigator.of(ctx).pop(true),
      ),
    ),
  );
  final leave = result ?? false;
  if (leave) MockSession.discard();
  if (leave && context.mounted) {
    context.resetTo(Routes.home, args: {'tab': 2});
  }
  return leave;
}

/// Body of the exit-confirm card: icon, title, copy, two buttons.
class MockExitContent extends StatelessWidget {
  const MockExitContent({
    super.key,
    required this.sectionName,
    required this.onKeep,
    required this.onExit,
    this.secondsLeft,
  });

  final String sectionName;
  final int? secondsLeft;
  final VoidCallback onKeep;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tail = secondsLeft == null
        ? 'Leaving now ends $sectionName.'
        : 'Leaving now ends $sectionName with ${mockClock(secondsLeft!)} left.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFBE5ED),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              AppIcons.logout,
              size: 24,
              color: t.isNight ? const Color(0xFFB63A26) : t.alert,
            ),
          ),
        ),
        const Text(
          'Leave the mock test?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.4,
          ),
        ),
        Text(
          'Your answers are saved, but the timer keeps running and can’t be paused. $tail',
          style: TextStyle(fontSize: 14, height: 1.5, color: t.textMuted),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: PrimaryButton(
            label: 'Keep going',
            height: 56,
            radius: 18,
            onTap: onKeep,
          ),
        ),
        OutlineButtonX(
          label: 'Exit test',
          height: 52,
          radius: 18,
          fontSize: 15,
          color: t.alert,
          onTap: onExit,
        ),
      ],
    );
  }
}

/// G11 · Mock Exit Confirm & Timer Warning (full-screen artboard version).
class MockExitWarningScreen extends StatefulWidget {
  const MockExitWarningScreen({super.key});

  @override
  State<MockExitWarningScreen> createState() => _MockExitWarningScreenState();
}

class _MockExitWarningScreenState extends State<MockExitWarningScreen> {
  final Map<String, dynamic> _data = mockContent.m('exitWarning');
  late int _seconds = _data.i('secondsLeft');
  Timer? _timer;
  String? _picked;

  /// Backdrop question: the last multiple-choice question of the mock's
  /// final reading passage (bank content).
  late final (MockGroup?, MockQuestion?) _backdrop = _findQuestion();

  static (MockGroup?, MockQuestion?) _findQuestion() {
    final mock = MockSession.active ? MockSession.mock : mockTest(mockDefaultId());
    final groups = mockReadingGroups(mock);
    for (final g in groups.reversed) {
      for (final q in g.questions.reversed) {
        if (q.options.isNotEmpty) return (g, q);
      }
    }
    return (null, null);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) _seconds--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _exit() {
    MockSession.discard();
    context.resetTo(Routes.home, args: {'tab': 2});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final g = _backdrop.$1;
    final q = _backdrop.$2;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  MockExamHeader(
                    title: _data.s('title'),
                    subtitle: MockSession.active ? MockSession.title : mockNextTitle(),
                    seconds: _seconds,
                    low: true,
                    onExit: () {},
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBE5ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: t.isNight
                            ? const Color(0xFF5C2A20)
                            : const Color(0xFFF4B8CB),
                      ),
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          AppIcons.hourglass,
                          size: 16,
                          color: t.isNight ? const Color(0xFF625C66) : t.warning,
                        ),
                        Expanded(
                          child: Text(
                            _data.s('banner'),
                            style: TextStyle(
                              fontSize: 13,
                              color: t.isNight ? const Color(0xFF625C66) : t.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (g != null && q != null)
                    AppCard(
                      radius: 24,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 10,
                        children: [
                          Text(
                            '${g.range} · ${g.title}',
                            style: TextStyle(fontSize: 12, color: t.textMuted),
                          ),
                          Text(
                            q.text,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          for (final o in q.options)
                            MockChoiceOption(
                              letter: o.key,
                              text: o.text,
                              selected: _picked == o.key,
                              onTap: () => setState(() => _picked = o.key),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () => context.back(),
              child: ColoredBox(
                color: t.isNight
                    ? Colors.black.withValues(alpha: 0.6)
                    : const Color(0xFF151515).withValues(alpha: 0.45),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: MockExitContent(
                sectionName: _data.s('sectionName'),
                secondsLeft: _seconds,
                onKeep: () => context.back(),
                onExit: _exit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
