import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'session.dart';

export 'bank.dart';
export 'session.dart';
export 'sim_audio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours without a token (same hex in Day and Night)
// ─────────────────────────────────────────────────────────────────────────────

/// The always-dark play button / pills on hero cards.
const Color kInk = Color(0xFF151515);

/// Cream icon on the dark play button (both themes).
const Color kCream = Color(0xFFFFC2B0);

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// "04:12" (or "4:12" when [pad] is false).
String timeLabel(double seconds, {bool pad = true}) {
  final total = seconds < 0 ? 0 : seconds.floor();
  final m = total ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return pad ? '${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

String normalizeAnswer(String v) => v
    .trim()
    .toLowerCase()
    .replaceAll('£', '')
    .replaceAll(RegExp(r'\s+'), ' ');

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

IconData listeningModuleIcon(String key) {
  switch (key) {
    case 'lesson':
      return AppIcons.school;
    case 'mini':
      return AppIcons.bolt;
    case 'parts':
      return AppIcons.layers;
    case 'test':
      return AppIcons.listening;
    case 'tips':
      return AppIcons.bulb;
    case 'guide':
      return AppIcons.article;
    default:
      return AppIcons.hearing;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Listening header: 56px buttons (radius 20) with a centred title block.
class ListeningHeader extends StatelessWidget {
  const ListeningHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.titleSize = 15,
    this.leadingIcon = AppIcons.back,
    this.leadingTooltip = 'Back',
    this.onLeading,
    this.trailingIcon,
    this.trailingTooltip,
    this.onTrailing,
    this.trailingDot = false,
  });

  final String title;
  final String? subtitle;
  final String? overline;
  final double titleSize;
  final IconData leadingIcon;
  final String leadingTooltip;
  final VoidCallback? onLeading;
  final IconData? trailingIcon;
  final String? trailingTooltip;
  final VoidCallback? onTrailing;

  /// Alert dot on the trailing button (e.g. filters are active).
  final bool trailingDot;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 8,
      children: [
        IconBox(
          icon: leadingIcon,
          tooltip: leadingTooltip,
          size: 56,
          radius: 20,
          iconSize: leadingIcon == AppIcons.back ? 18 : 22,
          onTap: onLeading ?? () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
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
        if (trailingIcon != null)
          IconBox(
            icon: trailingIcon!,
            tooltip: trailingTooltip,
            size: 56,
            radius: 20,
            iconSize: 22,
            dot: trailingDot,
            onTap: onTrailing,
          )
        else
          const SizedBox(width: 56),
      ],
    );
  }
}

/// Outlined filter chip (selected = solid text colour).
class OutlineChip extends StatelessWidget {
  const OutlineChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.text : Colors.transparent,
      shape: StadiumBorder(
        side: selected ? BorderSide.none : BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? t.onPrimary : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of [OutlineChip]s with single selection.
class OutlineChipRow extends StatelessWidget {
  const OutlineChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            OutlineChip(
              label: labels[i],
              selected: i == selected,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

/// "1.0x" outlined pill on hero cards.
class SpeedPill extends StatelessWidget {
  const SpeedPill({super.key, required this.speed, this.onTap, this.fontSize = 12});

  final double speed;
  final VoidCallback? onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: t.heroText)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: Text(
            speedLabel(speed),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: t.heroText,
            ),
          ),
        ),
      ),
    );
  }
}

String speedLabel(double speed) => speed == 1.0 ? '1.0x' : '${speed}x';

/// Next speed in the 0.75 → 1.0 → 1.25 cycle.
double nextSpeed(double speed) {
  if (speed < 1.0) return 1.0;
  if (speed < 1.25) return 1.25;
  return 0.75;
}

/// Play / pause tile on hero cards (peach with a dark glyph in both themes).
class DarkPlayButton extends StatelessWidget {
  const DarkPlayButton({
    super.key,
    required this.playing,
    this.onTap,
    this.size = 48,
    this.radius = 17,
    this.iconSize = 24,
    this.loading = false,
  });

  final bool playing;
  final VoidCallback? onTap;

