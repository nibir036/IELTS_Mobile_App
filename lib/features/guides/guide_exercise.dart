import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../reading/widgets.dart' show boldSpans, kInk, kLavender;

/// An exercise inside a guide chapter:
/// `["exercise", {title, kind, instructions, items: [{prompt, answer, accepted, reason}]}]`.
///
/// Short answers (gap_fill, correction) get a text field with Check and Show
/// answer; long ones (essay_edit) show the text to edit and reveal the model
/// answer. Prompts and answers are English (left-to-right) in every language;
/// the title, instructions and reasons follow the guide's language.
class GuideExercise extends StatefulWidget {
  const GuideExercise({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<GuideExercise> createState() => _GuideExerciseState();
}

enum _Result { none, correct, different }

class _GuideExerciseState extends State<GuideExercise> {
  final Map<int, TextEditingController> _inputs = <int, TextEditingController>{};
  final Map<int, _Result> _results = <int, _Result>{};
  final Set<int> _shown = <int>{};

  @override
  void dispose() {
    for (final c in _inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _items => <Map<String, dynamic>>[
        for (final x in (widget.data['items'] as List? ?? const <Object>[]))
          if (x is Map) x.cast<String, dynamic>(),
      ];

  bool get _long => widget.data['kind'] == 'essay_edit';

  static String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[‘’`]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll(RegExp(r'''[.,!?;:"/()]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _check(int i, Map<String, dynamic> item) {
    final given = norm(_inputs[i]?.text ?? '');
    if (given.isEmpty) return;
    final ok = <String>[
      '${item['answer']}',
      for (final a in (item['accepted'] as List? ?? const <Object>[])) '$a',
    ].map(norm).contains(given);
    setState(() {
      _results[i] = ok ? _Result.correct : _Result.different;
      _shown.add(i);
    });
  }

  int get _score => _results.values.where((r) => r == _Result.correct).length;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final items = _items;
    final body = TextStyle(fontSize: 13.5, height: 1.5, color: t.textSoft);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: t.isNight ? t.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.isNight ? t.divider : kLavender, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kLavender, borderRadius: BorderRadius.circular(9)),
                child: const Icon(AppIcons.pen, size: 16, color: kInk),
              ),
              Expanded(
                child: Text(
                  '${widget.data['title'] ?? ''}',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
              if (!_long && _results.isNotEmpty)
                Text('$_score/${items.length}', style: TextStyle(fontSize: 12, color: t.textMuted)),
            ],
          ),
          Text.rich(TextSpan(children: boldSpans('${widget.data['instructions'] ?? ''}')), style: body),
          for (var i = 0; i < items.length; i++) _item(context, i, items[i]),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, int i, Map<String, dynamic> item) {
    final t = context.tk;
    final shown = _shown.contains(i);
    final result = _results[i] ?? _Result.none;
    final ltr = TextStyle(fontSize: 14, height: 1.5, color: t.text);
    final reason = '${item['reason'] ?? ''}';
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${i + 1}.', style: ltr.copyWith(fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: _long
                      ? Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: t.isNight ? t.surfaceAlt2 : const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${item['prompt']}', style: ltr.copyWith(fontSize: 13.5)),
                        )
                      : Text('${item['prompt']}', style: ltr),
                ),
              ],
            ),
          ),
          if (!_long)
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _inputs.putIfAbsent(i, TextEditingController.new),
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _check(i, item),
                style: TextStyle(fontSize: 14, color: t.text),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Your answer',
                  hintStyle: TextStyle(color: t.textFaint),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.divider),
                  ),
                ),
              ),
            ),
          Row(
            spacing: 8,
            children: [
              if (!_long)
                SoftButton(
                  label: 'Check',
                  height: 34,
                  radius: 12,
                  fontSize: 13,
                  bg: t.isNight ? t.surfaceAlt2 : kLavender,
                  fg: t.isNight ? t.text : kInk,
                  onTap: () => _check(i, item),
                ),
              SoftButton(
                label: shown ? 'Hide answer' : (_long ? 'Show model answer' : 'Show answer'),
                height: 34,
                radius: 12,
                fontSize: 13,
                bg: t.isNight ? t.surface : t.raised,
                onTap: () => setState(() => shown ? _shown.remove(i) : _shown.add(i)),
              ),
              const Spacer(),
              if (result == _Result.correct)
                Row(spacing: 4, children: [
                  Icon(AppIcons.check, size: 16, color: t.success),
                  Text('Correct', style: TextStyle(fontSize: 12.5, color: t.success, fontWeight: FontWeight.w600)),
                ]),
              if (result == _Result.different)
                Text('Compare with the answer', style: TextStyle(fontSize: 12, color: t.warning)),
            ],
          ),
          if (shown)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.isNight ? t.surfaceAlt2 : const Color(0xFFEAF6EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text('${item['answer']}', style: ltr.copyWith(fontWeight: FontWeight.w500)),
                  ),
                  if (reason.isNotEmpty)
                    Text.rich(
                      TextSpan(children: boldSpans(reason)),
                      style: TextStyle(fontSize: 13, height: 1.5, color: t.textSoft),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
