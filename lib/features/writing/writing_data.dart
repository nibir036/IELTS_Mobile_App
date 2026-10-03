import 'dart:math' as math;

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/services/ai_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Writing section data layer.
//
// • CONTENT (prompts, model answers, drills, lessons, templates, ideas) comes
//   from `Demo.section('writing')`.
// • USER DATA lives in the store:
//   - attempts: skill 'writing', kind 'task1' | 'task2' | 'drill'
//   - kv 'writing.draft.task1' / 'writing.draft.task2'
//       = {promptId, text, updatedAt, elapsedSec}
//   - kv 'writing.lessons.done' (list of lesson ids),
//     'writing.lessons.pos' ({lessonId: seconds})
//   - kv 'writing.template.values' ({"tplId|section|segment": value})
//   - kv 'writing.ideas.bookmarks' (list of idea item ids)
// ═════════════════════════════════════════════════════════════════════════════

class WritingKeys {
  WritingKeys._();
  static String draft(int task) => 'writing.draft.task$task';
  static const lessonsDone = 'writing.lessons.done';
  static const lessonsPos = 'writing.lessons.pos';
  static const templateValues = 'writing.template.values';
  static const ideaBookmarks = 'writing.ideas.bookmarks';
}

/// Read a kv entry as a map (empty if missing).
Map<String, dynamic> kvMap(Store store, String key) {
  final v = store.data.kv[key];
  if (v is Map) return v.cast<String, dynamic>();
  return <String, dynamic>{};
}

class WritingContent {
  WritingContent._();

  /// UI copy of the section (selector, lessons, drills, templates …).
  static Map<String, dynamic> get all => Demo.section('writing');

  // ── Prompt bank (Content.writingTask1 / writingTask2) ─────────────────────

  static Object? _cacheSrc;
  static List<Map<String, dynamic>> _cache = <Map<String, dynamic>>[];

  /// Display names of the bank's prompt types.
  static const Map<String, String> task1TypeNames = <String, String>{
    'line': 'Line graph',
    'bar': 'Bar chart',
    'pie': 'Pie chart',
    'table': 'Table',
    'process': 'Process diagram',
    'map': 'Map / plan',
    'mixed': 'Combination',
  };
  static const Map<String, String> task2TypeNames = <String, String>{
    'opinion': 'Opinion',
    'discussion': 'Discussion',
    'advantages': 'Advantages & disadvantages',
    'problem': 'Problem–solution',
    'two-part': 'Two-part question',
    'positive-negative': 'Positive / negative development',
  };

  /// "Line graph" / "Opinion" for a bank type key.
  static String typeName(int task, String type) {
    final names = task == 1 ? task1TypeNames : task2TypeNames;
    final n = names[type];
    if (n != null) return n;
    if (type.isEmpty) return task == 1 ? 'Report' : 'Essay';
    return type.substring(0, 1).toUpperCase() + type.substring(1);
  }

  /// Bank item → the prompt shape the screens use:
  /// {id, task, type (bank key), typeName, typeLabel, title, shortTitle,
  ///  header, subheader, topic, prompt, requirement, minWords, timeSeconds,
  ///  chart (with `type`), ideas, modelAnswer (text), modelBand} plus, for the
  ///  question bank (wb1_ / wb2_): {bank: true, number, difficulty, image,
  ///  dataText, statement, samples [{band, label, words, paragraphs, why}]}.
  static Map<String, dynamic> _normalize(Map<String, dynamic> raw, int task) {
    final type = raw.s('type');
    final name = typeName(task, type);
    final title = raw.s('title').isEmpty ? name : raw.s('title');
    final minWords = raw.i('minWords') > 0 ? raw.i('minWords') : (task == 1 ? 150 : 250);
    final chart = Map<String, dynamic>.from(raw.m('chart'));
    if (task == 1 && chart.isNotEmpty && chart.s('type').isEmpty) {
      chart['type'] = type;
    }
    final model = raw['modelAnswer'];
    var modelText = '';
    var modelBand = 0.0;
    if (model is Map) {
      final mm = model.cast<String, dynamic>();
      modelText = mm.s('text');
      modelBand = mm.d('band');
    } else if (model is String) {
      modelText = model;
    }
    if (modelText.trim().isNotEmpty && modelBand <= 0) modelBand = 8;
    final bank = raw.s('id').startsWith('wb');
    final fullTest = raw.s('test').isNotEmpty;
    return <String, dynamic>{
      if (bank || fullTest) ...<String, dynamic>{
        'bank': bank,
        if (fullTest) 'test': raw.s('test'),
        'number': raw.i('number'),
        'difficulty': raw.s('difficulty'),
        'image': raw.s('image'),
        'dataText': raw.s('dataText'),
        'statement': raw.s('statement').isNotEmpty ? raw.s('statement') : raw.s('question'),
        'samples': raw.l('samples'),
      },
      'id': raw.s('id'),
      'task': task,
      'type': type,
      'typeName': name,
      'typeLabel': 'Task $task · $name',
      'title': title,
      'shortTitle':
          task == 1 ? '$title, ${name.toLowerCase()}' : title,
      'header': 'Task $task · Academic',
      'subheader': '$name · aim $minWords+ words',
      'topic': raw.s('topic'),
      'prompt': raw.s('prompt'),
      'requirement': 'Write at least $minWords words.',
      'minWords': minWords,
      'timeSeconds': task == 1 ? 1200 : 2400,
      'chart': chart,
      'ideas': raw.m('ideas'),
      'modelAnswer': modelText.trim(),
      'modelBand': modelBand,
    };
  }

