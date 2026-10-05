import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/l10n.dart' show ContentDirection;
import '../../app/data/lessons.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../guides/study_guide_screen.dart' show GuideBlock;
import '../home/widgets.dart' show homeRouteFor;
import '../writing/writing_data.dart' show WritingContent;
import 'course_widgets.dart';

/// One lesson step, by its `type`.
class LessonStep extends StatelessWidget {
  const LessonStep({super.key, required this.module, required this.step, required this.picked, required this.onPick});

  final String module;
  final Map<String, dynamic> step;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return switch (step.s('type')) {
      'choice' => ChoiceStep(module: module, step: step, picked: picked, onPick: onPick),
      'roadmap' => _RoadmapStep(module: module, step: step),
      'concepts' => _ConceptsStep(module: module, step: step),
      'contrast' => _ContrastStep(module: module, step: step),
      'read' => _ReadStep(module: module, step: step),
      'practice' => _PracticeStep(module: module, step: step),
      'sampleFeedback' => _SampleFeedbackStep(module: module, step: step),
      _ => const SizedBox.shrink(),
    };
  }
}

TextStyle _title(Color c) => TextStyle(fontSize: 25, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: c);

/// `**bold**` in lesson text.
Widget _rich(String text, TextStyle style) {
  final spans = <TextSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    spans.add(TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null));
  }
  return Text.rich(TextSpan(style: style, children: spans));
}

// ── choice (hook / quick check / interactive check) ──────────────────────

class ChoiceStep extends StatelessWidget {
  const ChoiceStep({super.key, required this.module, required this.step, required this.picked, required this.onPick});

  final String module;
  final Map<String, dynamic> step;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final options = step['options'] is List ? step['options'] as List : const <Object>[];
    final answer = step.i('answer');
    final done = picked != null;
    final right = done && picked == answer;
    final passage = step.s('passage');
    final bars = step.l('bars');
    return ContentDirection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(lessonText(step['title'], module: module), style: _title(t.text)),
          if (lessonText(step['prompt'], module: module).isNotEmpty)
            Text(lessonText(step['prompt'], module: module), style: TextStyle(fontSize: 14.5, height: 1.45, color: t.textMuted)),
          if (passage.isNotEmpty)
            Directionality(
              textDirection: TextDirection.ltr,
              child: AppCard(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(passage, style: TextStyle(fontSize: 14.5, height: 1.55, color: t.textSoft)),
              ),
            ),
          for (var i = 0; i < options.length; i++)
            _OptionRow(
              letter: String.fromCharCode(65 + i),
              text: lessonText(options[i], module: module),
              sub: options[i] is Map ? lessonText((options[i] as Map)['sub'], module: module) : '',
              state: !done
                  ? _Opt.idle
                  : i == answer
                      ? _Opt.right
                      : i == picked
                          ? _Opt.wrong
                          : _Opt.dim,
              onTap: done ? null : () => onPick(i),
            ),
          if (done)
            FadeIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  if (bars.isNotEmpty)
                    AppCard(
                      radius: 20,
                      child: Column(
                        spacing: 10,
                        children: [
                          for (final b in bars)
                            Row(
                              spacing: 12,
                              children: [
                                SizedBox(width: 56, child: Text(b.s('label'), style: const TextStyle(fontSize: 13))),
                                Expanded(child: PeachBar(value: b.d('value'), height: 10)),
                                SizedBox(
                                  width: 40,
                                  child: Text(b.s('text'),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  _Feedback(
                    right: right,
                    title: right
                        ? (lessonText(step['right'], module: module).isNotEmpty
                            ? lessonText(step['right'], module: module)
                            : 'Correct!')
                        : 'Not quite - the answer is ${String.fromCharCode(65 + answer)}.',
                    body: lessonText(step['explain'], module: module),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _Opt { idle, right, wrong, dim }

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.letter, required this.text, required this.sub, required this.state, this.onTap});

  final String letter;
  final String text;
  final String sub;
  final _Opt state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final (Color bg, Color border, Color badge, Color badgeFg) = switch (state) {
      _Opt.right => (t.accentSoft, t.peach, t.peach, const Color(0xFF151515)),
      _Opt.wrong => (t.dangerSoft, t.danger, t.danger, Colors.white),
      _Opt.dim => (t.glassFill, t.glassBorder, t.surfaceAlt, t.textMuted),
      _Opt.idle => (t.glassFill, t.glassBorder, t.surfaceAlt, t.text),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: state == _Opt.dim ? 0.6 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: state == _Opt.idle || state == _Opt.dim ? 1 : 1.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
                  child: Text(letter, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: badgeFg)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(text, style: TextStyle(fontSize: 14.5, height: 1.4, color: t.text)),
                      if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 12.5, color: t.textMuted)),
                    ],
                  ),
                ),
                if (state == _Opt.right) Icon(AppIcons.checkCircle, color: t.peach, size: 24),
                if (state == _Opt.wrong) Icon(AppIcons.cancel, color: t.danger, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.right, required this.title, required this.body});

  final bool right;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: right ? t.successSoft : t.dangerSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: right ? t.blue : t.danger, shape: BoxShape.circle),
            child: Icon(right ? AppIcons.check : AppIcons.close, size: 18, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: right ? t.success : t.dangerText)),
                if (body.isNotEmpty) Text(body, style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── roadmap ───────────────────────────────────────────────────────────────

class _RoadmapStep extends StatelessWidget {
  const _RoadmapStep({required this.module, required this.step});

  final String module;
  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final items = step['items'] is List ? step['items'] as List : const <Object>[];
    final note = lessonText(step['note'], module: module);
    return ContentDirection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(lessonText(step['title'], module: module), style: _title(t.text)),
          Text("By the end of this lesson, you'll be able to:", style: TextStyle(fontSize: 14, color: t.textMuted)),
          for (var i = 0; i < items.length; i++)
            FadeIn(
              delay: Duration(milliseconds: 70 * i),
              child: AppCard(
                radius: 18,
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: tintBadge(t, alt: i.isOdd).$1, borderRadius: BorderRadius.circular(10)),
                      child: Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tintBadge(t, alt: i.isOdd).$2)),
                    ),
                    Expanded(child: Text(lessonText(items[i], module: module), style: const TextStyle(fontSize: 14.5, height: 1.35))),
                  ],
                ),
              ),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            NexiSays(pose: NexiPose.thumbs, height: 96, text: note, bubble: t.isNight ? t.surfaceAlt : Colors.white, textColor: t.text),
          ],
        ],
      ),
    );
  }
}

