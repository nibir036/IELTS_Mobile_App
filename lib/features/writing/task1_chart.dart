import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/theme/tokens.dart';

/// Renders any Academic Task 1 visual from the content bank
/// (CONTENT_SCHEMA.md → Writing → chart shapes):
///
/// * `line` / `bar` — `{unit, xLabels, series:[{name, values}]}`
///   (multi-series line with legend · grouped bars with legend)
/// * `pie` — `{unit, charts:[{label, slices:[{name, value}]}]}` (1–2 pies)
/// * `table` — `{columns:[…], rows:[[…], …]}` (bordered grid)
/// * `process` — `{steps:[…]}` (numbered step flow)
/// * `map` — `{before:{label, features}, after:{label, features}}`
/// * `mixed` — `{parts:[{type, …}, …]}` (each part rendered in turn)
///
/// [type] overrides `chart['type']` (pass the prompt's `type`). Missing or
/// malformed fields render as empty parts rather than throwing. Draw it
/// inside a card; it has no background of its own. [height] is the plot
/// height of line and bar charts.
class Task1Chart extends StatelessWidget {
  const Task1Chart({
    super.key,
    required this.chart,
    this.type,
    this.height = 150,
  });

  final Map<String, dynamic> chart;
  final String? type;
  final double height;

  /// Guesses the type from the fields present when none is given.
  static String resolveType(Map<String, dynamic> chart, String? type) {
    final given = (type ?? '').trim().isNotEmpty ? type!.trim() : chart.s('type');
    if (given.isNotEmpty) return given;
    if (chart['parts'] is List) return 'mixed';
    if (chart['charts'] is List) return 'pie';
    if (chart['rows'] is List) return 'table';
    if (chart['steps'] is List) return 'process';
    if (chart['before'] is Map || chart['after'] is Map) return 'map';
    if (chart['series'] is List) return 'line';
    return '';
  }

  /// Series / slice colours (Day · Night).
  static List<Color> palette(AppTokens t) => t.isNight
      ? const <Color>[
          Color(0xFFF6ECC8),
          Color(0xFFFF7A5C),
          Color(0xFF8C8EE8),
          Color(0xFF6FCFB5),
          Color(0xFFF2A14A),
          Color(0xFF9A9A9A),
          Color(0xFFE58FB0),
        ]
      : const <Color>[
          Color(0xFF151515),
          Color(0xFFE0527A),
          Color(0xFF8C8EE8),
          Color(0xFF3FA58C),
          Color(0xFFF2A14A),
          Color(0xFFB8AEB5),
          Color(0xFF6B5CA5),
        ];

  static Color colorAt(AppTokens t, int i) {
    final p = palette(t);
    return p[i % p.length];
  }

  /// 5 → "5", 5.25 → "5.3", 1230 → "1,230".
  static String fmt(double v) {
    final isInt = (v - v.roundToDouble()).abs() < 0.0001;
    if (!isInt) {
      return v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    }
    final n = v.round();
    final raw = n.abs().toString();
    final b = StringBuffer();
    for (var k = 0; k < raw.length; k++) {
      if (k > 0 && (raw.length - k) % 3 == 0) b.write(',');
      b.write(raw[k]);
    }
    return n < 0 ? '-$b' : b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final kind = resolveType(chart, type);
    switch (kind) {
      case 'line':
      case 'bar':
        return _SeriesChart(chart: chart, bar: kind == 'bar', height: height);
      case 'pie':
        return _PieCharts(chart: chart);
      case 'table':
        return _TableChart(chart: chart);
      case 'process':
        return _ProcessChart(chart: chart);
      case 'map':
        return _MapChart(chart: chart);
      case 'mixed':
        return _MixedChart(chart: chart, height: height);
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.line = false});

  final Color color;
  final bool line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: line ? 14 : 10,
      height: line ? 3 : 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(line ? 2 : 3),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.names, this.line = false});

  final List<String> names;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (var i = 0; i < names.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              _Swatch(color: Task1Chart.colorAt(t, i), line: line),
              Text(
                names[i],
                style: TextStyle(fontSize: 11, color: t.textMuted),
              ),
            ],
          ),
      ],
    );
  }
}

/// A chart part's caption ("Fees paid by (2024)", unit …), if any.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    );
  }
}