  static List<Map<String, dynamic>> _legacyCache = <Map<String, dynamic>>[];

  /// Builds the prompt caches once per loaded content.
  static void _ensure() {
    final src = Demo.all;
    if (identical(src, _cacheSrc) && _cache.isNotEmpty) return;
    _cacheSrc = src;
    _cache = <Map<String, dynamic>>[
      for (final p in Content.writingTask1)
        if (p.s('id').isNotEmpty) _normalize(p, 1),
      for (final p in Content.writingTask2)
        if (p.s('id').isNotEmpty) _normalize(p, 2),
    ];
    _legacyCache = <Map<String, dynamic>>[
      // Full-test prompts (Writing Test 1–10): opened from the tests list and
      // mocks, never shown in the practice lists.
      for (final p in Content.writingTestPrompts)
        if (p.s('id').isNotEmpty) _normalize(p, p.i('task') == 2 ? 2 : 1),
      if (Content.writingBankTask1.isNotEmpty || Content.writingBankTask2.isNotEmpty) ...<Map<String, dynamic>>[
        for (final p in Content.writingDemoTask1)
          if (p.s('id').isNotEmpty) _normalize(p, 1),
        for (final p in Content.writingDemoTask2)
          if (p.s('id').isNotEmpty) _normalize(p, 2),
      ],
    ];
  }

  /// Practice prompts: the question bank (or the demo prompts without it).
  static List<Map<String, dynamic>> get _bank {
    _ensure();
    return _cache;
  }

  /// The demo prompts when the bank is loaded (older essays, mocks, ideas).
  static List<Map<String, dynamic>> get _legacy {
    _ensure();
    return _legacyCache;
  }

  /// All prompts of the bank (optionally one task), in bank order.
  static List<Map<String, dynamic>> prompts({int? task}) => _bank
      .where((p) => task == null || p.i('task') == task)
      .toList();

  static Map<String, dynamic>? prompt(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in _bank) {
      if (p.s('id') == id) return p;
    }
    for (final p in _legacy) {
      if (p.s('id') == id) return p;
    }
    return null;
  }

  /// Task 2 prompts that come with ideas (for / against / vocabulary).
  static List<Map<String, dynamic>> ideaPrompts() => <Map<String, dynamic>>[
        for (final p in <Map<String, dynamic>>[..._bank, ..._legacy])
          if (p.i('task') == 2 && p.m('ideas').isNotEmpty) p,
      ];

  /// Difficulty levels used by [task]'s prompts, easiest first.
  static List<String> difficulties(int task) {
    const order = <String>['Moderate', 'Upper-moderate', 'Difficult'];
    final seen = <String>{for (final p in prompts(task: task)) p.s('difficulty')}..remove('');
    return <String>[...order.where(seen.contains), ...seen.where((d) => !order.contains(d))];
  }

  /// Prompts that come with a model answer (C13), optionally one task.
  static List<Map<String, dynamic>> withModelAnswer({int? task}) => prompts(
        task: task,
      ).where((p) => p.s('modelAnswer').isNotEmpty).toList();

  /// Distinct type keys of a task, in bank order.
  static List<String> types(int task) {
    final out = <String>[];
    for (final p in prompts(task: task)) {
      final ty = p.s('type');
      if (ty.isNotEmpty && !out.contains(ty)) out.add(ty);
    }
    return out;
  }

  /// Distinct topics of the Task 2 prompts that have ideas (Ideas & topics).
  static List<String> topics() {
    final out = <String>[];
    for (final p in ideaPrompts()) {
      final tp = p.s('topic');
      if (tp.isNotEmpty && !out.contains(tp)) out.add(tp);
    }
    return out;
  }

  static Map<String, dynamic> defaultPrompt(int task) {
    final list = prompts(task: task);
    return list.isEmpty ? <String, dynamic>{'task': task} : list.first;
  }

  /// The prompt a task card opens: the first prompt of the bank the student
  /// hasn't attempted yet; when every prompt has been written, the one
  /// written longest ago.
  static Map<String, dynamic> nextPrompt(Store store, int task) {
    final list = prompts(task: task);
    if (list.isEmpty) return defaultPrompt(task);
    // attemptsFor is newest first → the last index is the oldest attempt.
    final lastSeen = <String, int>{};
    final attempts = store.attemptsFor(skill: Skill.writing, kind: 'task$task');
    for (var k = 0; k < attempts.length; k++) {
      lastSeen.putIfAbsent(attempts[k].refId, () => k);
    }
    for (final p in list) {
      if (!lastSeen.containsKey(p.s('id'))) return p;
    }
    var best = list.first;
    var bestIdx = -1;
    for (final p in list) {
      final idx = lastSeen[p.s('id')] ?? 0;
      if (idx > bestIdx) {
        bestIdx = idx;
        best = p;
      }
    }
    return best;
  }

  /// How many prompts of [task] the student has written at least once.
  static int attemptedCount(Store store, int task) {
    final ids = prompts(task: task).map((p) => p.s('id')).toSet();
    final done = <String>{};
    for (final a in store.attemptsFor(skill: Skill.writing, kind: 'task$task')) {
      final r = a.refId;
      if (ids.contains(r)) done.add(r);
    }
    return done.length;
  }

  /// Plain-text rendering of a Task 1 chart (sent to the AI examiner so it
  /// can check the figures). '' when there is nothing to describe.
  /// The visual's data for the AI examiner: the bank's data text when the
  /// prompt has one, else a rendering of the demo chart.
  static String visualText(Map<String, dynamic> prompt) {
    final d = prompt.s('dataText');
    return d.isNotEmpty ? d : chartText(prompt.m('chart'));
  }

  static String chartText(Map<String, dynamic> chart) {
    final b = StringBuffer();
    final parts = chart.l('parts');
    if (parts.isNotEmpty) {
      for (final part in parts) {
        final t = chartText(part);
        if (t.isNotEmpty) b.writeln(t);
      }
      return b.toString().trim();
    }
    final unit = chart.s('unit');
    final u = unit.isEmpty ? '' : ' ($unit)';
    final labels = chart.ls('xLabels');
    for (final s in chart.l('series')) {
      final vals = s.ls('values');
      final pairs = <String>[
        for (var i = 0; i < vals.length; i++)
          '${i < labels.length ? labels[i] : '#${i + 1}'}: ${vals[i]}',
      ];
      b.writeln('${s.s('name')}$u — ${pairs.join(', ')}');
    }
    for (final pie in chart.l('charts')) {
      final slices = <String>[
        for (final sl in pie.l('slices')) '${sl.s('name')} ${sl.s('value')}$unit',
      ];
      b.writeln('${pie.s('label')}: ${slices.join(', ')}');
    }
    final columns = chart.ls('columns');
    if (columns.isNotEmpty) b.writeln(columns.join(' | '));
    final rows = chart['rows'];
    if (rows is List) {
      for (final r in rows) {
        if (r is List) b.writeln(r.map((e) => '$e').join(' | '));
      }
    }
    final steps = chart.ls('steps');
    for (var i = 0; i < steps.length; i++) {
      b.writeln('${i + 1}. ${steps[i]}');
    }
    for (final side in const <String>['before', 'after']) {
      final m = chart.m(side);
      if (m.isEmpty) continue;
      b.writeln('${m.s('label').isEmpty ? side : m.s('label')}: ${m.ls('features').join('; ')}');
    }
    return b.toString().trim();
  }

  /// Model answer text for a prompt ('' if none).
  static String modelAnswer(String? promptId) =>
      prompt(promptId)?.s('modelAnswer') ?? '';
}

