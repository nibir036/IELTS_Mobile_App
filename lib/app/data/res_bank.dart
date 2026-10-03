import 'dart:math' as math;

import 'demo.dart';

/// The Resources bank (assets/content/resources_bank.json, built by
/// tool/import_resources_bank.py): IELTS vocabulary bank, idioms, phrasal
/// verbs, irregular verbs, linking words and academic words.
///
/// Every list is empty when the bank is missing; screens then fall back to
/// the demo lists in `resources`.
class ResBank {
  ResBank._();

  static Map<String, dynamic> get _b => Demo.resourcesBank;

  static bool get has => _b.l('vocab').isNotEmpty;

  /// {id, word, ipa, pos, definition, examples[2], synonyms[], register, band}
  static List<Map<String, dynamic>> get vocab => _b.l('vocab');

  /// {id, phrase, meaning, example}
  static List<Map<String, dynamic>> get idioms => _b.l('idioms');

  /// {id, phrase, meaning, example}
  static List<Map<String, dynamic>> get phrasalVerbs => _b.l('phrasalVerbs');

  /// {base, past, participle, meaning, example}
  static List<Map<String, dynamic>> get irregularVerbs => _b.l('irregularVerbs');

  /// Linking words by function: {id, title, note, items: [{id, word, use, example, function, register}]}
  static List<Map<String, dynamic>> get connectorGroups => _b.l('connectors');

  /// {id, word, pos, definition, example, family[], list: core | extended}
  static List<Map<String, dynamic>> get academicWords => _b.l('academicWords');

  /// IELTS topic vocabulary: {id, title, items: [{id, term, meaning, example}]} (23 topics).
  static List<Map<String, dynamic>> get topics => _b.l('topics');

  /// Academic words per study day.
  static const int wordsPerDay = 20;

  static int get academicDays => (academicWords.length / wordsPerDay).ceil();

  /// The academic words of study [day] (1-based).
  static List<Map<String, dynamic>> academicDay(int day) {
    final all = academicWords;
    final start = (day - 1) * wordsPerDay;
    if (start < 0 || start >= all.length) return <Map<String, dynamic>>[];
    return all.sublist(start, math.min(start + wordsPerDay, all.length));
  }

  /// Text without the **bold** markers of the examples.
  static String plain(String s) => s.replaceAll('**', '');

  // ── one shape for every kind of word ─────────────────────────────────────

  static Map<String, dynamic>? _src;
  static List<Map<String, dynamic>> _all = <Map<String, dynamic>>[];
  static Map<String, Map<String, dynamic>> _byId = <String, Map<String, dynamic>>{};

  static void _build() {
    if (identical(_src, _b)) return;
    _src = _b;
    final out = <Map<String, dynamic>>[];
    for (final v in vocab) {
      out.add(<String, dynamic>{
        'id': v.s('id'), 'kind': 'vocab', 'category': 'words', 'word': v.s('word'), 'partOfSpeech': v.s('pos'),
        'ipa': v.s('ipa'), 'definition': v.s('definition'), 'examples': v.ls('examples'),
        'synonyms': v.ls('synonyms'), 'register': v.s('register'), 'band': v.d('band'),
      });
    }
    for (final p in phrasalVerbs) {
      out.add(<String, dynamic>{
        'id': p.s('id'), 'kind': 'phrasal', 'category': 'phrasal', 'word': p.s('phrase'),
        'partOfSpeech': 'phrasal verb', 'definition': p.s('meaning'), 'examples': <String>[p.s('example')],
      });
    }
    for (final p in idioms) {
      out.add(<String, dynamic>{
        'id': p.s('id'), 'kind': 'idiom', 'category': 'idioms', 'word': p.s('phrase'), 'partOfSpeech': 'idiom',
        'definition': p.s('meaning'), 'examples': <String>[p.s('example')],
      });
    }
    for (final g in connectorGroups) {
      for (final c in g.l('items')) {
        out.add(<String, dynamic>{
          'id': c.s('id'), 'kind': 'linking', 'category': 'linking', 'word': c.s('word'),
          'partOfSpeech': 'linking word', 'definition': c.s('use'), 'examples': <String>[c.s('example')],
          'register': c.s('register'), 'group': g.s('title'),
        });
      }
    }
    for (final a in academicWords) {
      out.add(<String, dynamic>{
        'id': a.s('id'), 'kind': 'academic', 'category': 'academic', 'word': a.s('word'), 'partOfSpeech': a.s('pos'),
        'definition': a.s('definition'), 'examples': <String>[a.s('example')], 'family': a.ls('family'),
      });
    }
    for (final tp in topics) {
      for (final x in tp.l('items')) {
        out.add(<String, dynamic>{
          'id': x.s('id'), 'kind': 'topic', 'category': 'topic', 'word': x.s('term'), 'partOfSpeech': 'topic term',
          'definition': x.s('meaning'), 'examples': <String>[x.s('example')], 'group': tp.s('title'),
        });
      }
    }
    _all = out;
    _byId = <String, Map<String, dynamic>>{for (final w in out) w.s('id'): w};
  }