  /// Audio still loading: shows a small spinner and ignores taps.
  final bool loading;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: loading ? 'Loading audio' : (playing ? 'Pause' : 'Play'),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: kPeachGradient,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: InkWell(
            onTap: loading ? null : onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: loading
                  ? Center(
                      child: SizedBox(
                        width: iconSize * 0.75,
                        height: iconSize * 0.75,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kOnPeach,
                        ),
                      ),
                    )
                  : Icon(
                      playing ? AppIcons.pause : AppIcons.play,
                      size: iconSize,
                      color: kOnPeach,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum GapState { empty, filled, active, correct, wrong }

/// Numbered answer gap used in forms / notes ("[1 Fairfax]").
class GapBox extends StatelessWidget {
  const GapBox({
    super.key,
    required this.number,
    this.value = '',
    this.state = GapState.empty,
    this.onTap,
    this.filledColor,
    this.activeBorder,
    this.dashColor,
    this.editor,
    this.correction,
    this.height = 34,
    this.minWidth = 104,
  });

  final int number;
  final String value;
  final GapState state;
  final VoidCallback? onTap;
  final Color? filledColor;
  final Color? activeBorder;
  final Color? dashColor;

  /// Text field shown while [state] is [GapState.active].
  final Widget? editor;

  /// Correct answer shown after a wrong one.
  final String? correction;
  final double height;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color? bg;
    BoxBorder? border;
    var fg = t.text;
    var deco = TextDecoration.none;
    switch (state) {
      case GapState.empty:
        bg = null;
      case GapState.filled:
        bg = filledColor ?? t.surfaceAlt;
      case GapState.active:
        bg = t.isNight ? t.surfaceAlt2 : t.surface;
        border = Border.all(color: activeBorder ?? t.text, width: 1.5);
      case GapState.correct:
        bg = t.successSoft;
        border = Border.all(color: t.success);
      case GapState.wrong:
        bg = t.dangerSoft;
        border = Border.all(color: t.danger);
        fg = t.dangerText;
        deco = TextDecoration.lineThrough;
    }
    final wide = state == GapState.empty || state == GapState.active;
    Widget box = Container(
      height: height,
      constraints: BoxConstraints(minWidth: wide ? minWidth : 0),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text('$number', style: TextStyle(fontSize: 11, color: t.textMuted)),
          if (state == GapState.active && editor != null)
            editor!
          else if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
                decoration: deco,
                decorationColor: fg,
              ),
            ),
          if (state == GapState.wrong && correction != null)
            Text(
              '→ $correction',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.text),
            ),
        ],
      ),
    );
    if (state == GapState.empty) {
      box = CustomPaint(
        foregroundPainter: DashedRRectPainter(
          color: dashColor ?? (t.isNight ? t.border : const Color(0xFFE0CDC7)),
        ),
        child: box,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}

/// Single-line text editor that sits inside an active [GapBox].
class GapEditor extends StatelessWidget {
  const GapEditor({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.width = 110,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.next,
        cursorColor: t.alert,
        cursorWidth: 1.5,
        style: TextStyle(fontSize: 14, color: t.text),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// A form / notes line: optional label column, then text with an inline gap.
/// [prompt] (short-answer questions) is a full-width line above the gap.
class GapLine extends StatelessWidget {
  const GapLine({
    super.key,
    required this.gap,
    this.label,
    this.prompt,
    this.before = '',
    this.after = '',
  });

  final Widget gap;
  final String? label;
  final String? prompt;
  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final row = Row(
      spacing: 8,
      children: [
        if (label != null)
          SizedBox(
            width: 92,
            child: Text(
              label!,
              style: TextStyle(fontSize: 12, height: 1.3, color: t.textMuted),
            ),
          ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (before.trim().isNotEmpty)
                Text(before.trim(), style: const TextStyle(fontSize: 14)),
              gap,
              if (after.trim().isNotEmpty)
                Text(after.trim(), style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
    final p = prompt;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: p == null || p.isEmpty
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(p, style: const TextStyle(fontSize: 14, height: 1.35)),
                row,
              ],
            ),
    );
  }
}

/// (before, after) around the first "______" gap in [text].
(String, String) splitGap(String text) {
  final m = RegExp(r'_{2,}').firstMatch(text);
  if (m == null) return (text, '');
  return (text.substring(0, m.start), text.substring(m.end));
}

/// Letters currently chosen for a `multi` item.
Set<String> multiChosen(ListeningItem item, Map<int, String> answers) => <String>{
      for (final n in item.numbers)
        if ((answers[n] ?? '').trim().isNotEmpty) answers[n]!.trim().toUpperCase(),
    };

/// Toggles [letter] in a `multi` item (one letter per number, sorted).
void toggleMultiLetter(ListeningItem item, Map<int, String> answers, String letter) {
  final chosen = multiChosen(item, answers).toList();
  final l = letter.toUpperCase();
  if (chosen.contains(l)) {
    chosen.remove(l);
  } else {
    if (chosen.length >= item.span && chosen.isNotEmpty) chosen.removeLast();
    chosen.add(l);
  }
  chosen.sort();
  for (var k = 0; k < item.span; k++) {
    final n = item.number + k;
    if (k < chosen.length) {
      answers[n] = chosen[k];
    } else {
      answers.remove(n);
    }
  }
}

/// Short text describing an item (review sheets).
String itemPrompt(ListeningItem item) {
  final labelled = item.type == 'form' || item.type == 'table';
  final raw = labelled ? item.q.s('label') : item.q.s('text');
  final text = raw.replaceAll(RegExp(r'_{2,}'), '…').trim();
  return text.length > 34 ? '${text.substring(0, 33)}…' : text;
}

/// Lettered answer option (A / B / C …); selected = solid primary.
class ListeningOption extends StatelessWidget {
  const ListeningOption({
    super.key,
    required this.letter,
    required this.text,
    required this.selected,
    this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.primary : t.surfaceAlt2,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              spacing: 10,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? t.onPrimary : null,
                    borderRadius: BorderRadius.circular(9),
                    border: selected
                        ? null
                        : Border.all(
                            color: t.isNight ? const Color(0xFF3A3A3A) : t.border,
                          ),
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? t.primary : t.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: selected
                          ? t.onPrimary
                          : (t.isNight ? t.textSoft : t.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small selectable letter square (matching answers on the answer sheet).
class LetterChip extends StatelessWidget {
  const LetterChip({super.key, required this.letter, required this.selected, this.onTap});

  final String letter;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected ? BorderSide.none : BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? t.onPrimary : t.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rect outline (empty answer gaps).
class DashedRRectPainter extends CustomPainter {
  DashedRRectPainter({
    required this.color,
    this.radius = 11,
    this.dash = 4,
    this.gap = 3,
    this.strokeWidth = 1,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(strokeWidth / 2);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

/// Section landing row (icon tile, title, count, subtitle, progress).
class ListeningModuleRow extends StatelessWidget {
  const ListeningModuleRow({super.key, required this.item, this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
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
              color: t.surfaceAlt2,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(listeningModuleIcon(item.s('icon')), size: 20, color: t.text),
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
