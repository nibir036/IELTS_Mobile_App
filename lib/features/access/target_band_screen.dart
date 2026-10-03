import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// A6 · Target Band Setup (band gauge, test type, exam date).
class TargetBandScreen extends StatefulWidget {
  const TargetBandScreen({super.key});

  @override
  State<TargetBandScreen> createState() => _TargetBandScreenState();
}

class _TargetBandScreenState extends State<TargetBandScreen> {
  final Map<String, dynamic> _data = Demo.section('access').m('targetBand');
  late final List<double> _bands = _data.ld('bandOptions');
  late double _band;
  late DateTime _date;
  List<DateTime> _dates = <DateTime>[];

  static DateTime _today() => DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    final acc = Store.I.current;

    // Band: saved target (snapped to an option) or the default.
    final defaultBand = _data.d('defaultBand') > 0 ? _data.d('defaultBand') : 7.0;
    final saved = acc?.targetBand;
    _band = defaultBand;
    if (saved != null && _bands.isNotEmpty) {
      var best = _bands.first;
      for (final b in _bands) {
        if ((b - saved).abs() < (best - saved).abs()) best = b;
      }
      _band = best;
    }

    // Exam date: saved (if still in the future) or ~8 weeks out.
    final savedDate = acc?.examDate;
    final today = _today();
    if (savedDate != null && DateUtils.dateOnly(savedDate).isAfter(today)) {
      _date = DateUtils.dateOnly(savedDate);
    } else {
      _date = today.add(const Duration(days: 56));
    }
    _dates = _windowAround(_date);
  }

  /// Five consecutive days around [center], never before tomorrow.
  static List<DateTime> _windowAround(DateTime center) {
    final tomorrow = _today().add(const Duration(days: 1));
    var start = center.subtract(const Duration(days: 2));
    if (start.isBefore(tomorrow)) start = tomorrow;
    return <DateTime>[
      for (var i = 0; i < 5; i++) DateUtils.addDaysToDate(start, i),
    ];
  }

  static String _dateLabel(DateTime d) =>
      '${Store.weekdayShort(d.weekday)}, ${d.day} ${Store.monthShort(d.month)} ${d.year}';

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateUtils.dateOnly(picked);
      _dates = _windowAround(_date);
    });
  }

  void _continue() {
    Store.I.updateProfile(<String, dynamic>{
      'targetBand': _band,
      'testType': 'Academic',
      'examDate': Store.dateKey(_date),
    });
    context.push(Routes.diagnostic);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final minBand = _data.d('minBand');
    final maxBand = _data.d('maxBand') > minBand ? _data.d('maxBand') : minBand + 1;
    final daysAway = DateUtils.dateOnly(_date).difference(_today()).inDays;

    return AppScreen(
      gap: 18,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      footer: PrimaryButton(
        label: 'Continue',
        trailing: AppIcons.forward,
        fontSize: 17,
        onTap: _continue,
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              onTap: () => context.back(),
            ),
            const Expanded(
              child: Center(child: StepDots(count: 3, filled: 1)),
            ),
            LinkText(
              'Skip',
              fontSize: 15,
              weight: FontWeight.w400,
              color: t.textMuted,
              onTap: () => context.push(Routes.diagnostic),
            ),
          ],
        ),
        const OnboardingTitle(
          title: 'Set your target band',
          subtitle: 'We build your daily plan around this goal.',
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              // Gauge fill, knob and number glide to the chosen band.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _band),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOutCubic,
                builder: (context, shown, _) {
                  final fraction = ((shown - minBand) / (maxBand - minBand))
                      .clamp(0.0, 1.0)
                      .toDouble();
                  return FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 300,
                  height: 180,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: 300,
                        height: 168,
                        child: CustomPaint(
                          painter: _GaugePainter(
                            fraction: fraction,
                            track: t.isNight ? t.border : const Color(0xFFF1E6EC),
                            fill: t.accentStrong,
                            tick: t.isNight ? t.border : t.textFaint,
                            knob: t.text,
                            knobCore: t.surface,
                            knobRing: t.isNight ? t.bg : null,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              bandLabel(shown),
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w300,
                                height: 1,
                                letterSpacing: -2,
                              ),
                            ),
                            Text(
                              'Target overall band',
                              style: TextStyle(fontSize: 13, color: t.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 160,
                        child: Text(
                          bandLabel(minBand),
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 160,
                        child: Text(
                          bandLabel(maxBand),
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              );
                },
              ),
              Row(
                spacing: 4,
                children: [
                  for (final b in _bands)
                    Expanded(
                      child: _BandChip(
                        label: bandLabel(b),
                        selected: (b - _band).abs() < 0.01,
                        onTap: () => setState(() => _band = b),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.all(18),
          gradient: t.isNight
              ? null
              : const LinearGradient(
                  begin: Alignment(-0.34, -0.94),
                  end: Alignment(0.34, 0.94),
                  colors: [Color(0xFFF9D6E2), Color(0xFFFBEAF0)],
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickDate,
                child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.isNight ? t.heroChip : t.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(AppIcons.calendar, size: 20, color: t.heroText),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Exam date',
                          style: TextStyle(fontSize: 13, color: t.heroMuted),
                        ),
                        Text(
                          _dateLabel(_date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: t.heroFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$daysAway days',
                      style: const TextStyle(fontSize: 13, color: kOnDarkPill),
                    ),
                  ),
                ],
              ),
              ),
              Row(
                spacing: 6,
                children: [
                  for (var i = 0; i < _dates.length; i++)
                    Expanded(
                      child: _DateChip(
                        weekday: Store.weekdayShort(_dates[i].weekday),
                        day: '${_dates[i].day}',
                        selected: DateUtils.isSameDay(_dates[i], _date),
                        onTap: () => setState(() => _date = _dates[i]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.primary : (t.isNight ? t.surfaceAlt2 : t.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected ? BorderSide.none : BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? t.onPrimary : t.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final String weekday;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bg = selected
        ? t.heroFill
        : (t.isNight ? const Color(0x14151515) : t.heroChip);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              Text(
                weekday,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? (t.isNight ? kOnDarkPill : const Color(0xFFD6D0D4))
                      : t.heroMuted,
                ),
              ),
              Text(
                day,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? kOnDarkPill : t.heroText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Semicircle band gauge (300×168 artboard geometry).
class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.tick,
    required this.knob,
    required this.knobCore,
    this.knobRing,
  });

  final double fraction;
  final Color track;
  final Color fill;
  final Color tick;
  final Color knob;
  final Color knobCore;
  final Color? knobRing;

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(150, 150);
    const r = 120.0;
    final rect = Rect.fromCircle(center: center, radius: r);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    if (fraction > 0) {
      final arc = Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, math.pi, math.pi * fraction, false, arc);
    }
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(18, 150), const Offset(24, 150), tickPaint);
    canvas.drawLine(const Offset(276, 150), const Offset(282, 150), tickPaint);
    canvas.drawLine(const Offset(150, 12), const Offset(150, 18), tickPaint);
    canvas.drawLine(const Offset(53, 55), const Offset(57, 59), tickPaint);
    canvas.drawLine(const Offset(247, 55), const Offset(243, 59), tickPaint);

    final angle = math.pi + math.pi * fraction;
    final knobCenter = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    canvas.drawCircle(knobCenter, 14, Paint()..color = knob);
    if (knobRing != null) {
      canvas.drawCircle(
        knobCenter,
        14,
        Paint()
          ..color = knobRing!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.drawCircle(knobCenter, 5, Paint()..color = knobCore);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.fill != fill ||
      old.tick != tick ||
      old.knob != knob ||
      old.knobCore != knobCore ||
      old.knobRing != knobRing;
}