  /// Every word of the bank in one shape:
  /// {id, kind, category, word, partOfSpeech, definition, examples, ipa?, synonyms?, family?, register?, band?}.
  static List<Map<String, dynamic>> get allWords {
    _build();
    return _all;
  }

  /// A bank word by id (null if unknown).
  static Map<String, dynamic>? word(String id) {
    _build();
    return _byId[id];
  }

  static Map<String, dynamic>? _vSrc;
  static Map<String, Map<String, dynamic>> _vocabByWord = <String, Map<String, dynamic>>{};

  /// Vocabulary-bank entry for a headword (case-insensitive), or null.
  static Map<String, dynamic>? vocabFor(String word) {
    if (!identical(_vSrc, _b)) {
      _vSrc = _b;
      _vocabByWord = <String, Map<String, dynamic>>{for (final v in vocab) v.s('word').toLowerCase(): v};
    }
    return _vocabByWord[word.trim().toLowerCase()];
  }

  /// "Band 7.5" for a band number (empty for none).
  static String bandLabel(double band) {
    if (band <= 0) return '';
    return 'Band ${band == band.roundToDouble() ? band.toInt() : band}';
  }

  // ── word of the day ──────────────────────────────────────────────────────

  static const Map<String, String> _posShort = <String, String>{
    'noun': 'n.', 'verb': 'v.', 'adjective': 'adj.', 'adverb': 'adv.',
  };

  /// A Band 7.5+ word that changes every day, in the hub's word-of-the-day
  /// shape {id, word, partOfSpeech, partOfSpeechShort, phonetic, definition,
  /// example}; [fallback] when the bank is missing.
  static Map<String, dynamic> wordOfTheDay(Map<String, dynamic> fallback, {DateTime? now}) {
    final pool = vocab.where((v) => v.d('band') >= 7.5 && v.ls('examples').isNotEmpty).toList();
    if (pool.isEmpty) return fallback;
    final d = now ?? DateTime.now();
    final day = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
    // A fixed stride spreads consecutive days across the alphabet.
    final v = pool[(day * 37) % pool.length];
    final w = v.s('word');
    return <String, dynamic>{
      'id': v.s('id'),
      'word': w.isEmpty ? w : w[0].toUpperCase() + w.substring(1),
      'partOfSpeech': v.s('pos'),
      'partOfSpeechShort': _posShort[v.s('pos')] ?? v.s('pos'),
      'phonetic': v.s('ipa'),
      'definition': v.s('definition'),
      'example': plain(v.ls('examples').first),
    };
  }

  // ── generated quiz decks (Vocab Vault) ────────────────────────────────────

  /// Questions per generated round.
  static const int roundSize = 10;

  /// Deck definitions: id → (title, level label, prompt).
  static const List<(String, String, String, String)> _decks = <(String, String, String, String)>[
    ('b6', 'Band 6 words', 'Band 6', 'Choose the best meaning'),
    ('b7', 'Band 7 words', 'Band 7', 'Choose the best meaning'),
    ('b8', 'Band 8 words', 'Band 8', 'Choose the best meaning'),
    ('b9', 'Band 9 words', 'Band 9', 'Choose the best meaning'),
    ('syn', 'Synonyms', 'Synonyms', 'Choose the closest synonym'),
    ('idiom', 'Idioms', 'Idioms', 'Choose the best meaning'),
    ('pv', 'Phrasal verbs', 'Phrasal verbs', 'Choose the best meaning'),
    ('link', 'Linking words', 'Linking', 'Choose how it is used'),
    ('topic', 'Topic vocabulary', 'Topics', 'Choose the best meaning'),
  ];

  static Map<String, dynamic>? _qSrc;
  static Map<String, List<List<Map<String, dynamic>>>> _rounds = <String, List<List<Map<String, dynamic>>>>{};
  static Map<String, List<String>> _roundLabels = <String, List<String>>{};

