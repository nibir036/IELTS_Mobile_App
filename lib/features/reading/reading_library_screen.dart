import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// One row of the library (a full test or a single passage).
class _LibItem {
  const _LibItem({
    required this.id,
    required this.badge,
    required this.number,
    required this.title,
    required this.meta,
    required this.shortMeta,
  });

  final String id;
  final String badge;
  final int number;
  final String title;

  /// Shown when not attempted yet.
  final String meta;

  /// Prefix kept in front of the date once attempted.
  final String shortMeta;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// E1 · Reading Test Library (Academic).
class ReadingLibraryScreen extends StatefulWidget {
  const ReadingLibraryScreen({super.key});

  @override
  State<ReadingLibraryScreen> createState() => _ReadingLibraryScreenState();
}

class _ReadingLibraryScreenState extends State<ReadingLibraryScreen> {
  int _filter = 0;
  String _type = '';
  bool _ascending = true;
  bool _argsRead = false;

  List<Map<String, dynamic>> get _filters =>
      Demo.section('reading').m('library').l('filters');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final want = context.routeArgs['filter'];
    if (want is String) {
      final filters = _filters;
      for (var i = 0; i < filters.length; i++) {
        if (filters[i].s('id') == want) _filter = i;
      }
    }
    final type = context.routeArgs['type'];
    if (type is String) _type = type;
  }

  void _startTest(String id, {bool fresh = false}) {
    if (fresh) {
      ReadingSession.start(id);
      context.push(Routes.readingPassage);
    } else {
      context.push(Routes.readingPassage, args: readingArgsFor(id));
    }
  }

