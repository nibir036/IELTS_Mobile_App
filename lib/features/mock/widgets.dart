import 'dart:ui' show FontFeature, PathMetric;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────────────────────

/// "21:14" — two-digit minutes (exam timers).
String mockClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

/// "1:12" — short minutes (countdowns, speaking).
String mockShortClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// True when this screen's route is on top (no dialog / sheet / pushed page
/// above it). Timed auto-advances wait until it is.
bool mockIsTop(BuildContext context) => ModalRoute.of(context)?.isCurrent ?? true;

/// Band score with one decimal ("6.5").
String mockBand(double v) => v.toStringAsFixed(1);

/// Word count for essays.
int mockWordCount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
}

/// JSON list of numbers → set of ints.
Set<int> mockIntSet(Map<String, dynamic> row, String key) {
  final v = row[key];
  final out = <int>{};
  if (v is List) {
    for (final e in v) {
      if (e is num) out.add(e.toInt());
    }
  }
  return out;
}

/// Icon for a system-check / skill key.
IconData mockIcon(String key) {
  switch (key) {
    case 'headphones':
    case 'listening':
      return AppIcons.listening;
    case 'microphone':
    case 'speaking':
      return AppIcons.mic;
    case 'connection':
      return AppIcons.sync;
    case 'timer':
      return AppIcons.timer;
    case 'reading':
      return AppIcons.reading;
    case 'writing':
      return AppIcons.writing;
    default:
      return AppIcons.info;
  }
}

/// The dark pill badge used on hero cards in both themes ("In 27 days").
const Color kMockInk = Color(0xFF151515);
const Color kMockCream = Color(0xFFF6ECC8);

/// Pink used for flags in both themes.
const Color kMockFlagPink = Color(0xFFF9D6E2);
const Color kMockFlagStrong = Color(0xFFF4B8CB);

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class MockInkBadge extends StatelessWidget {
  const MockInkBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kMockInk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: kMockCream,
        ),
      ),
    );
  }
}

/// Outlined 36px pill ("Mock Test 07", "Sat 3 Oct · 9:00 AM").
class MockOutlinePill extends StatelessWidget {
  const MockOutlinePill(this.text, {super.key, this.leading, this.onTap});

