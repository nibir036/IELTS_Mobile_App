import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/share_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_session.dart';
import 'widgets.dart';

/// G9 · Final Mock Summary & Band Card.
class MockResultsScreen extends StatelessWidget {
  const MockResultsScreen({super.key});

  static const _names = <String, String>{
    'listening': 'Listening',
    'reading': 'Reading',
    'writing': 'Writing',
    'speaking': 'Speaking',
  };

  static String _avg(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  static String _score(Map<String, dynamic> m) =>
      m.isEmpty ? '–' : '${m.i('correct')}/${m.i('total')}';

  static String _shareText(Attempt a, double overall, List<Map<String, dynamic>> skills) {
    final b = StringBuffer()
      ..writeln('IELTS Academic mock result')
      ..writeln('${a.title} · ${Store.weekdayDate(a.createdAt)} ${a.createdAt.year}')
      ..writeln()
      ..writeln('Overall band: ${mockBand(overall)}');
    for (final s in skills) {
      final band = s.d('band');
      b.writeln('${s.s('name')}: ${band > 0 ? mockBand(band) : '–'}');
    }
    b
      ..writeln()
      ..write('Practised with IELTS AI by nextED');
    return b.toString();
  }

  Widget _empty(BuildContext context) {
    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      gap: 16,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              size: 56,
              radius: 20,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
          ],
        ),
        EmptyState(
          icon: AppIcons.timer,
          title: 'No mock results yet',
          message: 'Finish a full mock test to see your overall band, section scores and trend.',
          actionLabel: 'Start a mock test',
          onAction: () => context.push(Routes.mockSystemCheck),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final a = store.resolveAttempt(context.routeArgs, skill: Skill.mock, kind: 'mock');
    if (a == null) return _empty(context);

    final data = a.data;
    final skills = <Map<String, dynamic>>[
      for (final key in _names.keys)
        <String, dynamic>{
          'key': key,
          'name': _names[key],
          'band': mockSectionBand(a, key) ?? 0.0,
          'detail': switch (key) {
            'listening' => _score(data.m('listeningScore')),
            'reading' => _score(data.m('readingScore')),
            'writing' => 'AI rated',
            _ => '${((data.i('spokenSec') + 30) ~/ 60).clamp(1, 99)} min',
          },
        },
    ];
    final parts = data.l('listeningByPart');
    final older = mockOlderThan(a);
    final prev = older.isEmpty ? null : older.first;
    final trendAttempts = <Attempt>[...older.take(4).toList().reversed, a];
    final target = store.current?.targetBand ?? 7.0;
    final overall = a.band ?? data.d('overall');
    final average = data.containsKey('average') ? data.d('average') : overall;
    final toGo = target - overall;
    final changeLabel = prev == null || prev.band == null
        ? 'First mock'
        : '${mockSigned(overall - prev.band!)} vs M${mockNumberLabel(prev)}';
    var best = -1.0;
    var bestIndex = 0;
    for (var i = 0; i < skills.length; i++) {
      if (skills[i].d('band') > best) {
        best = skills[i].d('band');
        bestIndex = i;
      }
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      gap: 12,
      footer: PrimaryButton(
        label: 'See my improvement plan',
        leading: AppIcons.sparkle,
        radius: 999,
        onTap: () => context.push(Routes.improvementPlan, args: {'attemptId': a.id}),
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              size: 56,
              radius: 20,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Score report',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${a.title} · ${Store.weekdayDate(a.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.share,
              size: 56,
              radius: 20,
              tooltip: 'Share',
              onTap: () => ShareService.shareText(
                context,
                _shareText(a, overall, skills),
                subject: 'My IELTS mock result · Band ${mockBand(overall)}',
              ),
            ),
          ],
        ),
        HeroCard(
          radius: 32,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall band'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                        color: t.peach,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mockBand(overall),
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w300,
                        height: 0.95,
                        letterSpacing: -2.5,
                        color: t.heroText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Average ${_avg(average)} · rounded to nearest 0.5',
                      style: TextStyle(fontSize: 12, color: t.heroMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 8,
                children: [
                  MockInkBadge(changeLabel),
                  Text(
                    'Target ${mockBand(target)}\n'
                    '${toGo > 0 ? '${mockBand(toGo)} to go' : 'Reached'}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: t.heroMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          spacing: 6,
          children: [
            for (var i = 0; i < skills.length; i++)
              Expanded(
                child: _SkillTile(row: skills[i], highlight: i == bestIndex),
              ),
          ],
        ),
        if (mockHasAiNotes(data)) MockAiNotes(data: data),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Listening · by part',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push(Routes.mockAnswers, args: {'attemptId': a.id}),
                    child: Text(
                      'Answer key',
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ),
                ],
              ),
              if (parts.isEmpty)
                Text(
                  'No part breakdown for this mock.',
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              for (final p in parts) _PartBar(row: p),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Band trend',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    'Next goal · ${mockBand(target)}',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
              SizedBox(
                height: 64,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    values: [for (final p in trendAttempts) p.band ?? 0.0],
                    goal: target,
                    line: t.fill,
                    guide: t.isNight ? const Color(0xFF3A3A3A) : t.border,
                    hole: t.isNight ? t.bg : t.surface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < trendAttempts.length; i++)
                      Text(
                        'M${mockNumberLabel(trendAttempts[i])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: i == trendAttempts.length - 1
                              ? t.text
                              : (t.isNight ? t.textFaint : t.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.row, required this.highlight});

  final Map<String, dynamic> row;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bg = highlight ? t.peach : t.surface;
    final fg = highlight ? kOnPeach : t.text;
    final muted = highlight ? kOnPeach.withValues(alpha: 0.6) : t.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        spacing: 2,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(row.s('name'), style: TextStyle(fontSize: 12, color: muted)),
          ),
          Text(
            mockBand(row.d('band')),
            style: TextStyle(
              fontSize: 24,
              fontWeight: highlight ? FontWeight.w500 : FontWeight.w400,
              letterSpacing: -0.5,
              color: fg,
            ),
          ),
          Text(
            row.s('detail'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }
}

class _PartBar extends StatelessWidget {
  const _PartBar({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final total = row.i('total') == 0 ? 1 : row.i('total');
    final ratio = row.i('correct') / total;
    return Row(
      spacing: 10,
      children: [
        SizedBox(
          width: 48,
          child: Text(row.s('label'), style: TextStyle(fontSize: 13, color: t.textMuted)),
        ),
        Expanded(
          child: ProgressBar(
            value: ratio,
            height: 8,
            fill: ratio < 0.7 ? t.alert : null,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${row.i('correct')}/${row.i('total')}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.goal,
    required this.line,
    required this.guide,
    required this.hole,
  });

  final List<double> values;
  final double goal;
  final Color line;
  final Color guide;
  final Color hole;

  /// Pixels per band step (canvas: 0.5 band = 13px).
  static const double _perBand = 26;

  double _y(double v) => 7 + (goal - v) * _perBand;

  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      final end = x + 3 < size.width ? x + 3 : size.width;
      canvas.drawLine(Offset(x, _y(goal)), Offset(end, _y(goal)), guidePaint);
    }
    if (values.isEmpty) return;
    final n = values.length;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          n == 1 ? size.width / 2 : 10 + (size.width - 20) * i / (n - 1),
          _y(values[i]).clamp(4.0, size.height - 4),
        ),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final ring = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < pts.length; i++) {
      final last = i == pts.length - 1;
      canvas.drawCircle(pts[i], last ? 5 : 3.5, Paint()..color = last ? line : hole);
      canvas.drawCircle(pts[i], last ? 5 : 3.5, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values ||
      old.goal != goal ||
      old.line != line ||
      old.guide != guide ||
      old.hole != hole;
}
