import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../reading/widgets.dart' show boldSpans;
import 'widgets.dart';

/// Phrasal verbs / idioms list (content bank `content.resources.<kind>`),
/// styled like the Vocab Vault: search, topic chips, meaning + example cards,
/// save to "my words" (shared [ResKeys.savedWords]) and a 4-option practice
/// round that records a vocab `quiz` attempt.
class PhraseListScreen extends StatefulWidget {
  const PhraseListScreen({super.key, required this.kind});

  /// 'phrasalVerbs' | 'idioms' | 'topicVocab' (route args `{'topic'}` pick a topic).
  final String kind;

  @override
  State<PhraseListScreen> createState() => _PhraseListScreenState();
}

class _PhraseListScreenState extends State<PhraseListScreen> {
  late final List<Map<String, dynamic>> _items = phraseItems(widget.kind);

  late String _topic = _topicVocab ? _startTopic : ''; // '' = all topics
  late String _letter = _topicVocab || _letters.isEmpty || _items.length <= 60 ? '' : _letters.first; // '' = all letters

  bool get _topicVocab => widget.kind == 'topicVocab';

  /// Topic vocabulary opens on the topic in the route args, else the first.
  String get _startTopic {
    final a = context.routeArgs['topic'];
    if (a is String && _topics.contains(a)) return a;
    return _topics.isEmpty ? '' : _topics.first;
  }
  String _query = '';
  int _limit = _page;
  static const int _page = 40;
  bool _savedOnly = false;

  // Practice state (null = list mode).
  List<Map<String, dynamic>>? _questions;
  int _index = 0;
  int? _picked;
  int _score = 0;
  final List<Map<String, dynamic>> _answers = <Map<String, dynamic>>[];
  DateTime _startedAt = DateTime.now();
  bool _finished = false;
  bool _missedSaved = false;

  bool get _idioms => widget.kind == 'idioms';
  String get _title => _topicVocab ? 'Topic Vocabulary' : (_idioms ? 'Idioms' : 'Phrasal Verbs');
  String get _noun => _topicVocab ? 'terms' : (_idioms ? 'idioms' : 'phrasal verbs');

  /// First letters present (A–Z) — the bank lists are browsed by letter.
  List<String> get _letters {
    final out = <String>{};
    for (final p in _items) {
      final c = p.s('phrase').trim();
      if (c.isNotEmpty) out.add(c[0].toUpperCase());
    }
    return out.toList()..sort();
  }

  List<String> get _topics {
    final out = <String>[];
    for (final p in _items) {
      final topic = p.s('topic');
      if (topic.isNotEmpty && !out.contains(topic)) out.add(topic);
    }
    if (!_topicVocab) out.sort(); // topic sets keep their book order
    return out;
  }