class WritingDrafts {
  WritingDrafts._();

  /// The saved draft for a task, or null.
  static Map<String, dynamic>? read(Store store, int task) {
    final v = store.data.kv[WritingKeys.draft(task)];
    if (v is Map) {
      final m = v.cast<String, dynamic>();
      if (m.s('text').trim().isNotEmpty) return m;
    }
    return null;
  }

  /// Saves (or clears, if [text] is empty) the draft for [task].
  static void save(int task, String promptId, String text, int elapsedSec) {
    final store = Store.I;
    if (!store.isLoggedIn) return;
    final existing = read(store, task);
    if (text.trim().isEmpty) {
      if (existing != null && existing.s('promptId') == promptId) {
        store.setKv(WritingKeys.draft(task), null);
      }
      return;
    }
    if (existing != null &&
        existing.s('promptId') == promptId &&
        existing.s('text') == text) {
      return;
    }
    store.setKv(WritingKeys.draft(task), <String, dynamic>{
      'promptId': promptId,
      'text': text,
      'updatedAt': DateTime.now().toIso8601String(),
      'elapsedSec': elapsedSec,
    });
  }

  static void clear(int task) {
    if (Store.I.data.kv.containsKey(WritingKeys.draft(task))) {
      Store.I.setKv(WritingKeys.draft(task), null);
    }
  }

  /// All drafts as {task, promptId, text, updatedAt?, words}, newest first.
  static List<Map<String, dynamic>> all(Store store) {
    final out = <Map<String, dynamic>>[];
    for (final task in const <int>[1, 2]) {
      final d = read(store, task);
      if (d == null) continue;
      out.add(<String, dynamic>{...d, 'task': task});
    }
    out.sort((a, b) => b.s('updatedAt').compareTo(a.s('updatedAt')));
    return out;
  }

  /// "saved 2 h ago" / "saved draft".
  static String savedLabel(Map<String, dynamic> d) {
    final at = DateTime.tryParse(d.s('updatedAt'));
    if (at == null) return 'saved draft';
    final ago = Store.timeAgo(at);
    return ago == 'Just now' ? 'saved just now' : 'saved $ago';
  }
}

/// Words as the scorer counts them.
int essayWords(String text) =>
    RegExp(r"[A-Za-z0-9']+").allMatches(text).length;

// ═════════════════════════════════════════════════════════════════════════════
// Demo "AI" line-by-line review — deterministic from the text.
// Issue: {id, type ('grammar'|'vocab'), title, label, start, end, original,
//         suggestion, note, sentenceIndex}
// Strength: {start, end, text}
// ═════════════════════════════════════════════════════════════════════════════

