import 'dart:async';
import 'dart:math' as math;

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reading user data
//
// Content comes from the bank (`Content.readingTests` rt_01–rt_03 and
// `Content.readingPassages` rp_01–rp_09) and the question bank
// (`Content.readingBankPassages` rb_<type>_NN, `Content.readingPracticeTests`
// rpt_NN). A "ref" is a test id (full: 3 passages, Q1–40, 60 min; short
// practice test: 3 bank sets, its own minutes) or a single passage id
// (library passage: 20 min; bank set: 1.5 min per question).
//
// kv keys (per account):
//   'reading.inProgress'           {refId, testId|passageId, answers {qNo: value},
//                                   remainingSec, current, part, flagged [..]}
//   'reading.highlights.<passageId>' [{paragraph, phrase, color}]
//   'reading.notes.<passageId>'      [{paragraph, sentence, note, createdAt}]
//   'reading.lessonProgress'       {lessonId, index, correct, elapsedSec}
//   'resume'                       {label, route, args} (shared with Home)
// ─────────────────────────────────────────────────────────────────────────────

/// Writes a kv value without notifying immediately (safe from `dispose`);
/// listeners are notified in a microtask.
void persistKv(Map<String, Object?> values) {
  final kv = Store.I.data.kv;
  values.forEach((k, v) {
    if (v == null) {
      kv.remove(k);
    } else {
      kv[k] = v;
    }
  });
  scheduleMicrotask(Store.I.commit);
}

Map<String, dynamic> _asMap(Object? v) {
  if (v is Map) return v.cast<String, dynamic>();
  return <String, dynamic>{};
}

/// One question of a test or passage, with its global number.
class ReadingItem {
  const ReadingItem({
    required this.number,
    required this.local,
    required this.part,
    required this.q,
    required this.group,
    required this.passage,
    this.slot = 0,
  });

  /// Global number (1–40 in a full test).
  final int number;

  /// Number inside its passage (as stored in the bank).
  final int local;

  /// Passage index inside the ref (0 for a single passage).
  final int part;
  final Map<String, dynamic> q;
  final Map<String, dynamic> group;
  final Map<String, dynamic> passage;

  /// Position inside a "choose TWO" question (`numbers: [6, 7]` → 0, 1).
  final int slot;

  String get type => group.s('type');
  String get passageId => passage.s('id');

  /// The stored answer ("choose TWO": the letter of this slot).
  String get answer {
    final a = q['answer'];
    if (a is List) return slot < a.length ? '${a[slot]}' : '';
    return a == null ? '' : '$a';
  }

  /// Global numbers of the whole question (two for "choose TWO").
  List<int> get siblingNumbers {
    final nums = q['numbers'];
    if (nums is List && nums.length > 1) {
      final offset = number - local;
      return <int>[for (final n in nums) if (n is num) n.toInt() + offset];
    }
    return <int>[number];
  }
}

/// Resolves test / passage ids against the content bank.
class ReadingRefs {
  ReadingRefs._();

  static final Map<String, List<ReadingItem>> _cache = <String, List<ReadingItem>>{};

  static bool isTest(String id) => Content.readingTest(id).isNotEmpty;

  /// A short practice test built from bank sets (rpt_NN).
  static bool isShortTest(String id) => Content.isPracticeTest(id);

  /// A single question-bank set (rb_<type>_NN).
  static bool isBank(String id) => Content.isBankPassage(id);

  /// Question bank content (bank set or short practice test).
  static bool isBankContent(String id) => isBank(id) || isShortTest(id);

  static bool exists(String id) =>
      id.isNotEmpty && (isTest(id) || Content.readingPassage(id).isNotEmpty);

  /// Passages of a ref with their global question offset.
  static List<(Map<String, dynamic>, int)> parts(String id) {
    if (isTest(id)) return Content.readingTestPassages(id);
    final p = Content.readingPassage(id);
    if (p.isEmpty) return <(Map<String, dynamic>, int)>[];
    return <(Map<String, dynamic>, int)>[(p, 0)];
  }

