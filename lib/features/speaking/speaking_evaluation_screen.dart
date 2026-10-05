import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/share_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// D6 · Speaking evaluation & band report for one attempt
/// (`{'attemptId'}` or the newest speaking answer).
class SpeakingEvaluationScreen extends StatelessWidget {
  const SpeakingEvaluationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final heroMuted = t.heroMuted;
    final heroBody = t.heroText.withValues(alpha: 0.88);
    final a = resolveSpeakingAnswer(context);
    if (a == null) {
      return AppScreen(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        gap: 14,
        children: [
          const _Header(),
          EmptyState(
            icon: AppIcons.chart,
            title: 'No speaking report yet',
            message: 'Record an answer and your band, criteria scores and tips appear here.',
            actionLabel: 'Start speaking practice',
            onAction: () => openHub(context),
          ),
        ],
      );
    }
    final band = a.band ?? 0.0;
    final crit = a.data['criteria'];
    final critMap = crit is Map ? crit.cast<String, dynamic>() : <String, dynamic>{};
    var minBand = 9.0;
    for (final c in kSpeakingCriteria) {
      final v = critMap.d(c.$1);
      if (v < minBand) minBand = v;
    }
    // The server's full evaluation (synced in) fills gaps for answers saved
    // before these details were stored locally.
    final ev = a.data.m('evaluation');
    Map<String, dynamic> pick(String key, String evKey) =>
        a.data.m(key).isNotEmpty ? a.data.m(key) : ev.m(evKey);
    List<Map<String, dynamic>> pickList(String key, String evKey) =>
        a.data.l(key).isNotEmpty ? a.data.l(key) : ev.l(evKey);
    final critNotes = pick('criteriaFeedback', 'criteriaFeedback');
    final criteria = <Map<String, dynamic>>[
      for (final c in kSpeakingCriteria)
        <String, dynamic>{
          'name': c.$2,
          'band': critMap.d(c.$1),
          'progress': (critMap.d(c.$1) / 9).clamp(0.0, 1.0).toDouble(),
          'weak': critMap.d(c.$1) == minBand && minBand < band,
          'note': critNotes.s(c.$1).trim(),
        },
    ];
    // Full AI report (speaking service): quoted strengths, mistakes, fluency
    // patterns and sounds to practise. Empty for demo-scored answers.
    final strengths = <Map<String, dynamic>>[
      for (final s in pickList('aiStrengths', 'strengths'))
        if (s.s('quote').trim().isNotEmpty) s,
    ];
    final mistakes = <Map<String, dynamic>>[
      for (final e in a.data.l('errors'))
        if (e.s('original').trim().isNotEmpty) e,
    ];
    final fluency = pick('fluencyReport', 'fluency');
    final fluencyObs = <Map<String, dynamic>>[
      for (final o in fluency.l('observations'))
        if (o.s('quote').trim().isNotEmpty) o,
    ];
    final pron = pick('pronunciationReport', 'pronunciation');
    final sounds = <Map<String, dynamic>>[
      for (final s in pron.l('issues'))
        if (s.s('phoneme').trim().isNotEmpty) s,
    ];
    final perPart = a.data.ls('perPartFeedback').isNotEmpty
        ? a.data.ls('perPartFeedback')
        : ev.ls('perPartFeedback');
    final steps = a.data.ls('feedback');
    final summary = a.data.s('summary').isNotEmpty ? a.data.s('summary') : speakingSummary(band);
    double? previous;
    var seen = false;
    for (final x in context.store.attemptsFor(skill: Skill.speaking)) {
      if (x.id == a.id) {
        seen = true;
        continue;
      }
      if (seen && x.band != null && x.kind != 'pronunciation') {
        previous = x.band;
        break;
      }
    }
    final String delta;
    if (previous == null) {
      delta = 'First report';
    } else {
      final diff = band - previous;
      delta = diff == 0
          ? 'Same as last'
          : '${diff > 0 ? '+' : '−'}${diff.abs().toStringAsFixed(1)} vs last';
    }
    final spoken = spokenSecOf(a);
    final durationLabel = spoken >= 60
        ? '${spoken ~/ 60} min ${spoken % 60} s'
        : '$spoken s';
    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      gap: 14,
      footerPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Re-record',
              height: 56,
              radius: 18,
              fontSize: 15,
              bg: t.surface,
              expand: true,
              onTap: () => reRecordAttempt(context, a),
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: 'Train pronunciation',
              height: 56,
              radius: 18,
              fontSize: 15,
              onTap: () => context.push(Routes.pronunciation),
            ),
          ),
        ],
      ),
      children: [
        _Header(
          shareSubject: 'My IELTS Speaking report · Band ${bandText(band)}',
          shareText: _shareText(a, band, criteria, steps),
        ),
        if (a.data['test'] != true && sampleArgsFor(a.kind, a.refId) != null)
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
            child: ListRow(
              title: 'Compare with the sample answer',
              subtitle: 'See how a high-band answer handles the same question',
              leading: IconCircle(AppIcons.compare, size: 36, iconSize: 16),
              trailing: Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
              onTap: () => context.push(Routes.speakingSamples, args: sampleArgsFor(a.kind, a.refId)),
            ),
          ),
        HeroCard(
          radius: 30,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: heroMuted),
                        ),
                        Text(
                          bandText(band),
                          style: TextStyle(
                            fontSize: 76,
                            fontWeight: FontWeight.w300,
                            height: 0.95,
                            letterSpacing: -3,
                            color: t.heroText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: t.peach,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          delta,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnPeach),
                        ),
                      ),
                      Text(
                        durationLabel,
                        style: TextStyle(fontSize: 12, color: heroMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                summary,
                style: TextStyle(fontSize: 14, height: 1.45, color: heroBody),
              ),
            ],
          ),
        ),
        if (a.data.s('source') == 'demo')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Estimated offline (AI unavailable)',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            spacing: 14,
            children: [
              for (final c in criteria)
                Column(
                  spacing: 6,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.s('name'), style: const TextStyle(fontSize: 14)),
                        ),
                        Text(
                          bandText(c.d('band')),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    ProgressBar(
                      value: c.d('progress'),
                      height: 8,
                      track: t.isNight ? t.surfaceAlt2 : const Color(0xFFF6E8E4),
                      fill: c.b('weak') ? t.alert : t.fill,
                    ),
                    if (c.s('note').isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          c.s('note'),
                          style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              const Text(
                'Do this next',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              for (var i = 0; i < steps.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE2D8),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF151515)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (strengths.isNotEmpty)
          _ReportSection(
            title: 'What went well',
            children: [
              for (final s in strengths)
                _QuoteItem(
                  quote: s.s('quote'),
                  note: s.s('note'),
                  tag: s.s('type'),
                  good: true,
                ),
            ],
          ),
        if (mistakes.isNotEmpty)
          _ReportSection(
            title: 'Mistakes to fix',
            subtitle: 'Also highlighted in your transcript',
            children: [
              for (final e in mistakes)
                _QuoteItem(
                  quote: e.s('original'),
                  better: e.s('suggestion'),
                  note: e.s('note'),
                  tag: e.s('type'),
                ),
            ],
          ),
        if (fluencyObs.isNotEmpty || fluency.s('note').isNotEmpty)
          _ReportSection(
            title: 'Fluency',
            subtitle: fluency.s('note'),
            children: [
              for (final o in fluencyObs)
                _QuoteItem(
                  quote: o.s('quote'),
                  tag: o.s('pattern').replaceAll('-', ' '),
                  label: o.s('label').replaceAll('Segment', 'Answer'),
                ),
            ],
          ),
        if (sounds.isNotEmpty || pron.s('note').isNotEmpty)
          _ReportSection(
            title: 'Sounds to practise',
            subtitle: pron.s('note'),
            children: [
              for (final s in sounds) _SoundRow(sound: s),
            ],
          ),
        if (perPart.isNotEmpty)
          _ReportSection(
            title: 'Answer by answer',
            children: [
              for (final p in perPart)
                Text(p, style: const TextStyle(fontSize: 14, height: 1.4)),
            ],
          ),
      ],
    );
  }
}