  final String text;
  final IconData? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (leading != null) Icon(leading, size: 16, color: t.textMuted),
              Text(text, style: TextStyle(fontSize: 13, color: t.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header used inside the timed sections: Exit · title/subtitle · timer pill.
class MockExamHeader extends StatelessWidget {
  const MockExamHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.seconds,
    required this.onExit,
    this.low = false,
  });

  final String title;
  final String subtitle;
  final int seconds;
  final VoidCallback onExit;

  /// Timer running low → alert-coloured pill.
  final bool low;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final pillBg = low ? t.alert : t.primary;
    final pillFg = low ? t.onAlert : t.onPrimary;
    return Row(
      spacing: 8,
      children: [
        Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onExit,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Icon(AppIcons.close, size: 18, color: t.text),
                    Text('Exit', style: TextStyle(fontSize: 14, color: t.text)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          ),
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(AppIcons.timer, size: 16, color: pillFg),
              Text(
                mockClock(seconds),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: pillFg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Listening · Reading · Writing · Speaking strip. Sections before
/// [current] are filled, [current] is raised, later ones are muted.
class MockSectionTabs extends StatelessWidget {
  const MockSectionTabs({super.key, required this.current});

  final int current;

  static const labels = <String>['Listening', 'Reading', 'Writing', 'Speaking'];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: mockTrackTint(t),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Container(
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i < current
                      ? t.primary
                      : (i == current ? mockRaisedTint(t) : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == current ? FontWeight.w600 : FontWeight.w400,
                    color: i < current
                        ? t.onPrimary
                        : (i == current ? t.text : mockTabMuted(t)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Segmented-track tint. Day #EDE3E9 · Night #151515.
Color mockTrackTint(AppTokens t) =>
    t.isNight ? t.surface : const Color(0xFFEDE3E9);

/// Selected segment. Day #FFFFFF · Night #1F1F1F.
Color mockRaisedTint(AppTokens t) => t.isNight ? t.surfaceAlt2 : t.surface;

/// Unselected segment label. Day #8A8290 · Night #9A9A9A.
Color mockTabMuted(AppTokens t) =>
    t.isNight ? t.textMuted : const Color(0xFF8A8290);

/// 52px square nav button (Previous / Next) in the answer sheets.
class MockSquareButton extends StatelessWidget {
  const MockSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.tooltip,
    this.flagged = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final String? tooltip;

  /// Flag button in its "on" state (pink).
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return IconButtonBox(
      icon: icon,
      onTap: onTap,
      bg: primary ? t.primary : (flagged ? kMockFlagStrong : t.surfaceAlt2),
      fg: primary ? t.onPrimary : (flagged ? kMockInk : t.text),
      tooltip: tooltip,
    );
  }
}

class IconButtonBox extends StatelessWidget {
  const IconButtonBox({
    super.key,
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.fg,
    this.tooltip,
    this.size = 52,
    this.radius = 18,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;
  final String? tooltip;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Widget box = Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 22, color: fg),
        ),
      ),
    );
    if (tooltip != null) box = Tooltip(message: tooltip!, child: box);
    return box;
  }
}

/// Wide 52px soft button between the square nav buttons.
class MockWideButton extends StatelessWidget {
  const MockWideButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.bg,
    this.fg,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = fg ?? t.text;
    return Material(
      color: bg ?? t.surfaceAlt2,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              if (icon != null) Icon(icon, size: 18, color: c),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44×26 switch as drawn on the canvas (knob on the right when on).
class MockToggle extends StatelessWidget {
  const MockToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? t.primary : t.border,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? t.onPrimary : t.surface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Box with a dashed rounded border (pending tiles, empty answer gaps).
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = 20,
    this.strokeWidth = 1.5,
    this.dash = 4,
    this.gap = 3,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
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
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(half, half, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()..addRRect(rrect);
    for (final PathMetric metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + dash) < metric.length ? d + dash : metric.length;
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

/// Card with the soft upward shadow used for the bottom answer sheets.
BoxDecoration mockSheetDecoration(AppTokens t) => BoxDecoration(
      color: t.surface,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF151515).withValues(alpha: 0.06),
          blurRadius: 30,
          offset: const Offset(0, -8),
        ),
      ],
    );

/// Lettered answer option (A–E) used in the mock question cards.
class MockChoiceOption extends StatelessWidget {
  const MockChoiceOption({
    super.key,
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.primary : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected ? BorderSide.none : BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            spacing: 10,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? t.onPrimary : t.surfaceAlt2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? (t.isNight ? t.text : t.primary) : t.text,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: selected ? t.onPrimary : t.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI examiner notes (G9 / G10)
// ─────────────────────────────────────────────────────────────────────────────

String _mockText(Map<String, dynamic> data, String key) {
  final v = data[key];
  return v is String ? v.trim() : '';
}

/// True when any section of the attempt was scored by the offline demo scorer.
bool mockScoredOffline(Map<String, dynamic> data) {
  final src = data['source'];
  if (src is! Map) return false;
  return src.values.any((v) => v == 'demo');
}

/// True when the attempt has AI summary text or an offline-scoring note.
bool mockHasAiNotes(Map<String, dynamic> data) =>
    _mockText(data, 'writingSummary').isNotEmpty ||
    _mockText(data, 'speakingSummary').isNotEmpty ||
    mockScoredOffline(data);

/// AI summary text for Writing / Speaking (when present) plus the small
/// "Estimated offline (AI unavailable)" note.
class MockAiNotes extends StatelessWidget {
  const MockAiNotes({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final writing = _mockText(data, 'writingSummary');
    final speaking = _mockText(data, 'speakingSummary');
    final offline = mockScoredOffline(data);
    final rows = <(String, String)>[
      if (writing.isNotEmpty) ('Writing', writing),
      if (speaking.isNotEmpty) ('Speaking', speaking),
    ];
    final note = Text(
      'Estimated offline (AI unavailable)',
      style: TextStyle(fontSize: 11, color: t.textMuted),
    );
    if (rows.isEmpty) {
      return offline ? Center(child: note) : const SizedBox.shrink();
    }
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(AppIcons.sparkle, size: 16, color: t.iconAccent),
              const Text(
                'AI examiner notes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          for (final r in rows)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(r.$1, style: TextStyle(fontSize: 12, color: t.textMuted)),
                Text(
                  r.$2,
                  style: TextStyle(fontSize: 14, height: 1.45, color: t.textSoft),
                ),
              ],
            ),
          if (offline) note,
        ],
      ),
    );
  }
}
