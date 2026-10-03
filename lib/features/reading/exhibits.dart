import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/services/media.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import 'widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Question-bank exhibits: summary, notes, table, flow-chart and diagram
// layouts with numbered gaps "(n) ______", plus the lettered option box.
// Used by the question panel (gaps show the student's answers) and by the
// "How to attempt" lessons (plain gaps).
// ─────────────────────────────────────────────────────────────────────────────

/// Exhibit kinds this file can draw.
const Set<String> kExhibitKinds = <String>{'summary', 'notes', 'table', 'flowchart', 'diagram'};

final RegExp _gap = RegExp(r'\((\d+)\)\s*_{2,}');

/// Text with its "(n) ______" gaps drawn as numbered slots. [offset] shifts
/// the numbers (questions 14–26 in a test); [filled] maps a (shifted)
/// number to the answer typed/chosen so far; [current] is highlighted.
class GapText extends StatelessWidget {
  const GapText(
    this.text, {
    super.key,
    this.offset = 0,
    this.filled = const <int, String>{},
    this.current,
    this.style,
  });

  final String text;
  final int offset;
  final Map<int, String> filled;
  final int? current;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in _gap.allMatches(text)) {
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      final n = int.parse(m.group(1)!) + offset;
      final value = (filled[n] ?? '').trim();
      final isCurrent = current == n;
      spans.add(TextSpan(
        text: value.isNotEmpty ? '($n) $value' : '($n) ______',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isCurrent ? kInk : (value.isNotEmpty ? t.text : t.textMuted),
          backgroundColor: isCurrent ? kLavender : null,
          decoration: value.isNotEmpty ? TextDecoration.underline : TextDecoration.none,
          decorationColor: t.textMuted,
        ),
      ));
      pos = m.end;
    }
    if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    return Text.rich(
      TextSpan(children: spans),
      style: style ?? TextStyle(fontSize: 14, height: 1.45, color: t.text),
    );
  }
}

/// Soft panel the exhibits sit in (same tone as the list of headings).
class ExhibitPanel extends StatelessWidget {
  const ExhibitPanel({super.key, required this.child, this.title = '', this.padding});

  final Widget child;
  final String title;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: t.isNight ? t.surfaceAlt2 : const Color(0xFFF8F3F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          child,
        ],
      ),
    );
  }
}

/// A summary / notes / table / flow-chart / diagram. [data] is the question
/// group (or a lesson exhibit) holding `text`, `lines`, `columns`+`rows`,
/// `steps` or `labels`. [image] is the diagram picture (asset path).
class ReadingExhibit extends StatelessWidget {
  const ReadingExhibit({
    super.key,
    required this.kind,
    required this.data,
    this.offset = 0,
    this.filled = const <int, String>{},
    this.current,
    this.image = '',
    this.showTitle = true,
  });

  /// False inside a question card, which already shows the group title.
  final bool showTitle;
  final String kind;
  final Map<String, dynamic> data;
  final int offset;
  final Map<int, String> filled;
  final int? current;
  final String image;

  Widget _gapText(String text, {TextStyle? style}) => GapText(
        text,
        offset: offset,
        filled: filled,
        current: current,
        style: style,
      );

