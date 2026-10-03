import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'bank.dart';

/// Filters for the listening lists (F1 library, F7 mini practice), stored in
/// kv as {part, status, query, format}. part 0 = all parts; status 'all' |
/// 'todo' (not started) | 'done'; format '' = all, else a question-bank
/// format code (FN, MC, MA, PM, SC, TC, SM, SA).
class ListeningFilter {
  const ListeningFilter({this.part = 0, this.status = 'all', this.query = '', this.format = ''});

  factory ListeningFilter.fromKv(Object? v) {
    if (v is! Map) return const ListeningFilter();
    final p = v['part'];
    final s = v['status'];
    final q = v['query'];
    final f = v['format'];
    return ListeningFilter(
      part: p is int && p >= 0 && p <= 4 ? p : 0,
      status: s is String && statusIds.contains(s) ? s : 'all',
      query: q is String ? q : '',
      format: f is String && kListeningFormats.any((e) => e.$1 == f) ? f : '',
    );
  }

  static const statusIds = <String>['all', 'todo', 'done'];
  static const statusLabels = <String>['All', 'Not started', 'Done'];

  final int part;
  final String status;
  final String query;
  final String format;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'part': part,
        'status': status,
        'query': query,
        'format': format,
      };

  ListeningFilter copyWith({int? part, String? status, String? query, String? format}) => ListeningFilter(
        part: part ?? this.part,
        status: status ?? this.status,
        query: query ?? this.query,
        format: format ?? this.format,
      );

  /// "Table completion" (empty when no format is picked).
  String get formatLabel => format.isEmpty ? '' : listeningFormatLabel(format);

  /// Demo sets have no format code: they only match "all formats".
  bool matchesFormat(Map<String, dynamic> set) => format.isEmpty || set.s('formatCode') == format;

  String get statusLabel => statusLabels[statusIds.indexOf(status).clamp(0, 2).toInt()];

  bool matchesStatus(bool done) {
    switch (status) {
      case 'todo':
        return !done;
      case 'done':
        return done;
      default:
        return true;
    }
  }

  /// Case-insensitive match against any of [fields].
  bool matchesQuery(List<String> fields) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fields.any((f) => f.toLowerCase().contains(q));
  }
}

/// Filter sheet: Part chips, Status chips, optional question-format chips,
/// optional topic search, a live result count on the apply button and
/// "Clear". Returns the new filter.
Future<ListeningFilter?> showListeningFilterSheet(
  BuildContext context, {
  required ListeningFilter initial,
  /// Part choices; one label (or none) hides the Part section.
  required List<String> partLabels,
  required int Function(ListeningFilter f) countFor,
  bool showSearch = false,
  bool showFormats = false,
  String unit = 'result',
}) {
  return showAppSheet<ListeningFilter>(
    context,
    _FilterSheet(
      initial: initial,
      partLabels: partLabels,
      countFor: countFor,
      showSearch: showSearch,
      showFormats: showFormats,
      unit: unit,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.partLabels,
    required this.countFor,
    required this.showSearch,
    required this.showFormats,
    required this.unit,
  });

  final ListeningFilter initial;
  final List<String> partLabels;
  final int Function(ListeningFilter f) countFor;
  final bool showSearch;
  final bool showFormats;
  final String unit;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListeningFilter _f = widget.initial;

  Widget _label(String text) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: TextStyle(fontSize: 13, color: t.textMuted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final n = widget.countFor(_f);
    final unit = n == 1 ? widget.unit : '${widget.unit}s';
    final statusIndex = ListeningFilter.statusIds.indexOf(_f.status);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const SizedBox(height: 4),
        Row(
          spacing: 8,
          children: [
            Icon(AppIcons.filter, size: 18, color: t.iconAccent),
            const Expanded(
              child: Text(
                'Filter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '$n $unit',
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ],
        ),
        if (widget.partLabels.length > 1) ...[
          _label('Part'),
          ChipRow(
            labels: widget.partLabels,
            selected: _f.part.clamp(0, widget.partLabels.length - 1).toInt(),
            onChanged: (i) => setState(() => _f = _f.copyWith(part: i)),
          ),
        ],
        _label('Status'),
        ChipRow(
          labels: ListeningFilter.statusLabels,
          selected: statusIndex < 0 ? 0 : statusIndex,
          onChanged: (i) => setState(
            () => _f = _f.copyWith(status: ListeningFilter.statusIds[i]),
          ),
        ),
        if (widget.showFormats) ...[
          _label('Question format'),
          ChipRow(
            labels: <String>['All', for (final f in kListeningFormats) f.$2],
            selected: _f.format.isEmpty
                ? 0
                : 1 + kListeningFormats.indexWhere((f) => f.$1 == _f.format),
            onChanged: (i) => setState(
              () => _f = _f.copyWith(format: i == 0 ? '' : kListeningFormats[i - 1].$1),
            ),
          ),
        ],
        if (widget.showSearch) ...[
          _label('Topic or context'),
          AppTextField(
            hint: 'e.g. museum, lecture, enrolment',
            initialValue: _f.query,
            prefixIcon: AppIcons.search,
            height: 52,
            onChanged: (v) => setState(() => _f = _f.copyWith(query: v)),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: SoftButton(
                label: 'Clear',
                leading: AppIcons.close,
                height: 52,
                radius: 18,
                expand: true,
                onTap: () => Navigator.of(context).pop(const ListeningFilter()),
              ),
            ),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Show $n $unit',
                height: 52,
                radius: 18,
                fontSize: 14,
                onTap: () => Navigator.of(context).pop(_f),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small "N filters on · Clear" line shown above a filtered list.
class ActiveFilterBar extends StatelessWidget {
  const ActiveFilterBar({
    super.key,
    required this.labels,
    required this.onClear,
    this.onEdit,
  });

  final List<String> labels;
  final VoidCallback onClear;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(999),
                  child: Tag(
                    '${labels.length} ${labels.length == 1 ? 'filter' : 'filters'}',
                    tone: TagTone.primary,
                    icon: AppIcons.filter,
                  ),
                ),
                for (final l in labels) Tag(l, tone: TagTone.outline),
              ],
            ),
          ),
        ),
        LinkText('Clear', onTap: onClear, fontSize: 13),
      ],
    );
  }
}
