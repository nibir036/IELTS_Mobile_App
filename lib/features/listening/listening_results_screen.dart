
import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// F8 · Listening Practice Results (answer key) for one attempt.
///
/// Reads the attempt passed as `attemptId` (else the newest listening
/// attempt). Correct answers come from the content the attempt was made on.
class ListeningResultsScreen extends StatelessWidget {
  const ListeningResultsScreen({super.key});

  /// Sets the attempt was made on (a full test's 4 parts, or one set).
  List<(Map<String, dynamic>, int)> _sets(Attempt a) {
    final testId = a.data.s('testId');
    if (a.kind == 'test' || testId.isNotEmpty) {
      return listeningSetsFor(testId: testId.isNotEmpty ? testId : a.refId);
    }
    final setId = a.data.s('setId');
    return listeningSetsFor(setId: setId.isNotEmpty ? setId : a.refId);
  }

  /// Answer-key rows: {number, yourAnswer, correctAnswer, ok}, with a
  /// {header} row before each part of a full test.
  List<Map<String, dynamic>> _rows(Attempt a) {
    final given = listeningAnswersOf(a.data);
    final c = a.data['correct'];
    final ok = <int>{
      if (c is List)
        for (final e in c)
          if (e is num) e.toInt(),
    };
    final sets = _sets(a);
    return <Map<String, dynamic>>[
      for (final e in sets) ...[
        if (sets.length > 1)
          <String, dynamic>{'header': 'Part ${e.$1.i('part')} · ${e.$1.s('title')}'},
        for (final it in listeningItems(e.$1, e.$2)) ...listeningItemKey(it, given, ok),
      ],
    ];
  }

  /// Where "Next" goes: (label, route, args).
  (String, String, Map<String, dynamic>) _next(Attempt a) {
    if (a.kind == 'test') {
      final tests = Content.listeningTests;
      for (var i = 0; i < tests.length; i++) {
        if (tests[i].s('id') == a.refId && i + 1 < tests.length) {
          final next = tests[i + 1];
          return (
            'Next · ${next.s('title')}',
            Routes.listeningAnswerSheet,
            <String, dynamic>{'testId': next.s('id')},
          );
        }
      }
      return ('Back to library', Routes.listeningLibrary, <String, dynamic>{});
    }
    final sets = Content.listeningSets;
    final idx = sets.indexWhere((e) => e.s('id') == a.refId);
    Map<String, dynamic>? next;
    for (var k = 1; k <= sets.length; k++) {
      final e = sets[((idx < 0 ? 0 : idx) + k) % sets.length];
      if (e.s('id') != a.refId && latestListeningAttempt(Store.I, e.s('id')) == null) {
        next = e;
        break;
      }
    }
    if (next != null) {
      return (
        'Next set · Part ${next.i('part')}',
        Routes.listeningPlayer,
        <String, dynamic>{'setId': next.s('id'), 'mode': a.data.s('mode')},
      );
    }
    return ('All sets', Routes.listeningMiniList, <String, dynamic>{});
  }

  void _retry(BuildContext context, Attempt a) {
    if (a.kind == 'test') {
      context.replace(
        Routes.listeningAnswerSheet,
        args: <String, dynamic>{'testId': a.refId, 'fresh': true},
      );
    } else if (a.data['source'] == 'sheet') {
      context.replace(
        Routes.listeningAnswerSheet,
        args: <String, dynamic>{'setId': a.refId, 'fresh': true},
      );
    } else {
      context.replace(
        Routes.listeningPlayer,
        args: <String, dynamic>{'setId': a.refId, 'mode': a.data.s('mode'), 'fresh': true},
      );
    }
  }

