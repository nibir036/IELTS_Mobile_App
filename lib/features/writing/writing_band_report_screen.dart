import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/share_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'editor_common.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C5 · Writing Band Score Report (AI-driven feedback).
///
/// Shows `args['attemptId']` or the newest writing essay.
class WritingBandReportScreen extends StatelessWidget {
  const WritingBandReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final a = store.resolveAttempt(
      context.routeArgs,
      skill: Skill.writing,
      kindPrefix: 'task',
    );
    if (a == null) return const WritingNoEssay(title: 'Essay feedback');
    final task = WritingService.taskOf(a);
    // The AI examiner's own comment per criterion (its first sentence) when
    // there is one; otherwise the band-based note.
    final aiNotes = a.data.m('criteriaFeedback');
    String firstSentence(String s) {
      final m = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(s.trim());
      return (m?.group(0) ?? s).trim();
    }

    final notes = <String, dynamic>{
      ...a.data.m('notes'),
      for (final k in aiNotes.keys)
        if (aiNotes.s(k).trim().isNotEmpty) k: firstSentence(aiNotes.s(k)),
    };
    const keys = <String>['TA', 'CC', 'LR', 'GRA'];
    final names = <String>[
      task == 1 ? 'Task\nAchievement' : 'Task\nResponse',
      'Coherence\n& Cohesion',
      'Lexical\nResource',
      'Grammar\nRange & Acc.',
    ];
    final bands = [for (final k in keys) WritingService.criterion(a, k)];
    final minBand = bands.reduce((x, y) => x < y ? x : y);
    final maxBand = bands.reduce((x, y) => x > y ? x : y);
    var flagged = false;
    final criteria = <Map<String, dynamic>>[];
    for (var i = 0; i < keys.length; i++) {
      final flag = !flagged && bands[i] == minBand && minBand < maxBand;
      if (flag) flagged = true;
      criteria.add(<String, dynamic>{
        'name': names[i],
        'band': Store.formatBand(bands[i]),
        'progress': bands[i] / 9,
        'flag': flag,
        'note': notes.s(keys[i]).isNotEmpty
            ? notes.s(keys[i])
            : WritingService.criterionNote(keys[i], bands[i], task),
      });
    }
    final suggestions = WritingService.suggestions(a);
    final target = store.current?.targetBand;
    final minutes = (a.durationSec / 60).round();
    final meta = <String>[
      'Task $task',
      a.title,
      '${a.data.i('words')} words',
      if (minutes > 0) '$minutes min',
    ].join(' · ');
    final args = <String, dynamic>{'attemptId': a.id};
    final summary = a.data.s('summary').trim();
    final isDemo = a.data.s('source') == 'demo';
    final shareText = _shareText(
      a: a,
      task: task,
      criteria: <String>[
        '${task == 1 ? 'Task Achievement (TA)' : 'Task Response (TR)'}: ${Store.formatBand(bands[0])}',
        'Coherence & Cohesion (CC): ${Store.formatBand(bands[1])}',
        'Lexical Resource (LR): ${Store.formatBand(bands[2])}',
        'Grammatical Range & Accuracy (GRA): ${Store.formatBand(bands[3])}',
      ],
      tips: suggestions,
    );

    final rows = <Widget>[];
    for (var i = 0; i < criteria.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Expanded(child: _CriterionCard(c: criteria[i])),
              Expanded(
                child: i + 1 < criteria.length
                    ? _CriterionCard(c: criteria[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 14,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: WFlatButton(
              label: 'Line by line',
              bg: t.surface,
              fg: t.text,
              onTap: () => context.push(Routes.writingLineReview, args: args),
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: WritingService.rewriteLabel(a),
              trailing: AppIcons.forward,
              height: 56,
              radius: 18,
              fontSize: 15,
              onTap: () => context.push(Routes.writingRewriter, args: args),
            ),
          ),
        ],
      ),
      children: [
        WHeader(
          title: 'Essay feedback',
          trailing: IconBox(
            icon: AppIcons.share,
            tooltip: 'Share',
            onTap: () => ShareService.shareText(
              context,
              shareText,
              subject: 'My IELTS Writing Task $task feedback · Band ${Store.formatBand(a.band)}',
            ),
          ),
        ),
        HeroCard(
          radius: 30,
          padding: const EdgeInsets.all(20),
          gradient: t.isNight ? null : wGradient(0xFFF7C3D4, 0xFFFBE6EE),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated band',
                      style: TextStyle(fontSize: 13, color: t.heroMuted),
                    ),
                    Text(
                      Store.formatBand(a.band),
                      style: TextStyle(
                        fontSize: 76,
                        fontWeight: FontWeight.w300,
                        height: 0.95,
                        letterSpacing: -3,
                        color: t.heroText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.heroMuted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Target',
                      style: TextStyle(
                        fontSize: 12,
                        color: wc(t, 0xFFBDB6BB, 0xFF9A9A9A),
                      ),
                    ),
                    Text(
                      Store.formatBand(target),
                      style: const TextStyle(
                        fontSize: 26,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (summary.isNotEmpty)
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Icon(AppIcons.sparkle, size: 18, color: t.iconAccent),
                Expanded(
                  child: Text(
                    summary,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: t.isNight ? t.textSoft : t.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...rows,
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              const Text(
                'Top suggestions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              for (var i = 0; i < suggestions.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCDDFA),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF151515),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        suggestions[i],
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (isDemo)
          Center(
            child: Text(
              a.data.s('offlineReason').isNotEmpty
                  ? '${a.data.s('offlineReason')}\nEstimated offline (AI unavailable)'
                  : 'Estimated offline (AI unavailable)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ),
      ],
    );
  }
}

String _shareText({
  required Attempt a,
  required int task,
  required List<String> criteria,
  required List<String> tips,
}) {
  final b = StringBuffer()
    ..writeln('IELTS Academic Writing Task $task feedback')
    ..writeln('${a.title} · ${Store.weekdayDate(a.createdAt)} ${a.createdAt.year}')
    ..writeln('Word count: ${a.data.i('words')}')
    ..writeln()
    ..writeln('Overall band: ${Store.formatBand(a.band)}');
  for (final c in criteria) {
    b.writeln(c);
  }
  final top = tips.where((x) => x.trim().isNotEmpty).take(3).toList();
  if (top.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Key tips:');
    for (var i = 0; i < top.length; i++) {
      b.writeln('${i + 1}. ${top[i].trim()}');
    }
  }
  b
    ..writeln()
    ..write('Practised with IELTS AI by nextED');
  return b.toString();
}

class _CriterionCard extends StatelessWidget {
  const _CriterionCard({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.s('name'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: t.textMuted,
                  ),
                ),
              ),
              Text(c.s('band'), style: const TextStyle(fontSize: 26, height: 1)),
            ],
          ),
          ProgressBar(
            value: c.d('progress'),
            height: 6,
            track: wc(t, 0xFFF1E6EC, 0xFF1F1F1F),
            fill: c.b('flag') ? t.alert : t.fill,
          ),
          Text(
            c.s('note'),
            style: TextStyle(fontSize: 12, height: 1.35, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}
