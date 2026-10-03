import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// B4 · Study Analytics.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  static const List<String> _periodLabels = <String>['Week', 'Month', 'Year'];
  int _period = 1;

  /// Buckets (label, start inclusive, end exclusive) for the selected period.
  List<(String, DateTime, DateTime)> _buckets(int period) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final out = <(String, DateTime, DateTime)>[];
    if (period == 0) {
      for (var i = 6; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        out.add((Store.weekdayShort(d.weekday), d, d.add(const Duration(days: 1))));
      }
    } else if (period == 1) {
      for (var i = 4; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        out.add((Store.monthShort(m.month), m, DateTime(m.year, m.month + 1, 1)));
      }
    } else {
      final q = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
      for (var i = 4; i >= 0; i--) {
        final st = DateTime(q.year, q.month - 3 * i, 1);
        final qn = (st.month - 1) ~/ 3 + 1;
        final yy = (st.year % 100).toString().padLeft(2, '0');
        final label = i == 0 ? 'Now' : (st.year == now.year ? 'Q$qn' : "Q$qn '$yy");
        out.add((label, st, DateTime(st.year, st.month + 3, 1)));
      }
    }
    return out;
  }

  /// Band points per bucket (average of band-scored core/mock attempts),
  /// carried forward over empty buckets; leading empty buckets are dropped.
  List<(String, double)> _points(Store store, List<(String, DateTime, DateTime)> buckets) {
    final scored = store.attempts
        .where((a) =>
            a.band != null &&
            (Skill.core.contains(a.skill) || a.skill == Skill.mock))
        .toList();
    final out = <(String, double)>[];
    double? last;
    for (final b in buckets) {
      final inB = scored
          .where((a) => !a.createdAt.isBefore(b.$2) && a.createdAt.isBefore(b.$3))
          .map((a) => a.band!)
          .toList();
      if (inB.isNotEmpty) {
        last = inB.reduce((x, y) => x + y) / inB.length;
      }
      if (last != null) out.add((b.$1, last));
    }
    return out;
  }

  int _minutesBetween(Store store, DateTime start, DateTime end) {
    var m = 0;
    for (final a in store.attempts) {
      if (!a.createdAt.isBefore(start) && a.createdAt.isBefore(end)) {
        m += (a.durationSec / 60).round();
      }
    }
    return m;
  }

  /// Newest-3 mean minus the previous-3 mean for a skill ('' if unknown).
  String _delta(Store store, String skill) {
    final bands = store
        .attemptsFor(skill: skill)
        .where((a) => a.band != null)
        .map((a) => a.band!)
        .toList();
    if (bands.length < 2) return '';
    final recent = bands.take(3).toList();
    final older = bands.skip(recent.length).take(3).toList();
    if (older.isEmpty) return '';
    double mean(List<double> l) => l.reduce((x, y) => x + y) / l.length;
    return signedBand(Store.roundBand(mean(recent)) - Store.roundBand(mean(older)));
  }

  static const Map<String, String> _criteria = <String, String>{
    'TA': 'Task Achievement',
    'CC': 'Coherence & Cohesion',
    'LR': 'Lexical Resource',
    'GRA': 'Grammatical Range & Accuracy',
    'FC': 'Fluency & Coherence',
    'P': 'Pronunciation',
  };

  /// Lowest criterion of the newest attempt of [skill] that has criteria.
  (String, double)? _weakCriterion(Store store, String skill) {
    for (final a in store.attemptsFor(skill: skill)) {
      final d = a.data;
      final nested = d['criteria'];
      (String, double)? low;
      for (final e in _criteria.entries) {
        Object? v = d[e.key];
        if (v is! num && nested is Map) v = nested[e.key];
        if (v is num) {
          final b = v.toDouble();
          if (low == null || b < low.$2) low = (e.value, b);
        }
      }
      if (low != null) return low;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final content = Demo.section('home').m('analytics');
    final index = _period;

    final header = Row(
      children: [
        IconBox(
          icon: AppIcons.back,
          tooltip: 'Back',
          size: 56,
          radius: 20,
          iconSize: 20,
          onTap: () => context.back(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: t.raised,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _periodLabels.length; i++)
                        Material(
                          color: i == index ? t.primary : Colors.transparent,
                          shape: const StadiumBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => setState(() => _period = i),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                _periodLabels[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      i == index ? FontWeight.w500 : FontWeight.w400,
                                  color: i == index ? t.onPrimary : t.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ),
            ),
          ),
        ),
      ],
    );

    final buckets = _buckets(index);
    final points = _points(store, buckets);
    final studied = _minutesBetween(store, buckets.first.$2, buckets.last.$3);
    final phrase = index == 0
        ? 'in the last 7 days'
        : (index == 1 ? 'in the last 5 months' : 'in the last 15 months');

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        const Text(
          'Your progress',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          'Band estimates from practice and mock tests',
          style: TextStyle(fontSize: 14, color: t.textMuted),
        ),
        if (store.hasActivity)
          Text(
            '${studyTimeLabel(studied)} studied $phrase',
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
      ],
    );

    if (!store.hasActivity) {
      return AppScreen(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        gap: 16,
        children: [
          header,
          title,
          EmptyState(
            icon: AppIcons.insights,
            title: 'Analytics appear after your first practice',
            message: 'Finish a test, essay or speaking answer and your band trend, skill breakdown and study time show up here.',
            actionLabel: 'Start practising',
            onAction: () => context.resetTo(Routes.moduleHub),
          ),
        ],
      );
    }

    String change;
    if (points.length < 2) {
      change = 'No change yet';
    } else {
      final d = Store.roundBand(points.last.$2) - Store.roundBand(points.first.$2);
      change = index == 0
          ? '${signedBand(d)} this week'
          : '${signedBand(d)} since ${points.first.$1}';
    }

    // Skill rows
    final skillBands = <String, double?>{
      for (final k in Skill.core) k: store.skillBand(k),
    };
    String? weakest;
    for (final k in Skill.core) {
      final b = skillBands[k];
      if (b == null) continue;
      if (weakest == null || b < skillBands[weakest]!) weakest = k;
    }
    final skills = <Map<String, dynamic>>[
      for (final k in Skill.core)
        <String, dynamic>{
          'name': Skill.label(k),
          'band': skillBands[k],
          'deltaLabel': _delta(store, k),
          'progress': store.skillProgress(k),
          'weakest': k == weakest,
        },
    ];
    final weakCrit = weakest == null ? null : _weakCriterion(store, weakest);
    final weakTitle = weakest == null
        ? ''
        : (weakCrit == null
            ? '${Skill.label(weakest)} · Band ${Store.formatBand(skillBands[weakest])}'
            : '${Skill.label(weakest)} · ${weakCrit.$1} ${Store.formatBand(weakCrit.$2)}');
    final weakTarget =
        weakest == null ? '' : content.m('weakestTargets').s(weakest);

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      gap: 16,
      children: [
        header,
        title,

        // Overall band + line chart
        AppCard(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Overall band',
                          style: TextStyle(fontSize: 13, color: t.textMuted),
                        ),
                        Text(
                          Store.formatBand(store.estimatedBand),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w300,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      change,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: t.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 130,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LineChartPainter(
                          values: [for (final p in points) p.$2],
                          grid: t.isNight ? const Color(0xFF242424) : t.border,
                          line: t.fill,
                          dotFill: t.isNight ? t.bg : t.surface,
                        ),
                      ),
                    ),
                    if (points.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: t.text,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            Store.formatBand(Store.roundBand(points.last.$2)),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: t.surface,
                            ),
                          ),
                        ),
                      ),
                    if (points.isEmpty)
                      Center(
                        child: Text(
                          'No band scores in this period',
                          style: TextStyle(fontSize: 13, color: t.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < points.length; i++)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          points[i].$1,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                i == points.length - 1 ? t.text : t.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Skill breakdown
        AppCard(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              const Text('Skill breakdown', style: TextStyle(fontSize: 15)),
              for (final s in skills) _SkillBar(skill: s),
            ],
          ),
        ),

        // Weakest area
        if (weakest != null)
        Material(
          color: t.isNight
              ? const Color(0xFF1F1814)
              : t.alert.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: t.isNight ? const Color(0xFF3A2A22) : t.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openHomeTarget(context, weakTarget),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        Text(
                          'Weakest area',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.isNight
                                ? const Color(0xFFFF9A80)
                                : t.alert,
                          ),
                        ),
                        Text(
                          weakTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: t.alert,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(AppIcons.forward, size: 20, color: kInk),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.skill});

  final Map<String, dynamic> skill;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final weakest = skill.b('weakest');
    final v = skill.d('progress').clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(skill.s('name'), style: const TextStyle(fontSize: 14)),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: skill.s('deltaLabel').isEmpty
                        ? ''
                        : '${skill.s('deltaLabel')}  ',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                  TextSpan(
                    text: Store.formatBand(skill['band'] as double?),
                    style: TextStyle(fontSize: 14, color: t.text),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: t.isNight ? const Color(0xFF242424) : t.track,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: weakest
                ? StripedBox(
                    radius: 5,
                    a: t.isNight ? const Color(0xFFFF7A5C) : null,
                    b: t.isNight ? const Color(0xFF5A2A20) : null,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: t.fill,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.grid,
    required this.line,
    required this.dotFill,
  });

  final List<double> values;
  final Color grid;
  final Color line;
  final Color dotFill;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final gy in <double>[20, 55, 90]) {
      final y = gy / 130 * h;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    if (values.isEmpty) return;

    var minV = values.first;
    var maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final range = maxV - minV;
    final left = 10.0;
    final right = w - 10;
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? right
          : left + (right - left) * i / (values.length - 1);
      final norm = range == 0 ? 0.5 : (values[i] - minV) / range;
      final y = (104 - norm * 70) / 130 * h;
      pts.add(Offset(x, y));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(pts.last.dx, 120 / 130 * h)
      ..lineTo(pts.first.dx, 120 / 130 * h)
      ..close();
    canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.08));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final ring = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = dotFill;
    for (var i = 0; i < pts.length - 1; i++) {
      canvas.drawCircle(pts[i], 4, fill);
      canvas.drawCircle(pts[i], 4, ring);
    }
    canvas.drawCircle(pts.last, 6, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values ||
      old.grid != grid ||
      old.line != line ||
      old.dotFill != dotFill;
}
