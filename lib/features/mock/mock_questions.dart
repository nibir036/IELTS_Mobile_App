import 'package:flutter/material.dart';

import '../../app/services/media.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import 'mock_content.dart';
import 'widgets.dart';

/// Renders one bank question group inside a mock section (Listening G3 /
/// Reading G5): form & gap completion (typed), mcq, choose-TWO, matching
/// (shared box), headings, TRUE/FALSE/NOT GIVEN and YES/NO/NOT GIVEN.
///
/// Answers live in [answers] (question number → value); every change is
/// reported through [onChanged]. Give each group a `ValueKey(group.id)` so
/// its text controllers are rebuilt when the group changes.
class MockGroupView extends StatefulWidget {
  const MockGroupView({
    super.key,
    required this.group,
    required this.answers,
    required this.onChanged,
    this.current,
    this.onCurrent,
    this.flagged = const <int>{},
  });

  final MockGroup group;
  final Map<int, String> answers;
  final void Function(int number, String value) onChanged;

  /// Highlighted question number (quick-jump target).
  final int? current;
  final ValueChanged<int>? onCurrent;

  /// Flagged question numbers (badge turns pink with a flag).
  final Set<int> flagged;

  @override
  State<MockGroupView> createState() => _MockGroupViewState();
}

class _MockGroupViewState extends State<MockGroupView> {
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(int n) => _controllers.putIfAbsent(
        n,
        () => TextEditingController(text: widget.answers[n] ?? ''),
      );

  void _set(int n, String v) {
    widget.onChanged(n, v);
    widget.onCurrent?.call(n);
  }

  void _pick(MockQuestion q, String key) {
    final now = widget.answers[q.number] ?? '';
    _set(q.number, now == key ? '' : key);
  }

  void _toggleMulti(MockQuestion q, String key) {
    final sel = mockMultiKeys(widget.answers[q.number]);
    if (sel.contains(key)) {
      sel.remove(key);
    } else {
      sel.add(key);
      while (sel.length > q.span) {
        sel.removeAt(0);
      }
    }
    _set(q.number, sel.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final g = widget.group;
    final body = t.isNight ? t.text : t.textSoft;
    final boxed = g.shared.isNotEmpty && g.shared.any((o) => o.text.isNotEmpty);
    final title = g.type == 'form' && g.formTitle.isNotEmpty ? g.formTitle : g.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          g.instruction.isEmpty ? g.range : '${g.range} · ${g.instruction}',
          style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
        ),
        if (title.isNotEmpty)
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.35),
          ),
        if (g.type == 'form' && g.formSubtitle.isNotEmpty)
          Text(g.formSubtitle, style: TextStyle(fontSize: 13, color: t.textMuted)),
        if (g.image.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: InteractiveViewer(
              maxScale: 4,
              child: MediaImage(
                g.image,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (boxed)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: t.surfaceAlt2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 5,
              children: [
                for (final o in g.shared)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          o.key,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          o.text,
                          style: TextStyle(fontSize: 13, height: 1.35, color: body),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        for (final q in g.questions) _question(q, g),
      ],
    );
  }

  Widget _question(MockQuestion q, MockGroup g) {
    final t = context.tk;
    final body = t.isNight ? t.text : t.textSoft;
    final isCurrent = widget.current != null && q.numbers.contains(widget.current);
    final label = q.span > 1 ? '${q.number}–${q.lastNumber}' : '${q.number}';
    final isFlagged = q.numbers.any(widget.flagged.contains);

    Widget content;
    if (q.kind == 'text') {
      content = _textQuestion(q, g, body);
    } else if (q.kind == 'multi') {
      final sel = mockMultiKeys(widget.answers[q.number]);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(q.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
          for (final o in q.options)
            MockChoiceOption(
              letter: o.key,
              text: o.text,
              selected: sel.contains(o.key),
              onTap: () => _toggleMulti(q, o.key),
            ),
        ],
      );
    } else if (q.options.isNotEmpty) {
      final v = widget.answers[q.number] ?? '';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(q.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
          for (final o in q.options)
            MockChoiceOption(
              letter: o.key,
              text: o.text,
              selected: v == o.key,
              onTap: () => _pick(q, o.key),
            ),
        ],
      );
    } else {
      // Shared keys (matching letters, headings, TRUE/FALSE/NOT GIVEN).
      final v = widget.answers[q.number] ?? '';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(q.text, style: TextStyle(fontSize: 14, height: 1.4, color: body)),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in g.shared)
                _KeyChip(
                  label: o.key,
                  selected: v == o.key,
                  onTap: () => _pick(q, o.key),
                ),
            ],
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => widget.onCurrent?.call(q.number),
      child: Container(
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 28),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent ? t.alert : (isFlagged ? kMockFlagStrong : t.surfaceAlt2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 3,
                children: [
                  if (isFlagged)
                    Icon(
                      AppIcons.flag,
                      size: 11,
                      color: isCurrent ? t.onAlert : kMockInk,
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? t.onAlert : (isFlagged ? kMockInk : t.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _textQuestion(MockQuestion q, MockGroup g, Color body) {
    final field = MockBlankField(
      number: q.number,
      controller: _controller(q.number),
      current: widget.current == q.number,
      onFocus: () => widget.onCurrent?.call(q.number),
      onChanged: (v) => _set(q.number, v),
    );
    final style = TextStyle(fontSize: 14, height: 1.4, color: body);
    final pieces = <Widget>[];
    void words(String text) {
      for (final w in text.split(' ')) {
        if (w.isEmpty) continue;
        pieces.add(Text(w, style: style));
      }
    }

    if (q.label.isNotEmpty || q.text.isEmpty) {
      // Form completion: "Label:  before [____] after".
      if (q.label.isNotEmpty) {
        pieces.add(Text(
          '${q.label}:',
          style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500, color: context.tk.text),
        ));
      }
      words(q.before);
      pieces.add(field);
      words(q.after);
    } else {
      final parts = q.text.split(RegExp(r'_{3,}'));
      if (parts.length < 2) {
        words(q.text);
        pieces.add(field);
      } else {
        words(parts.first);
        pieces.add(field);
        words(parts.sublist(1).join(' '));
      }
    }
    return Wrap(
      spacing: 4,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: pieces,
    );
  }
}

/// Small selectable key (A, ii, TRUE …).
class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected ? BorderSide.none : BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? t.onPrimary : t.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline typed answer box ("12 [ ______ ]"), dashed until focused.
class MockBlankField extends StatelessWidget {
  const MockBlankField({
    super.key,
    required this.number,
    required this.controller,
    required this.current,
    required this.onFocus,
    required this.onChanged,
  });

  final int number;
  final TextEditingController controller;
  final bool current;
  final VoidCallback onFocus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final field = SizedBox(
      width: 130,
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          spacing: 4,
          children: [
            Text('$number', style: TextStyle(fontSize: 11, color: t.textMuted)),
            Expanded(
              child: TextField(
                controller: controller,
                onTap: onFocus,
                onChanged: onChanged,
                autocorrect: false,
                enableSuggestions: false,
                cursorColor: t.alert,
                cursorWidth: 1.5,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.text),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (current) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: t.text, width: 1.5),
        ),
        child: field,
      );
    }
    return DashedBorderBox(
      color: t.isNight ? t.border : const Color(0xFFE0CDC7),
      radius: 9,
      strokeWidth: 1,
      child: field,
    );
  }
}