  static String title(String id) {
    if (isTest(id)) return Content.readingTest(id).s('title');
    return Content.readingPassage(id).s('title');
  }

  /// "Test 1" for tests, a short passage title otherwise.
  static String shortTitle(String id) {
    if (isShortTest(id)) return 'Practice test ${Content.readingTest(id).i('number')}';
    if (isTest(id)) return 'Test ${Content.readingTest(id).i('number')}';
    var s = title(id).split(':').first.trim();
    if (s.startsWith('The ')) s = s.substring(4);
    if (s.length <= 22) return s;
    final words = s.split(' ');
    var out = '';
    for (final w in words) {
      final next = out.isEmpty ? w : '$out $w';
      if (next.length > 20) break;
      out = next;
    }
    return out.isEmpty ? s.substring(0, 20) : '$out…';
  }

  static int minutes(String id) {
    if (isTest(id)) {
      final m = Content.readingTest(id).i('minutes');
      return m > 0 ? m : 60;
    }
    if (isBank(id)) {
      // 1.5 minutes per question, rounded half up (same rule as the short tests).
      final n = Content.passageQuestionCount(Content.bankPassage(id));
      return math.max(5, (n * 3 + 1) ~/ 2);
    }
    return 20;
  }

  /// Header line for a single passage: "Question bank · Matching Headings".
  static String modeLabel(String id) {
    if (isShortTest(id)) return 'Practice test';
    if (isTest(id)) return 'Reading test';
    if (isBank(id)) {
      return 'Question bank · ${Content.typeName(Content.bankPassage(id).s('questionType'))}';
    }
    return 'Passage practice';
  }