  List<Map<String, dynamic>> _visible(Store store) {
    final q = _query.trim().toLowerCase();
    final saved = store.kvSet(ResKeys.savedWords);
    return _items.where((p) {
      if (_savedOnly && !saved.contains(p.s('id'))) return false;
      // Topic vocabulary: a search looks through every topic.
      if (_topic.isNotEmpty && p.s('topic') != _topic && !(_topicVocab && q.isNotEmpty)) return false;
      if (q.isEmpty && _letter.isNotEmpty && !p.s('phrase').toUpperCase().startsWith(_letter)) return false;
      if (q.isNotEmpty &&
          !p.s('phrase').toLowerCase().contains(q) &&
          !p.s('meaning').toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  static String _registerLabel(String r) => switch (r) {
        'speaking' => 'Speaking',
        'writing' => 'Writing',
        'both' => 'Speaking & Writing',
        _ => '',
      };

  // ── practice ──────────────────────────────────────────────────────────────

  void _startPractice(List<Map<String, dynamic>> visible) {
    if (_items.length < 4) {
      context.toast('Not enough $_noun to practise yet');
      return;
    }
    final rnd = math.Random();
    final pool = List<Map<String, dynamic>>.of(visible.length >= 4 ? visible : _items)
      ..shuffle(rnd);
    final picked = pool.take(10).toList();
    final questions = <Map<String, dynamic>>[];
    for (final item in picked) {
      final others = _items.where((p) => p.s('id') != item.s('id')).toList()
        ..shuffle(rnd);
      final options = <String>[
        item.s('phrase'),
        for (final o in others.take(3)) o.s('phrase'),
      ]..shuffle(rnd);
      questions.add(<String, dynamic>{
        'item': item,
        'options': options,
        'answer': options.indexOf(item.s('phrase')),
      });
    }
    setState(() {
      _questions = questions;
      _index = 0;
      _picked = null;
      _score = 0;
      _answers.clear();
      _startedAt = DateTime.now();
      _finished = false;
      _missedSaved = false;
    });
  }

  void _pick(int i) {
    final qs = _questions;
    if (qs == null || _picked != null) return;
    final q = qs[_index];
    final item = q['item'] as Map<String, dynamic>;
    final correct = i == (q['answer'] as int);
    setState(() {
      _picked = i;
      if (correct) _score++;
      _answers.add(<String, dynamic>{
        'qId': item.s('id'),
        'word': item.s('phrase'),
        'meaning': item.s('meaning'),
        'correct': correct,
      });
    });
  }

  void _next() {
    final qs = _questions;
    if (qs == null || _picked == null) return;
    if (_index + 1 < qs.length) {
      setState(() {
        _index++;
        _picked = null;
      });
      return;
    }
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    Store.I.addAttempt(
      Attempt(
        id: Store.newId('att'),
        skill: Skill.vocab,
        kind: 'quiz',
        title: '$_title practice',
        refId: widget.kind,
        score: _score,
        total: qs.length,
        durationSec: elapsed < 60 ? 60 : elapsed,
        createdAt: DateTime.now(),
        data: <String, dynamic>{
          'answers': List<Map<String, dynamic>>.of(_answers),
          'elapsedSec': elapsed,
          'addedToLearning': 0,
          'source': 'phrases',
        },
      ),
    );
    setState(() => _finished = true);
  }

  void _saveMissed() {
    var n = 0;
    for (final a in _answers) {
      if (!a.b('correct') && !isWordSaved(Store.I, a.s('qId'))) {
        kvSetAdd(Store.I, ResKeys.savedWords, a.s('qId'));
        n++;
      }
    }
    setState(() => _missedSaved = true);
    context.toast(n == 0 ? 'Already in your words' : 'Saved $n to your words');
  }

  void _exitPractice() => setState(() {
        _questions = null;
        _finished = false;
      });

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_questions != null) {
      return _finished ? _buildResult(context) : _buildQuestion(context);
    }
    final t = context.tk;
    final store = context.store;
    final visible = _visible(store);
    final topics = _topics;
    final savedHere = _items.where((p) => isWordSaved(store, p.s('id'))).length;

    return AppScreen(
      gap: 14,
      footer: PrimaryButton(
        label: 'Practise · quick self-test',
        trailing: AppIcons.forward,
        onTap: () => _startPractice(visible),
      ),
      children: [
        ResTopBar(
          title: _savedOnly ? 'Saved $_noun · $savedHere' : _title,
          actions: [
            IconBox(
              icon: _savedOnly ? AppIcons.bookmarkFilled : AppIcons.bookmark,
              tooltip: 'Saved only',
              onTap: () => setState(() => _savedOnly = !_savedOnly),
            ),
          ],
        ),
        const ContentLangSwitch(module: 'resources'),
        ResSearchField(
          hint: 'Search ${_items.length} $_noun',
          height: 50,
          radius: 18,
          onChanged: (v) => setState(() {
            _query = v;
            _limit = _page;
          }),
        ),
        if (!_topicVocab && _letters.length > 1 && _query.trim().isEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                for (final l in <String>['', ..._letters])
                  ResMiniPill(
                    label: l.isEmpty ? 'All' : l,
                    height: 36,
                    bold: l == _letter,
                    bg: l == _letter ? t.primary : (t.isNight ? t.surface : t.raised),
                    fg: l == _letter ? t.onPrimary : t.text,
                    onTap: () => setState(() {
                      _letter = l;
                      _limit = _page;
                    }),
                  ),
              ],
            ),
          ),
        if (topics.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (final topic in <String>['', ...topics])
                ResMiniPill(
                  label: topic.isEmpty ? 'All topics' : (_topicVocab ? topic : 'IELTS · $topic'),
                  height: 40,
                  bg: topic == _topic ? t.primary : (t.isNight ? t.surface : t.raised),
                  fg: topic == _topic ? t.onPrimary : t.text,
                  onTap: () => setState(() {
                    _topic = topic;
                    if (topic.isNotEmpty) _letter = '';
                    _limit = _page;
                  }),
                ),
            ],
          ),
        ),
        Text(
          '${visible.length} of ${_items.length} $_noun · tap the bookmark to save to your words',
          style: TextStyle(fontSize: 12, color: t.textMuted),
        ),
        if (visible.isEmpty)
          EmptyState(
            title: _savedOnly ? 'No saved $_noun yet' : 'Nothing matches',
            message: _savedOnly
                ? 'Save $_noun from the list and they will appear here and in your Vocab Vault.'
                : 'Try another topic or search.',
            icon: _savedOnly ? AppIcons.bookmark : AppIcons.search,
            actionLabel: _savedOnly ? 'Show all' : 'Clear filters',
            onAction: () => setState(() {
              _savedOnly = false;
              _topic = '';
              _letter = '';
            }),
          ),
        for (final p in visible.take(_limit))
          _PhraseCard(
            data: p,
            register: _registerLabel(p.s('register')),
            saved: isWordSaved(store, p.s('id')),
            onSave: () {
              final now = toggleSavedWord(p.s('id'));
              context.toast(now ? 'Saved to your words' : 'Removed from saved words');
            },
          ),
        if (visible.length > _limit)
          SoftButton(
            label: 'Show more · ${visible.length - _limit} left',
            height: 46,
            radius: 16,
            expand: true,
            bg: t.isNight ? t.surface : t.raised,
            onTap: () => setState(() => _limit += _page),
          ),
      ],
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final t = context.tk;
    final qs = _questions!;
    final q = qs[_index];
    final item = q['item'] as Map<String, dynamic>;
    final options = (q['options'] as List).map((e) => '$e').toList();
    final answer = q['answer'] as int;
    const letters = <String>['A', 'B', 'C', 'D'];

