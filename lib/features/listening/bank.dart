import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/services/media.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Listening question bank (assets/content/listening_bank.json)
//
// 32 sets P1-FN … P4-SA (4 parts × 8 formats, 20 questions each), imported
// from the Eleven v4 question-bank PDF by tool/import_listening_bank.py.
// Group types used by the bank on top of the demo ones (form, gap, mcq,
// multi, matching):
//   notes / sentence  text with a ______ gap          (like gap)
//   short             question, then an answer box
//   table             columns + rows; each blank is a question {label,
//                     before, after, row, col}
//   summary           one paragraph; each blank is a question {text}
//   map               plan / map / diagram: letters A–J with their written
//                     positions (options) and an optional drawing (image)
// ─────────────────────────────────────────────────────────────────────────────

/// Question formats of the bank, in the PDF's order: (formatCode, label).
const List<(String, String)> kListeningFormats = <(String, String)>[
  ('FN', 'Form / note completion'),
  ('MC', 'Multiple choice'),
  ('MA', 'Matching'),
  ('PM', 'Plan / map / diagram'),
  ('SC', 'Sentence completion'),
  ('TC', 'Table completion'),
  ('SM', 'Summary completion'),
  ('SA', 'Short answer'),
];

/// Short label of a format code ("TC" → "Table completion").
String listeningFormatLabel(String code) {
  for (final f in kListeningFormats) {
    if (f.$1 == code) return f.$2;
  }
  return code;
}

/// Group types answered by typing (not by choosing a letter).
bool listeningTypedGroup(String type) =>
    type != 'mcq' && type != 'multi' && type != 'matching' && type != 'map';

/// True for a question-bank set (has a code such as "P1-FN").
bool isBankSet(Map<String, dynamic> set) => set.s('code').isNotEmpty;

/// Two-line badge of a set: ("Part 1", "FN") for bank sets, ("Set", "03") for
/// the demo sets.
(String, String) listeningBadge(Map<String, dynamic> set) {
  if (isBankSet(set)) return ('Part ${set.i('part')}', set.s('formatCode'));
  final id = set.s('id');
  final i = id.lastIndexOf('_');
  return ('Set', i >= 0 ? id.substring(i + 1) : id);
}

/// "Form / note completion · Band 5.0 · British" (bank) or the set context.
String listeningSetMeta(Map<String, dynamic> set) {
  if (!isBankSet(set)) return set.s('context');
  final band = set.d('band');
  return <String>[
    listeningFormatLabel(set.s('formatCode')),
    if (band > 0) 'Band ${band.toStringAsFixed(1)}',
    if (set.s('accent').isNotEmpty) set.s('accent'),
  ].join(' · ');
}

/// Words searched by the lists' search boxes.
List<String> listeningSearchFields(Map<String, dynamic> set) => <String>[
      set.s('title'),
      set.s('context'),
      set.s('code'),
      set.s('formatLabel'),
      set.s('accent'),
      set.s('listeningContext'),
      ...set.ls('tags'),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// Group context: the plan / table / summary the questions refer to
// ─────────────────────────────────────────────────────────────────────────────

final RegExp _blank = RegExp(r'\((\d+)\)_{3,}');

/// Text with "(n)___" blanks → spans; a blank shows the student's answer (or
/// a numbered gap) and [current] is highlighted.
List<InlineSpan> listeningBlankSpans(
  String text,
  AppTokens t, {
  Map<int, String> answers = const <int, String>{},
  int? current,
}) {
  final out = <InlineSpan>[];
  var pos = 0;
  for (final m in _blank.allMatches(text)) {
    if (m.start > pos) out.add(TextSpan(text: text.substring(pos, m.start)));
    final n = int.parse(m.group(1)!);
    final given = (answers[n] ?? '').trim();
    final active = current == n;
    out.add(TextSpan(
      text: given.isEmpty ? '($n) ______' : '($n) $given',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: given.isEmpty ? t.textMuted : t.text,
        backgroundColor: active ? t.accentSoft : (given.isEmpty ? null : t.surfaceAlt),
      ),
    ));
    pos = m.end;
  }
  if (pos < text.length) out.add(TextSpan(text: text.substring(pos)));
  return out;
}

/// Plan (map groups), whole table (table groups) or whole paragraph (summary
/// groups) above / beside the questions. Other group types → nothing.
class ListeningGroupContext extends StatelessWidget {
  const ListeningGroupContext({
    super.key,
    required this.group,
    this.answers = const <int, String>{},
    this.current,
    this.showOptions = true,
  });

  final Map<String, dynamic> group;
  final Map<int, String> answers;
  final int? current;

