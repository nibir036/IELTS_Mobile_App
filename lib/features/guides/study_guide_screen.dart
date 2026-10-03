import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/nav.dart';
import '../../app/services/media.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../reading/widgets.dart' show ReadingHeader, boldSpans, kInk, kLavender, kPink;
import 'guide_exercise.dart';

/// A module's study guide (assets/content/<module>_guide.json): the contents
/// page, or one chapter when opened with `{'chapter': id}`. Chapters follow
/// the explanation language (English where not translated).
class StudyGuideScreen extends StatefulWidget {
  const StudyGuideScreen({super.key, required this.module, required this.route, this.name = 'Guide'});

  final String module;
  final String route;
  final String name;

  @override
  State<StudyGuideScreen> createState() => _StudyGuideScreenState();
}

class _StudyGuideScreenState extends State<StudyGuideScreen> with ContentLangListener {
  String _chapter = '';
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final c = context.routeArgs['chapter'];
    if (c is String) _chapter = c;
  }

  List<Map<String, dynamic>> get _chapters => Demo.guide(widget.module).l('chapters');

  void _open(String id) => context.push(widget.route, args: <String, dynamic>{'chapter': id});

  @override
  Widget build(BuildContext context) {
    final guide = Demo.guide(widget.module);
    final chapters = _chapters;
    if (chapters.isEmpty) {
      return AppScreen(
        gap: 12,
        children: [
          ReadingHeader(title: widget.name, onBack: () => context.back()),
          const EmptyState(
            title: 'Guide not available',
            message: 'The guide could not be loaded. Restart the app and try again.',
            icon: AppIcons.school,
          ),
        ],
      );
    }
    final at = chapters.indexWhere((c) => c.s('id') == _chapter);
    return at < 0 ? _contents(context, guide, chapters) : _chapterView(context, chapters, at);
  }

  Widget _contents(BuildContext context, Map<String, dynamic> guide, List<Map<String, dynamic>> chapters) {
    final t = context.tk;
    return AppScreen(
      gap: 12,
      children: [
        ReadingHeader(
          title: guide.s('title'),
          subtitle: '${chapters.length} chapters',
          onBack: () => context.back(),
        ),
        if (guide.s('subtitle').isNotEmpty)
          Text(guide.s('subtitle'), style: TextStyle(fontSize: 13, height: 1.4, color: t.textSoft)),
        ContentLangSwitch(module: widget.module),
        for (var i = 0; i < chapters.length; i++)
          Builder(builder: (context) {
            final c = ContentL10n.guideChapter(chapters[i], module: widget.module);
            final group = c.s('group');
            final prevGroup =
                i == 0 ? '' : ContentL10n.guideChapter(chapters[i - 1], module: widget.module).s('group');
            final m = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(c.s('title'));
            final badge = m == null ? '${i + 1}' : m.group(1)!;
            final title = m == null ? c.s('title') : m.group(2)!;
            final card = ContentDirection(
              child: AppCard(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => _open(c.s('id')),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.s('id').endsWith('_practice') ? kPink : kLavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3),
                      ),
                    ),
                    Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
                  ],
                ),
              ),
            );
            if (group.isEmpty || group == prevGroup) return card;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                  child: ContentDirection(
                    child: Text(
                      group,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textMuted),
                    ),
                  ),
                ),
                card,
              ],
            );
          }),
      ],
    );
  }

  Widget _chapterView(BuildContext context, List<Map<String, dynamic>> chapters, int at) {
    final t = context.tk;
    final c = ContentL10n.guideChapter(chapters[at], module: widget.module);
    final hasNext = at + 1 < chapters.length;
    return AppScreen(
      gap: 12,
      footer: Row(
        spacing: 8,
        children: [
          if (at > 0)
            Expanded(
              child: SoftButton(
                label: 'Previous',
                leading: AppIcons.chevronLeft,
                height: 52,
                radius: 18,
                expand: true,
                bg: t.isNight ? t.surface : t.raised,
                onTap: () => context.replace(widget.route, args: <String, dynamic>{'chapter': chapters[at - 1].s('id')}),
              ),
            ),
          Expanded(
            child: PrimaryButton(
              label: hasNext ? 'Next chapter' : 'Contents',
              trailing: hasNext ? AppIcons.chevronRight : null,
              height: 52,
              radius: 18,
              fontSize: 14,
              onTap: hasNext
                  ? () => context.replace(widget.route, args: <String, dynamic>{'chapter': chapters[at + 1].s('id')})
                  : () => context.back(),
            ),
          ),
        ],
      ),
      children: [
        ReadingHeader(
          overline: 'Chapter ${at + 1} of ${chapters.length}',
          title: widget.name,
          onBack: () => context.back(),
        ),
        ContentLangSwitch(module: widget.module),
        ContentDirection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Text(
                c.s('title'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500, height: 1.25, letterSpacing: -0.4),
              ),
              for (final b in (c['blocks'] as List? ?? const <Object>[]))
                if (b is List && b.isNotEmpty) GuideBlock(block: b),
            ],
          ),
        ),
      ],
    );
  }
}

/// One guide block: ["p", text] · ["h"|"h2", text] · ["ul"|"ol", [items]] ·
/// ["tip", text] · ["note", text] (rule / template box) · ["ex", text]
/// (English example, always LTR) · ["model", text] (model answer, LTR) ·
/// ["table", [columns], [[cells]]] · ["img", asset path, caption].
/// `**bold**` works in every text.
class GuideBlock extends StatelessWidget {
  const GuideBlock({super.key, required this.block});

