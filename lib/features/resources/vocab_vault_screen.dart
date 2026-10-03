import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../../app/widgets/speak_button.dart';
import 'quiz_rounds.dart';
import 'widgets.dart';
import 'word_sheet.dart';

/// H2 · Grammar & Vocab Vault.
class VocabVaultScreen extends StatefulWidget {
  const VocabVaultScreen({super.key});

  @override
  State<VocabVaultScreen> createState() => _VocabVaultScreenState();
}

class _VocabVaultScreenState extends State<VocabVaultScreen> {
  late final Map<String, dynamic> _vault =
      Demo.section('resources').m('vault');
  late final Map<String, dynamic> _wod =
      ResBank.wordOfTheDay(Demo.section('resources').m('hub').m('wordOfTheDay'));

  /// With the Resources bank the vault browses all of it (IELTS vocabulary,
  /// phrasal verbs, idioms, linking and academic words); else the demo words.
  bool get _bank => ResBank.has;

  static const List<(String, String)> _bankCats = <(String, String)>[
    ('band7', 'Band 7+ words'),
    ('words', 'All IELTS words'),
    ('phrasal', 'Phrasal verbs'),
    ('idioms', 'Idioms'),
    ('linking', 'Linking words'),
    ('academic', 'Academic words'),
    ('topic', 'Topic vocabulary'),
  ];

  List<String> get _cats => _bank ? <String>[for (final c in _bankCats) c.$2] : _vault.ls('categories');

  /// The bank, plus the curated vault words it does not have (e.g. "burgeoning").
  late final List<Map<String, dynamic>> _words = _bank
      ? () {
          final have = <String>{for (final w in ResBank.allWords) w.s('word').toLowerCase()};
          return <Map<String, dynamic>>[
            ...ResBank.allWords,
            for (final w in _vault.l('words'))
              if (!have.contains(w.s('word').toLowerCase()))
                <String, dynamic>{...w, 'category': w.s('category') == 'Band 7+ words' ? 'words' : 'other', 'kind': 'vocab'},
          ];
        }()
      : _vault.l('words');

  late final List<String> _alphabet = _bank
      ? (<String>{
          for (final w in _words)
            if (w.s('word').isNotEmpty && RegExp('[A-Za-z]').hasMatch(w.s('word')[0])) w.s('word')[0].toUpperCase()
        }.toList()
        ..sort())
      : _vault.ls('alphabet');

  /// Main word type: "noun / verb" → "noun".
  static String _type(Map<String, dynamic> w) => w.s('partOfSpeech').split('/').first.trim();

  static const int _page = 40;
  int _limit = _page;

  int _category = 0; // -1 = none
  String _letter = 'A'; // '' = all letters
  String _query = '';
  bool _savedOnly = false;

  // Filters sheet (persisted in kv [_filterKey]).
  static const String _filterKey = 'vault.filter';
  Set<String> _types = <String>{}; // partOfSpeech values; empty = all
  int _minBand = 0; // 0 = any
  String _sort = 'az'; // 'az' | 'recent'

  @override
  void initState() {
    super.initState();
    final f = Store.I.kv<Map>(_filterKey);
    if (f == null) return;
    final m = f.cast<String, dynamic>();
    final cats = _cats;
    final cat = m.s('category');
    _category = m.containsKey('category') ? cats.indexOf(cat) : 0;
    _types = m.ls('types').toSet();
    _minBand = m.i('minBand');
    _savedOnly = m.b('savedOnly');
    _sort = m.s('sort') == 'recent' ? 'recent' : 'az';
  }

  void _saveFilter() {
    final cats = _cats;
    Store.I.setKv(_filterKey, <String, dynamic>{
      'types': _types.toList(),
      'category': _category >= 0 && _category < cats.length ? cats[_category] : '',
      'minBand': _minBand,
      'savedOnly': _savedOnly,
      'sort': _sort,
    });
  }

  /// Number of active sheet filters (shown on the Filters button).
  int get _activeFilters =>
      (_types.isNotEmpty ? 1 : 0) +
      (_minBand > 0 ? 1 : 0) +
      (_savedOnly ? 1 : 0) +
      (_sort != 'az' ? 1 : 0);

  /// Word types (part of speech) the vault words actually have.
  List<String> get _allTypes {
    final out = <String>[];
    for (final w in _words) {
      final p = _type(w);
      if (p.isNotEmpty && !out.contains(p)) out.add(p);
    }
    out.sort();
    return out;
  }