  /// "Passage 4" style number of a passage id (rp_04 → 4).
  static int passageNumber(String id) {
    final m = RegExp(r'(\d+)$').firstMatch(id);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  static List<ReadingItem> items(String id) {
    final cached = _cache[id];
    if (cached != null) return cached;
    final out = <ReadingItem>[];
    final ps = parts(id);
    for (var i = 0; i < ps.length; i++) {
      final (p, offset) = ps[i];
      for (final g in p.l('groups')) {
        for (final q in g.l('questions')) {
          final nums = q['numbers'];
          if (nums is List && nums.length > 1) {
            // "Choose TWO letters": one item per mark.
            for (var slot = 0; slot < nums.length; slot++) {
              final n = nums[slot];
              if (n is! num) continue;
              out.add(ReadingItem(
                number: n.toInt() + offset,
                local: n.toInt(),
                part: i,
                q: q,
                group: g,
                passage: p,
                slot: slot,
              ));
            }
            continue;
          }
          out.add(ReadingItem(
            number: q.i('number') + offset,
            local: q.i('number'),
            part: i,
            q: q,
            group: g,
            passage: p,
          ));
        }
      }
    }
    out.sort((a, b) => a.number.compareTo(b.number));
    if (out.isNotEmpty) _cache[id] = out;
    return out;
  }

  /// Group types answered by typing words from the passage (unless the
  /// group has a word box, then they are answered with a letter).
  static const Set<String> typedTypes = <String>{
    'gap',
    'notes',
    'table',
    'flowchart',
    'diagram',
    'short_answer',
    'summary',
  };

  /// Lettered options of a group: {key, text} (sentence endings, features,
  /// word boxes). Empty for groups whose options are plain letters.
  static List<Map<String, dynamic>> optionObjects(Map<String, dynamic> g) =>
      g.s('type') == 'sentence_endings' ? g.l('endings') : g.l('options');

  /// Title of the option box ("List of Endings", "List of Explorers" …).
  static String optionsTitle(Map<String, dynamic> g) {
    final t = g.s('type') == 'sentence_endings' ? g.s('endingsTitle') : g.s('optionsTitle');
    if (t.isNotEmpty) return t;
    return g.s('type') == 'matching_features' ? 'List of options' : 'List of words';
  }

  /// True when the answer is typed (not chosen from letters).
  static bool isTyped(ReadingItem it) =>
      typedTypes.contains(it.type) && optionObjects(it.group).isEmpty;

  /// Letters a student chooses from (empty for typed answers and MCQ).
  static List<String> letters(ReadingItem it) {
    if (it.type == 'matching') return it.group.ls('options');
    return <String>[for (final o in optionObjects(it.group)) o.s('key')];
  }

  static bool isCorrect(ReadingItem it, String given) {
    final v = given.trim();
    if (v.isEmpty) return false;
    final accepted = it.q['accepted'] ?? it.q['answer'];
    if (isTyped(it)) return Scoring.matches(v, accepted);
    final list = accepted is List ? accepted.map((e) => '$e') : <String>['$accepted'];
    final lv = v.toLowerCase();
    return list.any((a) => a.trim().toLowerCase() == lv);
  }

  /// "iii · Too many bees…" / "B · even short delays…" / plain value.
  static String answerLabel(ReadingItem it, String value) {
    if (value.trim().isEmpty) return '—';
    if (it.type == 'heading') {
      for (final h in it.group.l('headings')) {
        if (h.s('key') == value) return '$value · ${h.s('text')}';
      }
    }
    if (it.type == 'mcq' || it.type == 'multi') {
      for (final o in it.q.l('options')) {
        if (o.s('key') == value) return '$value · ${o.s('text')}';
      }
    }
    for (final o in optionObjects(it.group)) {
      if (o.s('key') == value) return '$value · ${o.s('text')}';
    }
    return value;
  }

  /// Every correct letter of a "choose TWO" question.
  static List<String> _multiKeys(ReadingItem it) {
    final a = it.q['answer'];
    if (a is List) return <String>[for (final e in a) '$e'];
    return <String>[it.answer];
  }

  /// Correct answer for the solution card ("River Nile / Nile",
  /// "B · tiny living organisms…", "B and D · in either order").
  static String correctLabel(ReadingItem it) {
    if (it.type == 'multi') {
      final note = it.q.s('answerNote');
      return '${_multiKeys(it).join(' and ')}${note.isEmpty ? '' : ' · $note'}';
    }
    if (isTyped(it)) {
      final d = it.q.s('answerDisplay');
      return d.isNotEmpty ? d : it.answer;
    }
    return answerLabel(it, it.answer);
  }

  /// Short form of the correct answer ("B", "B & D", "River Nile").
  static String correctShort(ReadingItem it) {
    if (it.type == 'multi') return _multiKeys(it).join(' & ');
    if (isTyped(it)) {
      final d = it.q.s('answerDisplay');
      return d.isNotEmpty ? d : it.answer;
    }
    return it.answer;
  }

  static final RegExp _marker = RegExp(r'\((\d+)\)(?=\s*_{2,})');

  /// Shifts "(n)" gap markers by [offset] (question numbers in a test).
  static String renumber(String text, int offset) {
    if (offset == 0) return text;
    return text.replaceAllMapped(_marker, (m) => '(${int.parse(m.group(1)!) + offset})');
  }

  /// Flow-chart steps as plain text, including the steps inside
  /// `{branches: [[…], […]]}` forks.
  static List<String> flowSteps(Object? steps) {
    final out = <String>[];
    if (steps is! List) return out;
    for (final s in steps) {
      if (s is Map) {
        final branches = s['branches'];
        if (branches is List) {
          for (final b in branches) {
            if (b is List) out.addAll(b.map((e) => '$e'));
          }
        }
      } else if (s != null) {
        out.add('$s');
      }
    }
    return out;
  }

  /// The line / cell / step / sentence of a group that holds gap [local].
  static String blankContext(Map<String, dynamic> g, int local) {
    final marker = '($local)';
    final text = g.s('text');
    if (text.contains(marker)) {
      for (final sentence in text.split(RegExp(r'(?<=[.!?])\s+'))) {
        if (sentence.contains(marker)) return sentence.trim();
      }
      return text;
    }
    for (final line in g.l('lines')) {
      if (line.s('text').contains(marker)) return line.s('text');
    }
    final rows = g['rows'];
    if (rows is List) {
      final columns = g.ls('columns');
      for (final row in rows) {
        if (row is! List) continue;
        for (var j = 0; j < row.length; j++) {
          final cell = '${row[j]}';
          if (!cell.contains(marker)) continue;
          if (j == 0 || row.isEmpty) return cell;
          final column = j < columns.length ? '${columns[j]}: ' : '';
          return '${row[0]} · $column$cell';
        }
      }
    }
    for (final step in flowSteps(g['steps'])) {
      if (step.contains(marker)) return step;
    }
    for (final label in g.l('labels')) {
      if (label.s('text').contains(marker)) return label.s('text');
    }
    return '';
  }

  /// What the question asks: its own text, or the gap's line in a summary,
  /// notes, table, flow-chart or diagram (numbered like the test).
  static String questionText(ReadingItem it) {
    final text = it.q.s('text');
    if (text.isNotEmpty) return text;
    final ctx = blankContext(it.group, it.local);
    if (ctx.isEmpty) return 'Question ${it.number}';
    return renumber(ctx, it.number - it.local);
  }

  /// "Questions 14–18" for a group of a ref.
  static String groupRange(List<ReadingItem> all, int part, String groupId) {
    final nums = <int>[
      for (final it in all)
        if (it.part == part && it.group.s('id') == groupId) it.number,
    ];
    if (nums.isEmpty) return '';
    if (nums.length == 1) return 'Question ${nums.first}';
    return 'Questions ${nums.first}–${nums.last}';
  }

  static String partRange(List<ReadingItem> all, int part) {
    final nums = <int>[
      for (final it in all)
        if (it.part == part) it.number,
    ];
    if (nums.isEmpty) return '';
    return '${nums.first}–${nums.last}';
  }
}

/// Attempt kind for a ref.
String readingKindFor(String refId) => ReadingRefs.isTest(refId) ? 'test' : 'mini';

/// Latest scored attempt of a test or passage.
Attempt? latestReadingAttempt(Store store, String refId) {
  for (final a in store.attemptsFor(skill: Skill.reading)) {
    if (a.kind != 'lesson' && a.refId == refId) return a;
  }
  return null;
}

/// The reading test/passage currently saved as "in progress" (null if none).
Map<String, dynamic>? readingInProgress(Store store) {
  final v = store.kv<Map>('reading.inProgress');
  if (v == null) return null;
  final m = v.cast<String, dynamic>();
  final id = m.s('refId');
  return ReadingRefs.exists(id) ? m : null;
}

/// Route args that open [refId] ({'testId'} or {'passageId'}).
Map<String, dynamic> readingArgsFor(String refId) => ReadingRefs.isTest(refId)
    ? <String, dynamic>{'testId': refId}
    : <String, dynamic>{'passageId': refId};

/// Holds answers, highlights, flags and the countdown for the reading test or
/// passage that is open, so the Passage (E2) and Questions (E3) screens share
/// one session. Saved to kv as "in progress" whenever the student leaves;
/// cleared on submit.
class ReadingSession {
  ReadingSession._();

