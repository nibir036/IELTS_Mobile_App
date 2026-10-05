import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C10 · Writing Template (fill-in essay structures). Filled slots are user
/// data: kv `writing.template.values` ({"tplId|section|segment": value}).
class WritingTemplateScreen extends StatefulWidget {
  const WritingTemplateScreen({super.key});

  @override
  State<WritingTemplateScreen> createState() => _WritingTemplateScreenState();
}

class _WritingTemplateScreenState extends State<WritingTemplateScreen> {
  late final Map<String, dynamic> _data =
      WritingContent.all.m('templates');
  late final List<String> _types = _data.ls('types');
  late final List<Map<String, dynamic>> _items = _data.l('items');
  int _type = 0;

  /// Version of the selected type (e.g. Opinion: standard / strongly agree /
  /// partly agree).
  int _variant = 0;
  final Set<int> _open = <int>{0, 1};

  /// Filled slot values keyed by "templateId|section|segment".
  Map<String, dynamic> get _values =>
      kvMap(Store.I, WritingKeys.templateValues);

  /// Every template (version) of the selected type.
  List<Map<String, dynamic>> get _versions {
    if (_type >= _types.length) return <Map<String, dynamic>>[];
    final name = _types[_type];
    return <Map<String, dynamic>>[for (final it in _items) if (it.s('type') == name) it];
  }

  Map<String, dynamic>? get _template {
    final v = _versions;
    if (v.isEmpty) return null;
    return v[_variant.clamp(0, v.length - 1)];
  }

  String _valueOf(String tplId, int s, int g, Map<String, dynamic> seg) {
    final k = '$tplId|$s|$g';
    final v = _values[k];
    return v is String ? v : seg.s('value');
  }

  (int, int) _counts(Map<String, dynamic> tpl) {
    var filled = 0;
    var total = 0;
    final sections = tpl.l('sections');
    for (var s = 0; s < sections.length; s++) {
      final segs = sections[s].l('segments');
      for (var g = 0; g < segs.length; g++) {
        if (!segs[g].containsKey('slot')) continue;
        total++;
        if (_valueOf(tpl.s('id'), s, g, segs[g]).isNotEmpty) filled++;
      }
    }
    return (filled, total);
  }

  String _plain(Map<String, dynamic> tpl) {
    final b = StringBuffer();
    final sections = tpl.l('sections');
    for (var s = 0; s < sections.length; s++) {
      final segs = sections[s].l('segments');
      for (var g = 0; g < segs.length; g++) {
        final seg = segs[g];
        if (seg.containsKey('slot')) {
          final v = _valueOf(tpl.s('id'), s, g, seg);
          b.write(v.isEmpty ? '[${seg.s('slot')}]' : v);
        } else {
          b.write(seg.s('text'));
        }
      }
      b.write('\n\n');
    }
    return b.toString().trim();
  }

  void _copy(Map<String, dynamic>? tpl) {
    if (tpl == null) return;
    Clipboard.setData(ClipboardData(text: _plain(tpl)));
    context.toast('Template copied');
  }