    return AppScreen(
      gap: 14,
      footer: PrimaryButton(
        label: _index + 1 < qs.length ? 'Next' : 'See score',
        trailing: AppIcons.forward,
        enabled: _picked != null,
        onTap: _picked == null ? null : _next,
      ),
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.close,
              tooltip: 'Stop practice',
              iconSize: 18,
              onTap: _exitPractice,
            ),
            Expanded(
              child: Text(
                '$_title practice',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
            Tag('${_index + 1}/${qs.length}'),
          ],
        ),
        SegmentBar(count: qs.length, filled: _index + (_picked == null ? 0 : 1)),
        HeroCard(
          radius: 26,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                'Which ${_idioms ? 'idiom' : 'phrasal verb'} means…',
                style: TextStyle(fontSize: 13, color: t.heroMuted),
              ),
              Text(
                item.s('meaning'),
                style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: t.heroText,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < options.length; i++)
          OptionTile(
            label: options[i],
            leadingText: letters[i],
            selected: _picked == i,
            state: _picked == null
                ? OptionState.none
                : (i == answer
                    ? OptionState.correct
                    : (i == _picked ? OptionState.wrong : OptionState.none)),
            onTap: _picked == null ? () => _pick(i) : null,
          ),
        if (_picked != null)
          AppCard(
            radius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  _picked == answer ? 'Correct' : 'The answer is “${options[answer]}”',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _picked == answer ? t.success : t.dangerText,
                  ),
                ),
                Text(
                  '“${item.s('example').replaceAll('**', '')}”',
                  style: TextStyle(fontSize: 14, height: 1.4, color: t.textSoft),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final t = context.tk;
    final total = _questions!.length;
    final missed = _answers.where((a) => !a.b('correct')).toList();
    return AppScreen(
      gap: 14,
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Back to list',
              height: 56,
              fontSize: 15,
              expand: true,
              bg: t.isNight ? t.surface : t.raised,
              onTap: _exitPractice,
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: 'Practise again',
              height: 56,
              fontSize: 15,
              onTap: () => _startPractice(_visible(Store.I)),
            ),
          ),
        ],
      ),
      children: [
        ResTopBar(title: '$_title practice', overline: 'Your score'),
        HeroCard(
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                'Score',
                style: TextStyle(fontSize: 13, color: t.heroMuted),
              ),
              BigNumber('$_score/$total', color: t.heroText),
              Text(
                _score == total
                    ? 'Perfect round — every meaning matched.'
                    : '${missed.length} to review. Saved to your vocab history.',
                style: TextStyle(fontSize: 14, color: t.heroText),
              ),
              const SizedBox(height: 4),
              ProgressBar(value: total == 0 ? 0 : _score / total, onHero: true),
            ],
          ),
        ),
        if (missed.isNotEmpty) ...[
          SectionTitle(
            'Review',
            action: _missedSaved ? null : 'Save missed',
            onAction: _missedSaved ? null : _saveMissed,
          ),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              children: [
                for (var i = 0; i < missed.length; i++)
                  ListRow(
                    divider: i > 0,
                    title: missed[i].s('word'),
                    subtitle: missed[i].s('meaning'),
                    trailing: Icon(AppIcons.close, size: 18, color: t.danger),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({
    required this.data,
    required this.register,
    required this.saved,
    required this.onSave,
  });

  final Map<String, dynamic> data;
  final String register;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final care = data.s('care');
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  data.s('phrase'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              IconBox(
                icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                tooltip: saved ? 'Remove from saved words' : 'Save to my words',
                size: 38,
                radius: 13,
                iconSize: 18,
                bg: saved ? t.primary : t.surfaceAlt2,
                fg: saved ? t.onPrimary : t.text,
                onTap: onSave,
              ),
            ],
          ),
          Text(
            data.s('meaning'),
            style: TextStyle(fontSize: 14, height: 1.4, color: t.textMuted),
          ),
          TrMeaning(data.s('id'), fontSize: 14),
          Text.rich(
            TextSpan(children: boldSpans('“${data.s('example')}”')),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: t.textSoft,
            ),
          ),
          if (data.s('ieltsExample').isNotEmpty)
            Text(
              'IELTS: “${data.s('ieltsExample')}”',
              style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
            ),
          if (register.isNotEmpty || data.s('topic').isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (register.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ResPalette.lavender,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    register,
                    style: const TextStyle(fontSize: 12, color: ResPalette.ink),
                  ),
                ),
              if (data.s('topic').isNotEmpty) Tag(data.s('topic'), height: 24),
            ],
          ),
          if (care.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Icon(AppIcons.info, size: 16, color: t.text),
                  Expanded(
                    child: Text(
                      'Use with care · $care',
                      style: TextStyle(fontSize: 12, height: 1.35, color: t.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