  static String refId = '';
  static bool active = false;
  static String _owner = '';
  static final Map<int, String> answers = <int, String>{};
  static final Set<int> flagged = <int>{};

  /// Highlights per passage id.
  static final Map<String, List<Map<String, dynamic>>> highlights =
      <String, List<Map<String, dynamic>>>{};
  static DateTime _deadline = DateTime.now();
  static int limitSec = 3600;
  static int current = 0;

  /// Index of the passage on screen (0 for a single passage).
  static int part = 0;

  static bool get isTest => ReadingRefs.isTest(refId);
  static String get title => ReadingRefs.title(refId);
  static List<(Map<String, dynamic>, int)> get parts => ReadingRefs.parts(refId);
  static List<ReadingItem> get items => ReadingRefs.items(refId);
  static int get partCount => parts.length;

  static Map<String, dynamic> get passage {
    final ps = parts;
    if (ps.isEmpty) return <String, dynamic>{};
    final i = part < 0 ? 0 : (part >= ps.length ? ps.length - 1 : part);
    return ps[i].$1;
  }

  static String get passageId => passage.s('id');

  static List<Map<String, dynamic>> get paragraphs => passage.l('paragraphs');

  static List<Map<String, dynamic>> get groups => passage.l('groups');

  /// Items of the passage on screen.
  static List<ReadingItem> get partItems => <ReadingItem>[
        for (final it in items)
          if (it.part == part) it,
      ];

