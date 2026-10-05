import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// H10 · Scoring Criteria - how each skill is scored (tabs: Listening,
/// Reading, Writing, Speaking, Overall). Each tab is a list of blocks from
/// resources.json → scoring.skills[].blocks:
///   table    {title, columns, rows, note?}
///   parts    {title, items: [{label, title, text}]}
///   criteria {title, subtitle?, criteria: [{name, color, tag?, focus, levels}]}
///   bullets  {title, items}      chips {title, items}
///   note     {title, items}      bands {title, items: [{band, name, text}]}
class ScoringCriteriaScreen extends StatefulWidget {
  const ScoringCriteriaScreen({super.key});

  @override
  State<ScoringCriteriaScreen> createState() => _ScoringCriteriaScreenState();
}

class _ScoringCriteriaScreenState extends State<ScoringCriteriaScreen> {
  late final Map<String, dynamic> _data = Demo.section('resources').m('scoring');
  late int _skill = _data.i('defaultSkill');

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final skills = _data.l('skills');
    final index = skills.isEmpty ? 0 : _skill.clamp(0, skills.length - 1).toInt();
    final skill = skills.isEmpty ? <String, dynamic>{} : skills[index];

    return AppScreen(
      gap: 12,
      children: [
        const ResTopBar(title: 'Scoring Criteria'),
        ResSegments(
          labels: [for (final s in skills) s.s('name')],
          index: index,
          height: 38,
          fontSize: 12,
          onChanged: (i) => setState(() => _skill = i),
        ),
        Text(
          skill.s('intro'),
          style: TextStyle(fontSize: 13, height: 1.45, color: t.textMuted),
        ),
        if (skill.l('facts').isNotEmpty) _Facts(items: skill.l('facts')),
        for (final b in skill.l('blocks')) _block(b),
        // Older data: a plain criteria list on the skill.
        for (final c in skill.l('criteria')) _CriterionCard(data: c),
      ],
    );
  }

  Widget _block(Map<String, dynamic> b) {
    switch (b.s('type')) {
      case 'table':
        return _TableCard(data: b);
      case 'parts':
        return _PartsCard(data: b);
      case 'criteria':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            _Heading(b.s('title'), subtitle: b.s('subtitle')),
            for (final c in b.l('criteria')) _CriterionCard(data: c),
          ],
        );
      case 'bullets':
        return _ListCard(data: b);
      case 'note':
        return _ListCard(data: b, note: true);
      case 'chips':
        return _ChipsCard(data: b);
      case 'bands':
        return _BandsCard(data: b);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── pieces ──────────────────────────────────────────────────────────────────

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.subtitle = ''});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 3,
      children: [
        if (title.isNotEmpty)
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted)),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in items)
            Container(
              width: w,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.isNight ? t.surfaceAlt2 : ResPalette.periwinkleDay,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(f.s('label'), style: TextStyle(fontSize: 11.5, color: t.textMuted)),
                  Text(f.s('value'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final cols = data.ls('columns');
    final rows = <List<String>>[
      for (final r in (data['rows'] as List? ?? const []))
        [for (final c in r as List) '$c'],
    ];
    // A wide first column for two-column tables, equal columns otherwise.
    int flex(int i) => cols.length == 2 ? (i == 0 ? 3 : 2) : 1;
    Widget row(List<String> cells, {bool head = false, bool shade = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: head
              ? (t.isNight ? t.surfaceAlt2 : ResPalette.lavender)
              : shade
                  ? t.surfaceAlt.withValues(alpha: t.isNight ? 0.5 : 0.6)
                  : null,
          borderRadius: head ? BorderRadius.circular(10) : null,
        ),
        child: Row(
          children: [
            for (var i = 0; i < cols.length; i++)
              Expanded(
                flex: flex(i),
                child: Text(
                  i < cells.length ? cells[i] : '',
                  textAlign: i == 0 ? TextAlign.start : TextAlign.center,
                  style: TextStyle(
                    fontSize: cols.length > 3 ? 12 : 13,
                    height: 1.3,
                    fontWeight: head || (i == cols.length - 1 && cols.length > 2)
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: head && !t.isNight ? ResPalette.ink : t.text,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return AppCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(data.s('title'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          row(cols, head: true),
          for (var i = 0; i < rows.length; i++) row(rows[i], shade: i.isOdd),
          if (data.s('note').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 2),
              child: Text(data.s('note'),
                  style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted)),
            ),
        ],
      ),
    );
  }
}

class _PartsCard extends StatelessWidget {
  const _PartsCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text(data.s('title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          for (final p in data.l('items'))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ResPalette.pink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.s('label'),
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600, color: ResPalette.ink)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(p.s('title'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      Text(p.s('text'),
                          style: TextStyle(
                              fontSize: 12.5, height: 1.4, color: t.isNight ? t.text : t.textSoft)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.data, this.note = false});

  final Map<String, dynamic> data;
  final bool note;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 20,
      color: note ? (t.isNight ? t.surfaceAlt : ResPalette.creamChip) : null,
      borderColor: note && !t.isNight ? ResPalette.creamBorder : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          Text(data.s('title'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: note && !t.isNight ? ResPalette.ink : t.text)),
          for (final item in data.ls('items'))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: note ? ResPalette.creamBorder : ResPalette.indigoDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(item,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: note && !t.isNight
                              ? ResPalette.ink
                              : (t.isNight ? t.text : t.textSoft))),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChipsCard extends StatelessWidget {
  const _ChipsCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(data.s('title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in data.ls('items'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(c, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BandsCard extends StatelessWidget {
  const _BandsCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(data.s('title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          for (final b in data.l('items'))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                _BandBox(band: int.tryParse(b.s('band')) ?? 0),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${b.s('name')} · ',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(
                          text: b.s('text'),
                          style: TextStyle(color: t.isNight ? t.text : t.textSoft)),
                    ]),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CriterionCard extends StatelessWidget {
  const _CriterionCard({required this.data});

  final Map<String, dynamic> data;

  Color _dot(AppTokens t) {
    switch (data.s('color')) {
      case 'alert':
        return t.alert;
      case 'lavender':
        return ResPalette.indigoDot;
      case 'pink':
        return ResPalette.blush;
      default:
        return t.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final focus = data.ls('focus');
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _dot(t),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Text(
                  data.s('name'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              if (data.s('tag').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(data.s('tag'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          if (focus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.isNight ? t.surfaceAlt : ResPalette.periwinkleDay,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text('The examiner looks at',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600, color: t.textMuted)),
                  for (final f in focus)
                    Text('• $f', style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
          for (final l in data.l('levels')) _LevelRow(data: l),
        ],
      ),
    );
  }
}

class _BandBox extends StatelessWidget {
  const _BandBox({required this.band});

  final int band;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg;
    Color fg;
    if (band >= 9) {
      bg = ResPalette.lavender;
      fg = ResPalette.ink;
    } else if (band >= 7) {
      bg = t.isNight ? t.surfaceAlt2 : ResPalette.periwinkleDay;
      fg = t.text;
    } else {
      bg = t.surfaceAlt2;
      fg = t.text;
    }
    return Container(
      width: 30,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$band',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _BandBox(band: data.i('band')),
        Expanded(
          child: Text(
            data.s('text'),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: t.isNight ? t.text : t.textSoft,
            ),
          ),
        ),
      ],
    );
  }
}