  Future<void> _fill(String key, String slot, String current) async {
    final result = await showAppSheet<String>(
      context,
      _FillSheet(slot: slot, initial: current),
    );
    if (!mounted || result == null) return;
    final values = Map<String, dynamic>.from(_values);
    if (result.isEmpty) {
      values.remove(key);
    } else {
      values[key] = result;
    }
    Store.I.setKv(WritingKeys.templateValues, values);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tpl = _template;
    final sections = tpl == null ? <Map<String, dynamic>>[] : tpl.l('sections');
    final counts = tpl == null ? (0, 0) : _counts(tpl);
    final tplId = tpl == null ? '' : tpl.s('id');
    final isTask1 = tpl != null && tpl.s('task') == 'task1';

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 10,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            flex: 1,
            child: WFlatButton(
              label: 'Copy',
              leading: AppIcons.doc,
              bg: t.surface,
              fg: t.text,
              onTap: () => _copy(tpl),
            ),
          ),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: 'Use in editor',
              trailing: AppIcons.forward,
              height: 56,
              radius: 18,
              fontSize: 15,
              onTap: () => context.push(
                isTask1
                    ? Routes.writingTask1Editor
                    : Routes.writingEditor,
                args: <String, dynamic>{
                  if (tpl != null) 'text': _plain(tpl),
                },
              ),
            ),
          ),
        ],
      ),
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.back,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Writing Template',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                  Text(
                    tpl == null ? _types[_type] : tpl.s('title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.doc,
              tooltip: 'Copy template',
              onTap: () => _copy(tpl),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (var i = 0; i < _types.length; i++)
                SizedBox(
                  height: 36,
                  child: Material(
                    color: i == _type ? t.primary : t.surface,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() {
                        _type = i;
                        _variant = 0;
                        _open
                          ..clear()
                          ..addAll(<int>[0, 1]);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            _types[i],
                            style: TextStyle(
                              fontSize: 13,
                              color: i == _type ? t.onPrimary : t.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_versions.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                Text('Version', style: TextStyle(fontSize: 12, color: t.textMuted)),
                for (final (i, v) in _versions.indexed)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      _variant = i;
                      _open
                        ..clear()
                        ..addAll(<int>[0, 1]);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: i == _variant ? t.surfaceAlt2 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: i == _variant ? t.text : t.border),
                      ),
                      child: Text(
                        v.s('variant').isEmpty ? 'Version ${i + 1}' : v.s('variant'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: i == _variant ? FontWeight.w600 : FontWeight.w400,
                          color: t.text,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          spacing: 6,
          children: [
            Icon(AppIcons.sparkle, size: 14, color: t.textMuted),
            Expanded(
              child: Text(
                tpl == null
                    ? 'No template for this type - pick another type above'
                    : 'Tap a dashed slot to fill it in · ${counts.$1} of ${counts.$2} filled',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ),
          ],
        ),
        if (tpl != null)
          for (var s = 0; s < sections.length; s++)
            _SectionCard(
              index: s,
              section: sections[s],
              open: _open.contains(s),
              onToggle: () => setState(() {
                if (!_open.remove(s)) _open.add(s);
              }),
              spanFor: (g, seg) => _slotSpan(tplId, s, g, seg),
            ),
      ],
    );
  }

  InlineSpan _slotSpan(String tplId, int s, int g, Map<String, dynamic> seg) {
    final t = context.tk;
    if (!seg.containsKey('slot')) return TextSpan(text: seg.s('text'));
    final key = '$tplId|$s|$g';
    final value = _valueOf(tplId, s, g, seg);
    final slot = seg.s('slot');
    final Widget chip = value.isNotEmpty
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCE6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
                color: Color(0xFF151515),
              ),
            ),
          )
        : DashedBox(
            color: wc(t, 0xFFB4C8FF, 0xFF3A4570),
            radius: 8,
            strokeWidth: 1,
            dash: 3,
            gap: 2,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              slot,
              style: TextStyle(fontSize: 14, height: 1.6, color: t.textMuted),
            ),
          );
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: GestureDetector(
          onTap: () => _fill(key, slot, value),
          child: chip,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.index,
    required this.section,
    required this.open,
    required this.onToggle,
    required this.spanFor,
  });

  final int index;
  final Map<String, dynamic> section;
  final bool open;
  final VoidCallback onToggle;
  final InlineSpan Function(int g, Map<String, dynamic> seg) spanFor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final segs = section.l('segments');
    final header = Row(
      spacing: 10,
      children: [
        LetterBadge(
          '${index + 1}',
          size: 28,
          radius: 10,
          fontSize: 13,
          bg: open ? t.primary : t.surfaceAlt2,
          fg: open ? t.onPrimary : t.text,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                section.s('title'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                section.s('subtitle'),
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          ),
        ),
        Icon(
          open ? AppIcons.chevronUp : AppIcons.chevronRight,
          size: 18,
          color: t.textMuted,
        ),
      ],
    );
    return AppCard(
      radius: 20,
      padding: open
          ? const EdgeInsets.all(14)
          : const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: open ? null : onToggle,
      child: open
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: header,
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      for (var g = 0; g < segs.length; g++) spanFor(g, segs[g]),
                    ],
                  ),
                  style: TextStyle(fontSize: 14, height: 2, color: t.text),
                ),
              ],
            )
          : header,
    );
  }
}

class _FillSheet extends StatefulWidget {
  const _FillSheet({required this.slot, required this.initial});

  final String slot;
  final String initial;

  @override
  State<_FillSheet> createState() => _FillSheetState();
}

class _FillSheetState extends State<_FillSheet> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        const SizedBox(height: 8),
        Text(
          'Fill in: ${widget.slot}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        AppTextField(controller: _c, hint: widget.slot),
        PrimaryButton(
          label: 'Done',
          onTap: () => Navigator.of(context).pop(_c.text.trim()),
        ),
      ],
    );
  }
}