  Map<String, dynamic> _transcriptArgs(Attempt a) {
    final sets = _sets(a);
    if (sets.length > 1) return <String, dynamic>{'testId': a.refId};
    if (sets.isNotEmpty) return <String, dynamic>{'setId': sets.first.$1.s('id')};
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final wanted = context.routeArgs['attemptId'];
    Attempt? found = store.attemptById(wanted is String ? wanted : null);
    if (found == null || found.skill != Skill.listening) {
      found = null;
      for (final x in store.attemptsFor(skill: Skill.listening)) {
        if (x.kind != 'lesson') {
          found = x;
          break;
        }
      }
    }
    final a = found;
    if (a == null) {
      return AppScreen(
        gap: 16,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        children: [
          ListeningHeader(
            title: 'Results',
            leadingIcon: AppIcons.close,
            leadingTooltip: 'Close',
            onLeading: () => context.back(),
          ),
          EmptyState(
            title: 'No listening results yet',
            message: 'Finish a mini practice set or a full test to see your score and answer key.',
            icon: AppIcons.listening,
            actionLabel: 'Start mini practice',
            onAction: () => context.replace(Routes.listeningMiniList),
          ),
        ],
      );
    }

    final answers = _rows(a);
    final keyRows = answers.where((r) => r['header'] == null).toList();
    final correct = a.score ?? keyRows.where((r) => r['ok'] == true).length;
    final total = a.total ?? keyRows.length;
    final toReview = keyRows.where((r) => r['ok'] != true).length;
    final time = timeLabel(a.durationSec.toDouble(), pad: false);
    var best = correct;
    for (final x in store.attemptsFor(skill: Skill.listening)) {
      if (x.refId == a.refId && x.kind == a.kind && (x.score ?? 0) > best) best = x.score ?? 0;
    }
    final (nextLabel, nextRoute, nextArgs) = _next(a);

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Retry',
              leading: AppIcons.replay,
              height: 56,
              fontSize: 15,
              expand: true,
              bg: t.raised,
              onTap: () => _retry(context, a),
            ),
          ),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: nextLabel,
              trailing: AppIcons.forward,
              height: 56,
              radius: 999,
              fontSize: 15,
              onTap: () => context.replace(nextRoute, args: nextArgs),
            ),
          ),
        ],
      ),
      children: [
        ListeningHeader(
          title: 'Results',
          subtitle: a.title,
          leadingIcon: AppIcons.close,
          leadingTooltip: 'Close',
          onLeading: () => context.back(),
          trailingIcon: AppIcons.article,
          trailingTooltip: 'Transcript',
          onTrailing: () => context.push(Routes.listeningTranscript, args: _transcriptArgs(a)),
        ),
        HeroCard(
          radius: 32,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Score', style: TextStyle(fontSize: 13, color: t.heroMuted)),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$correct'),
                          TextSpan(
                            text: '/$total',
                            style: TextStyle(fontSize: 26, color: t.heroMuted),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        height: 1,
                        letterSpacing: -2,
                        color: t.heroText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kInk,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Est. band ${Store.formatBand(a.band)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kCream,
                      ),
                    ),
                  ),
                  Text(
                    'Time $time · best $best/$total',
                    style: TextStyle(fontSize: 12, color: t.heroMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Answer key',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    Text(
                      toReview == 0 ? 'All correct' : '$toReview to review',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              for (final r in answers)
                if (r['header'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Text(
                      r.s('header'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  )
                else
                  _AnswerRow(answer: r),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.answer});

  final Map<String, dynamic> answer;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final yours = answer.s('yourAnswer');
    final right = answer.s('correctAnswer');
    final ok = answer['ok'] == true;
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Row(
        spacing: 8,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${answer.i('number')}',
              style: TextStyle(
                fontSize: 12,
                color: t.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ok
                  ? t.primary
                  : (t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ok ? AppIcons.check : AppIcons.close,
              size: 14,
              color: ok ? t.onPrimary : t.alert,
            ),
          ),
          Expanded(
            child: Text(
              yours.isEmpty ? '—' : yours,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: ok ? t.text : t.textMuted,
                decoration: ok ? TextDecoration.none : TextDecoration.lineThrough,
                decorationColor: t.textMuted,
              ),
            ),
          ),
          if (!ok)
            Text('→ $right', style: TextStyle(fontSize: 12, color: t.primary)),
        ],
      ),
    );
  }
}
