import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/theme/tokens.dart';

/// Writing Task 1 visual inside the mock (G6), drawn from the bank's chart
/// data: line / bar charts are painted; pie, table, process, map and mixed
/// get a compact readable rendering.
class MockTask1Chart extends StatelessWidget {
  const MockTask1Chart({super.key, required this.type, required this.chart});

  final String type;
  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'line':
      case 'bar':
        return _SeriesChart(chart: chart, bars: type == 'bar');
      case 'pie':
        return _PieCharts(chart: chart);
      case 'table':
        return _TableView(chart: chart);
      case 'process':
        return _Steps(steps: chart.ls('steps'));
      case 'map':
        return _MapCompare(chart: chart);
      case 'mixed':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            for (final part in chart.l('parts'))
              MockTask1Chart(type: part.s('type'), chart: part),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Series colours (Day / Night).
List<Color> _palette(AppTokens t) => <Color>[
      t.text,
      t.alert,
      t.isNight ? const Color(0xFF8E97F0) : const Color(0xFF5B63D6),
      t.isNight ? const Color(0xFF7FC8A9) : const Color(0xFF2E8B67),
      t.textMuted,
      t.warning,
    ];

String _num(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}

class _Legend extends StatelessWidget {
  const _Legend({required this.names, required this.colors});

  final List<String> names;
  final List<Color> colors;

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
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Text(names[i], style: TextStyle(fontSize: 11, color: t.textMuted)),
            ],
          ),
      ],
    );
  }
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({required this.chart, required this.bars});

  final Map<String, dynamic> chart;
  final bool bars;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final colors = _palette(t);
    final series = chart.l('series');
    final labels = chart.ls('xLabels');
    final values = <List<double>>[for (final s in series) s.ld('values')];
    var maxV = 0.0;
    for (final v in values) {
      for (final x in v) {
        maxV = math.max(maxV, x);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (chart.s('unit').isNotEmpty)
          Text('Unit: ${chart.s('unit')}', style: TextStyle(fontSize: 11, color: t.textMuted)),
        SizedBox(
          height: 150,
          child: CustomPaint(
            painter: _SeriesPainter(
              values: values,
              labels: labels,
              maxValue: maxV <= 0 ? 1 : maxV,
              colors: colors,
              bars: bars,
              axis: t.border,
              label: t.textMuted,
            ),
          ),
        ),
        _Legend(names: <String>[for (final s in series) s.s('name')], colors: colors),
      ],
    );
  }
}

class _SeriesPainter extends CustomPainter {
  _SeriesPainter({
    required this.values,
    required this.labels,
    required this.maxValue,
    required this.colors,
    required this.bars,
    required this.axis,
    required this.label,
  });

  final List<List<double>> values;
  final List<String> labels;
  final double maxValue;
  final List<Color> colors;
  final bool bars;
  final Color axis;
  final Color label;

  static const double _left = 30;
  static const double _bottom = 18;

  double _niceMax() {
    final raw = maxValue * 1.1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = mag / 2;
    return (raw / step).ceil() * step;
  }

  void _text(Canvas canvas, String s, Offset at, {bool center = false, bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 9, color: label)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 60);
    var dx = at.dx;
    if (center) dx -= tp.width / 2;
    if (right) dx -= tp.width;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _left;
    final h = size.height - _bottom;
    if (w <= 0 || h <= 0) return;
    final top = _niceMax();
    final grid = Paint()
      ..color = axis
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      canvas.drawLine(Offset(_left, y), Offset(size.width, y), grid);
      _text(canvas, _num(top * i / 4), Offset(_left - 4, y), right: true);
    }
    final n = labels.isEmpty ? (values.isEmpty ? 0 : values.first.length) : labels.length;
    if (n == 0) return;

    if (bars) {
      final slot = w / n;
      final groupW = slot * 0.7;
      final k = values.isEmpty ? 1 : values.length;
      final barW = groupW / k;
      for (var i = 0; i < n; i++) {
        final x0 = _left + slot * i + (slot - groupW) / 2;
        for (var s = 0; s < values.length; s++) {
          if (i >= values[s].length) continue;
          final bh = h * values[s][i] / top;
          final r = Rect.fromLTWH(x0 + barW * s, h - bh, math.max(1.0, barW - 2), bh);
          canvas.drawRRect(
            RRect.fromRectAndCorners(r, topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
            Paint()..color = colors[s % colors.length],
          );
        }
        if (i < labels.length) {
          _text(canvas, labels[i], Offset(_left + slot * i + slot / 2, h + _bottom / 2 + 2), center: true);
        }
      }
      return;
    }

    final step = n <= 1 ? 0.0 : w / (n - 1);
    for (var i = 0; i < labels.length; i++) {
      final x = n <= 1 ? _left + w / 2 : _left + step * i;
      _text(canvas, labels[i], Offset(x, h + _bottom / 2 + 2), center: true);
    }
    for (var s = 0; s < values.length; s++) {
      final paint = Paint()
        ..color = colors[s % colors.length]
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < values[s].length && i < n; i++) {
        final x = n <= 1 ? _left + w / 2 : _left + step * i;
        final y = h - h * values[s][i] / top;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = colors[s % colors.length]);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter old) =>
      old.values != values || old.colors != colors || old.axis != axis;
}

class _PieCharts extends StatelessWidget {
  const _PieCharts({required this.chart});

  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final colors = _palette(t);
    final unit = chart.s('unit');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final c in chart.l('charts'))
          Row(
            spacing: 14,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _PiePainter(
                    values: <double>[for (final s in c.l('slices')) s.d('value')],
                    colors: colors,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(c.s('label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    for (var i = 0; i < c.l('slices').length; i++)
                      Row(
                        spacing: 6,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors[i % colors.length],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${c.l('slices')[i].s('name')} · ${_num(c.l('slices')[i].d('value'))}${unit == '%' ? '%' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: t.textMuted),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[i % colors.length]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.values != values || old.colors != colors;
}

class _TableView extends StatelessWidget {
  const _TableView({required this.chart});

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
    Widget cell(String s, {bool head = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(
            s,
            style: TextStyle(
              fontSize: 11,
              fontWeight: head ? FontWeight.w600 : FontWeight.w400,
              color: head ? t.text : t.textSoft,
            ),
          ),
        );
    final n = columns.length;
    if (n == 0) return const SizedBox.shrink();
    return Table(
      border: TableBorder(horizontalInside: BorderSide(color: t.divider)),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: t.surfaceAlt2),
          children: [for (final c in columns) cell(c, head: true)],
        ),
        for (final r in rows)
          TableRow(
            children: [
              for (var i = 0; i < n; i++) cell(i < r.length ? r[i] : ''),
            ],
          ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.onPrimary),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(steps[i], style: TextStyle(fontSize: 13, height: 1.35, color: t.textSoft)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _MapCompare extends StatelessWidget {
  const _MapCompare({required this.chart});

  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget side(Map<String, dynamic> m) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.surfaceAlt2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(m.s('label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              for (final f in m.ls('features'))
                Text('• $f', style: TextStyle(fontSize: 11, height: 1.35, color: t.textSoft)),
            ],
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(child: side(chart.m('before'))),
        Expanded(child: side(chart.m('after'))),
      ],
    );
  }
}
