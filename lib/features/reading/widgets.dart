
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

export 'session.dart';

/// "42:18"
String clockLabel(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// "0:45"
String shortClock(int seconds) {
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$s';
}

/// Splits `**bold**` markup into spans.
List<TextSpan> boldSpans(String text, {Color? boldColor}) {
  final parts = text.split('**');
  return <TextSpan>[
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        TextSpan(
          text: parts[i],
          style: i.isOdd
              ? TextStyle(fontWeight: FontWeight.w600, color: boldColor)
              : null,
        ),
  ];
}

/// Sentence splitter used by the passage view (tap-to-highlight).
final RegExp sentencePattern = RegExp(r'[^.!?…]+(?:[.!?…]+["”’]?)?\s*');

/// Returns the sentence of [text] that contains [phrase] (trimmed), or ''.
String sentenceContaining(String text, String phrase) {
  for (final m in sentencePattern.allMatches(text)) {
    final s = m.group(0) ?? '';
    if (phrase.isNotEmpty && s.contains(phrase)) return s.trim();
  }
  return '';
}

// ─────────────────────────────────────────────────────────────────────────────
// Colours that have no token (pastel tiles, highlighter pens)
// ─────────────────────────────────────────────────────────────────────────────

const Color kInk = Color(0xFF151515);
const Color kPink = Color(0xFFFFE2D8);
const Color kLavender = Color(0xFFDCE6FF);
const Color kRose = Color(0xFFFFD2C4);
const Color kPastelMuted = Color(0xFF625C66);

/// Pastel tile colours (same in Day and Night, except the neutral tones).
Color toneBg(AppTokens t, String tone) {
  switch (tone) {
    case 'pink':
      return kPink;
    case 'lavender':
      return kLavender;
    case 'rose':
      return kRose;
    case 'mist':
      return t.isNight ? t.surfaceAlt2 : t.successSoft;
    default:
      return t.surfaceAlt2;
  }
}

bool isPastel(String tone) =>
    tone == 'pink' || tone == 'lavender' || tone == 'rose';

Color toneFg(AppTokens t, String tone) => isPastel(tone) ? kInk : t.text;

Color toneMuted(AppTokens t, String tone) =>
    isPastel(tone) ? kPastelMuted : t.textMuted;

/// Highlighter pen colour for a saved highlight.
Color highlightColor(AppTokens t, String color) {
  if (color == 'pink') return kPink;
  if (color == 'evidence') {
    return t.isNight ? const Color(0xFFFFC2B0) : kLavender;
  }
  return t.isNight ? const Color(0xFFFFC2B0) : const Color(0xFFFFC9B8);
}

IconData moduleIcon(String key) {
  switch (key) {
    case 'lesson':
      return AppIcons.school;
    case 'mini':
      return AppIcons.bolt;
    case 'passage':
      return AppIcons.article;
    case 'test':
      return AppIcons.doc;
    case 'tips':
      return AppIcons.bulb;
    case 'guide':
      return AppIcons.school;
    default:
      return AppIcons.reading;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Reading header: 44px back button, title/subtitle, optional trailing.
class ReadingHeader extends StatelessWidget {
  const ReadingHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.trailing,
    this.titleSize = 16,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final String? overline;
  final Widget? trailing;
  final double titleSize;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 8,
      children: [
        IconBox(
          icon: AppIcons.back,
          tooltip: 'Back',
          iconSize: 18,
          bg: t.surface,
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (overline != null)
                Text(
                  overline!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w500),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Countdown pill ("⏱ 42:18").
class TimerPill extends StatelessWidget {
  const TimerPill({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(AppIcons.timer, size: 16, color: t.text),
          Text(
            clockLabel(seconds),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-option toggle (Passage / Questions).
class ReadingTabs extends StatelessWidget {
  const ReadingTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.isNight ? t.surface : const Color(0xFFF2E6E2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == index
                    ? (t.isNight ? t.surfaceAlt2 : t.surface)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              i == index ? FontWeight.w500 : FontWeight.w400,
                          color: i == index ? t.text : t.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Passage 1 / 2 / 3 switcher for full tests (optional small sub-labels).
class PassageSwitcher extends StatelessWidget {
  const PassageSwitcher({
    super.key,
    required this.count,
    required this.index,
    required this.onChanged,
    this.sublabels = const <String>[],
  });

  final int count;
  final int index;
  final ValueChanged<int> onChanged;
  final List<String> sublabels;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 6,
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Material(
              color: i == index ? t.primary : t.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(i),
                child: SizedBox(
                  height: 40,
                  child: Center(
                    child: Text(
                      i < sublabels.length && sublabels[i].isNotEmpty
                          ? 'P${i + 1} · ${sublabels[i]}'
                          : 'Passage ${i + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == index ? FontWeight.w500 : FontWeight.w400,
                        color: i == index ? t.onPrimary : t.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A highlighted phrase inside a paragraph.
class HighlightSpec {
  const HighlightSpec(this.phrase, this.color);
  final String phrase;
  final Color color;
}

/// One lettered paragraph with highlighted phrases. When [onSentenceTap] is
/// set every sentence is tappable; [selected] underlines the chosen sentence.
class PassageParagraph extends StatefulWidget {
  const PassageParagraph({
    super.key,
    required this.text,
    this.letter,
    this.highlights = const <HighlightSpec>[],
    this.onSentenceTap,
    this.selected,
    this.fontSize = 15,
    this.lineHeight = 1.7,
    this.color,
    this.prefix = '',
  });

  final String text;
  final String? letter;

  /// Plain text shown before the paragraph (e.g. an ellipsis).
  final String prefix;
  final List<HighlightSpec> highlights;
  final ValueChanged<String>? onSentenceTap;
  final String? selected;
  final double fontSize;
  final double lineHeight;
  final Color? color;

  @override
  State<PassageParagraph> createState() => _PassageParagraphState();
}

class _PassageParagraphState extends State<PassageParagraph> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  List<InlineSpan> _segments(
    String sentence,
    TapGestureRecognizer? rec,
    bool isSelected,
    AppTokens t,
  ) {
    final ranges = <(int, int, Color)>[];
    for (final h in widget.highlights) {
      if (h.phrase.isEmpty) continue;
      final idx = sentence.indexOf(h.phrase);
      if (idx >= 0) ranges.add((idx, idx + h.phrase.length, h.color));
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final plain = TextStyle(
      decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
      decorationColor: t.textMuted,
      decorationThickness: 1.5,
    );
    final out = <InlineSpan>[];
    var pos = 0;
    for (final r in ranges) {
      if (r.$1 < pos) continue;
      if (r.$1 > pos) {
        out.add(TextSpan(
          text: sentence.substring(pos, r.$1),
          recognizer: rec,
          style: plain,
        ));
      }
      out.add(TextSpan(
        text: sentence.substring(r.$1, r.$2),
        recognizer: rec,
        style: plain.copyWith(backgroundColor: r.$3, color: kInk),
      ));
      pos = r.$2;
    }
    if (pos < sentence.length) {
      out.add(TextSpan(
        text: sentence.substring(pos),
        recognizer: rec,
        style: plain,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    _clearRecognizers();
    final base = TextStyle(
      fontSize: widget.fontSize,
      height: widget.lineHeight,
      color: widget.color ?? (t.isNight ? t.text : const Color(0xFF2F2B2E)),
    );
    final spans = <InlineSpan>[
      if (widget.prefix.isNotEmpty) TextSpan(text: widget.prefix),
    ];
    for (final m in sentencePattern.allMatches(widget.text)) {
      final sentence = m.group(0) ?? '';
      if (sentence.isEmpty) continue;
      final trimmed = sentence.trim();
      TapGestureRecognizer? rec;
      final cb = widget.onSentenceTap;
      if (cb != null) {
        rec = TapGestureRecognizer()..onTap = () => cb(trimmed);
        _recognizers.add(rec);
      }
      spans.addAll(_segments(sentence, rec, widget.selected == trimmed, t));
    }
    final body = Text.rich(TextSpan(style: base, children: spans));
    if (widget.letter == null) return body;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text(
          widget.letter!,
          style: base.copyWith(fontWeight: FontWeight.w600, color: t.text),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Section landing row (icon tile, title, count, subtitle, progress).
class ModuleRow extends StatelessWidget {
  const ModuleRow({super.key, required this.item, this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tone = item.s('tone');
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: toneBg(t, tone),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(moduleIcon(item.s('icon')), size: 20, color: toneFg(t, tone)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        item.s('title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      item.s('count'),
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
                Text(
                  item.s('subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                ProgressBar(value: item.d('progress')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