  static List<int> get numbers => <int>[for (final it in items) it.number];

  static List<int> get partNumbers => <int>[for (final it in partItems) it.number];

  static String get partRange => ReadingRefs.partRange(items, part);

  static ReadingItem? item(int number) {
    for (final it in items) {
      if (it.number == number) return it;
    }
    return null;
  }

  static List<Map<String, dynamic>> highlightsFor(String pid) =>
      highlights.putIfAbsent(pid, () => <Map<String, dynamic>>[]);

  static Map<String, dynamic> paragraph(String letter) {
    for (final p in paragraphs) {
      if (p.s('letter') == letter) return p;
    }
    return <String, dynamic>{};
  }

  static String _defaultRef() {
    final store = Store.I;
    for (final t in Content.readingTests) {
      if (latestReadingAttempt(store, t.s('id')) == null) return t.s('id');
    }
    final tests = Content.readingTests;
    if (tests.isNotEmpty) return tests.first.s('id');
    final ps = Content.readingPassages;
    return ps.isEmpty ? '' : ps.first.s('id');
  }

  static void _reset(String id) {
    refId = id;
    active = true;
    _owner = Store.I.current?.id ?? '';
    answers.clear();
    flagged.clear();
    highlights.clear();
    part = 0;
    final nums = numbers;
    current = nums.isEmpty ? 0 : nums.first;
    limitSec = ReadingRefs.minutes(id) * 60;
    _deadline = DateTime.now().add(Duration(seconds: limitSec));
    // The student's own saved highlights for these passages.
    for (final (p, _) in parts) {
      final pid = p.s('id');
      highlights[pid] = <Map<String, dynamic>>[
        for (final h in Store.I.kvList('reading.highlights.$pid')) Map<String, dynamic>.from(h),
      ];
    }
  }

  /// Fresh attempt at [id] (no answers).
  static void start(String id) => _reset(id);

  static void _resume(Map<String, dynamic> saved) {
    _reset(saved.s('refId'));
    _asMap(saved['answers']).forEach((k, v) {
      final n = int.tryParse(k);
      if (n != null && v != null) answers[n] = '$v';
    });
    final f = saved['flagged'];
    if (f is List) {
      for (final e in f) {
        if (e is num) flagged.add(e.toInt());
      }
    }
    final p = saved.i('part');
    part = p >= 0 && p < partCount ? p : 0;
    final cur = saved.i('current');
    if (numbers.contains(cur)) focus(cur);
    final rem = saved.i('remainingSec');
    _deadline = DateTime.now().add(
      Duration(seconds: rem > 0 && rem <= limitSec ? rem : limitSec),
    );
  }

  /// Opens a ref from route args ({'testId'} / {'passageId'}): resumes its
  /// saved progress or starts it fresh. Without an id: keeps the open
  /// session, else resumes the saved one, else starts the next test.
  static void open(Map<String, dynamic> args) {
    final me = Store.I.current?.id ?? '';
    if (_owner != me) active = false;
    final a = args['testId'];
    final b = args['passageId'];
    final id = a is String && a.isNotEmpty ? a : (b is String ? b : '');
    final saved = readingInProgress(Store.I);
    if (ReadingRefs.exists(id)) {
      if (active && refId == id) return;
      if (saved != null && saved.s('refId') == id) {
        _resume(saved);
      } else {
        start(id);
      }
      return;
    }
    if (active && ReadingRefs.exists(refId)) return;
    if (saved != null) {
      _resume(saved);
      return;
    }
    start(_defaultRef());
  }

  /// Make sure a session exists (screens opened without arguments).
  static void ensure() => open(const <String, dynamic>{});