  void _openItem(_LibItem item) {
    final id = item.id;
    final store = Store.I;
    final last = latestReadingAttempt(store, id);
    final saved = readingInProgress(store);
    if (last == null || (saved != null && saved.s('refId') == id)) {
      _startTest(id);
      return;
    }
    showAppSheet<void>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            const SizedBox(height: 4),
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text(
              'Band ${Store.formatBand(last.band)} · ${Store.shortDate(last.createdAt)} · ${last.score ?? 0}/${last.total ?? 0}',
              style: TextStyle(fontSize: 13, color: ctx.tk.textMuted),
            ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: 'Review solutions',
              onTap: () {
                Navigator.of(ctx).pop();
                context.push(
                  Routes.readingSolution,
                  args: <String, dynamic>{'attemptId': last.id},
                );
              },
            ),
            SoftButton(
              label: ReadingRefs.isTest(id) ? 'Retake test' : 'Practise again',
              expand: true,
              onTap: () {
                Navigator.of(ctx).pop();
                _startTest(id, fresh: true);
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  List<_LibItem> _tests() => <_LibItem>[
        for (final x in Content.readingTests)
          _LibItem(
            id: x.s('id'),
            badge: 'Test',
            number: x.i('number'),
            title: x.s('title'),
            meta: '3 passages · 60 min · ${ReadingRefs.items(x.s('id')).length} questions',
            shortMeta: '${ReadingRefs.items(x.s('id')).length} questions',
          ),
      ];

  _LibItem _passageItem(Map<String, dynamic> p, {String type = ''}) {
    final id = p.s('id');
    final all = ReadingRefs.items(id);
    final n = type.isEmpty ? all.length : all.where((it) => it.type == type).length;
    final label = type.isEmpty
        ? '$n questions'
        : '$n ${ReadingStats.typeLabels[type] ?? type} Q';
    return _LibItem(
      id: id,
      badge: 'Passage',
      number: ReadingRefs.passageNumber(id),
      title: p.s('title'),
      meta: '${p.s('topic')} · ${_cap(p.s('difficulty'))} · $label',
      shortMeta: '${p.s('topic')} · ${_cap(p.s('difficulty'))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final saved = readingInProgress(store);
    final filters = _filters;
    final filterId = filters.isEmpty ? 'full' : filters[_filter].s('id');
    final types = ReadingStats.bankTypes();
    final type = types.contains(_type) ? _type : (types.isEmpty ? '' : types.first);

    List<_LibItem> items;
    String countLine;
    switch (filterId) {
      case 'passage':
        items = <_LibItem>[for (final p in Content.readingPassages) _passageItem(p)];
        countLine = '${items.length} passages · '
            '${ReadingStats.doneIds(store, tests: false).length} done';
      case 'type':
        items = <_LibItem>[
          for (final p in Content.readingPassages)
            if (p.l('groups').any((g) => g.s('type') == type)) _passageItem(p, type: type),
        ];
        final done = ReadingStats.doneIds(store, tests: false);
        countLine = '${items.length} passages with ${ReadingStats.typeLabels[type] ?? type} · '
            '${items.where((e) => done.contains(e.id)).length} done';
      default:
        items = _tests();
        countLine = '${items.length} tests · '
            '${ReadingStats.doneIds(store, tests: true).length} done';
    }
    items.sort((a, b) => _ascending
        ? a.number.compareTo(b.number)
        : b.number.compareTo(a.number));
    final ids = <String>{for (final e in items) e.id};
    var newestDone = '';
    for (final a in store.attemptsFor(skill: Skill.reading)) {
      if (a.kind != 'lesson' && ids.contains(a.refId)) {
        newestDone = a.refId;
        break;
      }
    }

    return AppScreen(
      gap: 12,
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              bg: t.surface,
              onTap: () => context.back(),
            ),
            const Expanded(
              child: Text(
                'Reading',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
            IconBox(
              icon: AppIcons.sort,
              tooltip: 'Sort',
              bg: t.surface,
              onTap: () => setState(() => _ascending = !_ascending),
            ),
          ],
        ),
        Text(
          'Academic · ${Content.readingTests.length} full tests · '
          '${Content.readingPassages.length} passages',
          style: TextStyle(fontSize: 12, color: t.textMuted),
        ),
        if (saved != null)
          _ContinueCard(
            saved: saved,
            onResume: () => _startTest(saved.s('refId')),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (var i = 0; i < filters.length; i++)
                _FilterChip(
                  label: filters[i].s('label'),
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
            ],
          ),
        ),
        if (filterId == 'type')
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                for (final ty in types)
                  ChipPill(
                    label: ReadingStats.typeLabels[ty] ?? ty,
                    selected: ty == type,
                    onTap: () => setState(() => _type = ty),
                  ),
              ],
            ),
          ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        countLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _ascending = !_ascending),
                      child: Text(
                        _ascending ? 'First → last' : 'Last → first',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.divider)),
                  ),
                  child: Text(
                    'Nothing here yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ),
              for (final item in items)
                _TestRow(
                  item: item,
                  last: latestReadingAttempt(store, item.id),
                  inProgress: saved != null && saved.s('refId') == item.id,
                  newest: newestDone == item.id,
                  onTap: () => _openItem(item),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.saved, required this.onResume});

  final Map<String, dynamic> saved;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final muted = t.isNight ? t.heroMuted : const Color(0xFFB5B5B5);
    final done = t.isNight ? t.onPrimary : kRose;
    final todo = t.isNight ? t.heroTrack : const Color(0xFF3A3A3A);
    final refId = saved.s('refId');
    final count = ReadingRefs.parts(refId).length;
    final passage = saved.i('part') + 1;
    final total = ReadingRefs.items(refId).length;
    final answered = saved.m('answers').length;
    final secondsLeft = saved.i('remainingSec');
    final title = ReadingRefs.title(refId);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Continue', style: TextStyle(fontSize: 12, color: muted)),
              ),
              Icon(AppIcons.clock, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(
                '${clockLabel(secondsLeft)} left',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          Text(
            title.isEmpty ? 'Reading test' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 22, letterSpacing: -0.3, color: t.onPrimary),
          ),
          Row(
            spacing: 4,
            children: [
              for (var i = 0; i < (count < 1 ? 1 : count); i++)
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < passage ? done : todo,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Text(
                  count > 1
                      ? 'Passage $passage of $count · $answered/$total answered'
                      : 'Single passage · $answered/$total answered',
                  maxLines: 2,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
              SizedBox(
                height: 40,
                child: Material(
                  color: t.onPrimary,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onResume,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Text(
                          'Resume',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.primary : t.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? t.onPrimary : t.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.item,
    required this.last,
    required this.inProgress,
    required this.newest,
    this.onTap,
  });

  final _LibItem item;
  final Attempt? last;
  final bool inProgress;
  final bool newest;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final a = last;
    final done = a != null;
    final tone = inProgress || !done ? 'pink' : (newest ? 'lavender' : 'neutral');
    final meta = inProgress
        ? item.meta
        : (a != null
            ? '${item.shortMeta} · ${Store.shortDate(a.createdAt)} · '
                '${(a.durationSec / 60).round()} min'
            : item.meta);
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: toneBg(t, tone),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.badge,
                    style: TextStyle(fontSize: 10, height: 1, color: toneMuted(t, tone)),
                  ),
                  Text(
                    '${item.number}',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: toneFg(t, tone),
                    ),
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
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            if (a != null && !inProgress)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Store.formatBand(a.band),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${a.score ?? 0}/${a.total ?? 0}',
                    style: TextStyle(fontSize: 11, color: t.textMuted),
                  ),
                ],
              )
            else
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: inProgress ? t.primary : kPink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  inProgress ? 'In progress' : 'Not started',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: inProgress ? t.onPrimary : kInk,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