  /// A–Z, or "recently added": most recently saved first, then the rest
  /// newest content first.
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final out = List<Map<String, dynamic>>.of(list);
    if (_sort == 'recent') {
      final saved = Store.I.kvSet(ResKeys.savedWords).toList();
      final order = <String, int>{};
      for (var i = 0; i < list.length; i++) {
        order[list[i].s('id')] = i;
      }
      int rank(Map<String, dynamic> w) {
        final si = saved.indexOf(w.s('id'));
        if (si >= 0) return 1000000 + si;
        return order[w.s('id')] ?? 0;
      }
      out.sort((a, b) => rank(b).compareTo(rank(a)));
    } else {
      out.sort((a, b) => a.s('word').toLowerCase().compareTo(b.s('word').toLowerCase()));
    }
    return out;
  }

  List<Map<String, dynamic>> get _visible {
    final cats = _cats;
    final q = _query.trim().toLowerCase();
    final list = _words.where((w) {
      if (_types.isNotEmpty && !_types.contains(_type(w))) return false;
      if (_minBand > 0 && w.d('band') < _minBand) return false;
      final word = w.s('word');
      if (q.isNotEmpty) {
        return word.toLowerCase().contains(q) ||
            w.s('definition').toLowerCase().contains(q);
      }
      if (_letter.isNotEmpty && !word.toUpperCase().startsWith(_letter)) {
        return false;
      }
      if (_bank) {
        if (_category < 0 || _category >= _bankCats.length) return true;
        final key = _bankCats[_category].$1;
        if (key == 'band7') return w.s('kind') == 'vocab' && w.d('band') >= 7;
        return w.s('category') == key;
      }
      if (_category == 0) return w.i('band') >= 7;
      if (_category > 0 && _category < cats.length) {
        return w.s('category') == cats[_category];
      }
      return true;
    }).toList();
    return _sorted(list);
  }

  /// Known → 'mastered', Learning → 'learning'; tapping the active one resets
  /// the word to 'new'.
  void _setStatus(String id, String value) {
    final current = wordMasteryOf(Store.I, id);
    setWordMastery(id, current == value ? 'new' : value);
  }

  List<Map<String, dynamic>> _savedWords(Store store) {
    final q = _query.trim().toLowerCase();
    final out = <Map<String, dynamic>>[];
    for (final id in store.kvSet(ResKeys.savedWords)) {
      final w = resolveWord(id);
      if (w == null) continue;
      if (_types.isNotEmpty && !_types.contains(_type(w))) continue;
      if (q.isNotEmpty &&
          !w.s('word').toLowerCase().contains(q) &&
          !w.s('definition').toLowerCase().contains(q)) {
        continue;
      }
      out.add(w);
    }
    return _sorted(out);
  }

  Future<void> _openFilters() async {
    final cats = _cats;
    final types = _allTypes;
    var selTypes = Set<String>.of(_types);
    var selCategory = _category;
    var selBand = _minBand;
    var selSaved = _savedOnly;
    var selSort = _sort;
    final applied = await showAppSheet<bool>(
      context,
      StatefulBuilder(
        builder: (ctx, setSheet) {
          final t = ctx.tk;
          Widget label(String text) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(text, style: TextStyle(fontSize: 13, color: t.textMuted)),
              );
          final active = (selTypes.isNotEmpty ? 1 : 0) +
              (selBand > 0 ? 1 : 0) +
              (selSaved ? 1 : 0) +
              (selSort != 'az' ? 1 : 0);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Filter words',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ),
                label('Word type'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ty in types)
                      ChipPill(
                        label: ty,
                        selected: selTypes.contains(ty),
                        onTap: () => setSheet(() {
                          if (!selTypes.remove(ty)) selTypes.add(ty);
                        }),
                      ),
                  ],
                ),
                label('Category'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChipPill(
                      label: 'All words',
                      selected: selCategory < 0,
                      onTap: () => setSheet(() => selCategory = -1),
                    ),
                    for (var i = 0; i < cats.length; i++)
                      ChipPill(
                        label: cats[i],
                        selected: selCategory == i,
                        onTap: () => setSheet(() => selCategory = i),
                      ),
                  ],
                ),
                label('Band level'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in const <int>[0, 6, 7, 8])
                      ChipPill(
                        label: b == 0 ? 'Any' : 'Band $b+',
                        selected: selBand == b,
                        onTap: () => setSheet(() => selBand = b),
                      ),
                  ],
                ),
                CheckRow(
                  value: selSaved,
                  label: 'Saved words only',
                  onChanged: (v) => setSheet(() => selSaved = v),
                ),
                label('Sort'),
                SegmentedTabs(
                  labels: const <String>['A–Z', 'Recently added'],
                  index: selSort == 'recent' ? 1 : 0,
                  onChanged: (i) => setSheet(() => selSort = i == 1 ? 'recent' : 'az'),
                ),
                const SizedBox(height: 4),
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: OutlineButtonX(
                        label: 'Clear',
                        height: 52,
                        radius: 18,
                        fontSize: 15,
                        onTap: () => setSheet(() {
                          selTypes = <String>{};
                          selCategory = -1;
                          selBand = 0;
                          selSaved = false;
                          selSort = 'az';
                        }),
                      ),
                    ),
                    Expanded(
                      child: PrimaryButton(
                        label: active > 0 ? 'Apply · $active' : 'Apply',
                        height: 52,
                        radius: 18,
                        fontSize: 15,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (!mounted || applied != true) return;
    setState(() {
      _types = selTypes;
      _category = selCategory;
      _minBand = selBand;
      _savedOnly = selSaved;
      _sort = selSort;
      _letter = ''; // show every match of the new filters
    });
    _saveFilter();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final cats = _cats;
    final letters = _alphabet;
    final words = _visible;
    final mastery = kvStringMap(store, ResKeys.wordMastery);
    final savedCount = store.kvSet(ResKeys.savedWords).length;
    final savedList = _savedOnly ? _savedWords(store) : <Map<String, dynamic>>[];
    final wodSaved = isWordSaved(store, _wod.s('id'));

    return AppScreen(
      gap: 14,
      footer: PrimaryButton(
        label: 'Start quiz · $totalQuizRounds rounds',
        trailing: AppIcons.forward,
        // Compact round picker (title, level, best score) → H5 with quizId.
        onTap: () => showQuizRoundPicker(context),
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              onTap: () => context.back(),
            ),
            Expanded(
              child: Text(
                _savedOnly ? 'Saved words · $savedCount' : 'Vocab Vault',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
            IconBox(
              icon: _savedOnly ? AppIcons.bookmarkFilled : AppIcons.bookmark,
              tooltip: 'Saved words',
              onTap: () {
                setState(() => _savedOnly = !_savedOnly);
                _saveFilter();
              },
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: ResSearchField(
                hint: _savedOnly
                    ? 'Search saved words'
                    : 'Search ${_bank ? _words.length : _vault.s('totalWords')} words',
                height: 50,
                radius: 18,
                onChanged: (v) => setState(() {
                  _query = v;
                  _limit = _page;
                }),
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconBox(
                  icon: AppIcons.filter,
                  tooltip: 'Filters',
                  size: 50,
                  radius: 18,
                  bg: t.primary,
                  fg: t.onPrimary,
                  onTap: _openFilters,
                ),
                if (_activeFilters > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: IgnorePointer(child: CountBadge(_activeFilters)),
                  ),
              ],
            ),
          ],
        ),
        const ContentLangSwitch(module: 'resources'),
        if (_savedOnly) ...[
          if (savedList.isEmpty)
            EmptyState(
              title: savedCount == 0 ? 'No saved words yet' : 'No saved words match',
              message: savedCount == 0
                  ? 'Save words from quizzes, word of the day and lists'
                  : 'Try a different search.',
              icon: AppIcons.bookmark,
              actionLabel: savedCount == 0 ? 'Browse the vault' : null,
              onAction: savedCount == 0
                  ? () {
                      setState(() => _savedOnly = false);
                      _saveFilter();
                    }
                  : null,
            ),
          for (final w in savedList)
            _SavedWordCard(
              data: w,
              status: mastery[w.s('id')] ?? 'new',
              onUnsave: () {
                toggleSavedWord(w.s('id'));
                context.toast('Removed from saved words');
              },
            ),
        ] else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                for (var i = 0; i < cats.length; i++)
                  ResMiniPill(
                    label: cats[i],
                    height: 40,
                    bg: i == _category ? t.primary : (t.isNight ? t.surface : t.raised),
                    fg: i == _category ? t.onPrimary : t.text,
                    onTap: () {
                      setState(() {
                        _category = _category == i ? -1 : i;
                        _limit = _page;
                      });
                      _saveFilter();
                    },
                  ),
              ],
            ),
          ),
          _WordOfDayCard(
            data: _wod,
            saved: wodSaved,
            onSave: () {
              final now = toggleSavedWord(_wod.s('id'));
              context.toast(now ? 'Saved to your words' : 'Removed from saved words');
            },
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              spacing: 2,
              children: [
                for (final l in letters)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _letter = _letter == l ? '' : l;
                      _limit = _page;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: l == _letter ? FontWeight.w600 : FontWeight.w400,
                          color: l == _letter ? t.text : t.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (words.isEmpty)
            AppCard(
              radius: 22,
              child: Text(
                'No words match. Try another letter or filter.',
                style: TextStyle(fontSize: 14, color: t.textMuted),
              ),
            ),
          if (words.isNotEmpty)
            Text(
              '${words.length} ${words.length == 1 ? 'word' : 'words'}${_bank ? ' · tap a word for examples' : ''}',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          for (final w in words.take(_limit))
            _WordCard(
              data: w,
              status: mastery[w.s('id')] ?? 'new',
              onTap: ResBank.word(w.s('id')) == null ? null : () => showResWord(context, w.s('id')),
              onKnown: () => _setStatus(w.s('id'), 'mastered'),
              onLearning: () => _setStatus(w.s('id'), 'learning'),
            ),
          if (words.length > _limit)
            SoftButton(
              label: 'Show more · ${words.length - _limit} left',
              height: 46,
              radius: 16,
              expand: true,
              bg: t.isNight ? t.surface : t.raised,
              onTap: () => setState(() => _limit += _page),
            ),
        ],
      ],
    );
  }
}

