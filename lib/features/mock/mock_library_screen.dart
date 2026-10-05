import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../shell/main_shell.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G1 · Mock Test Library & History (bottom-nav tab 2).
class MockLibraryScreen extends StatelessWidget {
  const MockLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final tests = mockTests();
    final history = mockAttempts();
    final next = mockNextScheduledTask(store);
    final lengthLabel = mockContent.m('meta').s('lengthLabel');

    String inLabel = '';
    String dateLabel = '';
    if (next != null) {
      final date = DateTime.tryParse('${next['date']}') ?? DateTime.now();
      final days = DateUtils.dateOnly(date).difference(DateUtils.dateOnly(DateTime.now())).inDays;
      inLabel = days <= 0 ? 'Today' : (days == 1 ? 'Tomorrow' : 'In $days days');
      dateLabel = Store.weekdayDate(date);
    }

    final bands = [for (final a in history) a.band ?? 0.0];
    final best = bands.isEmpty ? null : bands.reduce((a, b) => a > b ? a : b);
    final last = history.isEmpty ? null : history.first.band;
    final average = bands.isEmpty
        ? null
        : Store.roundBand(bands.reduce((a, b) => a + b) / bands.length);

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, MainShell.navClearance),
      gap: 16,
      children: [
        Row(
          children: [
            const SizedBox(width: 56, height: 56),
            const Expanded(
              child: Text(
                'Mock tests',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            IconBox(
              icon: AppIcons.add,
              size: 56,
              radius: 20,
              tooltip: 'New mock test',
              onTap: () => context.push(Routes.mockSystemCheck),
            ),
          ],
        ),
        if (next != null)
          HeroCard(
            padding: const EdgeInsets.all(20),
            radius: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Text(
                            'Next scheduled'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                              color: t.peach,
                            ),
                          ),
                          Text(
                            '${next['title'] ?? 'Mock test'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              letterSpacing: -0.4,
                              color: t.heroText,
                            ),
                          ),
                          MockInkBadge(inLabel),
                        ],
                      ),
                    ),
                    const Nexi(NexiPose.grad, height: 110),
                  ],
                ),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(child: _HeroInfo(label: 'Date', value: dateLabel)),
                    Expanded(
                      child: _HeroInfo(
                        label: 'Starts',
                        value: mockTimeLabel('${next['time'] ?? '09:00'}'),
                      ),
                    ),
                    Expanded(child: _HeroInfo(label: 'Length', value: lengthLabel)),
                  ],
                ),
                PrimaryButton(
                  label: 'Run system check',
                  height: 50,
                  radius: 999,
                  fontSize: 15,
                  onTap: () => context.push(Routes.mockSystemCheck),
                ),
              ],
            ),
          ),
        if (history.isEmpty)
          EmptyState(
            icon: AppIcons.timer,
            title: 'No mock tests yet',
            message: 'Take a full timed mock - Listening, Reading, Writing and '
                'Speaking - to get your overall band and a study plan.',
            actionLabel: 'Start your first mock',
            onAction: () => context.push(Routes.mockSystemCheck),
          )
        else ...[
          Row(
            spacing: 8,
            children: [
              Expanded(child: _StatTile(label: 'Best', value: Store.formatBand(best))),
              Expanded(child: _StatTile(label: 'Last', value: Store.formatBand(last))),
              Expanded(child: _StatTile(label: 'Average', value: Store.formatBand(average))),
            ],
          ),
          AppCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Text(
                          'History',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        'Overall band',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < history.length; i++)
                  _HistoryRow(
                    attempt: history[i],
                    change: i == 0 && history.length > 1
                        ? _change(history[0], history[1])
                        : '',
                    onTap: () => context.push(
                      Routes.mockResults,
                      args: {'attemptId': history[i].id},
                    ),
                  ),
              ],
            ),
          ),
        ],
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Available tests',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              for (final test in tests)
                _TestRow(
                  test: test,
                  taken: mockAttemptsOn(test.s('id')),
                  lengthLabel: lengthLabel,
                  onTap: () => context.push(
                    Routes.mockSystemCheck,
                    args: {'mockId': test.s('id')},
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _change(Attempt a, Attempt b) {
    if (a.band == null || b.band == null) return '';
    final d = a.band! - b.band!;
    if (d.abs() < 0.001) return '';
    return mockSigned(d);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.test,
    required this.taken,
    required this.lengthLabel,
    required this.onTap,
  });

  final Map<String, dynamic> test;
  final List<Attempt> taken;
  final String lengthLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final last = taken.isEmpty ? null : taken.first;
    final status = last == null
        ? <String>['Not started', if (lengthLabel.isNotEmpty) lengthLabel].join(' · ')
        : 'Taken · Band ${Store.formatBand(last.band)} · ${Store.shortDate(last.createdAt)}';
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.surfaceAlt2,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                last == null ? AppIcons.timer : AppIcons.check,
                size: 20,
                color: t.text,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mockTestName(test),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Tag(
              last == null ? 'Start' : 'Retake',
              tone: last == null ? TagTone.primary : TagTone.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.heroChip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: t.heroMuted)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: t.heroText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.attempt, required this.change, required this.onTap});

  final Attempt attempt;
  final String change;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    String b(String k) => Store.formatBand(mockSectionBand(attempt, k));
    final scores = 'L${b('listening')} R${b('reading')} W${b('writing')} S${b('speaking')}';
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
            LetterBadge(
              mockNumberLabel(attempt),
              size: 44,
              radius: 15,
              fontSize: 14,
              bg: t.surfaceAlt2,
              fg: t.text,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attempt.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    '${Store.weekdayDate(attempt.createdAt)} · $scores',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Store.formatBand(attempt.band),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                ),
                if (change.isNotEmpty)
                  Text(change, style: TextStyle(fontSize: 12, color: t.iconAccent)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