  /// Saves the open test as "in progress" (+ Home's resume card).
  static void save() {
    if (!active || refId.isEmpty) return;
    if (_owner != (Store.I.current?.id ?? '')) return;
    final given = <String, dynamic>{
      for (final e in answers.entries)
        if (e.value.trim().isNotEmpty) '${e.key}': e.value,
    };
    final values = <String, Object?>{
      'reading.inProgress': <String, dynamic>{
        'refId': refId,
        ...readingArgsFor(refId),
        'answers': given,
        'remainingSec': remainingSeconds,
        'current': current,
        'part': part,
        'flagged': flagged.toList(),
      },
      'resume': <String, dynamic>{
        'label': 'Resume Reading · ${ReadingRefs.shortTitle(refId)}',
        'route': Routes.readingPassage,
        'args': readingArgsFor(refId),
      },
    };
    highlights.forEach((pid, list) {
      values['reading.highlights.$pid'] = <Map<String, dynamic>>[
        for (final h in list) Map<String, dynamic>.from(h),
      ];
    });
    persistKv(values);
  }

  /// Scores every question, records the attempt and clears the in-progress
  /// state. Returns the new attempt.
  static Attempt submit() {
    final all = items;
    final correct = <int>[];
    final given = <String, dynamic>{};
    for (final it in all) {
      final v = (answers[it.number] ?? '').trim();
      if (v.isNotEmpty) given['${it.number}'] = v;
      if (ReadingRefs.isCorrect(it, v)) correct.add(it.number);
    }
    final elapsed = limitSec - remainingSeconds;
    final test = isTest;
    final attempt = Attempt(
      id: Store.newId('att'),
      skill: Skill.reading,
      kind: readingKindFor(refId),
      title: title,
      refId: refId,
      band: Scoring.readingBand(correct.length, all.length),
      score: correct.length,
      total: all.length,
      durationSec: math.max(60, elapsed),
      createdAt: DateTime.now(),
      data: <String, dynamic>{
        if (test) 'testId': refId else 'passageId': refId,
        'answers': given,
        'correct': correct,
        'total': all.length,
        'passages': <String>[for (final (p, _) in parts) p.s('id')],
        'flagged': flagged.toList(),
      },
    );
    active = false;
    final kv = Store.I.data.kv;
    kv.remove('reading.inProgress');
    final resume = kv['resume'];
    if (resume is Map && resume['route'] == Routes.readingPassage) {
      kv.remove('resume');
    }
    highlights.forEach((pid, list) {
      kv['reading.highlights.$pid'] = <Map<String, dynamic>>[
        for (final h in list) Map<String, dynamic>.from(h),
      ];
    });
    Store.I.addAttempt(attempt);
    return attempt;
  }