// ── concept cards (dark) ─────────────────────────────────────────────────

class _ConceptsStep extends StatefulWidget {
  const _ConceptsStep({required this.module, required this.step});

  final String module;
  final Map<String, dynamic> step;

  @override
  State<_ConceptsStep> createState() => _ConceptsStepState();
}

class _ConceptsStepState extends State<_ConceptsStep> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final cards = widget.step.l('cards');
    final m = widget.module;
    if (cards.isEmpty) return const SizedBox.shrink();
    final sel = cards[_sel.clamp(0, cards.length - 1)];
    return ContentDirection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text(lessonText(widget.step['title'], module: m), style: _title(t.onHeroDark)),
          if (lessonText(widget.step['intro'], module: m).isNotEmpty)
            Text(lessonText(widget.step['intro'], module: m), style: TextStyle(fontSize: 14, height: 1.45, color: t.onHeroDarkMuted)),
          const SizedBox(height: 2),
          for (var i = 0; i < cards.length; i++)
            DarkGlass(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              radius: 18,
              color: i == _sel ? const Color(0x33FFB8A3) : null,
              onTap: () => setState(() => _sel = i),
              child: Row(
                spacing: 12,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == _sel ? t.peach : const Color(0x1FFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == _sel ? const Color(0xFF151515) : t.onHeroDark)),
                  ),
                  Icon(lessonIcon(cards[i].s('icon')), size: 20, color: i == _sel ? t.peach : t.onHeroDarkMuted),
                  Expanded(
                    child: Text(lessonText(cards[i]['title'], module: m),
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: t.onHeroDark)),
                  ),
                  Icon(AppIcons.chevronRight, size: 18, color: t.onHeroDarkMuted),
                ],
              ),
            ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Container(
              key: ValueKey<int>(_sel),
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Text(lessonText(sel['title'], module: m),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF151515))),
                  _rich(lessonText(sel['body'], module: m), const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF3A353D))),
                  Row(
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 5),
                          width: i == _sel ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _sel ? const Color(0xFFFF7E67) : const Color(0x33151515),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      const Spacer(),
                      Material(
                        color: const Color(0xFFFF8F7A),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _sel = (_sel + 1) % cards.length),
                          child: const SizedBox(width: 40, height: 40, child: Icon(AppIcons.forward, size: 20, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── weak vs strong example ───────────────────────────────────────────────

class _ContrastStep extends StatelessWidget {
  const _ContrastStep({required this.module, required this.step});

  final String module;
  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final weak = step.m('weak');
    final strong = step.m('strong');
    final tip = lessonText(step['tip'], module: module);
    Widget example(Map<String, dynamic> e, bool good) {
      final text = e.s('text');
      final mark = e.s('mark');
      final style = TextStyle(fontSize: 14.5, height: 1.55, color: t.textSoft);
      Widget body;
      final at = mark.isEmpty ? -1 : text.indexOf(mark);
      if (at < 0) {
        body = Text(text, style: style);
      } else {
        body = Text.rich(TextSpan(style: style, children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: mark,
            style: TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: t.peach, decorationThickness: 2),
          ),
          TextSpan(text: text.substring(at + mark.length)),
        ]));
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
        decoration: BoxDecoration(
          color: good ? t.successSoft : t.dangerSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(lessonText(e['label'], module: module),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: good ? t.success : t.dangerText)),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: good ? t.blue : t.danger, shape: BoxShape.circle),
                  child: Icon(good ? AppIcons.check : AppIcons.close, size: 16, color: Colors.white),
                ),
              ],
            ),
            Directionality(textDirection: TextDirection.ltr, child: body),
          ],
        ),
      );
    }

    return ContentDirection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(lessonText(step['title'], module: module), style: _title(t.text)),
          if (lessonText(step['intro'], module: module).isNotEmpty)
            Text(lessonText(step['intro'], module: module), style: TextStyle(fontSize: 14.5, height: 1.45, color: t.textMuted)),
          FadeIn(child: example(weak, false)),
          FadeIn(delay: const Duration(milliseconds: 150), child: example(strong, true)),
          if (tip.isNotEmpty)
            FadeIn(
              delay: const Duration(milliseconds: 300),
              child: AppCard(
                radius: 20,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Icon(AppIcons.bulb, color: const Color(0xFFFFB020), size: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          const Text('Tip', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(tip, style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── reading card (a slice of the study guide) ────────────────────────────

class _ReadStep extends StatelessWidget {
  const _ReadStep({required this.module, required this.step});

  final String module;
  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final blocks = lessonBlocks(module, step.s('chapter'), step.i('from'), step.i('to'));
    final title = lessonText(step['title'], module: module);
    // Don't repeat the card title when the slice starts with that heading.
    final skipFirst = blocks.isNotEmpty &&
        (blocks.first.first == 'h' || blocks.first.first == 'h2') &&
        title.isNotEmpty;
    return ContentDirection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (title.isNotEmpty) Text(title, style: _title(t.text)),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                for (var i = skipFirst ? 1 : 0; i < blocks.length; i++) GuideBlock(block: blocks[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── practice (opens the real question) ───────────────────────────────────

class _PracticeStep extends StatelessWidget {
  const _PracticeStep({required this.module, required this.step});

  final String module;
  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final prompt = WritingContent.prompt(step.s('promptId'));
    final items = step.l('items');
    final plan = step['plan'] is List ? step['plan'] as List : const <Object>[];
    final tip = lessonText(step['tip'], module: module);
    final task = lessonText(step['task'], module: module);
    void open(Map<String, dynamic> item) {
      final target = item.s('target');
      if (target.isNotEmpty) {
        final route = homeRouteFor(target);
        if (route.isEmpty) return;
        final args = item.m('args');
        context.push(route, args: args.isEmpty ? null : args);
        return;
      }
      switch (item.s('action')) {
        case 'plan':
          showAppSheet<void>(
            context,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                const Text('Plan your answer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                for (var i = 0; i < plan.length; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Expanded(child: Text(lessonText(plan[i], module: module), style: const TextStyle(height: 1.45))),
                    ],
                  ),
                const SizedBox(height: 6),
              ],
            ),
          );
        case 'write':
          if (prompt != null) {
            context.push(
              prompt.i('task') == 1 ? Routes.writingTask1Editor : Routes.writingEditor,
              args: <String, dynamic>{'promptId': prompt.s('id')},
            );
          }
        case 'check':
          context.toast('Write your essay, then tap Submit - the AI report opens right after.');
      }
    }

    return ContentDirection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(lessonText(step['title'], module: module), style: _title(t.text)),
          if (task.isNotEmpty)
            AppCard(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Text(task, style: TextStyle(fontSize: 14.5, height: 1.5, color: t.textSoft)),
            ),
          if (prompt != null)
            Directionality(
              textDirection: TextDirection.ltr,
              child: AppCard(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(prompt.s('prompt'), style: TextStyle(fontSize: 14.5, height: 1.55, color: t.textSoft)),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            AppCard(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              color: i == 0 ? t.accentSoft : null,
              onTap: () => open(items[i]),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == 0 ? t.peach : tintBadge(t).$1, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: i == 0 ? const Color(0xFF151515) : tintBadge(t).$2)),
                  ),
                  Expanded(
                    child: Text(
                      '${lessonText(items[i], module: module)}${items[i].i('minutes') > 0 ? ' (${items[i].i('minutes')} min)' : ''}',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
                ],
              ),
            ),
          Text(prompt != null
                  ? 'Optional - you can come back to this question any time from Writing.'
                  : 'Optional - you can do this now or later.',
              style: TextStyle(fontSize: 12.5, color: t.textMuted)),
          if (tip.isNotEmpty)
            NexiSays(pose: NexiPose.wave, height: 100, text: tip, bubble: t.isNight ? t.surfaceAlt : Colors.white, textColor: t.text),
        ],
      ),
    );
  }
}