class _SavedWordCard extends StatelessWidget {
  const _SavedWordCard({
    required this.data,
    required this.status,
    required this.onUnsave,
  });

  final Map<String, dynamic> data;
  final String status;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final label = switch (status) {
      'mastered' => 'Known',
      'learning' => 'Learning',
      _ => 'New',
    };
    final id = data.s('id');
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      onTap: ResBank.word(id) == null ? null : () => showResWord(context, id),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${data.s('word')} '),
                      TextSpan(
                        text: data.s('partOfSpeech'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                Text(
                  data.s('definition'),
                  style: TextStyle(fontSize: 14, color: t.textMuted),
                ),
                TrMeaning(data.s('id')),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          SpeakButton(
            text: data.s('word'),
            size: 40,
            radius: 14,
            iconSize: 18,
            bg: t.surfaceAlt2,
          ),
          IconBox(
            icon: AppIcons.bookmarkFilled,
            tooltip: 'Remove from saved words',
            size: 40,
            radius: 14,
            iconSize: 18,
            bg: t.surfaceAlt2,
            onTap: onUnsave,
          ),
        ],
      ),
    );
  }
}

class _WordOfDayCard extends StatelessWidget {
  const _WordOfDayCard({
    required this.data,
    required this.saved,
    required this.onSave,
  });