  /// One quiz entry {id, word, pos, meaning, example, ipa, group?}.
  static Map<String, dynamic> _q(String id, String word, String pos, String meaning, String example,
          {String ipa = '', String group = ''}) =>
      <String, dynamic>{
        'id': id, 'word': word, 'pos': pos, 'meaning': meaning, 'example': plain(example), 'ipa': ipa,
        'group': group,
      };

  static List<List<Map<String, dynamic>>> _chunk(List<Map<String, dynamic>> items, int seed) {
    final list = List<Map<String, dynamic>>.of(items)..shuffle(math.Random(seed));
    return <List<Map<String, dynamic>>>[
      for (var i = 0; i + 4 <= list.length; i += roundSize) list.sublist(i, math.min(i + roundSize, list.length)),
    ];
  }

  static void _buildRounds() {
    if (identical(_qSrc, _b)) return;
    _qSrc = _b;
    final rounds = <String, List<List<Map<String, dynamic>>>>{};
    final labels = <String, List<String>>{};
    List<Map<String, dynamic>> band(bool Function(double b) ok) => <Map<String, dynamic>>[
          for (final v in vocab)
            if (ok(v.d('band')))
              _q(v.s('id'), v.s('word'), v.s('pos'), v.s('definition'),
                  v.ls('examples').isEmpty ? '' : v.ls('examples').first, ipa: v.s('ipa')),
        ];
    rounds['b6'] = _chunk(band((b) => b > 0 && b < 7), 6);
    rounds['b7'] = _chunk(band((b) => b >= 7 && b < 8), 7);
    rounds['b8'] = _chunk(band((b) => b >= 8 && b < 9), 8);
    rounds['b9'] = _chunk(band((b) => b >= 9), 9);
    // Synonyms: the "meaning" is the word's first synonym.
    rounds['syn'] = _chunk(<Map<String, dynamic>>[
      for (final v in vocab)
        if (v.ls('synonyms').isNotEmpty)
          _q(v.s('id'), v.s('word'), v.s('pos'), v.ls('synonyms').first,
              v.ls('examples').isEmpty ? '' : v.ls('examples').first, ipa: v.s('ipa')),
    ], 11);
    rounds['idiom'] = _chunk(<Map<String, dynamic>>[
      for (final x in idioms) _q(x.s('id'), x.s('phrase'), 'idiom', x.s('meaning'), x.s('example')),
    ], 12);
    rounds['pv'] = _chunk(<Map<String, dynamic>>[
      for (final x in phrasalVerbs) _q(x.s('id'), x.s('phrase'), 'phrasal verb', x.s('meaning'), x.s('example')),
    ], 13);
    rounds['link'] = _chunk(<Map<String, dynamic>>[
      for (final g in connectorGroups)
        for (final c in g.l('items')) _q(c.s('id'), c.s('word'), 'linking word', c.s('use'), c.s('example')),
    ], 14);
    // Topic vocabulary: rounds stay inside one topic, in book order.
    final topicRounds = <List<Map<String, dynamic>>>[];
    final topicLabels = <String>[];
    var n = 0;
    for (final tp in topics) {
      final items = <Map<String, dynamic>>[
        for (final x in tp.l('items'))
          _q(x.s('id'), x.s('term'), 'topic term', x.s('meaning'), x.s('example'), group: tp.s('title')),
      ];
      final rs = _chunk(items, 100 + n++);
      for (var i = 0; i < rs.length; i++) {
        topicRounds.add(rs[i]);
        topicLabels.add('${tp.s('title')} ${i + 1}');
      }
    }
    rounds['topic'] = topicRounds;
    labels['topic'] = topicLabels;
    _rounds = rounds;
    _roundLabels = labels;
  }

  /// Decks with at least one round: {id, title, level, rounds}.
  static List<Map<String, dynamic>> get quizDecks {
    _buildRounds();
    return <Map<String, dynamic>>[
      for (final d in _decks)
        if ((_rounds[d.$1] ?? const <List<Map<String, dynamic>>>[]).isNotEmpty)
          <String, dynamic>{'id': d.$1, 'title': d.$2, 'level': d.$3, 'rounds': _rounds[d.$1]!.length},
    ];
  }