List<double> _numbers(dynamic v) {
  if (v is! List) return <double>[];
  return <double>[
    for (final e in v)
      e is num ? e.toDouble() : (double.tryParse('$e') ?? 0),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Line & bar
// ─────────────────────────────────────────────────────────────────────────────

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({
    required this.chart,
    required this.bar,
    required this.height,
  });

  final Map<String, dynamic> chart;
  final bool bar;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final series = chart.l('series');
    final names = <String>[
      for (var i = 0; i < series.length; i++)
        series[i].s('name').isEmpty ? 'Series ${i + 1}' : series[i].s('name'),
    ];
    final values = <List<double>>[for (final s in series) _numbers(s['values'])];
    final labels = chart.ls('xLabels');
    final unit = chart.s('unit');
    final title = chart.s('title').isNotEmpty ? chart.s('title') : chart.s('label');
    if (series.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (title.isNotEmpty) _Caption(title),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Expanded(child: _Legend(names: names, line: !bar)),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: TextStyle(fontSize: 11, color: t.textMuted),
              ),
          ],
        ),
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SeriesPainter(
              values: values,
              colors: <Color>[
                for (var i = 0; i < values.length; i++) Task1Chart.colorAt(t, i),
              ],
              xLabels: labels,
              bar: bar,
              gridColor: t.divider,
              labelColor: t.textMuted,
              dotFill: t.surface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.values,
    required this.colors,
    required this.xLabels,
    required this.bar,
    required this.gridColor,
    required this.labelColor,
    required this.dotFill,
  });

  final List<List<double>> values;
  final List<Color> colors;
  final List<String> xLabels;
  final bool bar;
  final Color gridColor;
  final Color labelColor;
  final Color dotFill;

  /// A "nice" axis maximum ≥ [v] (1, 2, 2.5, 5 × 10^n).
  static double niceMax(double v) {
    if (v <= 0) return 1;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in const <double>[1, 2, 2.5, 5, 10]) {
      if (m * exp >= v) return m * exp;
    }
    return 10 * exp;
  }

  TextPainter _text(String s, double maxWidth, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 9, color: labelColor)),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    );
    tp.layout(maxWidth: math.max(1.0, maxWidth));
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    var maxV = 0.0;
    var count = xLabels.length;
    for (final s in values) {
      count = math.max(count, s.length);
      for (final v in s) {
        if (v > maxV) maxV = v;
      }
    }
    if (count == 0) return;
    final yMax = niceMax(maxV);
    final ticks = <double>[0, yMax / 2, yMax];
    final tickLabels = <String>[for (final v in ticks) Task1Chart.fmt(v)];

    var left = 0.0;
    for (final l in tickLabels) {
      left = math.max(left, _text(l, 60).width);
    }
    left += 6;
    const top = 6.0;
    const bottomPad = 16.0;
    final right = size.width - 4;
    final bottom = size.height - bottomPad;
    final plotH = bottom - top;
    final plotW = right - left;
    if (plotH <= 0 || plotW <= 0) return;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var k = 0; k < ticks.length; k++) {
      final y = bottom - plotH * (ticks[k] / yMax);
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
      final tp = _text(tickLabels[k], left - 4);
      tp.paint(canvas, Offset(left - 4 - tp.width, y - tp.height / 2));
    }

    if (bar) {
      final groupW = plotW / count;
      final nSeries = math.max(1, values.length);
      final barW = (groupW * 0.72) / nSeries;
      for (var i = 0; i < count; i++) {
        final gx = left + groupW * i + groupW * 0.14;
        if (i < xLabels.length) {
          final tp = _text(xLabels[i], groupW - 2, align: TextAlign.center);
          tp.paint(
            canvas,
            Offset(left + groupW * (i + 0.5) - tp.width / 2, bottom + 4),
          );
        }
        for (var k = 0; k < values.length; k++) {
          final vals = values[k];
          if (i >= vals.length) continue;
          final h = plotH * (vals[i] / yMax).clamp(0.0, 1.0);
          if (h <= 0) continue;
          final w = math.max(1.0, barW - 2);
          final r = math.min(3.0, w / 2);
          final rect = RRect.fromRectAndCorners(
            Rect.fromLTWH(gx + barW * k + 1, bottom - h, w, h),
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r),
          );
          canvas.drawRRect(rect, Paint()..color = colors[k % colors.length]);
        }
      }
      return;
    }

    double xAt(int i) => count <= 1 ? left + plotW / 2 : left + plotW * (i / (count - 1));
    final slot = count <= 1 ? plotW : plotW / (count - 1);
    for (var i = 0; i < xLabels.length && i < count; i++) {
      final tp = _text(xLabels[i], slot, align: TextAlign.center);
      var dx = xAt(i) - tp.width / 2;
      dx = dx.clamp(0.0, math.max(0.0, size.width - tp.width)).toDouble();
      tp.paint(canvas, Offset(dx, bottom + 4));
    }
    for (var k = 0; k < values.length; k++) {
      final vals = values[k];
      if (vals.isEmpty) continue;
      final color = colors[k % colors.length];
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = Path();
      final points = <Offset>[];
      for (var i = 0; i < vals.length && i < count; i++) {
        final p = Offset(xAt(i), bottom - plotH * (vals[i] / yMax).clamp(0.0, 1.0));
        points.add(p);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, stroke);
      final fill = Paint()..color = dotFill;
      final ring = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (final p in points) {
        canvas.drawCircle(p, 2.6, fill);
        canvas.drawCircle(p, 2.6, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pie
// ─────────────────────────────────────────────────────────────────────────────

class _PieCharts extends StatelessWidget {
  const _PieCharts({required this.chart});

  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    var pies = chart.l('charts');
    if (pies.isEmpty && chart['slices'] is List) pies = <Map<String, dynamic>>[chart];
    if (pies.isEmpty) return const SizedBox.shrink();
    if (pies.length > 2) pies = pies.sublist(0, 2);
    final unit = chart.s('unit');

    // Legend names across the pies, first-seen order.
    final names = <String>[];
    for (final p in pies) {
      for (final s in p.l('slices')) {
        final n = s.s('name');
        if (!names.contains(n)) names.add(n);
      }
    }
    double valueOf(Map<String, dynamic> pie, String name) {
      for (final s in pie.l('slices')) {
        if (s.s('name') == name) return s.d('value');
      }
      return -1;
    }

    String suffix(double v) => unit == '%' ? '${Task1Chart.fmt(v)}%' : Task1Chart.fmt(v);
    final title = chart.s('title').isNotEmpty ? chart.s('title') : chart.s('label');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        if (title.isNotEmpty) _Caption(title),
        Row(
          spacing: 12,
          children: [
            for (final p in pies)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    if (p.s('label').isNotEmpty)
                      Text(
                        p.s('label'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: CustomPaint(
                        painter: _PiePainter(
                          values: <double>[
                            for (final n in names) math.max(0.0, valueOf(p, n)),
                          ],
                          colors: <Color>[
                            for (var i = 0; i < names.length; i++)
                              Task1Chart.colorAt(t, i),
                          ],
                          gap: t.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 5,
          children: [
            for (var i = 0; i < names.length; i++)
              Row(
                spacing: 8,
                children: [
                  _Swatch(color: Task1Chart.colorAt(t, i)),
                  Expanded(
                    child: Text(
                      names[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textSoft),
                    ),
                  ),
                  for (final p in pies)
                    SizedBox(
                      width: 52,
                      child: Text(
                        valueOf(p, names[i]) < 0 ? '–' : suffix(valueOf(p, names[i])),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.values, required this.colors, required this.gap});

  final List<double> values;
  final List<Color> colors;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    var total = 0.0;
    for (final v in values) {
      total += v;
    }
    final r = math.min(size.width, size.height) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    if (total <= 0) {
      canvas.drawCircle(c, r, Paint()..color = gap);
      return;
    }
    var start = -math.pi / 2;
    final sep = Paint()
      ..color = gap
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[i % colors.length]);
      canvas.drawArc(rect, start, sweep, true, sep);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Table
// ─────────────────────────────────────────────────────────────────────────────

class _TableChart extends StatelessWidget {
  const _TableChart({required this.chart});

  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final columns = chart.ls('columns');
    final rows = <List<String>>[];
    final raw = chart['rows'];
    if (raw is List) {
      for (final r in raw) {
        if (r is List) rows.add(<String>[for (final c in r) '$c']);
      }
    }
    var width = columns.length;
    for (final r in rows) {
      width = math.max(width, r.length);
    }
    if (width == 0) return const SizedBox.shrink();
    final title = chart.s('title');

    Widget cell(String text, {bool head = false, bool first = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Text(
            text,
            textAlign: first ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: head ? 11 : 12,
              height: 1.25,
              fontWeight: head || first ? FontWeight.w500 : FontWeight.w400,
              color: head ? t.textMuted : t.text,
            ),
          ),
        );

    List<String> pad(List<String> r) =>
        <String>[for (var k = 0; k < width; k++) k < r.length ? r[k] : ''];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (title.isNotEmpty) _Caption(title),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Table(
            border: TableBorder.all(
              color: t.border,
              borderRadius: BorderRadius.circular(12),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FlexColumnWidth(1.3),
            },
            children: [
              if (columns.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(color: t.surfaceAlt2),
                  children: [
                    for (var k = 0; k < width; k++)
                      cell(pad(columns)[k], head: true, first: k == 0),
                  ],
                ),
              for (final r in rows)
                TableRow(
                  children: [
                    for (var k = 0; k < width; k++)
                      cell(pad(r)[k], first: k == 0),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Process
// ─────────────────────────────────────────────────────────────────────────────

class _ProcessChart extends StatelessWidget {
  const _ProcessChart({required this.chart});

  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final steps = chart.ls('steps').where((s) => s.trim().isNotEmpty).toList();
    if (steps.isEmpty) return const SizedBox.shrink();
    final title = chart.s('title');
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == 0 || i == steps.length - 1 ? t.primary : t.surfaceAlt2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: i == 0 || i == steps.length - 1 ? t.onPrimary : t.text,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  steps[i],
                  style: TextStyle(fontSize: 13, height: 1.35, color: t.text),
                ),
              ),
            ),
          ],
        ),
      );
      if (i < steps.length - 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              width: 2,
              height: 10,
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _Caption(title),
          ),
        ...children,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map (before / after)
// ─────────────────────────────────────────────────────────────────────────────

class _MapChart extends StatelessWidget {
  const _MapChart({required this.chart});

  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    final before = chart.m('before');
    final after = chart.m('after');
    if (before.isEmpty && after.isEmpty) return const SizedBox.shrink();
    final title = chart.s('title');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (title.isNotEmpty) _Caption(title),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Expanded(
              child: _MapColumn(
                side: before,
                fallback: 'Before',
                highlight: false,
              ),
            ),
            Expanded(
              child: _MapColumn(
                side: after,
                fallback: 'After',
                highlight: true,
                compare: before.ls('features'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapColumn extends StatelessWidget {
  const _MapColumn({
    required this.side,
    required this.fallback,
    required this.highlight,
    this.compare = const <String>[],
  });

  final Map<String, dynamic> side;
  final String fallback;
  final bool highlight;

  /// The other side's features: rows that differ get an accent dot.
  final List<String> compare;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final features = side.ls('features');
    final label = side.s('label').isEmpty ? fallback : side.s('label');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: highlight ? t.surfaceAlt : t.surfaceAlt2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 7,
        children: [
          Row(
            children: [
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: highlight ? t.primary : t.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: highlight ? t.onPrimary : t.text,
                  ),
                ),
              ),
            ],
          ),
          for (var i = 0; i < features.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: highlight &&
                              (i >= compare.length || compare[i] != features[i])
                          ? t.alert
                          : t.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    features[i],
                    style: TextStyle(fontSize: 11.5, height: 1.35, color: t.text),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mixed
// ─────────────────────────────────────────────────────────────────────────────

class _MixedChart extends StatelessWidget {
  const _MixedChart({required this.chart, required this.height});

  final Map<String, dynamic> chart;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final parts = chart.l('parts');
    if (parts.isEmpty) return const SizedBox.shrink();
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      final kind = Task1Chart.resolveType(parts[i], null);
      if (kind.isEmpty || kind == 'mixed') continue;
      if (children.isNotEmpty) {
        children.add(Container(height: 1, color: t.divider));
      }
      children.add(Task1Chart(chart: parts[i], type: kind, height: height));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 14,
      children: children,
    );
  }
}