class EssayAnalysis {
  EssayAnalysis._();

  static const linkers = <String>[
    'however', 'moreover', 'furthermore', 'therefore', 'although', 'whereas',
    'in addition', 'on the other hand', 'for example', 'for instance',
    'consequently', 'nevertheless', 'in conclusion', 'overall', 'firstly',
    'secondly', 'finally', 'as a result', 'in contrast', 'to begin with',
    'meanwhile', 'admittedly',
  ];

  static const _informal = <String, String>{
    'very good things': 'tangible benefits',
    'good things': 'benefits',
    'a lot of': 'a great deal of',
    'lots of': 'numerous',
    'kids': 'children',
    'get': 'obtain',
    'gets': 'obtains',
    'got': 'obtained',
    'stuff': 'possessions',
    'really': 'genuinely',
    'very good': 'highly beneficial',
    'very bad': 'extremely harmful',
    'big': 'significant',
    'okay': 'acceptable',
    "can't": 'cannot',
    "don't": 'do not',
    "doesn't": 'does not',
    "won't": 'will not',
    "isn't": 'is not',
    "aren't": 'are not',
    "it's": 'it is',
  };

  static const _synonyms = <String, String>{
    'important': 'crucial',
    'people': 'individuals',
    'problem': 'issue',
    'problems': 'issues',
    'good': 'beneficial',
    'bad': 'harmful',
    'many': 'numerous',
    'think': 'believe',
    'benefit': 'advantage',
    'benefits': 'advantages',
    'increase': 'rise',
    'change': 'shift',
    'show': 'illustrate',
    'shows': 'illustrates',
    'help': 'support',
    'use': 'utilise',
    'very': 'highly',
    'money': 'funds',
    'jobs': 'positions',
  };

  static const _openers = <String, String>{
    'And': 'Moreover,',
    'But': 'However,',
    'So': 'Therefore,',
    'Also': 'In addition,',
  };

  static const _commaLinkers = <String>[
    'On the other hand', 'In addition', 'For example', 'For instance',
    'As a result', 'In conclusion', 'In contrast', 'To begin with',
    'However', 'Moreover', 'Furthermore', 'Therefore', 'Consequently',
    'Nevertheless', 'Firstly', 'Secondly', 'Finally', 'Overall',
  ];

  static const _strongPhrases = <String>[
    'moreover', 'furthermore', 'in addition', 'consequently', 'nevertheless',
    'in contrast', 'as a result', 'whereas', 'on the other hand',
    'for instance', 'to begin with', 'admittedly', 'in conclusion',
  ];

  static String _cap(String s) =>
      s.isEmpty ? s : s.substring(0, 1).toUpperCase() + s.substring(1);

  static String _matchCase(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    final first = original.substring(0, 1);
    if (first == first.toUpperCase() && first != first.toLowerCase()) {
      return _cap(replacement);
    }
    return replacement;
  }

  static RegExp _word(String phrase) =>
      RegExp('\\b${RegExp.escape(phrase)}\\b', caseSensitive: false);

  /// Sentences with offsets: (start, end, text).
  static List<(int, int, String)> sentences(String text) {
    final out = <(int, int, String)>[];
    for (final m in RegExp(r'[^.!?\n]+[.!?]*').allMatches(text)) {
      final raw = m.group(0)!;
      final lead = raw.length - raw.trimLeft().length;
      final body = raw.trim();
      if (body.isEmpty) continue;
      final start = m.start + lead;
      out.add((start, start + body.length, body));
    }
    return out;
  }

  static Map<String, dynamic> _issue(
    String type,
    String label,
    int start,
    int end,
    String original,
    String suggestion,
    String note,
  ) =>
      <String, dynamic>{
        'type': type,
        'title': type == 'vocab' ? 'Vocabulary' : 'Grammar',
        'label': label,
        'start': start,
        'end': end,
        'original': original,
        'suggestion': suggestion,
        'note': note,
      };