// ── example AI report (dark) ─────────────────────────────────────────────

class _SampleFeedbackStep extends StatelessWidget {
  const _SampleFeedbackStep({required this.module, required this.step});

  final String module;
  final Map<String, dynamic> step;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final band = step.d('band');
    final criteria = step.l('criteria');
    final good = step['good'] is List ? step['good'] as List : const <Object>[];
    final improve = step['improve'] is List ? step['improve'] as List : const <Object>[];
    Widget point(String text, bool ok) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(color: ok ? t.blue : t.peach, borderRadius: BorderRadius.circular(6)),
              child: Icon(ok ? AppIcons.check : AppIcons.forward, size: 14, color: ok ? Colors.white : const Color(0xFF151515)),
            ),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, height: 1.4, color: t.onHeroDark))),
          ],
        );
    return ContentDirection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            children: [
              Expanded(child: Text(lessonText(step['title'], module: module), style: _title(t.onHeroDark))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(999)),
                child: Text('Example', style: TextStyle(fontSize: 12, color: t.onHeroDarkMuted)),
              ),
            ],
          ),
          if (lessonText(step['intro'], module: module).isNotEmpty)
            Text(lessonText(step['intro'], module: module), style: TextStyle(fontSize: 14, height: 1.45, color: t.onHeroDarkMuted)),
          DarkGlass(
            child: Row(
              spacing: 16,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CustomPaint(
                    painter: _RingPainter(band / 9),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Store.formatBand(band), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: t.onHeroDark)),
                          Text('Band', style: TextStyle(fontSize: 11, color: t.onHeroDarkMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    spacing: 8,
                    children: [
                      for (final c in criteria)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 4,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(c.s('name'), style: TextStyle(fontSize: 12, color: t.onHeroDark))),
                                Text(Store.formatBand(c.d('band')),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.onHeroDark)),
                              ],
                            ),
                            PeachBar(value: c.d('band') / 9, height: 5, track: const Color(0x26FFFFFF)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (good.isNotEmpty)
            DarkGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text('What you did well', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.onHeroDark)),
                  for (final g in good) point(lessonText(g, module: module), true),
                ],
              ),
            ),
          if (improve.isNotEmpty)
            DarkGlass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text('Main areas to improve', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.onHeroDark)),
                  for (final g in improve) point(lessonText(g, module: module), false),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.09;
    final r = rect.deflate(stroke / 2);
    final track = Paint()
      ..color = const Color(0x26FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()
      ..shader = const SweepGradient(colors: [Color(0xFFFFB8A3), Color(0xFFFF7E67), Color(0xFFFFB8A3)]).createShader(r)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
