import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/ai_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'editor_common.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C6 · AI Essay Rewriter & Band Comparison for `args['attemptId']` (or the
/// newest essay). "Improved" = the AI's rewrite two bands up (Band 9 from
/// Band 8 upwards, see [WritingService.rewriteTarget]), fetched once and
/// cached in the attempt's `data['rewrite']` = {target, text, changes}; without
/// the AI, the prompt's Band 8 model answer when the content has one, else
/// the essay with every AI fix applied.
class WritingRewriterScreen extends StatefulWidget {
  const WritingRewriterScreen({super.key});

  @override
  State<WritingRewriterScreen> createState() => _WritingRewriterScreenState();
}

class _WritingRewriterScreenState extends State<WritingRewriterScreen> {
  int _mode = 0;
  bool _inited = false;
  bool _loading = false;

  static String _signed(int n) => n > 0 ? '+$n' : '$n';

  /// The cached AI rewrite {text, changes} of [a], or null.
  static Map<String, dynamic>? _rewriteOf(Attempt a) {
    final m = a.data.m('rewrite');
    return m.s('text').trim().isEmpty ? null : m;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final a = Store.I.resolveAttempt(
      context.routeArgs,
      skill: Skill.writing,
      kindPrefix: 'task',
    );
    if (a == null || _rewriteOf(a) != null || !AiService.available) return;
    if (a.data.s('text').trim().isEmpty) return;
    _loading = true;
    _fetch(a);
  }