  /// Generates the line-by-line review for [text].
  static List<Map<String, dynamic>> issues(String text) {
    final c = <Map<String, dynamic>>[];
    final sents = sentences(text);

    // 1 · lowercase "i"
    for (final m in RegExp(r"(^|\s)i(?=[\s',])").allMatches(text)) {
      final start = m.start + m.group(1)!.length;
      c.add(_issue('grammar', 'capital letter', start, start + 1, 'i', 'I',
          'The pronoun “I” is always written with a capital letter.'));
      break;
    }

    // 2 · sentence openers And / But / So / Also
    var openers = 0;
    for (final s in sents) {
      if (openers >= 2) break;
      final m = RegExp(r'^(And|But|So|Also)\b,?').firstMatch(s.$3);
      if (m == null) continue;
      final word = m.group(1)!;
      final orig = m.group(0)!;
      c.add(_issue(
        'grammar',
        'sentence opener',
        s.$1,
        s.$1 + orig.length,
        orig,
        _openers[word] ?? orig,
        'Starting a sentence with “$word” sounds informal. A linking phrase such as “${_openers[word]}” reads better in an academic essay and improves Coherence & Cohesion.',
      ));
      openers++;
    }

    // 3 · missing comma after a linker at the start of a sentence
    var commas = 0;
    for (final s in sents) {
      if (commas >= 2) break;
      for (final l in _commaLinkers) {
        if (s.$3.length > l.length &&
            s.$3.toLowerCase().startsWith(l.toLowerCase()) &&
            s.$3.substring(l.length, l.length + 1) == ' ') {
          final orig = s.$3.substring(0, l.length);
          c.add(_issue('grammar', 'punctuation', s.$1, s.$1 + l.length, orig,
              '$orig,',
              'Put a comma after an introductory linker such as “$orig”. It separates the link from the main clause and makes the sentence easier to read.'));
          commas++;
          break;
        }
      }
    }

    // 4 · over-long sentences → split
    var longs = 0;
    for (final s in sents) {
      if (longs >= 2) break;
      final n = essayWords(s.$3);
      if (n <= 35) continue;
      for (final m in RegExp(r",\s+(and|but|so)\s+([A-Za-z']+)").allMatches(s.$3)) {
        if (essayWords(s.$3.substring(0, m.start)) < 8) continue;
        final join = m.group(1)!;
        final next = m.group(2)!;
        final replacement = switch (join) {
          'but' => '. However, $next',
          'so' => '. As a result, $next',
          _ => '. ${_cap(next)}',
        };
        c.add(_issue('grammar', 'long sentence', s.$1 + m.start,
            s.$1 + m.end, m.group(0)!, replacement,
            'This sentence has $n words. Splitting it here makes it easier to follow and reduces the risk of grammar slips.'));
        longs++;
        break;
      }
    }

    // 5 · informal words
    var informal = 0;
    for (final e in _informal.entries) {
      if (informal >= 4) break;
      final m = _word(e.key).firstMatch(text);
      if (m == null) continue;
      final orig = m.group(0)!;
      c.add(_issue('vocab', 'informal word', m.start, m.end, orig,
          _matchCase(orig, e.value),
          '“$orig” is informal. A more precise, academic choice such as “${e.value}” raises your Lexical Resource score.'));
      informal++;
    }

    // 6 · repeated words → synonym on the third use
    var repeats = 0;
    for (final e in _synonyms.entries) {
      if (repeats >= 2) break;
      final all = _word(e.key).allMatches(text).toList();
      if (all.length < 3) continue;
      final m = all[2];
      final orig = m.group(0)!;
      c.add(_issue('vocab', 'repetition', m.start, m.end, orig,
          _matchCase(orig, e.value),
          'You use “${e.key}” ${all.length} times. Varying it with a synonym such as “${e.value}” shows a wider range of vocabulary.'));
      repeats++;
    }

    return finalize(text, c, cap: 10);
  }

  /// Orders [c], drops overlaps, caps at [cap] and numbers the issues
  /// (`id`, `sentenceIndex`).
  static List<Map<String, dynamic>> finalize(
    String text,
    List<Map<String, dynamic>> c, {
    int cap = 10,
  }) {
    final sents = sentences(text);
    c.sort((a, b) {
      final s = a.i('start').compareTo(b.i('start'));
      return s != 0 ? s : b.i('end').compareTo(a.i('end'));
    });
    final out = <Map<String, dynamic>>[];
    var cursor = -1;
    for (final i in c) {
      if (i.i('start') < cursor) continue;
      out.add(i);
      cursor = i.i('end');
      if (out.length >= cap) break;
    }
    for (var k = 0; k < out.length; k++) {
      out[k]['id'] = 'i${k + 1}';
      var idx = 0;
      for (var j = 0; j < sents.length; j++) {
        if (sents[j].$1 <= out[k].i('start')) idx = j;
      }
      out[k]['sentenceIndex'] = idx;
    }
    return out;
  }

  /// Well-chosen linkers and less common words, not overlapping [issues].
  static List<Map<String, dynamic>> strengths(
    String text,
    List<Map<String, dynamic>> issues,
  ) {
    final taken = <(int, int)>[
      for (final i in resolve(text, issues)) (i.i('start'), i.i('end')),
    ];
    bool free(int s, int e) => !taken.any((r) => s < r.$2 && e > r.$1);
    final out = <Map<String, dynamic>>[];
    void add(int s, int e) {
      if (out.length >= 6 || !free(s, e)) return;
      taken.add((s, e));
      out.add(<String, dynamic>{
        'start': s,
        'end': e,
        'text': text.substring(s, e),
      });
    }

    for (final p in _strongPhrases) {
      final m = _word(p).firstMatch(text);
      if (m != null) add(m.start, m.end);
    }
    for (final m in RegExp(r'[A-Za-z]{11,}').allMatches(text)) {
      add(m.start, m.end);
    }
    out.sort((a, b) => a.i('start').compareTo(b.i('start')));
    return out;
  }

  /// Issues whose offsets are valid for [text] (repairs stale offsets by
  /// searching for the original phrase), sorted and non-overlapping.
  static List<Map<String, dynamic>> resolve(
    String text,
    List<Map<String, dynamic>> issues,
  ) {
    final fixed = <Map<String, dynamic>>[];
    for (final raw in issues) {
      final i = Map<String, dynamic>.from(raw);
      final orig = i.s('original');
      if (orig.isEmpty) continue;
      var s = i.i('start');
      var e = i.i('end');
      final ok = s >= 0 && e <= text.length && s < e &&
          text.substring(s, e) == orig;
      if (!ok) {
        s = text.indexOf(orig);
        if (s < 0) continue;
        e = s + orig.length;
      }
      i['start'] = s;
      i['end'] = e;
      fixed.add(i);
    }
    fixed.sort((a, b) => a.i('start').compareTo(b.i('start')));
    final out = <Map<String, dynamic>>[];
    var cursor = -1;
    for (final i in fixed) {
      if (i.i('start') < cursor) continue;
      out.add(i);
      cursor = i.i('end');
    }
    return out;
  }

