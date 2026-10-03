import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../resources/word_sheet.dart';
import '../speaking/bank.dart' show showSpeakingWord;
import 'search_index.dart';
import 'widgets.dart';

/// B8 · Search (live filtering over the demo search index).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Map<String, dynamic> _data =
      Demo.section('home').m('search');
  final TextEditingController _controller = TextEditingController();
  String _filter = 'all';

  static const String _recentKey = 'search.recent';

  List<String> _recent(Store store) {
    final v = store.kv<List>(_recentKey);
    if (v == null) return <String>[];
    return v.map((e) => '$e').toList();
  }

  static const int _maxResults = 30;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _matches(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return <Map<String, dynamic>>[];
    bool hit(String hay) {
      final h = hay.toLowerCase();
      return words.every(h.contains);
    }

    // The student's own work (essays, recordings, tests) first.
    final own = <Map<String, dynamic>>[];
    for (final a in Store.I.attempts) {
      if (a.kind == 'session') continue;
      final type = switch (a.skill) {
        Skill.writing => 'Essay',
        Skill.speaking => 'Recording',
        Skill.mock => 'Mock',
        _ => 'Result',
      };
      const category = 'mine';
      if (!hit('${a.title} ${Skill.label(a.skill)} $type ${a.kind}')) continue;
      own.add(<String, dynamic>{
        'id': a.id,
        'type': type,
        'category': category,
        'title': a.title,
        'subtitle': <String>[
          'Your ${Skill.label(a.skill).toLowerCase()}',
          if (a.band != null) 'Band ${Store.formatBand(a.band)}',
          Store.shortDate(a.createdAt),
        ].join(' · '),
        'attemptId': a.id,
      });
    }
    return <Map<String, dynamic>>[...own, ...SearchIndex.search(query)];
  }

  void _setQuery(String q) {
    _controller.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    setState(() {});
  }

  void _remember(String q) {
    final v = q.trim();
    if (v.isEmpty) return;
    final list = _recent(Store.I)
      ..remove(v)
      ..insert(0, v);
    if (list.length > 6) list.removeRange(6, list.length);
    Store.I.setKv(_recentKey, list);
  }

  void _openResult(Map<String, dynamic> r) {
    final att = Store.I.attemptById(r.s('attemptId'));
    if (att != null) {
      openAttempt(context, att);
    } else if (r.s('resWord').isNotEmpty) {
      showResWord(context, r.s('resWord'));
    } else if (r.s('word').isNotEmpty) {
      showSpeakingWord(context, r.s('word'));
    } else if (r.s('route').isNotEmpty) {
      context.push(r.s('route'), args: r.m('args'));
    } else {
      openHomeTarget(context, r.s('target'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final recent = _recent(context.store);
    final query = _controller.text;
    final all = _matches(query);
    final filters = _data.l('filters');
    final inFilter = _filter == 'all' ? all : all.where((x) => x.s('category') == _filter).toList();
    final shown = inFilter.take(_maxResults).toList();

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      gap: 12,
      children: [
        // Back + search field
        Row(
          spacing: 8,
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              bg: t.isNight ? t.surface : t.raised,
              onTap: () => context.back(),
            ),
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.isNight ? t.surface : t.raised,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.text, width: 1.5),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(AppIcons.search, size: 20, color: t.text),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: _remember,
                        style: TextStyle(fontSize: 15, color: t.text),
                        cursorColor: t.text,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search tests, lessons, words, essays',
                          hintStyle:
                              TextStyle(fontSize: 15, color: t.textFaint),
                        ),
                      ),
                    ),
                    if (query.isNotEmpty)
                      InkWell(
                        onTap: () => _setQuery(''),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            AppIcons.close,
                            size: 20,
                            color: t.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Category chips with live counts
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (final f in filters)
                _CountChip(
                  label:
                      '${f.s('label')} · ${f.s('id') == 'all' ? all.length : all.where((x) => x.s('category') == f.s('id')).length}',
                  selected: _filter == f.s('id'),
                  onTap: () => setState(() => _filter = f.s('id')),
                ),
            ],
          ),
        ),

        // Results
        if (query.trim().isNotEmpty)
          AppCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          inFilter.length > shown.length
                              ? 'Top ${shown.length} of ${inFilter.length} · add a word to narrow down'
                              : 'Top results',
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ),
                      Text(
                        'Relevance',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                if (shown.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _divider(t))),
                    ),
                    child: Text(
                      'No results for “${query.trim()}”',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: t.textMuted),
                    ),
                  ),
                for (final r in shown)
                  _ResultRow(
                    item: r,
                    query: query.trim(),
                    onTap: () {
                      _remember(query);
                      _openResult(r);
                    },
                  ),
              ],
            ),
          ),

        // Recent searches
        if (recent.isNotEmpty)
          AppCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recent searches',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    InkWell(
                      onTap: () => Store.I.setKv(_recentKey, null),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.text,
                          decoration: TextDecoration.underline,
                          decorationColor: t.text,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in recent)
                      Material(
                        color: t.surfaceAlt2,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _setQuery(r),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 6,
                              children: [
                                Icon(AppIcons.clock, size: 14, color: t.text),
                                Flexible(
                                  child: Text(
                                    r,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Color _divider(AppTokens t) =>
    t.isNight ? t.border : const Color(0xFFF1E8ED);

class _CountChip extends StatelessWidget {
  const _CountChip({
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
    return Material(
      color: selected ? t.primary : t.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
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

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.query,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final String query;
  final VoidCallback onTap;

  (Color, Color) _badgeColors(AppTokens t) {
    switch (item.s('type')) {
      case 'Drill':
        return (kPastelPink, kInk);
      case 'Vocab':
        return (const Color(0xFFF7C6D6), kInk);
      case 'Essay':
      case 'Recording':
      case 'Mock':
      case 'Result':
        return t.isNight
            ? (t.surfaceAlt2, t.text)
            : (const Color(0xFFEEEFFD), kInk);
      default:
        return (kPastelLavender, kInk);
    }
  }

  List<InlineSpan> _highlight(String title, AppTokens t) {
    final lower = title.toLowerCase();
    final q = query.toLowerCase();
    final at = q.isEmpty ? -1 : lower.indexOf(q);
    if (at < 0) return <InlineSpan>[TextSpan(text: title)];
    return <InlineSpan>[
      if (at > 0) TextSpan(text: title.substring(0, at)),
      TextSpan(
        text: title.substring(at, at + q.length),
        style: const TextStyle(
          backgroundColor: kPastelPink,
          color: kInk,
        ),
      ),
      if (at + q.length < title.length)
        TextSpan(text: title.substring(at + q.length)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final colors = _badgeColors(t);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _divider(t))),
        ),
        child: Row(
          spacing: 12,
          children: [
            Container(
              height: 26,
              constraints: const BoxConstraints(minWidth: 58),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.$1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.s('type'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.$2,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.text,
                      ),
                      children: _highlight(item.s('title'), t),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item.s('subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}