/// A titled card of the full AI report.
class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.children, this.subtitle = ''});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              if (subtitle.trim().isNotEmpty)
                Text(
                  subtitle.trim(),
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
                ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

/// A quoted phrase from the answer with its tag, an optional better
/// version and the examiner's note.
class _QuoteItem extends StatelessWidget {
  const _QuoteItem({
    required this.quote,
    this.note = '',
    this.tag = '',
    this.better = '',
    this.label = '',
    this.good = false,
  });

  final String quote;
  final String note;
  final String tag;
  final String better;
  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final accent = good ? t.success : t.alert;
    final tagText = <String>[
      if (label.trim().isNotEmpty) label.trim(),
      if (tag.trim().isNotEmpty) tag.trim(),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: t.isNight ? t.surfaceAlt : t.surfaceAlt2,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          if (tagText.isNotEmpty)
            Text(
              tagText.toUpperCase(),
              style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, color: t.textMuted),
            ),
          Text(
            '“${quote.trim()}”',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontStyle: FontStyle.italic,
              decoration: better.trim().isNotEmpty ? TextDecoration.lineThrough : null,
              decorationColor: t.textMuted,
            ),
          ),
          if (better.trim().isNotEmpty)
            Text(
              '→ ${better.trim()}',
              style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500, color: t.text),
            ),
          if (note.trim().isNotEmpty)
            Text(note.trim(), style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted)),
        ],
      ),
    );
  }
}