  final Map<String, dynamic> data;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return HeroCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      gradient: t.isNight
          ? null
          : const LinearGradient(
              begin: Alignment(-0.5, -0.87),
              end: Alignment(0.5, 0.87),
              stops: [0, 0.7],
              colors: [Color(0xFFF7C6D6), Color(0xFFFBE7EE)],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.isNight
                          ? ResPalette.ink.withValues(alpha: 0.08)
                          : ResPalette.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Word of the day',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.heroText),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SpeakButton(
                text: data.s('word'),
                size: 40,
                radius: 14,
                iconSize: 18,
                bg: t.isNight ? ResPalette.creamChip : ResPalette.white,
                fg: ResPalette.ink,
              ),
              const SizedBox(width: 6),
              IconBox(
                icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                tooltip: 'Save word',
                size: 40,
                radius: 14,
                iconSize: 18,
                bg: ResPalette.ink,
                fg: ResPalette.white,
                onTap: onSave,
              ),
            ],
          ),
          Text(
            data.s('word'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
              color: t.heroText,
            ),
          ),
          Text(
            '${data.s('partOfSpeech')} · ${data.s('phonetic')}',
            style: TextStyle(fontSize: 13, color: t.heroMuted),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${data.s('definition')} '),
                TextSpan(
                  text: '“${data.s('example')}”',
                  style: TextStyle(color: t.heroMuted),
                ),
              ],
            ),
            style: TextStyle(fontSize: 14, height: 1.4, color: t.heroText),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.data,
    required this.status,
    required this.onKnown,
    required this.onLearning,
    this.onTap,
  });

  final Map<String, dynamic> data;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback onKnown;
  final VoidCallback onLearning;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final offBg = t.isNight ? t.surfaceAlt2 : t.surface;
    final known = status == 'mastered';
    final learning = status == 'learning';
    final band = ResBank.bandLabel(data.d('band'));
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${data.s('word')} '),
                      TextSpan(
                        text: data.s('partOfSpeech'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              SpeakButton(
                text: data.s('word'),
                size: 32,
                radius: 10,
                iconSize: 16,
                bg: t.surfaceAlt2,
              ),
              const SizedBox(width: 8),
              if (band.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ResPalette.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  band,
                  style: const TextStyle(fontSize: 12, color: ResPalette.ink),
                ),
              ),
            ],
          ),
          Text(
            data.s('definition'),
            style: TextStyle(fontSize: 14, color: t.textMuted),
          ),
          TrMeaning(data.s('id')),
          Row(
            spacing: 6,
            children: [
              ResMiniPill(
                label: 'Known',
                bg: known ? t.primary : offBg,
                fg: known ? t.onPrimary : t.text,
                border: known ? null : t.border,
                bold: known,
                onTap: onKnown,
              ),
              ResMiniPill(
                label: 'Learning',
                bg: learning ? ResPalette.pink : offBg,
                fg: learning ? ResPalette.ink : t.text,
                border: learning ? null : t.border,
                bold: learning,
                onTap: onLearning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
