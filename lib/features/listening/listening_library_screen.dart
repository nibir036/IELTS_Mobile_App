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

/// F1 · Listening Test Library: the full tests (filter 0) and the part sets
/// of the bank (filters Part 1–4).
class ListeningLibraryScreen extends StatefulWidget {
  const ListeningLibraryScreen({super.key});

  @override
  State<ListeningLibraryScreen> createState() => _ListeningLibraryScreenState();
}

class _ListeningLibraryScreenState extends State<ListeningLibraryScreen> {
  static const _filterKey = 'listening.libraryFilter';

  /// Part shown (0 = full tests, 1–4 = part sets) — the chips and the
  /// filter sheet's Part. Status and topic search come from [_f].
  int _filter = 0;
  ListeningFilter _f = const ListeningFilter();
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    // Full tests only: single-part sets live in Part practice (mini list).
    _f = ListeningFilter.fromKv(Store.I.kv<Map>(_filterKey)).copyWith(part: 0);
    _filter = 0;
    final f = context.routeArgs['filter'];
    if (f is int && f >= 1 && f <= 4) {
      // Old links to a part tab: open that part in Part practice instead.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.replace(Routes.listeningMiniList, args: <String, dynamic>{'part': f});
      });
    }
  }

  /// Applies and remembers a filter (kv `listening.libraryFilter`).
  void _apply(ListeningFilter f) {
    f = f.copyWith(part: 0);
    setState(() {
      _f = f;
      _filter = 0;
    });
    Store.I.setKv(_filterKey, f.toJson());
  }

  /// Search text for a row: a test matches on any of its parts' topics.
  List<String> _fields(Map<String, dynamic> r, bool isTest) {
    if (!isTest) return listeningSearchFields(r);
    return <String>[
      r.s('title'),
      for (final e in Content.listeningTestSets(r.s('id'))) ...<String>[
        e.$1.s('title'),
        e.$1.s('context'),
      ],
    ];
  }

  /// Tests (part 0) or part sets that pass [f].
  List<Map<String, dynamic>> _rowsFor(Store store, ListeningFilter f) {
    final isTest = f.part == 0;
    final base = isTest
        ? Content.listeningTests
        : Content.listeningSets.where((x) => x.i('part') == f.part).toList();
    return base
        .where((r) =>
            (isTest || f.matchesFormat(r)) &&
            f.matchesStatus(latestListeningAttempt(store, r.s('id')) != null) &&
            f.matchesQuery(_fields(r, isTest)))
        .toList();
  }

  List<String> get _partLabels => const <String>['Full tests'];

  Future<void> _openFilter() async {
    final store = Store.I;
    final picked = await showListeningFilterSheet(
      context,
      initial: _f.copyWith(part: _filter),
      partLabels: _partLabels,
      countFor: (f) => _rowsFor(store, f).length,
      showSearch: true,
      unit: 'test',
    );
    if (!mounted || picked == null) return;
    _apply(picked);
  }

  void _openTest(Map<String, dynamic> test) {
    final last = latestListeningAttempt(Store.I, test.s('id'));
    if (last != null) {
      context.push(Routes.listeningResults, args: <String, dynamic>{'attemptId': last.id});
      return;
    }
    context.push(Routes.listeningAnswerSheet, args: <String, dynamic>{'testId': test.s('id')});
  }

  void _openSet(Map<String, dynamic> set) {
    final last = latestListeningAttempt(Store.I, set.s('id'));
    if (last != null) {
      context.push(Routes.listeningResults, args: <String, dynamic>{'attemptId': last.id});
      return;
    }
    context.push(
      Routes.listeningPlayer,
      args: <String, dynamic>{'setId': set.s('id'), 'mode': 'Part Practice'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final tests = Content.listeningTests;
    final shown = _rowsFor(store, _f.copyWith(part: _filter));
    final testsShown = _filter == 0 ? shown : <Map<String, dynamic>>[];
    final sets = _filter == 0 ? <Map<String, dynamic>>[] : shown;
    final rows = shown;
    final activeLabels = <String>[
      if (_f.format.isNotEmpty && _filter > 0) _f.formatLabel,
      if (_f.status != 'all') _f.statusLabel,
      if (_f.query.trim().isNotEmpty) '“${_f.query.trim()}”',
    ];

    // Per-row status for the current filter.
    final saved = listeningSaved(store, ListeningSession.sheetKey);
    final savedTest = saved == null ? '' : saved.s('testId');
    final savedSet = saved == null ? '' : saved.s('setId');
    final mini = listeningSaved(store, ListeningSession.miniKey);
    final miniSet = mini == null ? '' : mini.s('setId');
    final status = <String, String>{};
    final bands = <double>[];
    String nextId = '';
    for (final r in rows) {
      final id = r.s('id');
      final last = latestListeningAttempt(store, id);
      if (last != null) {
        status[id] = 'done';
        if (last.band != null) bands.add(last.band!);
      } else if (id == savedTest || id == savedSet || id == miniSet) {
        status[id] = 'next';
        if (nextId.isEmpty) nextId = id;
      }
    }
    if (nextId.isEmpty) {
      for (final r in rows) {
        if (!status.containsKey(r.s('id'))) {
          nextId = r.s('id');
          status[nextId] = 'next';
          break;
        }
      }
    }
    for (final r in rows) {
      status.putIfAbsent(r.s('id'), () => 'notStarted');
    }
    final done = bands.length;
    final avg = bands.isEmpty
        ? null
        : Store.roundBand(bands.reduce((a, b) => a + b) / bands.length);

    // Continue / up-next card (full tests on the answer sheet).
    final savedSets = saved == null
        ? <(Map<String, dynamic>, int)>[]
        : listeningSetsFor(testId: savedTest, setId: savedSet);
    final hasSaved = savedSets.isNotEmpty;
    Map<String, dynamic> nextTest = <String, dynamic>{};
    for (final test in tests) {
      if (nextTest.isEmpty && latestListeningAttempt(store, test.s('id')) == null) nextTest = test;
    }
    var totalQ = 0;
    for (final e in savedSets) {
      totalQ += Content.setQuestionCount(e.$1);
    }
    final answeredCount = saved == null ? 0 : saved.m('answers').length;
    final savedPart = saved == null ? 0 : saved.i('part');
    final savedTitle = saved == null ? '' : saved.s('title');
    final contLabel = hasSaved
        ? (savedSets.length > 1
            ? 'Continue · Part ${savedPart + 1} of ${savedSets.length}'
            : 'Continue · Part ${savedSets.first.$1.i('part')}')
        : (nextTest.isEmpty ? 'All tests done' : 'Up next');
    final contTitle = hasSaved
        ? savedTitle
        : (nextTest.isEmpty ? 'Full Listening Tests' : nextTest.s('title'));
    final contProgress = hasSaved && totalQ > 0 ? (answeredCount / totalQ).clamp(0.0, 1.0).toDouble() : 0.0;
    void openContinue() {
      if (hasSaved) {
        context.push(
          Routes.listeningAnswerSheet,
          args: <String, dynamic>{
            if (savedTest.isNotEmpty) 'testId': savedTest else 'setId': savedSet,
          },
        );
      } else if (nextTest.isNotEmpty) {
        context.push(Routes.listeningAnswerSheet, args: <String, dynamic>{'testId': nextTest.s('id')});
      } else {
        context.push(Routes.listeningMiniList);
      }
    }

    // Weak spot.
    final weakPart = ListeningStats.weakestPart(store);
    String weakTitle = 'Find your weak spot';
    String weakSub = 'Finish a few sets to see your weakest part';
    if (weakPart != null) {
      final totals = ListeningStats.partTotals(store)[weakPart];
      final avgTen = totals == null || totals.$2 == 0 ? 0 : (totals.$1 * 10 / totals.$2).round();
      final ready = Content.listeningSets
          .where((e) => e.i('part') == weakPart && latestListeningAttempt(store, e.s('id')) == null)
          .length;
      weakTitle = 'Weak spot: Part $weakPart';
      weakSub = '$avgTen/10 on average · $ready ${ready == 1 ? 'set' : 'sets'} ready';
    }

    final heading = _filter == 0
        ? '${testsShown.length} full ${testsShown.length == 1 ? 'test' : 'tests'}'
        : '${sets.length} Part $_filter ${sets.length == 1 ? 'set' : 'sets'}';

    return AppScreen(
      gap: 16,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        ListeningHeader(
          title: 'Full tests',
          titleSize: 16,
          onLeading: () => context.back(),
          trailingIcon: AppIcons.filter,
          trailingTooltip: 'Filter',
          onTrailing: _openFilter,
          trailingDot: activeLabels.isNotEmpty,
        ),
        HeroCard(
          radius: 32,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          onTap: openContinue,
          child: Row(
            spacing: 14,
            children: [
              DarkPlayButton(
                playing: false,
                size: 60,
                radius: 22,
                iconSize: 28,
                onTap: openContinue,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contLabel,
                      style: TextStyle(fontSize: 12, color: t.heroMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, color: t.heroText),
                    ),
                    const SizedBox(height: 10),
                    ProgressBar(value: contProgress, onHero: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (activeLabels.isNotEmpty)
          ActiveFilterBar(
            labels: activeLabels,
            onEdit: _openFilter,
            onClear: () => _apply(ListeningFilter(part: _filter)),
          ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      heading,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    done == 0 ? 'None done yet' : '$done done · avg ${Store.formatBand(avg)}',
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ],
              ),
              if (rows.isEmpty)
                Text(
                  activeLabels.isNotEmpty
                      ? 'Nothing matches your filters'
                      : (_filter == 0 ? 'No tests yet' : 'No sets for this part yet'),
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              Column(
                spacing: 8,
                children: [
                  if (_filter == 0)
                    for (final test in testsShown)
                      _BankRow(
                        badge: test.i('number').toString().padLeft(2, '0'),
                        title: test.s('title'),
                        subtitle:
                            '${Content.listeningTestSets(test.s('id')).length} parts · ${listeningTestQuestions(test.s('id'))} questions · ${approxMinutes(listeningTestSeconds(test.s('id')))} audio',
                        status: status[test.s('id')] ?? 'notStarted',
                        last: latestListeningAttempt(store, test.s('id')),
                        onTap: () => _openTest(test),
                      ),
                  if (_filter != 0)
                    for (final set in sets)
                      _BankRow(
                        badge: listeningBadge(set).$2,
                        title: set.s('title'),
                        subtitle: isBankSet(set)
                            ? '${listeningSetMeta(set)}\n${set.s('context')}'
                            : '${set.s('context')}\n${Content.setQuestionCount(set)} questions · ${timeLabel(set.d('durationSeconds'), pad: false)}',
                        status: status[set.s('id')] ?? 'notStarted',
                        last: latestListeningAttempt(store, set.s('id')),
                        onTap: () => _openSet(set),
                      ),
                ],
              ),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Legend(status: 'done', label: 'Done'),
                  _Legend(status: 'next', label: 'Next up'),
                  _Legend(status: 'notStarted', label: 'Not started'),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () {
            context.push(
              Routes.listeningMiniList,
              args: <String, dynamic>{if (weakPart != null) 'part': weakPart},
            );
          },
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(AppIcons.target, size: 20, color: t.alert),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(weakTitle, style: const TextStyle(fontSize: 14)),
                    Text(
                      weakSub,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tile colours by status: (background, foreground, border).
(Color, Color, Color?) _tileColors(AppTokens t, String status) {
  switch (status) {
    case 'done':
      return (t.primary, t.onPrimary, null);
    case 'next':
      if (t.isNight) return (t.text, t.onPrimary, null);
      return (t.surface, t.text, t.text);
    default:
      return (
        t.isNight ? const Color(0xFF222222) : t.surfaceAlt,
        t.textMuted,
        null,
      );
  }
}

/// A test or set row: status-coloured number tile, title, details, result.
class _BankRow extends StatelessWidget {
  const _BankRow({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.status,
    this.last,
    this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String status;
  final Attempt? last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final (bg, fg, border) = _tileColors(t, status);
    final a = last;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: border == null ? null : Border.all(color: border, width: 1.5),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 15,
                fontWeight: status == 'next'
                    ? FontWeight.w600
                    : (status == 'done' ? FontWeight.w500 : FontWeight.w400),
                color: fg,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.35, color: t.textMuted),
                ),
              ],
            ),
          ),
          if (a != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Band ${Store.formatBand(a.band)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${a.score ?? 0}/${a.total ?? 0} · ${Store.shortDate(a.createdAt)}',
                  style: TextStyle(fontSize: 11, color: t.textMuted),
                ),
              ],
            )
          else
            Text(
              status == 'next' ? 'Up next' : 'Not started',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final (bg, _, border) = _tileColors(t, status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
            border: border == null ? null : Border.all(color: border, width: 1.5),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
      ],
    );
  }
}