  /// Applies the suggestions of [issues] (or only [ids] if given).
  /// Returns the new text and the marks of the replaced parts.
  static (String, List<Map<String, dynamic>>) applyFixes(
    String text,
    List<Map<String, dynamic>> issues, {
    Set<String>? ids,
  }) {
    final b = StringBuffer();
    final marks = <Map<String, dynamic>>[];
    var cursor = 0;
    for (final i in resolve(text, issues)) {
      if (ids != null && !ids.contains(i.s('id'))) continue;
      final s = i.i('start');
      final e = i.i('end');
      if (s < cursor) continue;
      b.write(text.substring(cursor, s));
      final ns = b.length;
      b.write(i.s('suggestion'));
      marks.add(<String, dynamic>{
        'start': ns,
        'end': b.length,
        'mark': 'new',
        'issueId': i.s('id'),
      });
      cursor = e;
    }
    b.write(text.substring(cursor));
    return (b.toString(), marks);
  }

  /// Splits [text] into paragraphs of segments {text, mark?, issueId?}
  /// using [marks] ({start, end, mark, issueId?}).
  static List<List<Map<String, dynamic>>> paragraphs(
    String text,
    List<Map<String, dynamic>> marks,
  ) {
    final sorted = List<Map<String, dynamic>>.from(marks)
      ..sort((a, b) => a.i('start').compareTo(b.i('start')));
    final out = <List<Map<String, dynamic>>>[];
    for (final p in RegExp(r'[^\n]+').allMatches(text)) {
      if (p.group(0)!.trim().isEmpty) continue;
      final ps = p.start;
      final pe = p.end;
      final segs = <Map<String, dynamic>>[];
      var cursor = ps;
      for (final m in sorted) {
        final s = m.i('start');
        final e = m.i('end');
        if (s < cursor || s < ps || e > pe || s >= e) continue;
        if (s > cursor) {
          segs.add(<String, dynamic>{'text': text.substring(cursor, s)});
        }
        segs.add(<String, dynamic>{
          'text': text.substring(s, e),
          'mark': m.s('mark'),
          'issueId': m.s('issueId'),
        });
        cursor = e;
      }
      if (cursor < pe) {
        segs.add(<String, dynamic>{'text': text.substring(cursor, pe)});
      }
      out.add(segs);
    }
    return out;
  }

  /// Marks every linking phrase in [text] as `mark` (non-overlapping).
  static List<Map<String, dynamic>> linkerMarks(String text, String mark) {
    final found = <Map<String, dynamic>>[];
    for (final l in linkers) {
      for (final m in _word(l).allMatches(text)) {
        found.add(<String, dynamic>{'start': m.start, 'end': m.end, 'mark': mark});
      }
    }
    found.sort((a, b) {
      final s = a.i('start').compareTo(b.i('start'));
      return s != 0 ? s : b.i('end').compareTo(a.i('end'));
    });
    final out = <Map<String, dynamic>>[];
    var cursor = -1;
    for (final f in found) {
      if (f.i('start') < cursor) continue;
      out.add(f);
      cursor = f.i('end');
    }
    return out;
  }

  /// Finds [phrase] in [text]: the first exact occurrence that doesn't
  /// overlap [used], else the first such case-insensitive one. Null if absent.
  static (int, int)? locate(String text, String phrase, List<(int, int)> used) {
    if (phrase.isEmpty || text.isEmpty) return null;
    bool free(int s, int e) => !used.any((r) => s < r.$2 && e > r.$1);
    (int, int)? scan(String hay, String needle) {
      var from = 0;
      while (from <= hay.length - needle.length) {
        final s = hay.indexOf(needle, from);
        if (s < 0) return null;
        final e = s + needle.length;
        if (free(s, e)) return (s, e);
        from = s + 1;
      }
      return null;
    }

    return scan(text, phrase) ??
        scan(text.toLowerCase(), phrase.toLowerCase());
  }

  static int linkerCount(String text) {
    var n = 0;
    for (final l in linkers) {
      n += _word(l).allMatches(text).length;
    }
    return n;
  }

  static int complexCount(String text) {
    final re = RegExp(
      r'\b(which|who|whom|whose|because|although|though|while|whereas|when|if|since|unless|as a result)\b',
      caseSensitive: false,
    );
    return sentences(text).where((s) => re.hasMatch(s.$3)).length;
  }

  static int rareWordCount(String text) => RegExp(r'[A-Za-z]{9,}')
      .allMatches(text)
      .map((m) => m.group(0)!.toLowerCase())
      .toSet()
      .length;
}

// ═════════════════════════════════════════════════════════════════════════════
// Attempts
// ═════════════════════════════════════════════════════════════════════════════

class WritingService {
  WritingService._();