  final List<dynamic> block;

  String _s(int i) => i < block.length ? '${block[i]}' : '';

  List<String> _list(int i) =>
      i < block.length && block[i] is List ? <String>[for (final x in block[i] as List) '$x'] : <String>[];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final body = TextStyle(fontSize: 14, height: 1.55, color: t.textSoft);
    switch ('${block.first}') {
      case 'h':
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_s(1), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35)),
        );
      case 'h2':
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(_s(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
        );
      case 'note':
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: t.isNight ? t.surfaceAlt2 : const Color(0xFFFFF6E0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _rich(_s(1), body),
        );
      case 'model':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.isNight ? t.surface : const Color(0xFFEAF6EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _rich(_s(1), body.copyWith(color: t.text)),
          ),
        );
      case 'img':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.white,
                  child: MediaImage(_s(1), fit: BoxFit.contain, errorBuilder: (context, error, stack) => const SizedBox(height: 40)),
                ),
              ),
            ),
            if (_s(2).isNotEmpty)
              Text(_s(2), textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: t.textMuted)),
          ],
        );
      case 'ul':
      case 'ol':
        final items = _list(1);
        final numbered = block.first == 'ol';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (var i = 0; i < items.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(numbered ? '${i + 1}.' : '•', style: body.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: _rich(items[i], body)),
                ],
              ),
          ],
        );
      case 'tip':
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: t.isNight ? t.surfaceAlt2 : const Color(0xFFFDF0F4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(AppIcons.bulb, size: 15, color: t.text),
                  const Text('Tip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              _rich(_s(1), body),
            ],
          ),
        );
      case 'ex':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.isNight ? t.surface : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _rich(_s(1), body.copyWith(fontSize: 13, color: t.text)),
          ),
        );
      case 'table':
        final cols = _list(1);
        final rows = <List<String>>[
          if (block.length > 2 && block[2] is List)
            for (final r in block[2] as List)
              if (r is List) <String>[for (final c in r) '$c'],
        ];
        Widget cell(String s, {bool head = false}) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Text.rich(
                TextSpan(children: boldSpans(s)),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: head ? FontWeight.w600 : FontWeight.w400,
                  color: head ? kInk : t.textSoft,
                ),
              ),
            );
        final caption = block.length > 3 ? _s(3) : '';
        final table = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Table(
            border: TableBorder(horizontalInside: BorderSide(color: t.divider)),
            columnWidths: <int, TableColumnWidth>{
              for (var i = 0; i < cols.length; i++) i: FlexColumnWidth(i == cols.length - 1 ? 1.6 : 1),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: kLavender),
                children: [for (final c in cols) cell(c, head: true)],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    for (var i = 0; i < cols.length; i++) cell(i < r.length ? r[i] : ''),
                  ],
                ),
            ],
          ),
        );
        if (caption.isEmpty) return table;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            table,
            Text(caption, style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted)),
          ],
        );
      case 'pair':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.isNight ? t.surface : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                _mark('✗', _s(1), t.danger, body.copyWith(color: t.text)),
                _mark('✓', _s(2), t.success, body.copyWith(color: t.text, fontWeight: FontWeight.w500)),
                if (_s(3).isNotEmpty)
                  Directionality(
                    textDirection: Directionality.of(context),
                    child: _rich(_s(3), body.copyWith(fontSize: 13)),
                  ),
              ],
            ),
          ),
        );
      case 'box':
        final (Color bg, IconData icon, String label) = switch (_s(1)) {
          'l1' => (t.isNight ? t.surfaceAlt2 : const Color(0xFFFFF1E6), AppIcons.translate, 'Bangla speakers'),
          'impact' => (t.isNight ? t.surfaceAlt2 : const Color(0xFFEEEFFD), AppIcons.medal, 'IELTS impact'),
          _ => (t.isNight ? t.surfaceAlt2 : const Color(0xFFFFF6E0), AppIcons.bulb, 'Tip'),
        };
        final boxItems = _list(4);
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(icon, size: 15, color: t.text),
                  Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.textMuted)),
                ],
              ),
              if (_s(2).isNotEmpty)
                Text(_s(2), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
              _rich(_s(3), body),
              for (final it in boxItems) _boxItem(it, t, body),
            ],
          ),
        );
      case 'exercise':
        final exercise = block.length > 1 && block[1] is Map ? (block[1] as Map).cast<String, dynamic>() : null;
        return exercise == null ? const SizedBox.shrink() : GuideExercise(data: exercise);
      default:
        return _rich(_s(1), body);
    }
  }

  static Widget _rich(String s, TextStyle style) => Text.rich(TextSpan(children: boldSpans(s)), style: style);

  static Widget _mark(String mark, String text, Color color, TextStyle style) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(mark, style: style.copyWith(color: color, fontWeight: FontWeight.w700)),
          Expanded(child: Text(text, style: style)),
        ],
      );

  /// A box item: lines starting with ✗ / ✓ are English examples (LTR),
  /// "Label: text" lines show the label in bold.
  static Widget _boxItem(String item, AppTokens t, TextStyle body) {
    final lines = item.split('\n');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.isNight ? t.surface : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          for (final l in lines)
            if (l.startsWith('✗ ') || l.startsWith('✓ '))
              Directionality(
                textDirection: TextDirection.ltr,
                child: _mark(l.substring(0, 1), l.substring(2), l.startsWith('✗') ? t.danger : t.success,
                    body.copyWith(fontSize: 13, color: t.text)),
              )
            else
              _rich(l, body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