  @override
  Widget build(BuildContext context) {
    final title = showTitle ? data.s('title') : '';
    switch (kind) {
      case 'summary':
        return ExhibitPanel(title: title, child: _gapText(data.s('text')));
      case 'notes':
        return ExhibitPanel(title: title, child: _notes(context));
      case 'table':
        return ExhibitPanel(title: title, child: _table(context));
      case 'flowchart':
        return ExhibitPanel(title: title, child: _flowchart(context));
      case 'diagram':
        return _diagram(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _notes(BuildContext context) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        for (final line in data.l('lines'))
          if (line.i('level') == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _gapText(
                line.s('text'),
                style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: t.text),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(left: 10.0 * line.i('level')),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text('•', style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted)),
                  Expanded(child: _gapText(line.s('text'))),
                ],
              ),
            ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final t = context.tk;
    final columns = data.ls('columns');
    final raw = data['rows'];
    final rows = <List<String>>[
      if (raw is List)
        for (final r in raw)
          if (r is List) <String>[for (final c in r) '$c'],
    ];
    final width = <int>[columns.length, for (final r in rows) r.length].fold<int>(0, (a, b) => a > b ? a : b);
    if (width == 0) return const SizedBox.shrink();
    Widget cell(String text, {bool header = false}) => ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 90, maxWidth: 170),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: header
                ? Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
                : _gapText(text, style: TextStyle(fontSize: 13, height: 1.4, color: t.text)),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder.all(color: t.border, borderRadius: BorderRadius.circular(10)),
        children: [
          if (columns.isNotEmpty)
            TableRow(
              decoration: BoxDecoration(color: t.isNight ? t.surface : t.surfaceAlt),
              children: [
                for (var j = 0; j < width; j++) cell(j < columns.length ? columns[j] : '', header: true),
              ],
            ),
          for (final r in rows)
            TableRow(
              children: [
                for (var j = 0; j < width; j++) cell(j < r.length ? r[j] : ''),
              ],
            ),
        ],
      ),
    );
  }

  Widget _flowchart(BuildContext context) {
    final t = context.tk;
    final raw = data['steps'];
    final steps = raw is List ? raw : const <Object?>[];
    Widget box(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border),
          ),
          child: _gapText(text, style: TextStyle(fontSize: 13, height: 1.4, color: t.text)),
        );
    Widget arrow() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Icon(AppIcons.chevronDown, size: 18, color: t.textMuted),
        );
    Widget column(List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              box(items[i]),
              if (i < items.length - 1) arrow(),
            ],
          ],
        );
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step is Map) {
        // A fork: two (or more) branches side by side.
        final branches = <List<String>>[
          if (step['branches'] is List)
            for (final b in step['branches'] as List)
              if (b is List) <String>[for (final e in b) '$e'],
        ];
        if (branches.isEmpty) continue;
        children.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [for (final b in branches) Expanded(child: column(b))],
        ));
      } else {
        children.add(box('$step'));
      }
      if (i < steps.length - 1) children.add(arrow());
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _diagram(BuildContext context) {
    final t = context.tk;
    final caption = data.s('caption');
    if (image.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          DiagramImage(asset: image, semanticLabel: data.s('title')),
          Text(
            'Tap the diagram to zoom',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: t.textMuted),
          ),
        ],
      );
    }
    // No picture (lesson examples): labels either side of a captioned box.
    final labels = data.l('labels');
    List<Map<String, dynamic>> side(String s) {
      final out = <Map<String, dynamic>>[
        for (final l in labels)
          if (l.s('side') == s) l,
      ];
      out.sort((a, b) => a.i('order').compareTo(b.i('order')));
      return out;
    }

    Widget column(List<Map<String, dynamic>> ls, TextAlign align) => Column(
          crossAxisAlignment: align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          spacing: 10,
          children: [
            for (final l in ls)
              GapText(
                l.s('text'),
                offset: offset,
                filled: filled,
                current: current,
                style: TextStyle(fontSize: 12, height: 1.35, color: t.text),
              ),
          ],
        );
    return ExhibitPanel(
      title: showTitle ? data.s('title') : '',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          Expanded(child: column(side('left'), TextAlign.right)),
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.border),
            ),
            child: Text(
              caption.isEmpty ? 'diagram' : caption,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: t.textMuted),
            ),
          ),
          Expanded(child: column(side('right'), TextAlign.left)),
        ],
      ),
    );
  }
}

/// Diagram picture on a white card; tap opens a zoomable full-screen view.
class DiagramImage extends StatelessWidget {
  const DiagramImage({super.key, required this.asset, this.semanticLabel = ''});

  final String asset;
  final String semanticLabel;

  void _zoom(BuildContext context) {
    final t = context.tk;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: MediaImage(asset, fit: BoxFit.contain),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Material(
                color: t.primary,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(AppIcons.close, size: 18, color: t.onPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _zoom(context),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: MediaImage(
            asset,
            fit: BoxFit.contain,
            semanticLabel: semanticLabel.isEmpty ? null : semanticLabel,
            errorBuilder: (_, _, _) => Center(
              child: Text('Diagram not available', style: TextStyle(fontSize: 12, color: t.textMuted)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lettered option box: "List of Endings", "List of Explorers", word box.
class OptionBox extends StatelessWidget {
  const OptionBox({super.key, required this.title, required this.options});

  final String title;
  final List<Map<String, dynamic>> options;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.isNight ? t.surfaceAlt2 : const Color(0xFFF8F3F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: t.textMuted)),
          for (final o in options)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    o.s('key'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    o.s('text'),
                    style: TextStyle(fontSize: 13, height: 1.35, color: t.textSoft),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