  /// Same number on every platform and run (String.hashCode is not guaranteed to be).
  static int _stableHash(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  /// Quiz id of round [n] (1-based) of [deck].
  static String deckRoundId(String deck, int n) => 'gq_${deck}_$n';

  /// (deck, round number) of a generated quiz id, or null.
  static (String, int)? parseRoundId(String id) {
    final m = RegExp(r'^gq_([a-z0-9]+)_(\d+)$').firstMatch(id);
    if (m == null) return null;
    return (m.group(1)!, int.parse(m.group(2)!));
  }

  /// A generated round in the content quiz shape {id, title, level, prompt,
  /// questions: [{id, word, partOfSpeech, phonetic, options[4], answer, example,
  /// meaningShort, wordId}]}; empty map for an unknown id.
  static Map<String, dynamic> deckQuiz(String id) {
    final r = parseRoundId(id);
    if (r == null) return <String, dynamic>{};
    _buildRounds();
    final rounds = _rounds[r.$1];
    if (rounds == null || r.$2 < 1 || r.$2 > rounds.length) return <String, dynamic>{};
    final deck = _decks.firstWhere((d) => d.$1 == r.$1);
    final items = rounds[r.$2 - 1];
    final pool = <Map<String, dynamic>>[for (final rs in rounds) ...rs];
    final rnd = math.Random(_stableHash(id));
    final questions = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final w = items[i];
      final answer = w.s('meaning');
      final avoid = <String>{answer.toLowerCase()};
      if (r.$1 == 'syn') {
        // other synonyms of this word are not wrong answers
        final v = vocabFor(w.s('word'));
        if (v != null) avoid.addAll(v.ls('synonyms').map((x) => x.toLowerCase()));
      }
      final samePos = pool.where((o) => o.s('pos') == w.s('pos') && o.s('id') != w.s('id')).toList();
      final from = samePos.length >= 12 ? samePos : pool;
      final others = <String>[];
      var guard = 0;
      while (others.length < 3 && guard++ < 400) {
        final o = from[rnd.nextInt(from.length)].s('meaning');
        if (o.isNotEmpty && !avoid.contains(o.toLowerCase())) {
          avoid.add(o.toLowerCase());
          others.add(o);
        }
      }
      final options = <String>[answer, ...others]..shuffle(rnd);
      questions.add(<String, dynamic>{
        'id': '${id}_q${i + 1}',
        'word': w.s('word'),
        'partOfSpeech': w.s('pos'),
        'phonetic': w.s('ipa'),
        'options': options,
        'answer': options.indexOf(answer),
        'example': w.s('example'),
        'meaningShort': answer,
        'wordId': w.s('id'),
      });
    }
    final label = (_roundLabels[r.$1] ?? const <String>[]);
    final name = r.$1 == 'topic' && r.$2 <= label.length ? label[r.$2 - 1] : '${deck.$2} ${r.$2}';
    return <String, dynamic>{
      'id': id,
      'title': 'Vocabulary quiz · $name',
      'level': r.$1 == 'topic' && r.$2 <= label.length ? 'Topic' : deck.$3,
      'prompt': deck.$4,
      'deck': r.$1,
      'questions': questions,
    };
  }

  // ── generated quizzes ────────────────────────────────────────────────────

  /// Quiz id of an academic study day.
  static String academicQuizId(int day) => 'aw_day_$day';

  /// Choose-the-meaning quiz on the words of an academic study day (id
  /// `aw_day_N`), in the shape of the content quizzes; empty map otherwise.
  static Map<String, dynamic> academicDayQuiz(String id) {
    final m = RegExp(r'^aw_day_(\d+)$').firstMatch(id);
    if (m == null) return <String, dynamic>{};
    final day = int.parse(m.group(1)!);
    final words = academicDay(day);
    if (words.length < 4) return <String, dynamic>{};
    final all = academicWords;
    final rnd = math.Random(day * 7919);
    final ipa = <String, String>{for (final v in vocab) v.s('word').toLowerCase(): v.s('ipa')};
    final questions = <Map<String, dynamic>>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final others = <String>[];
      while (others.length < 3) {
        final o = all[rnd.nextInt(all.length)];
        final def = o.s('definition');
        if (def != w.s('definition') && !others.contains(def)) others.add(def);
      }
      final options = <String>[w.s('definition'), ...others]..shuffle(rnd);
      questions.add(<String, dynamic>{
        'id': '${id}_q${i + 1}',
        'word': w.s('word'),
        'partOfSpeech': w.s('pos'),
        'phonetic': ipa[w.s('word').toLowerCase()] ?? '',
        'options': options,
        'answer': options.indexOf(w.s('definition')),
        'example': plain(w.s('example')),
        'meaningShort': w.s('definition'),
        'wordId': w.s('id'),
      });
    }
    return <String, dynamic>{
      'id': id,
      'title': 'Academic words · Day $day',
      'level': 'Day $day',
      'prompt': 'Choose the best meaning',
      'questions': questions,
    };
  }
}
