import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/services/media.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'task1_chart.dart';

/// Day / Night pick for the rare canvas hues that have no token.
Color wc(AppTokens t, int day, int night) => Color(t.isNight ? night : day);

/// Diagonal two-stop gradient used by the pastel Day cards.
LinearGradient wGradient(int a, int b) => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(a), Color(b)],
    );

/// Solid "gradient" (for HeroCard with a flat Day colour).
LinearGradient wSolid(int c) => LinearGradient(colors: [Color(c), Color(c)]);

/// 125 → "02:05".
String mmss(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

/// Live word count for the editors.
int countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

/// Header row used by most writing screens: back button, centred title,
/// optional trailing widget (keeps the title centred with a spacer).
class WHeader extends StatelessWidget {
  const WHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
    this.backIcon = AppIcons.back,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;
  final IconData backIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBox(
          icon: backIcon,
          iconSize: 18,
          tooltip: 'Back',
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        trailing ?? const SizedBox(width: 44, height: 44),
      ],
    );
  }
}

/// Two/three-option segmented control with a rounded-rect track
/// (Band comparison, Sample answer).
class WSegmented extends StatelessWidget {
  const WSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.height = 44,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: wc(t, 0xFFEDE3E9, 0xFF151515),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: i == index
                    ? wc(t, 0xFFFFFFFF, 0xFF1F1F1F)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: SizedBox(
                    height: height,
                    child: Center(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
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

/// Box with a dashed rounded border (drop zones, empty template slots).
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.color,
    this.child,
    this.radius = 14,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 4,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.fill,
  });

  final Color color;
  final Widget? child;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final EdgeInsets padding;
  final double? width;
  final double? height;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
        fill: fill,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
    this.fill,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - strokeWidth),
      math.max(0, size.height - strokeWidth),
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill!);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()..addRRect(rrect);
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
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.fill != fill;
}

/// Small rounded pill label with a fixed colour pair.
class WPill extends StatelessWidget {
  const WPill(
    this.text, {
    super.key,
    required this.bg,
    required this.fg,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.radius = 999,
    this.weight = FontWeight.w400,
  });

  final String text;
  final Color bg;
  final Color fg;
  final double fontSize;
  final EdgeInsets padding;
  final double radius;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, color: fg, fontWeight: weight),
      ),
    );
  }
}

/// Flat rounded button with custom colours (56px secondary buttons that
/// sit on the page: "Save draft", "Line by line", "Skip" …).
class WFlatButton extends StatelessWidget {
  const WFlatButton({
    super.key,
    required this.label,
    this.onTap,
    required this.bg,
    required this.fg,
    this.height = 56,
    this.radius = 18,
    this.fontSize = 15,
    this.weight = FontWeight.w400,
    this.borderColor,
    this.leading,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final double height;
  final double radius;
  final double fontSize;
  final FontWeight weight;
  final Color? borderColor;
  final IconData? leading;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 6,
              children: [
                if (leading != null) Icon(leading, size: 16, color: fg),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: weight,
                      color: fg,
                    ),
                  ),
                ),
                if (trailing != null) Icon(trailing, size: 18, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Task 1 visual: the question bank's rendered image (tap to zoom) or, for
/// prompts without one, the native [Task1Chart]. [height] is the chart plot
/// height / the image's maximum height.
class WritingVisual extends StatelessWidget {
  const WritingVisual({super.key, required this.prompt, this.height = 120});

  final Map<String, dynamic> prompt;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final image = prompt.s('image');
    final chart = prompt.m('chart');
    if (image.isEmpty) {
      if (chart.isEmpty) return const SizedBox.shrink();
      return Task1Chart(chart: chart, type: prompt.s('type'), height: height);
    }
    return Semantics(
      image: true,
      label: '${prompt.s('typeName')}: ${prompt.s('title')}. Tap to enlarge.',
      child: GestureDetector(
        onTap: () => _zoom(context, image),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.white,
                constraints: BoxConstraints(maxHeight: height * 2.4),
                width: double.infinity,
                child: MediaImage(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => chart.isEmpty
                      ? const SizedBox.shrink()
                      : Task1Chart(chart: chart, type: prompt.s('type'), height: height),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(AppIcons.search, size: 14, color: t.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _zoom(BuildContext context, String image) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: MediaImage(image, fit: BoxFit.contain),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(AppIcons.close, color: Color(0xFF151515)),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