  /// The band of the improved version shown for [a]: two bands up to a
  /// Band 8 for most essays (6 → 8, 5 → 7), Band 9 from Band 8 upwards.
  /// An already fetched rewrite keeps the band it was written for.
  static double rewriteTarget(Attempt a) {
    final rw = a.data.m('rewrite');
    if (rw.s('text').trim().isNotEmpty) {
      final cached = rw['target'];
      return cached is num ? cached.toDouble() : 8; // older rewrites were Band 8
    }
    final band = a.band ?? 6;
    if (band >= 8) return 9;
    final up = band.floorToDouble() + 2;
    return up > 8 ? 8 : up;
  }

  /// "Band 8 version" / "Band 9 version" for [a].
  static String rewriteLabel(Attempt a) => 'Band ${Store.formatBand(rewriteTarget(a)).replaceAll('.0', '')} version';

  static int taskOf(Attempt a) {
    final t = a.data['task'];
    if (t is num) return t.toInt();
    return a.kind == 'task1' ? 1 : 2;
  }

  /// Scores [text], stores the attempt, clears the task's draft.
  static Attempt submit({
    required Map<String, dynamic> prompt,
    required String text,
    required int elapsedSec,
  }) {
    final task = prompt.i('task') == 1 ? 1 : 2;
    final r = Scoring.writing(text, task: task);
    final issues = EssayAnalysis.issues(text);
    final strengths = EssayAnalysis.strengths(text, issues);
    final a = Attempt(
      id: Store.newId('att'),
      skill: Skill.writing,
      kind: 'task$task',
      title: prompt.s('shortTitle'),
      refId: prompt.s('id'),
      band: (r['band'] as num).toDouble(),
      durationSec: math.max(60, elapsedSec),
      createdAt: DateTime.now(),
      data: <String, dynamic>{
        'text': text,
        'prompt': prompt.s('prompt'),
        'promptId': prompt.s('id'),
        'task': task,
        'criteria': <String, dynamic>{
          'TA': r['TA'],
          'CC': r['CC'],
          'LR': r['LR'],
          'GRA': r['GRA'],
        },
        'words': r['words'],
        'feedback': r['feedback'],
        'issues': issues,
        'strengths': strengths,
        'source': 'demo',
      },
    );
    Store.I.addAttempt(a);
    WritingDrafts.clear(task);
    return a;
  }

  /// The essay waiting to be scored by C12 (set by the editors, also passed
  /// as route args `{'essay': …}`): {prompt (map), text, elapsedSec}.
  static Map<String, dynamic>? pending;

  /// Scores [text] with the AI (falls back to the local demo scorer when the
  /// AI is unavailable or fails), stores the attempt, clears the draft.
  static Future<Attempt> evaluate({
    required Map<String, dynamic> prompt,
    required String text,
    required int elapsedSec,
  }) async {
    final task = prompt.i('task') == 1 ? 1 : 2;
    // The server stores its graded copy under this id too (one record).
    final id = Store.newId('att');
    Map<String, dynamic>? r;
    try {
      final data = task == 1 ? WritingContent.visualText(prompt) : '';
      r = await AiService.evaluateWriting(
        task: task,
        prompt: data.isEmpty
            ? prompt.s('prompt')
            : '${prompt.s('prompt')}\n\nData shown in the visual:\n$data',
        text: text,
        attemptId: id,
        promptId: prompt.s('id'),
        title: prompt.s('shortTitle'),
        durationSec: math.max(60, elapsedSec),
      ).timeout(const Duration(seconds: 95));
    } catch (_) {
      r = null;
    }
    final band = r == null ? null : r['band'];
    if (r == null || band is! num) {
      final a = submit(prompt: prompt, text: text, elapsedSec: elapsedSec);
      // e.g. the free-plan limit: say so on the report.
      const shown = <String>{'quota_reached', 'too_short', 'ai_failed', 'ai_busy', 'ai_not_configured'};
      if (shown.contains(AiService.lastErrorCode) && (AiService.lastError ?? '').isNotEmpty) {
        a.data['offlineReason'] = AiService.lastError;
        Store.I.commit();
      }
      return a;
    }
    final overall = Store.roundBand(band.toDouble());
    final crit = r.m('criteria');
    double cb(String k) {
      final v = crit[k];
      return v is num ? Store.roundBand(v.toDouble()) : overall;
    }

    final issues = aiIssues(text, r.l('issues'));
    final words = r['words'] is num ? (r['words'] as num).toInt() : essayWords(text);
    final a = Attempt(
      id: id,
      skill: Skill.writing,
      kind: 'task$task',
      title: prompt.s('shortTitle'),
      refId: prompt.s('id'),
      band: overall,
      durationSec: math.max(60, elapsedSec),
      createdAt: DateTime.now(),
      data: <String, dynamic>{
        'text': text,
        'prompt': prompt.s('prompt'),
        'promptId': prompt.s('id'),
        'task': task,
        'criteria': <String, dynamic>{
          'TA': cb('TA'),
          'CC': cb('CC'),
          'LR': cb('LR'),
          'GRA': cb('GRA'),
        },
        'words': words,
        'feedback': _strings(r['feedback']),
        'summary': r.s('summary'),
        'criteriaFeedback': r.m('criteriaFeedback'),
        if (r.s('enhancedSnippet').isNotEmpty) 'enhancedSnippet': r.s('enhancedSnippet'),
        'aiStrengths': _strings(r['strengths']),
        'issues': issues,
        'strengths': EssayAnalysis.strengths(text, issues),
        'source': 'ai',
      },
    );
    Store.I.addAttempt(a);
    WritingDrafts.clear(task);
    return a;
  }