  static int get remainingSeconds {
    final s = _deadline.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  static bool isAnswered(int number) => (answers[number] ?? '').trim().isNotEmpty;

  static int get answeredCount => numbers.where(isAnswered).length;

  /// Moves focus to [number] (and to its passage).
  static void focus(int number) {
    current = number;
    final it = item(number);
    if (it != null) part = it.part;
  }

  /// Shows passage [index] and focuses its first question.
  static void showPart(int index) {
    if (index < 0 || index >= partCount) return;
    part = index;
    final nums = partNumbers;
    if (nums.isNotEmpty && !nums.contains(current)) current = nums.first;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Derived reading stats (landing / library)
// ─────────────────────────────────────────────────────────────────────────────

class ReadingStats {
  ReadingStats._();

  static const typeOrder = <String>['tfng', 'ynng', 'heading', 'matching', 'mcq', 'gap'];

  static const typeLabels = <String, String>{
    'tfng': 'T / F / NG',
    'ynng': 'Y / N / NG',
    'heading': 'Headings',
    'matching': 'Matching',
    'mcq': 'Multiple choice',
    'multi': 'Multiple choice',
    'gap': 'Gap fill',
    'matching_features': 'Matching features',
    'sentence_endings': 'Sentence endings',
    'summary': 'Summary',
    'notes': 'Note completion',
    'table': 'Table completion',
    'flowchart': 'Flow-chart',
    'diagram': 'Diagram labels',
    'short_answer': 'Short answer',
  };

  /// Question types used in the bank, in display order.
  static List<String> bankTypes() {
    final seen = <String>{};
    for (final p in Content.readingPassages) {
      for (final g in p.l('groups')) {
        seen.add(g.s('type'));
      }
    }
    return <String>[for (final t in typeOrder) if (seen.contains(t)) t];
  }

  /// Distinct library refs with a scored attempt; [tests] true → full tests
  /// only, false → single passages only. Question-bank sets and short
  /// practice tests are left out (see [bankDone] / [practiceTestsDone]).
  static Set<String> doneIds(Store store, {bool? tests}) {
    final ids = <String>{};
    for (final a in store.attemptsFor(skill: Skill.reading)) {
      if (a.kind == 'lesson' || !ReadingRefs.exists(a.refId)) continue;
      if (ReadingRefs.isBankContent(a.refId)) continue;
      final isTest = ReadingRefs.isTest(a.refId);
      if (tests != null && tests != isTest) continue;
      ids.add(a.refId);
    }
    return ids;
  }

  /// Question-bank sets with a scored attempt.
  static Set<String> bankDone(Store store) => <String>{
        for (final a in store.attemptsFor(skill: Skill.reading))
          if (a.kind != 'lesson' && ReadingRefs.isBank(a.refId)) a.refId,
      };

  /// Short practice tests with a scored attempt.
  static Set<String> practiceTestsDone(Store store) => <String>{
        for (final a in store.attemptsFor(skill: Skill.reading))
          if (a.kind != 'lesson' && ReadingRefs.isShortTest(a.refId)) a.refId,
      };

  /// Bank question types with at least one finished set.
  static Set<String> bankTypesPractised(Store store) => <String>{
        for (final id in bankDone(store)) Content.bankPassage(id).s('questionType'),
      };

  static int lessonsDone(Store store) => store
      .attemptsFor(skill: Skill.reading, kind: 'lesson')
      .map((a) => a.refId)
      .toSet()
      .length;

  static Set<int> _correctOf(Attempt a) {
    final c = a.data['correct'];
    if (c is List) {
      return <int>{
        for (final e in c)
          if (e is num) e.toInt(),
      };
    }
    final out = <int>{};
    final given = _asMap(a.data['answers']);
    for (final it in ReadingRefs.items(a.refId)) {
      if (ReadingRefs.isCorrect(it, '${given['${it.number}'] ?? ''}')) out.add(it.number);
    }
    return out;
  }

  /// Question types the student has practised.
  static Set<String> typesPractised(Store store) {
    final out = <String>{};
    for (final a in store.attemptsFor(skill: Skill.reading)) {
      if (a.kind == 'lesson') continue;
      for (final it in ReadingRefs.items(a.refId)) {
        out.add(it.type);
      }
    }
    return out;
  }

  /// Question type with the lowest share of correct answers ('–' if none).
  static String weakestType(Store store) {
    final right = <String, int>{};
    final seen = <String, int>{};
    for (final a in store.attemptsFor(skill: Skill.reading)) {
      if (a.kind == 'lesson') continue;
      final all = ReadingRefs.items(a.refId);
      if (all.isEmpty) continue;
      final ok = _correctOf(a);
      for (final it in all) {
        seen[it.type] = (seen[it.type] ?? 0) + 1;
        if (ok.contains(it.number)) right[it.type] = (right[it.type] ?? 0) + 1;
      }
    }
    String? worst;
    var worstRate = 2.0;
    seen.forEach((type, n) {
      if (n == 0) return;
      final rate = (right[type] ?? 0) / n;
      if (rate < worstRate) {
        worstRate = rate;
        worst = type;
      }
    });
    final w = worst;
    if (w == null) return '–';
    return typeLabels[w] ?? w;
  }
}

/// UI copy for the reading section (landing modules, lesson).
Map<String, dynamic> get readingCopy => Demo.section('reading');