  Future<void> _fetch(Attempt a) async {
    Map<String, dynamic>? r;
    final target = WritingService.rewriteTarget(a);
    try {
      // Task 1: include the visual's data so the rewrite uses the real figures.
      final source = WritingContent.prompt(a.refId);
      final data = source == null || WritingService.taskOf(a) != 1 ? '' : WritingContent.visualText(source);
      r = await AiService.rewriteWriting(
        task: WritingService.taskOf(a),
        prompt: data.isEmpty ? a.data.s('prompt') : '${a.data.s('prompt')}\n\nData shown in the visual:\n$data',
        text: a.data.s('text'),
        targetBand: target,
      ).timeout(const Duration(seconds: 95));
    } catch (_) {
      r = null;
    }
    if (r != null && r.s('text').trim().isNotEmpty) {
      a.data['rewrite'] = <String, dynamic>{
        'target': target,
        'text': r.s('text').trim(),
        'changes': r.l('changes'),
      };
      Store.I.updateAttempt(a);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  /// Non-overlapping marks for each change's [key] phrase found in [text].
  static List<Map<String, dynamic>> _changeMarks(
    String text,
    List<Map<String, dynamic>> changes,
    String key,
    String mark,
  ) {
    final used = <(int, int)>[];
    final out = <Map<String, dynamic>>[];
    for (final c in changes) {
      final phrase = c.s(key).trim();
      if (phrase.isEmpty) continue;
      final hit = EssayAnalysis.locate(text, phrase, used);
      if (hit == null) continue;
      used.add(hit);
      out.add(<String, dynamic>{'start': hit.$1, 'end': hit.$2, 'mark': mark});
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final a = context.store.resolveAttempt(
      context.routeArgs,
      skill: Skill.writing,
      kindPrefix: 'task',
    );
    if (a == null) return const WritingNoEssay(title: 'Band comparison');
    final text = a.data.s('text');
    final issues = WritingService.issuesOf(a);
    final fixed = EssayAnalysis.applyFixes(text, issues);
    final model = WritingContent.modelAnswer(a.refId);

    final rw = _rewriteOf(a);
    final aiChanges = rw == null
        ? <Map<String, dynamic>>[]
        : rw.l('changes').where((c) => c.s('to').trim().isNotEmpty ||
            c.s('from').trim().isNotEmpty).toList();

    final issueMarks = <Map<String, dynamic>>[
      for (final i in issues)
        <String, dynamic>{
          'start': i.i('start'),
          'end': i.i('end'),
          'mark': 'cut',
        },
    ];
    final aiCuts = _changeMarks(text, aiChanges, 'from', 'cut');
    final yoursParas = EssayAnalysis.paragraphs(
      text,
      aiCuts.isNotEmpty ? aiCuts : issueMarks,
    );
    final String improvedText;
    final List<Map<String, dynamic>> improvedMarks;
    final String improvedLabel;
    if (rw != null) {
      improvedText = rw.s('text');
      improvedMarks = _changeMarks(improvedText, aiChanges, 'to', 'new');
      improvedLabel = WritingService.rewriteLabel(a);
    } else if (model.isNotEmpty) {
      improvedText = model;
      improvedMarks = EssayAnalysis.linkerMarks(model, 'new');
      improvedLabel = 'Band 8 model';
    } else {
      improvedText = fixed.$1;
      improvedMarks = fixed.$2;
      improvedLabel = 'Improved';
    }
    final improvedParas = EssayAnalysis.paragraphs(improvedText, improvedMarks);
    final changes = <Map<String, dynamic>>[
      <String, dynamic>{
        'value': _signed(EssayAnalysis.rareWordCount(improvedText) -
            EssayAnalysis.rareWordCount(text)),
        'label': 'less common words',
      },
      <String, dynamic>{
        'value': '${EssayAnalysis.linkerCount(text)}→${EssayAnalysis.linkerCount(improvedText)}',
        'label': 'linking devices',
      },
      <String, dynamic>{
        'value': '${EssayAnalysis.complexCount(text)}→${EssayAnalysis.complexCount(improvedText)}',
        'label': 'complex sentences',
      },
    ];

    final Widget improvedCol = _loading
        ? _LoadingColumn(label: WritingService.rewriteLabel(a))
        : _Column(
            label: improvedLabel,
            // The band the improved text was written for: the rewrite's
            // target, the content's Band 8 model, or none for plain fixes.
            band: rw != null
                ? Store.formatBand(WritingService.rewriteTarget(a))
                : (model.isNotEmpty ? '8.0' : ''),
            improved: true,
            paragraphs: improvedParas,
          );
    final yoursCol = _Column(
      label: 'Yours',
      band: Store.formatBand(a.band),
      improved: false,
      paragraphs: yoursParas,
    );
    final task = WritingService.taskOf(a);

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 14,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      footer: PrimaryButton(
        label: 'Rewrite my essay with these changes',
        height: 56,
        radius: 18,
        onTap: () => context.push(
          task == 1 ? Routes.writingTask1Editor : Routes.writingEditor,
          args: <String, dynamic>{
            'promptId': a.refId,
            'text': rw != null ? improvedText : fixed.$1,
          },
        ),
      ),
      children: [
        WHeader(
          title: 'Band comparison',
          trailing: IconBox(
            icon: AppIcons.doc,
            tooltip: 'Copy improved version',
            onTap: () {
              if (_loading) {
                context.toast('The ${WritingService.rewriteLabel(a)} is still being written');
                return;
              }
              Clipboard.setData(ClipboardData(text: improvedText));
              context.toast('Improved version copied');
            },
          ),
        ),
        WSegmented(
          labels: const ['Side by side', 'Improved only'],
          index: _mode,
          onChanged: (i) => setState(() => _mode = i),
        ),
        if (_mode == 0)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Expanded(child: yoursCol),
                Expanded(child: improvedCol),
              ],
            ),
          )
        else
          improvedCol,
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              const Text(
                'What changed',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              if (aiChanges.isNotEmpty && !_loading)
                ...<Widget>[
                  for (final c in aiChanges.take(8)) _ChangeRow(change: c),
                ]
              else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    for (final c in changes)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: wc(t, 0xFFEEEFFD, 0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.s('value'),
                                style: const TextStyle(fontSize: 20),
                              ),
                              Text(
                                c.s('label'),
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: wc(t, 0xFF4F4A6B, 0xFF9A9A9A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.label,
    required this.band,
    required this.improved,
    required this.paragraphs,
  });

  final String label;
  final String band;
  final bool improved;
  final List<List<Map<String, dynamic>>> paragraphs;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final Color bg = improved ? t.primary : t.surface;
    final Color labelColor = improved
        ? wc(t, 0xFFBDB6BB, 0xFF5A5446)
        : t.textMuted;
    final Color pillBg = improved
        ? wc(t, 0xFFDCDDFA, 0xFF151515)
        : t.surfaceAlt2;
    final Color pillFg = improved
        ? wc(t, 0xFF151515, 0xFFFFFFFF)
        : t.text;
    final Color body = improved
        ? wc(t, 0xFFE8E4E7, 0xFF151515)
        : (t.isNight ? t.text : const Color(0xFF3A3538));

    InlineSpan span(Map<String, dynamic> s) {
      final mark = s.s('mark');
      final text = s.s('text');
      if (mark == 'cut') {
        return TextSpan(
          text: text,
          style: const TextStyle(
            backgroundColor: Color(0xFFFCE0DA),
            color: Color(0xFF151515),
            decoration: TextDecoration.lineThrough,
            decorationColor: Color(0xFFB63A26),
          ),
        );
      }
      if (mark == 'new') {
        return TextSpan(
          text: text,
          style: TextStyle(
            backgroundColor: wc(t, 0xFF3B3C6B, 0xFF151515),
            color: t.isNight ? const Color(0xFFFFFFFF) : body,
          ),
        );
      }
      return TextSpan(text: text);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: labelColor),
                ),
              ),
              if (band.isNotEmpty)
                WPill(
                  band,
                  bg: pillBg,
                  fg: pillFg,
                  fontSize: 13,
                  weight: FontWeight.w500,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
            ],
          ),
          for (final p in paragraphs)
            Text.rich(
              TextSpan(children: [for (final s in p) span(s)]),
              style: TextStyle(fontSize: 13.5, height: 1.6, color: body),
            ),
        ],
      ),
    );
  }
}

/// Placeholder for the improved column while the AI writes the rewrite.
class _LoadingColumn extends StatelessWidget {
  const _LoadingColumn({this.label = 'improved version'});

  /// "Band 9 version" …
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 28),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: t.fill),
          ),
          Text(
            'Writing a $label…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

/// One AI change: "from → to" plus why.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final Map<String, dynamic> change;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final from = change.s('from').trim();
    final to = change.s('to').trim();
    final why = change.s('why').trim();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: wc(t, 0xFFEEEFFD, 0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (from.isNotEmpty)
                  TextSpan(
                    text: from,
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: t.textMuted,
                    ),
                  ),
                if (from.isNotEmpty && to.isNotEmpty) const TextSpan(text: '  →  '),
                if (to.isNotEmpty)
                  TextSpan(
                    text: to,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            style: TextStyle(fontSize: 13.5, height: 1.4, color: t.text),
          ),
          if (why.isNotEmpty)
            Text(
              why,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: wc(t, 0xFF4F4A6B, 0xFF9A9A9A),
              ),
            ),
        ],
      ),
    );
  }
}