  /// A list of strings from AI output (strings, or maps with text/note).
  static List<String> _strings(dynamic v) {
    final out = <String>[];
    if (v is! List) return out;
    for (final e in v) {
      if (e is String) {
        if (e.trim().isNotEmpty) out.add(e.trim());
      } else if (e is Map) {
        final m = e.cast<String, dynamic>();
        final s = m.s('text').isNotEmpty ? m.s('text') : m.s('note');
        if (s.trim().isNotEmpty) out.add(s.trim());
      }
    }
    return out;
  }

  static const _aiTitles = <String, String>{
    'grammar': 'Grammar',
    'vocabulary': 'Vocabulary',
    'vocab': 'Vocabulary',
    'cohesion': 'Cohesion',
    'task': 'Task response',
    'punctuation': 'Punctuation',
    'style': 'Style',
  };

  /// AI issues {original, suggestion, type, note} → the line-review issue
  /// shape with offsets. Issues whose `original` isn't in [text] are dropped.
  static List<Map<String, dynamic>> aiIssues(String text, List<Map<String, dynamic>> raw) {
    final used = <(int, int)>[];
    final c = <Map<String, dynamic>>[];
    for (final r in raw) {
      final orig = r.s('original').trim();
      if (orig.isEmpty) continue;
      final hit = EssayAnalysis.locate(text, orig, used);
      if (hit == null) continue;
      used.add(hit);
      final category = r.s('type').toLowerCase().trim();
      final isVocab = category == 'vocabulary' ||
          category == 'vocab' ||
          category == 'style';
      c.add(<String, dynamic>{
        'type': isVocab ? 'vocab' : 'grammar',
        'category': category,
        'title': _aiTitles[category] ?? (isVocab ? 'Vocabulary' : 'Grammar'),
        'label': category.isEmpty ? (isVocab ? 'vocabulary' : 'grammar') : category,
        'start': hit.$1,
        'end': hit.$2,
        'original': text.substring(hit.$1, hit.$2),
        'suggestion': r.s('suggestion'),
        'note': r.s('note'),
      });
    }
    return EssayAnalysis.finalize(text, c, cap: 20);
  }

  /// Issues stored on the attempt, or generated from its text.
  static List<Map<String, dynamic>> issuesOf(Attempt a) {
    final text = a.data.s('text');
    final raw = a.data.l('issues');
    if (raw.isNotEmpty || a.data.containsKey('issues')) {
      return EssayAnalysis.resolve(text, raw);
    }
    return EssayAnalysis.issues(text);
  }

  static List<Map<String, dynamic>> strengthsOf(Attempt a) {
    if (a.data.containsKey('strengths')) return a.data.l('strengths');
    return EssayAnalysis.strengths(a.data.s('text'), issuesOf(a));
  }

  static double criterion(Attempt a, String key) {
    final c = a.data.m('criteria');
    final v = c[key];
    if (v is num) return v.toDouble();
    return a.band ?? 0;
  }

  static String criterionNote(String key, double band, int task) {
    switch (key) {
      case 'TA':
        if (task == 1) {
          if (band >= 7) return 'Clear overview; key features well selected.';
          if (band >= 6) return 'Overview present; add more precise figures.';
          return 'Add a clear overview of the main trends.';
        }
        if (band >= 7) return 'Clear position developed throughout.';
        if (band >= 6) return 'Clear position; second idea needs an example.';
        return 'Answer every part of the question in full.';
      case 'CC':
        if (band >= 7) return 'Logical paragraphs; good range of linkers.';
        if (band >= 6) return 'Linkers repeat; check each paragraph’s focus.';
        return 'Organise ideas into clear, linked paragraphs.';
      case 'LR':
        if (band >= 7) return 'Good range; a few informal words.';
        if (band >= 6) return 'Adequate range; replace informal and repeated words.';
        return 'Limited range; learn topic vocabulary.';
      default:
        if (band >= 7) return 'Wide range of structures, mostly accurate.';
        if (band >= 6) return 'Mixed structures; some agreement slips.';
        return 'Frequent errors; practise complex sentences.';
    }
  }

  /// Top suggestions for the report (max 3).
  static List<String> suggestions(Attempt a) {
    final stored = a.data.ls('suggestions');
    if (stored.isNotEmpty) return stored.take(3).toList();
    final out = <String>[...a.data.ls('feedback')];
    final issues = issuesOf(a);
    final g = issues.where((i) => i.s('type') != 'vocab').length;
    final v = issues.where((i) => i.s('type') == 'vocab').length;
    if (g > 0) {
      out.add('Fix the $g grammar point${g == 1 ? '' : 's'} highlighted in the line-by-line review.');
    }
    if (v > 0) {
      out.add('Replace $v informal or repeated word${v == 1 ? '' : 's'} with more precise vocabulary.');
    }
    if (out.isEmpty) {
      out.add('Compare your essay with the ${rewriteLabel(a)} to find the next step up.');
    }
    return out.take(3).toList();
  }
}