  /// Map groups: list the lettered positions under the plan.
  final bool showOptions;

  @override
  Widget build(BuildContext context) {
    switch (group.s('type')) {
      case 'map':
        return _mapCard(context);
      case 'table':
        return _tableCard(context);
      case 'summary':
        return _summaryCard(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _frame(BuildContext context, {required IconData icon, required String label, required Widget child}) {
    final t = context.tk;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surfaceAlt2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 16, color: t.iconAccent),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textMuted),
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  Widget _mapCard(BuildContext context) {
    final t = context.tk;
    final image = group.s('image');
    final intro = group.s('layoutIntro');
    final options = group.l('options');
    final positions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        if (intro.isNotEmpty)
          Text(intro, style: TextStyle(fontSize: 13, height: 1.35, color: t.isNight ? t.textSoft : t.text)),
        if (showOptions)
          for (final o in options)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${o.s('key')}  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: o.s('text')),
                ],
              ),
              style: TextStyle(fontSize: 13, height: 1.3, color: t.isNight ? t.textSoft : t.text),
            ),
      ],
    );
    return _frame(
      context,
      icon: AppIcons.layers,
      label: image.isEmpty ? 'Plan · letter positions' : 'Plan',
      child: image.isEmpty
          ? positions
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                GestureDetector(
                  onTap: () => _zoomPlan(context, image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: MediaImage(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => positions,
                    ),
                  ),
                ),
                Text(
                  'Tap the plan to zoom',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: t.textMuted),
                ),
              ],
            ),
    );
  }

  /// Full-screen plan with pinch-zoom (white page, like the printed paper).
  static void _zoomPlan(BuildContext context, String image) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: MediaImage(image, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton(
                  icon: Icon(AppIcons.close, color: const Color(0xFF151515)),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableCard(BuildContext context) {
    final t = context.tk;
    final columns = group.ls('columns');
    final raw = group['rows'];
    final rows = <List<String>>[
      if (raw is List)
        for (final r in raw)
          if (r is List) <String>[for (final c in r) '$c'],
    ];
    if (columns.isEmpty) return const SizedBox.shrink();
    final style = TextStyle(fontSize: 12.5, height: 1.3, color: t.isNight ? t.textSoft : t.text);
    Widget cell(Widget child, {bool head = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: DefaultTextStyle.merge(
            style: head ? const TextStyle(fontWeight: FontWeight.w600) : null,
            child: child,
          ),
        );
    return _frame(
      context,
      icon: AppIcons.grid,
      label: 'Table',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(150),
          columnWidths: const <int, TableColumnWidth>{0: FixedColumnWidth(120)},
          border: TableBorder(
            horizontalInside: BorderSide(color: t.divider),
            verticalInside: BorderSide(color: t.divider),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: t.surfaceAlt),
              children: [for (final c in columns) cell(Text(c, style: style), head: true)],
            ),
            for (final r in rows)
              TableRow(
                children: [
                  for (var k = 0; k < columns.length; k++)
                    cell(Text.rich(
                      TextSpan(
                        children: listeningBlankSpans(
                          k < r.length ? r[k] : '',
                          t,
                          answers: answers,
                          current: current,
                        ),
                      ),
                      style: style,
                    )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final t = context.tk;
    return _frame(
      context,
      icon: AppIcons.article,
      label: 'Summary',
      child: Text.rich(
        TextSpan(
          children: listeningBlankSpans(group.s('summary'), t, answers: answers, current: current),
        ),
        style: TextStyle(fontSize: 13.5, height: 1.55, color: t.isNight ? t.textSoft : t.text),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info sheets
// ─────────────────────────────────────────────────────────────────────────────

Widget _sheetScroll(BuildContext context, List<Widget> children) {
  final h = MediaQuery.of(context).size.height;
  return ConstrainedBox(
    constraints: BoxConstraints(maxHeight: h * 0.85),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: children,
      ),
    ),
  );
}

Widget _heading(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tk.textMuted),
      ),
    );

Widget _para(BuildContext context, String text, {String lead = ''}) {
  final t = context.tk;
  return Text.rich(
    TextSpan(
      children: [
        if (lead.isNotEmpty) TextSpan(text: '$lead ', style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: text),
      ],
    ),
    style: TextStyle(fontSize: 14, height: 1.4, color: t.isNight ? t.textSoft : t.text),
  );
}

/// Everything the bank says about one set: situation, scenario, instructions,
/// topics, speakers and the recording setup.
Future<void> showListeningSetInfo(BuildContext context, Map<String, dynamic> set) {
  final t = context.tk;
  final band = set.d('band');
  final production = set.m('production');
  final pending = set.s('audioStatus') == 'pending';
  return showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) => _sheetScroll(ctx, [
        const SizedBox(height: 4),
        Text(
          isBankSet(set) ? '${set.s('code')} · ${set.s('formatLabel')}' : 'Part ${set.i('part')}',
          style: TextStyle(fontSize: 12, color: t.textMuted),
        ),
        Text(set.s('title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, height: 1.2)),
        const SizedBox(height: 2),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Tag('Part ${set.i('part')}', tone: TagTone.outline),
            if (band > 0) Tag('Band ${band.toStringAsFixed(1)}', tone: TagTone.outline),
            if (set.s('accent').isNotEmpty)
              Tag(
                set.s('locale').isEmpty ? set.s('accent') : '${set.s('accent')} · ${set.s('locale')}',
                tone: TagTone.outline,
              ),
            if (set.i('minutes') > 0) Tag('~${set.i('minutes')} min', tone: TagTone.outline),
            Tag('${Content.setQuestionCount(set)} questions', tone: TagTone.outline),
          ],
        ),
        if (set.s('listeningContext').isNotEmpty) ...[
          _heading(ctx, 'Situation'),
          _para(ctx, set.s('listeningContext')),
        ],
        if (set.s('scenario').isNotEmpty || set.s('context').isNotEmpty) ...[
          _heading(ctx, 'Scenario'),
          _para(ctx, set.s('scenario').isNotEmpty ? set.s('scenario') : set.s('context')),
        ],
        if (set.s('instructions').isNotEmpty) ...[
          _heading(ctx, 'Instructions'),
          _para(ctx, set.s('instructions')),
        ],
        if (set.ls('tags').isNotEmpty) ...[
          _heading(ctx, 'Topics'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final g in set.ls('tags')) Tag(g)],
          ),
        ],
        if (set.l('speakers').isNotEmpty) ...[
          _heading(ctx, set.l('speakers').length == 1 ? 'Speaker' : 'Speakers'),
          for (final sp in set.l('speakers'))
            _para(
              ctx,
              sp.s('description').isNotEmpty ? sp.s('description') : sp.s('voice'),
              lead: sp.s('name'),
            ),
        ],
        if (production.isNotEmpty) ...[
          _heading(ctx, 'Recording'),
          if (pending)
            _para(ctx, 'The recording is being produced. Until it is added, practice runs on a timed '
                'simulation and transcript timings are estimates.'),
          for (final row in production.l('setup'))
            if (!row.s('setting').startsWith('Voice: '))
              _para(ctx, row.s('value'), lead: '${row.s('setting')}:'),
        ],
        const SizedBox(height: 8),
      ]),
    ),
  );
}