/// One sound the speaker found hard: /ɛ/ ×7 + where it came up.
class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.sound});

  final Map<String, dynamic> sound;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final count = sound.i('count');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: t.isNight ? t.surfaceAlt : t.surfaceAlt2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '/${sound.s('phoneme')}/',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              if (count > 0)
                Text('Flagged $count×', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
              if (sound.s('note').isNotEmpty)
                Text(sound.s('note'), style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

String _shareText(
  Attempt a,
  double band,
  List<Map<String, dynamic>> criteria,
  List<String> steps,
) {
  final b = StringBuffer()
    ..writeln('IELTS Academic Speaking report')
    ..writeln('${a.title} · ${Store.weekdayDate(a.createdAt)} ${a.createdAt.year}')
    ..writeln()
    ..writeln('Overall band: ${bandText(band)}');
  for (final c in criteria) {
    b.writeln('${c.s('name')}: ${bandText(c.d('band'))}');
  }
  final tips = steps.where((x) => x.trim().isNotEmpty).take(3).toList();
  if (tips.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Top tips:');
    for (var i = 0; i < tips.length; i++) {
      b.writeln('${i + 1}. ${tips[i].trim()}');
    }
  }
  b
    ..writeln()
    ..write('Practised with IELTS AI by nextED');
  return b.toString();
}

class _Header extends StatelessWidget {
  const _Header({this.shareText, this.shareSubject});

  /// Plain-text report; null when there is nothing to share yet.
  final String? shareText;
  final String? shareSubject;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        IconBox(
          icon: AppIcons.back,
          iconSize: 18,
          bg: t.surface,
          tooltip: 'Back to speaking',
          onTap: () => backToHub(context),
        ),
        const Expanded(
          child: Text(
            'Speaking report',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        IconBox(
          icon: AppIcons.share,
          iconSize: 20,
          bg: t.surface,
          tooltip: 'Share',
          onTap: () {
            final text = shareText;
            if (text == null) {
              context.toast('Record an answer first - then share your report');
              return;
            }
            ShareService.shareText(context, text, subject: shareSubject);
          },
        ),
      ],
    );
  }
}
