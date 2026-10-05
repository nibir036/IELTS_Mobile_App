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
import 'writing_data.dart';

/// C9 · Saved Essay History - the student's writing attempts (+ drafts and
/// full mocks with a writing band) from the store.
class EssayHistoryScreen extends StatefulWidget {
  const EssayHistoryScreen({super.key});

  @override
  State<EssayHistoryScreen> createState() => _EssayHistoryScreenState();
}

class _EssayHistoryScreenState extends State<EssayHistoryScreen> {
  int _filter = 0;

  /// Rows: {kind ('task1'|'task2'|'mock'|'draft'), task, title, band, meta,
  /// badge, tone, draft, route, args}.
  List<Map<String, dynamic>> _rows(Store store) {
    final rows = <Map<String, dynamic>>[];
    for (final d in WritingDrafts.all(store)) {
      final task = d.i('task');
      final p = WritingContent.prompt(d.s('promptId'));
      rows.add(<String, dynamic>{
        'kind': 'task$task',
        'title': p?.s('shortTitle') ?? 'Untitled draft',
        'band': '',
        'meta': 'Task $task · ${WritingDrafts.savedLabel(d)} · ${countWords(d.s('text'))} words',
        'badge': '',
        'tone': 'none',
        'draft': true,
        'route': task == 1 ? Routes.writingTask1Editor : Routes.writingEditor,
        'args': <String, dynamic>{'promptId': d.s('promptId')},
      });
    }
    final essays = store.attemptsFor(skill: Skill.writing, kindPrefix: 'task');
    for (var i = 0; i < essays.length; i++) {
      final a = essays[i];
      final task = WritingService.taskOf(a);
      var older = 0;
      for (var j = i + 1; j < essays.length; j++) {
        if (essays[j].refId == a.refId && a.refId.isNotEmpty) older++;
      }
      rows.add(<String, dynamic>{
        'kind': 'task$task',
        'title': a.title,
        'band': Store.formatBand(a.band),
        'meta': 'Task $task · ${Store.shortDate(a.createdAt)} · ${a.data.i('words')} words',
        'badge': older > 0 ? 'Revised ×$older' : '',
        'tone': task == 1 ? 'lavender' : 'pink',
        'draft': false,
        'route': Routes.writingBandReport,
        'args': <String, dynamic>{'attemptId': a.id},
      });
    }
    for (final a in store.attemptsFor(skill: Skill.mock)) {
      final sec = a.data['sections'];
      if (sec is! Map || sec['writing'] is! num) continue;
      rows.add(<String, dynamic>{
        'kind': 'mock',
        'title': a.title.isEmpty ? 'Full mock test' : a.title,
        'band': Store.formatBand((sec['writing'] as num).toDouble()),
        'meta': 'Mock · ${Store.shortDate(a.createdAt)} · Writing section',
        'badge': '',
        'tone': 'pink',
        'draft': false,
        'route': resultRouteFor(a),
        'args': <String, dynamic>{'attemptId': a.id},
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final filters = WritingContent.all.m('history').l('filters');
    final rows = _rows(store);
    final values = store.bandHistory(Skill.writing);
    final latest = values.isEmpty ? null : values.last;
    final delta = values.length < 2 ? null : values.last - values.first;
    final deltaLabel = delta == null
        ? ''
        : '${delta >= 0 ? '+' : '−'}${delta.abs().toStringAsFixed(1)}';
    final key = _filter < filters.length ? filters[_filter].s('key') : 'all';
    final shown = rows.where((e) {
      if (key == 'all') return true;
      return e.s('kind') == key;
    }).toList();

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      gap: 14,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            const Spacer(),
            IconBox(
              icon: AppIcons.search,
              tooltip: 'Search essays',
              onTap: () => context.push(Routes.search),
            ),
          ],
        ),
        const Text(
          'My essays',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
          ),
        ),
        HeroCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Writing band trend',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.heroMuted,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: Store.formatBand(latest)),
                              TextSpan(
                                text: latest == null
                                    ? ' no essays yet'
                                    : ' latest essay',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: t.heroMuted,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (deltaLabel.isNotEmpty)
                    WPill(
                      deltaLabel,
                      bg: t.peach,
                      fg: kOnPeach,
                      weight: FontWeight.w600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: 74,
                child: CustomPaint(
                  painter: _TrendPainter(
                    values: values,
                    line: t.peach,
                    dotFill: t.heroText,
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (var i = 0; i < filters.length; i++)
                _FilterChip(
                  label: filters[i].s('key') == 'all'
                      ? '${filters[i].s('label')} ${rows.length}'
                      : filters[i].s('label'),
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
            ],
          ),
        ),
        Column(
          spacing: 8,
          children: [
            for (final e in shown) _EssayRow(essay: e),
            if (rows.isEmpty)
              EmptyState(
                title: 'No essays yet',
                message: 'Your essays, band scores and drafts will appear here.',
                icon: AppIcons.writing,
                actionLabel: 'Write an essay',
                onAction: () => context.push(Routes.writingSelector),
              )
            else if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No essays here yet',
                  style: TextStyle(fontSize: 14, color: t.textMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return SizedBox(
      height: 40,
      child: Material(
        color: selected ? t.primary : t.surface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? t.onPrimary : t.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EssayRow extends StatelessWidget {
  const _EssayRow({required this.essay});

  final Map<String, dynamic> essay;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final draft = essay.b('draft');
    final tone = essay.s('tone');
    final badge = essay.s('badge');
    Color boxBg;
    if (draft) {
      boxBg = t.surfaceAlt2;
    } else if (tone == 'lavender') {
      boxBg = const Color(0xFFDCE6FF);
    } else {
      boxBg = const Color(0xFFFFE2D8);
    }
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(essay.s('route'), args: essay.m('args')),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              draft ? 'Draft' : essay.s('band'),
              style: TextStyle(
                fontSize: draft ? 13 : 17,
                fontWeight: draft ? FontWeight.w400 : FontWeight.w500,
                color: draft
                    ? t.textMuted
                    : wc(t, 0xFF151515, 0xFF625C66),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  essay.s('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  essay.s('meta'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          if (badge.isNotEmpty)
            WPill(
              badge,
              bg: t.surfaceAlt2,
              fg: t.isNight ? t.textMuted : t.text,
              fontSize: 11,
              radius: 8,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            )
          else
            Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.line,
    required this.dotFill,
  });

  final List<double> values;
  final Color line;
  final Color dotFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    const padX = 8.0;
    const top = 18.0;
    final bottom = size.height - 14;
    final n = values.length;
    Offset at(int i) {
      final x = n <= 1
          ? size.width / 2
          : padX + (size.width - padX * 2) * (i / (n - 1));
      final y = bottom - (bottom - top) * ((values[i] - minV) / range);
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < n; i++) {
      final p = at(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
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
    for (var i = 0; i < n; i++) {
      final p = at(i);
      if (i == n - 1) {
        canvas.drawCircle(p, 6, Paint()..color = line);
      } else {
        canvas.drawCircle(p, 4, Paint()..color = dotFill);
        canvas.drawCircle(p, 4, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.values != values || old.dotFill != dotFill || old.line != line;
}