/// About the question bank: edition notes, how answers were checked, the
/// production guide and the set index.
Future<void> showListeningBankInfo(BuildContext context) {
  final meta = Content.listeningBankMeta;
  final t = context.tk;
  return showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) => _sheetScroll(ctx, [
        const SizedBox(height: 4),
        Text(meta.s('title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
        if (meta.s('edition').isNotEmpty)
          Text(meta.s('edition'), style: TextStyle(fontSize: 13, color: t.textMuted)),
        if (meta.s('summary').isNotEmpty) _para(ctx, meta.s('summary')),
        if (meta.l('parts').isNotEmpty) ...[
          _heading(ctx, 'The four parts'),
          for (final p in meta.l('parts')) _para(ctx, p.s('description'), lead: 'Part ${p.i('part')}'),
        ],
        for (final sec in meta.l('sections')) ...[
          _heading(ctx, sec.s('heading')),
          for (final b in sec.l('bullets')) _para(ctx, b.s('text'), lead: b.s('lead')),
        ],
        if (meta.l('productionGuide').isNotEmpty) ...[
          _heading(ctx, 'Recording guide (${meta.s('model')})'),
          for (final r in meta.l('productionGuide')) _para(ctx, r.s('guidance'), lead: r.s('topic')),
        ],
        if (meta.l('setIndex').isNotEmpty) ...[
          _heading(ctx, 'Set index'),
          for (final r in meta.l('setIndex'))
            _para(ctx, '${r.s('title')} · ${r.s('format')} · Band ${r.s('band')} · ${r.s('accent')}',
                lead: r.s('code')),
          if (meta.s('accentMix').isNotEmpty)
            Text(meta.s('accentMix'), style: TextStyle(fontSize: 12, color: t.textMuted)),
        ],
        const SizedBox(height: 8),
      ]),
    ),
  );
}
