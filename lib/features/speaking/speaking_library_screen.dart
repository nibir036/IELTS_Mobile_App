import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// D11 · Speaking question bank & vocabulary: every Part 1 topic, cue card
/// and Part 3 topic with its sample answers, plus the vocabulary list.
/// Args: `{'tab': 0..3}` (Part 1 · Part 2 · Part 3 · Words).
class SpeakingLibraryScreen extends StatefulWidget {
  const SpeakingLibraryScreen({super.key});

  @override
  State<SpeakingLibraryScreen> createState() => _SpeakingLibraryScreenState();
}

class _SpeakingLibraryScreenState extends State<SpeakingLibraryScreen> {
  static const _tabs = <String>['Part 1', 'Part 2', 'Part 3', 'Words'];
  static const _levels = <String>['All', 'B2', 'C1', 'C2'];

  int _tab = 0;
  int _filter = 0;
  String _query = '';
  bool _inited = false;

  /// One vocabulary key per headword, sorted by headword.
  late final List<String> _wordKeys = () {
    final vocab = Content.speakingVocab;
    final byHead = <String, String>{};
    for (final k in vocab.keys) {
      final head = vocab.m(k).s('headword').toLowerCase();
      byHead.putIfAbsent(head, () => k);
    }
    final heads = byHead.keys.toList()..sort();
    return <String>[for (final h in heads) byHead[h]!];
  }();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final tab = context.routeArgs['tab'];
    if (tab is num && tab >= 0 && tab < _tabs.length) _tab = tab.toInt();
  }

  List<Map<String, dynamic>> _categories() {
    final meta = Content.speakingBankMeta;
    switch (_tab) {
      case 0:
        return meta.l('part1Categories');
      case 1:
        return meta.l('part2Categories');
      case 2:
        return meta.l('part3Categories');
      default:
        return <Map<String, dynamic>>[];
    }
  }

  List<String> get _filterLabels => _tab == 3
      ? _levels
      : <String>['All', for (final c in _categories()) c.s('label')];

  bool _matches(String q, List<String> fields) =>
      q.isEmpty || fields.any((f) => f.toLowerCase().contains(q));

  List<Map<String, dynamic>> _rows() {
    final q = _query.trim().toLowerCase();
    final cats = _categories();
    final cat = _filter > 0 && _filter <= cats.length ? cats[_filter - 1].s('id') : '';
    bool catOk(Map<String, dynamic> m) => cat.isEmpty || m.s('category') == cat;
    switch (_tab) {
      case 0:
        return <Map<String, dynamic>>[
          for (final tp in Content.speakingBankPart1)
            if (catOk(tp) && _matches(q, <String>[tp.s('topic'), ...tp.ls('questions')]))
              <String, dynamic>{
                'id': tp.s('id'),
                'title': tp.s('topic'),
                'subtitle': '${tp.l('samples').length} questions · ${tp.s('categoryLabel')}',
              },
        ];
      case 1:
        return <Map<String, dynamic>>[
          for (final c in Content.speakingBankCards)
            if (catOk(c) && _matches(q, <String>[c.s('title'), ...c.ls('bullets')]))
              <String, dynamic>{
                'id': c.s('id'),
                'title': c.s('title'),
                'subtitle': '${c.s('categoryLabel')} · ${c.m('sample').i('words')}-word sample talk',
              },
        ];
      case 2:
        return <Map<String, dynamic>>[
          for (final tp in Content.part3Topics)
            if (catOk(tp) &&
                _matches(q, <String>[tp.s('topic'), tp.s('description'), for (final x in tp.l('questions')) x.s('q')]))
              <String, dynamic>{
                'id': tp.s('id'),
                'title': tp.s('topic'),
                'subtitle': '${tp.l('questions').length} questions · ${tp.s('categoryLabel')}',
              },
        ];
      default:
        final level = _filter > 0 ? _levels[_filter] : '';
        final out = <Map<String, dynamic>>[];
        for (final k in _wordKeys) {
          final e = speakingWord(k);
          if (level.isNotEmpty && e.s('level') != level) continue;
          if (!_matches(q, <String>[e.s('headword'), e.s('meaning'), ...e.ls('synonyms')])) continue;
          out.add(<String, dynamic>{
            'id': k,
            'title': e.s('headword'),
            'subtitle': e.s('meaning'),
            'level': e.s('level'),
          });
        }
        return out;
    }
  }

  void _open(Map<String, dynamic> row) {
    if (_tab == 3) {
      showSpeakingWord(context, row.s('id'));
      return;
    }
    final part = _tab + 1;
    context.push(Routes.speakingSamples, args: {
      'part': part,
      if (part == 2) 'cardId': row.s('id') else 'topicId': row.s('id'),
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final meta = Content.speakingBankMeta.m('counts');
    final rows = hasSpeakingBank ? _rows() : <Map<String, dynamic>>[];
    final labels = _filterLabels;
    final filter = _filter < labels.length ? _filter : 0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      IconBox(
                        icon: AppIcons.back,
                        iconSize: 18,
                        bg: t.surface,
                        tooltip: 'Back',
                        onTap: () => context.back(),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      const Text(
                        'Sample answers',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.6),
                      ),
                      Text(
                        hasSpeakingBank
                            ? '${meta.i('part1Topics')} Part 1 topics · ${meta.i('part2Cards')} cue cards · '
                                  '${meta.i('part3Topics')} Part 3 topics · ${_wordKeys.length} words'
                            : 'The speaking question bank is not installed in this build.',
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ],
                  ),
                  SegmentedTabs(
                    labels: _tabs,
                    index: _tab,
                    onChanged: (i) => setState(() {
                      _tab = i;
                      _filter = 0;
                    }),
                  ),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      spacing: 10,
                      children: [
                        Icon(AppIcons.search, size: 18, color: t.textMuted),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            cursorColor: t.primary,
                            style: TextStyle(fontSize: 15, color: t.text),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: _tab == 3 ? 'Search a word or meaning' : 'Search topics and questions',
                              hintStyle: TextStyle(fontSize: 15, color: t.textMuted),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ChipRow(
                    labels: labels,
                    selected: filter,
                    onChanged: (i) => setState(() => _filter = i),
                  ),
                  Text(
                    '${rows.length} ${_tab == 3 ? 'words' : 'items'}',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: rows.length,
                itemBuilder: (ctx, i) {
                  final r = rows[i];
                  return ListRow(
                    divider: i > 0,
                    title: r.s('title'),
                    subtitle: r.s('subtitle'),
                    titleSize: 15,
                    trailing: _tab == 3
                        ? Tag(r.s('level'), tone: TagTone.soft, height: 24)
                        : Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
                    onTap: () => _open(r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
