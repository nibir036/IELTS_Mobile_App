import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'filter_sheet.dart';
import 'widgets.dart';

/// F7 · Listening Mini Practice List (search, filters, paging).
class ListeningMiniListScreen extends StatefulWidget {
  const ListeningMiniListScreen({super.key});

  @override
  State<ListeningMiniListScreen> createState() => _ListeningMiniListScreenState();
}

class _ListeningMiniListScreenState extends State<ListeningMiniListScreen> {
  late final Map<String, dynamic> _data = Demo.section('listening').m('miniPractice');
  List<Map<String, dynamic>> get _sets => Content.listeningSets;
  static const _filterKey = 'listening.miniFilter';

  /// Part + status filter (sheet and chips share it), kept in kv.
  ListeningFilter _f = ListeningFilter.fromKv(Store.I.kv<Map>(_filterKey));
  int _page = 0;
  String _query = '';
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    // {'part': n} opens straight on that part (from the module list, Full
    // tests' weak-spot card, or the listening overview).
    final p = context.routeArgs['part'];
    if (p is int && p >= 1 && p <= 4) {
      _f = ListeningFilter(part: p, format: _f.format);
      Store.I.setKv(_filterKey, _f.toJson());
    }
  }

  /// Chip shown as selected for the current filter: All · Not done · Part n.
  int get _chip {
    if (_f.part > 0) return _f.part + 1;
    if (_f.status == 'todo') return 1;
    return 0;
  }

  void _apply(ListeningFilter f) {
    final keep = ListeningFilter(part: f.part, status: f.status, format: f.format);
    setState(() {
      _f = keep;
      _page = 0;
    });
    Store.I.setKv(_filterKey, keep.toJson());
  }

  void _onChip(int i) {
    switch (i) {
      case 0:
        _apply(const ListeningFilter());
      case 1:
        _apply(const ListeningFilter(status: 'todo'));
      default:
        _apply(_f.copyWith(part: i - 1));
    }
  }

  Future<void> _openFilter() async {
    final store = Store.I;
    final picked = await showListeningFilterSheet(
      context,
      initial: _f,
      partLabels: const <String>['All', 'Part 1', 'Part 2', 'Part 3', 'Part 4'],
      countFor: (f) => _filtered(store, f).length,
      showFormats: Content.listeningBankSets.isNotEmpty,
      unit: 'set',
    );
    if (!mounted || picked == null) return;
    _apply(picked);
  }

  /// 'done' | 'inProgress' | 'new' for a set, from the student's data.
  String _status(Store store, Map<String, dynamic> item) {
    if (latestListeningAttempt(store, item.s('id')) != null) return 'done';
    final saved = listeningSaved(store, ListeningSession.miniKey);
    if (saved != null && saved.s('setId') == item.s('id')) return 'inProgress';
    return 'new';
  }

  List<Map<String, dynamic>> _filtered(Store store, ListeningFilter f) {
    final q = _query.trim().toLowerCase();
    return _sets.where((s) {
      if (q.isNotEmpty && !listeningSearchFields(s).any((x) => x.toLowerCase().contains(q))) {
        return false;
      }
      if (f.part > 0 && s.i('part') != f.part) return false;
      if (!f.matchesFormat(s)) return false;
      return f.matchesStatus(_status(store, s) == 'done');
    }).toList();
  }

  void _open(Map<String, dynamic> item) {
    final last = latestListeningAttempt(Store.I, item.s('id'));
    if (last != null) {
      context.push(Routes.listeningResults, args: <String, dynamic>{'attemptId': last.id});
      return;
    }
    context.push(
      Routes.listeningPlayer,
      args: <String, dynamic>{'setId': item.s('id'), 'mode': 'Mini Practice'},
    );
  }

  int _answeredFor(Store store, Map<String, dynamic> item) {
    final saved = listeningSaved(store, ListeningSession.miniKey);
    if (saved == null || saved.s('setId') != item.s('id')) return 0;
    return saved.m('answers').length;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final all = _filtered(store, _f);
    final activeLabels = <String>[
      if (_f.part > 0) 'Part ${_f.part}',
      if (_f.format.isNotEmpty) _f.formatLabel,
      if (_f.status != 'all') _f.statusLabel,
    ];
    final doneCount = ListeningStats.doneSets(store).length;
    final setTotal = _sets.length;
    final pageSize = _data.i('pageSize') <= 0 ? 5 : _data.i('pageSize');
    final pages = all.isEmpty ? 1 : (all.length + pageSize - 1) ~/ pageSize;
    final page = _page >= pages ? pages - 1 : _page;
    final start = page * pageSize;
    final end = start + pageSize > all.length ? all.length : start + pageSize;
    final visible = all.isEmpty ? <Map<String, dynamic>>[] : all.sublist(start, end);
    final showing =
        visible.isEmpty ? 'No sets found' : 'Showing ${start + 1}–$end of ${all.length}';

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      footer: Row(
        children: [
          IconBox(
            icon: AppIcons.chevronLeft,
            tooltip: 'Previous page',
            size: 48,
            radius: 16,
            iconSize: 22,
            onTap: page > 0 ? () => setState(() => _page = page - 1) : null,
          ),
          Expanded(
            child: Text(
              showing,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ),
          IconBox(
            icon: AppIcons.chevronRight,
            tooltip: 'Next page',
            size: 48,
            radius: 16,
            iconSize: 22,
            onTap: page < pages - 1 ? () => setState(() => _page = page + 1) : null,
          ),
        ],
      ),
      children: [
        ListeningHeader(
          title: 'Mini Practice',
          subtitle: 'Listening · $setTotal ${setTotal == 1 ? 'set' : 'sets'}',
          onLeading: () => context.back(),
          trailingIcon: AppIcons.filter,
          trailingTooltip: 'Filter',
          onTrailing: _openFilter,
          trailingDot: activeLabels.isNotEmpty,
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            spacing: 10,
            children: [
              Icon(AppIcons.search, size: 20, color: t.textMuted),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() {
                    _query = v;
                    _page = 0;
                  }),
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 15, color: t.text),
                  cursorColor: t.text,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search by topic, format or set code',
                    hintStyle: TextStyle(fontSize: 15, color: t.textMuted),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        OutlineChipRow(
          labels: _data.ls('filters'),
          selected: _chip,
          onChanged: _onChip,
        ),
        if (activeLabels.isNotEmpty)
          ActiveFilterBar(
            labels: activeLabels,
            onEdit: _openFilter,
            onClear: () => _apply(const ListeningFilter()),
          ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activeLabels.isEmpty
                            ? '$doneCount done · ${setTotal - doneCount < 0 ? 0 : setTotal - doneCount} to go'
                            : '${all.length} of $setTotal sets match',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    Text(
                      _data.s('sort'),
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              if (visible.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.divider)),
                  ),
                  child: Text(
                    activeLabels.isEmpty ? 'No sets match your search' : 'No sets match your filters',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ),
              for (final s in visible)
                _SetRow(
                  item: s,
                  status: _status(store, s),
                  last: latestListeningAttempt(store, s.s('id')),
                  answered: _answeredFor(store, s),
                  onTap: () => _open(s),
                ),
            ],
          ),
        ),
        if (Content.listeningBankMeta.isNotEmpty)
          Center(
            child: LinkText(
              'About this question bank',
              fontSize: 13,
              onTap: () => showListeningBankInfo(context),
            ),
          ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.item,
    required this.status,
    required this.last,
    required this.answered,
    this.onTap,
  });

  final Map<String, dynamic> item;
  final String status;
  final Attempt? last;
  final int answered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final a = last;
    Widget trailing;
    if (a != null) {
      trailing = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${a.score ?? 0}/${a.total ?? Content.setQuestionCount(item)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          Text('Done', style: TextStyle(fontSize: 11, color: t.textMuted)),
        ],
      );
    } else if (status == 'inProgress') {
      trailing = Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$answered / ${Content.setQuestionCount(item)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.onPrimary),
        ),
      );
    } else {
      trailing = Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.border),
        ),
        child: Text('Start', style: TextStyle(fontSize: 12, color: t.textMuted)),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.divider)),
        ),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: t.surfaceAlt2,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(listeningBadge(item).$1, style: TextStyle(fontSize: 10, height: 1, color: t.textMuted)),
                  Text(
                    listeningBadge(item).$2,
                    style: const TextStyle(fontSize: 15, height: 1.1, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.s('title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    isBankSet(item)
                        ? '${listeningSetMeta(item)} · ${Content.setQuestionCount(item)} questions'
                        : 'Part ${item.i('part')} · ${Content.setQuestionCount(item)} questions · ${timeLabel(item.d('durationSeconds'), pad: false)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
