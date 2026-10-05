import 'dart:async';
import 'dart:math' as math;

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Listening user data
//
// Content comes from the question bank (`Content.listeningSets`: lb_p1_fn …,
// 20 questions each; see bank.dart) and the demo sets ls_01… that full tests
// `Content.listeningTests` lt_01… are built from. Questions are numbered
// locally in a set; full tests add the part offset (Part 2 → 11–20 …). Answers are
// always stored under GLOBAL numbers. A `multi` question (pick 2) covers two
// numbers: one chosen letter per number, order-free.
//
// kv keys (per account):
//   'listening.inProgress'       answer sheet (F3), a full test or one set:
//                                {testId | setId, title, answers {qNo: v},
//                                 current, part, audioPart, audioSec,
//                                 audioDone, remainingSec}
//   'listening.mini.inProgress'  set practice on the player (F2):
//                                {setId, mode, answers, current, audioSec,
//                                 elapsedSec}
//   'listening.lesson.<id>'      {answers, current} (bite-size lesson)
//   'resume'                     {label, route, args} (shared with Home)
//
// Attempt data: {testId | setId, answers, correct [global numbers], total,
//   parts [{setId, part, from, to, correct, total}], source, part?, mode?}
// ─────────────────────────────────────────────────────────────────────────────

/// Writes kv values without notifying immediately (safe from `dispose`);
/// listeners are notified in a microtask.
void persistListeningKv(Map<String, Object?> values) {
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

Map<int, String> _answersFrom(Object? v) {
  final out = <int, String>{};
  if (v is Map) {
    v.forEach((k, val) {
      final n = int.tryParse('$k');
      if (n != null && val != null && '$val'.trim().isNotEmpty) out[n] = '$val';
    });
  }
  return out;
}

Map<String, dynamic> _answersTo(Map<int, String> answers) => <String, dynamic>{
      for (final e in answers.entries)
        if (e.value.trim().isNotEmpty) '${e.key}': e.value.trim(),
    };

/// Answers map of an attempt / saved state, keyed by global number.
Map<int, String> listeningAnswersOf(Map<String, dynamic> data) => _answersFrom(data['answers']);

/// Saved in-progress map for [key] (null if none).
Map<String, dynamic>? listeningSaved(Store store, String key) {
  final v = store.kv<Map>(key);
  return v?.cast<String, dynamic>();
}

/// Latest scored attempt made on [refId] (a test or a set).
Attempt? latestListeningAttempt(Store store, String refId) {
  for (final a in store.attemptsFor(skill: Skill.listening)) {
    if (a.kind != 'lesson' && a.refId == refId) return a;
  }
  return null;
}

void _clearResume(String route) {
  final kv = Store.I.data.kv;
  final r = kv['resume'];
  if (r is Map && r['route'] == route) kv.remove('resume');
}

// ─────────────────────────────────────────────────────────────────────────────
// Bank helpers
// ─────────────────────────────────────────────────────────────────────────────

/// One answerable unit: a question of a set. A `multi` item covers [span]
/// consecutive numbers starting at [number] (global = local + [offset]).
class ListeningItem {
  const ListeningItem({
    required this.set,
    required this.group,
    required this.q,
    required this.number,
    required this.span,
    required this.offset,
  });

  final Map<String, dynamic> set;
  final Map<String, dynamic> group;
  final Map<String, dynamic> q;
  final int number;
  final int span;
  final int offset;

  String get type => group.s('type');
  int get last => number + span - 1;
  String get label => span > 1 ? '$number–$last' : '$number';
  List<int> get numbers => <int>[for (var k = 0; k < span; k++) number + k];
  bool get isChoice => type == 'mcq' || type == 'multi' || type == 'matching' || type == 'map';

  /// Letter options (matching and map options live on the group).
  List<Map<String, dynamic>> get options =>
      type == 'matching' || type == 'map' ? group.l('options') : q.l('options');

  /// Correct letters of a `multi` item (upper case).
  List<String> get rightLetters => letterList(q['answer']);

  /// Display text of the correct answer for a text / single-letter item
  /// (bank sets print every accepted form: "10 / ten").
  String get answerText => q.s('answerDisplay').isNotEmpty ? q.s('answerDisplay') : q.s('answer');

  bool contains(int n) => n >= number && n <= last;
}

List<String> letterList(Object? v) {
  if (v is List) {
    return <String>[
      for (final e in v)
        if ('$e'.trim().isNotEmpty) '$e'.trim().toUpperCase(),
    ];
  }
  return <String>[
    for (final e in '${v ?? ''}'.split(RegExp(r'[,|/ ]')))
      if (e.trim().isNotEmpty) e.trim().toUpperCase(),
  ];
}

/// Items of [set], numbered from `local + offset`.
List<ListeningItem> listeningItems(Map<String, dynamic> set, [int offset = 0]) {
  final out = <ListeningItem>[];
  for (final g in set.l('groups')) {
    final pick = g.i('pick');
    for (final q in g.l('questions')) {
      out.add(ListeningItem(
        set: set,
        group: g,
        q: q,
        number: q.i('number') + offset,
        span: pick > 1 ? pick : 1,
        offset: offset,
      ));
    }
  }
  return out;
}

/// Global numbers of [item] answered correctly.
List<int> listeningItemCorrect(ListeningItem item, Map<int, String> answers) {
  final type = item.type;
  if (type == 'multi') {
    final right = item.rightLetters.toSet();
    final used = <String>{};
    final out = <int>[];
    for (final n in item.numbers) {
      final v = (answers[n] ?? '').trim().toUpperCase();
      if (v.isNotEmpty && right.contains(v) && used.add(v)) out.add(n);
    }
    return out;
  }
  final given = (answers[item.number] ?? '').trim();
  if (given.isEmpty) return const <int>[];
  if (type == 'mcq' || type == 'matching' || type == 'map') {
    return given.toUpperCase() == item.q.s('answer').trim().toUpperCase()
        ? <int>[item.number]
        : const <int>[];
  }
  final accepted = item.q['accepted'] ?? item.q['answer'];
  return Scoring.matches(given, accepted) ? <int>[item.number] : const <int>[];
}

/// Answer-key rows {number, yourAnswer, correctAnswer, ok} for [item].
List<Map<String, dynamic>> listeningItemKey(
  ListeningItem item,
  Map<int, String> answers,
  Set<int> correct,
) {
  if (item.type == 'multi') {
    final right = item.rightLetters;
    final chosenRight = <String>{
      for (final n in item.numbers)
        if (correct.contains(n)) (answers[n] ?? '').trim().toUpperCase(),
    };
    final missing = right.where((l) => !chosenRight.contains(l)).toList();
    return <Map<String, dynamic>>[
      for (final n in item.numbers)
        <String, dynamic>{
          'number': n,
          'yourAnswer': (answers[n] ?? '').trim().toUpperCase(),
          'correctAnswer': correct.contains(n)
              ? (answers[n] ?? '').trim().toUpperCase()
              : (missing.isNotEmpty ? missing.removeAt(0) : right.join(' / ')),
          'ok': correct.contains(n),
        },
    ];
  }
  final yours = (answers[item.number] ?? '').trim();
  return <Map<String, dynamic>>[
    <String, dynamic>{
      'number': item.number,
      'yourAnswer': item.isChoice ? yours.toUpperCase() : yours,
      'correctAnswer': item.answerText,
      'ok': correct.contains(item.number),
    },
  ];
}

/// "ls_03" → "03"; bank sets → their code ("P1-FN").
String listeningSetNo(Map<String, dynamic> set) {
  if (set.s('code').isNotEmpty) return set.s('code');
  final id = set.s('id');
  final i = id.lastIndexOf('_');
  return i >= 0 ? id.substring(i + 1) : id;
}

/// "1 speaker" / "3 speakers".
String listeningSpeakers(Map<String, dynamic> set) {
  final n = set.l('speakers').length;
  return n == 1 ? '1 speaker' : '$n speakers';
}

/// Total audio seconds of a full test.
double listeningTestSeconds(String testId) {
  var total = 0.0;
  for (final e in Content.listeningTestSets(testId)) {
    total += e.$1.d('durationSeconds');
  }
  return total;
}

/// "~13 min".
String approxMinutes(double seconds) => '~${(seconds / 60).round()} min';

/// Question count of a full test.
int listeningTestQuestions(String testId) {
  var n = 0;
  for (final e in Content.listeningTestSets(testId)) {
    n += Content.setQuestionCount(e.$1);
  }
  return n;
}

/// Sets of a test (with offsets) or a single set (offset 0).
List<(Map<String, dynamic>, int)> listeningSetsFor({String testId = '', String setId = ''}) {
  if (testId.isNotEmpty) return Content.listeningTestSets(testId);
  final s = Content.listeningSet(setId);
  if (s.isEmpty) return <(Map<String, dynamic>, int)>[];
  return <(Map<String, dynamic>, int)>[(s, 0)];
}

/// Scores [answers] on [sets] and builds the attempt.
Attempt _scoreAttempt({
  required String kind,
  required String refId,
  required String title,
  required List<(Map<String, dynamic>, int)> sets,
  required Map<int, String> answers,
  required int durationSec,
  required Map<String, dynamic> extra,
}) {
  final correct = <int>[];
  final parts = <Map<String, dynamic>>[];
  var total = 0;
  for (final e in sets) {
    final set = e.$1;
    final offset = e.$2;
    var right = 0;
    var count = 0;
    for (final it in listeningItems(set, offset)) {
      final c = listeningItemCorrect(it, answers);
      correct.addAll(c);
      right += c.length;
      count += it.span;
    }
    total += count;
    parts.add(<String, dynamic>{
      'setId': set.s('id'),
      'part': set.i('part'),
      'from': offset + 1,
      'to': offset + count,
      'correct': right,
      'total': count,
    });
  }
  correct.sort();
  return Attempt(
    id: Store.newId('att'),
    skill: Skill.listening,
    kind: kind,
    title: title,
    refId: refId,
    band: Scoring.listeningBand(correct.length, total),
    score: correct.length,
    total: total,
    durationSec: math.max(60, durationSec),
    createdAt: DateTime.now(),
    data: <String, dynamic>{
      ...extra,
      'answers': _answersTo(answers),
      'correct': correct,
      'total': total,
      'parts': parts,
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Session state shared by F2 / F3 (in-flight answers; saved to kv on leave)
// ─────────────────────────────────────────────────────────────────────────────

class ListeningSession {
  ListeningSession._();

  /// UI copy part (`assets/demo/parts/listening.json`).
  static Map<String, dynamic> get data => Demo.section('listening');

  static String _owner = '';
  static bool _mine() => _owner == (Store.I.current?.id ?? '');

  /// First set with no attempt (else the first set).
  static String nextSetId({int part = 0}) {
    final sets = Content.listeningSets
        .where((s) => part == 0 || s.i('part') == part)
        .toList();
    for (final s in sets) {
      if (latestListeningAttempt(Store.I, s.s('id')) == null) return s.s('id');
    }
    return sets.isEmpty ? '' : sets.first.s('id');
  }

  /// First full test with no attempt (else the first test).
  static String nextTestId() {
    final tests = Content.listeningTests;
    for (final t in tests) {
      if (latestListeningAttempt(Store.I, t.s('id')) == null) return t.s('id');
    }
    return tests.isEmpty ? '' : tests.first.s('id');
  }

  // ── F2 · player (one set: Mini Practice / Part Practice) ─────────────────
  static const miniKey = 'listening.mini.inProgress';
  static bool playerActive = false;
  static String playerSetId = '';
  static String playerMode = 'Mini Practice';
  static final Map<int, String> playerAnswers = <int, String>{};
  static final Set<int> playerBookmarks = <int>{};
  static int playerCurrent = 1;
  static double playerAudioSec = 0;
  static int _playerElapsedBefore = 0;
  static DateTime _playerOpenedAt = DateTime.now();

  static Map<String, dynamic> get playerSet => Content.listeningSet(playerSetId);
  static List<ListeningItem> get playerItems => listeningItems(playerSet);
  static String get playerTitle => playerSet.s('title');

  static void _freshPlayer(String setId, String mode) {
    _owner = Store.I.current?.id ?? '';
    playerActive = true;
    playerSetId = setId;
    playerMode = mode.isEmpty ? 'Mini Practice' : mode;
    playerAnswers.clear();
    playerBookmarks.clear();
    final items = playerItems;
    playerCurrent = items.isEmpty ? 1 : items.first.number;
    playerAudioSec = 0;
    _playerElapsedBefore = 0;
    _playerOpenedAt = DateTime.now();
  }

  static void _resumePlayer(Map<String, dynamic> saved) {
    _freshPlayer(saved.s('setId'), saved.s('mode'));
    playerAnswers.addAll(_answersFrom(saved['answers']));
    final cur = saved.i('current');
    if (playerItems.any((q) => q.number == cur)) playerCurrent = cur;
    playerAudioSec = saved.d('audioSec');
    _playerElapsedBefore = saved.i('elapsedSec');
  }

  /// Opens the player for [setId] (resuming saved progress for it), or -
  /// without an id - keeps the open session / resumes the saved one /
  /// starts the next set not yet practised.
  static void openPlayer({String? setId, String mode = '', bool fresh = false}) {
    if (!_mine()) playerActive = false;
    if (playerActive && Content.listeningSet(playerSetId).isEmpty) playerActive = false;
    final saved = listeningSaved(Store.I, miniKey);
    final savedId = saved == null ? '' : saved.s('setId');
    final savedOk = savedId.isNotEmpty && Content.listeningSet(savedId).isNotEmpty;
    if (setId != null && Content.listeningSet(setId).isNotEmpty) {
      if (!fresh && saved != null && savedOk && savedId == setId) {
        _resumePlayer(saved);
        if (mode.isNotEmpty) playerMode = mode;
      } else if (!fresh && playerActive && playerSetId == setId) {
        if (mode.isNotEmpty) playerMode = mode;
      } else {
        _freshPlayer(setId, mode);
      }
      return;
    }
    if (playerActive) return;
    if (saved != null && savedOk) {
      _resumePlayer(saved);
      return;
    }
    _freshPlayer(nextSetId(), mode);
  }

  static int get _playerElapsed =>
      _playerElapsedBefore + DateTime.now().difference(_playerOpenedAt).inSeconds;

  static void savePlayer() {
    if (!playerActive || playerSetId.isEmpty || !_mine()) return;
    persistListeningKv(<String, Object?>{
      miniKey: <String, dynamic>{
        'setId': playerSetId,
        'mode': playerMode,
        'answers': _answersTo(playerAnswers),
        'current': playerCurrent,
        'audioSec': playerAudioSec,
        'elapsedSec': _playerElapsed,
      },
      'resume': <String, dynamic>{
        'label': 'Resume $playerTitle',
        'route': Routes.listeningPlayer,
        'args': <String, dynamic>{'setId': playerSetId},
      },
    });
  }

  /// Scores the player answers and records a 'mini' attempt.
  static Attempt submitPlayer() {
    final set = playerSet;
    final a = _scoreAttempt(
      kind: 'mini',
      refId: playerSetId,
      title: set.s('title'),
      sets: <(Map<String, dynamic>, int)>[(set, 0)],
      answers: playerAnswers,
      durationSec: _playerElapsed,
      extra: <String, dynamic>{
        'setId': playerSetId,
        'part': set.i('part'),
        'mode': playerMode,
        'source': 'player',
      },
    );
    playerActive = false;
    final kv = Store.I.data.kv;
    final saved = kv[miniKey];
    if (saved is Map && saved['setId'] == playerSetId) kv.remove(miniKey);
    _clearResume(Routes.listeningPlayer);
    Store.I.addAttempt(a);
    return a;
  }

  // ── F3 · answer sheet (full test, or one set) ────────────────────────────
  static const sheetKey = 'listening.inProgress';
  static bool sheetActive = false;
  static String sheetTestId = '';
  static String sheetSetId = '';
  static String sheetTitle = '';
  static List<(Map<String, dynamic>, int)> sheetSets = <(Map<String, dynamic>, int)>[];
  static final Map<int, String> sheetAnswers = <int, String>{};

  /// Questions the student flagged to come back to (first number of an item).
  static final Set<int> sheetFlags = <int>{};
  static int sheetCurrent = 1;

  /// Page shown (index into [sheetSets]).
  static int sheetPart = 0;

  /// Set whose recording is playing (index into [sheetSets]).
  static int sheetAudioPart = 0;

  /// Position inside the playing set's recording.
  static double sheetAudioSeconds = 0;

  /// The whole recording has been played (it plays once - no replay).
  static bool sheetAudioDone = false;
  static int sheetLimit = 1800;
  static DateTime _deadline = DateTime.now();

  static bool get sheetIsTest => sheetTestId.isNotEmpty;
  static String get sheetRefId => sheetIsTest ? sheetTestId : sheetSetId;

  /// Items of page [index] (global numbers).
  static List<ListeningItem> sheetItems(int index) {
    if (index < 0 || index >= sheetSets.length) return <ListeningItem>[];
    return listeningItems(sheetSets[index].$1, sheetSets[index].$2);
  }

  static List<ListeningItem> get sheetAllItems => <ListeningItem>[
        for (var i = 0; i < sheetSets.length; i++) ...sheetItems(i),
      ];

  /// Total audio seconds of the sheet (content durations).
  static double get sheetAudioTotal {
    var s = 0.0;
    for (final e in sheetSets) {
      s += e.$1.d('durationSeconds');
    }
    return s;
  }

  static bool _freshSheet(String testId, String setId) {
    final sets = listeningSetsFor(testId: testId, setId: testId.isEmpty ? setId : '');
    if (sets.isEmpty) return false;
    _owner = Store.I.current?.id ?? '';
    sheetActive = true;
    sheetTestId = testId;
    sheetSetId = testId.isEmpty ? setId : '';
    sheetSets = sets;
    sheetTitle = testId.isNotEmpty
        ? Content.listeningTest(testId).s('title')
        : sets.first.$1.s('title');
    sheetAnswers.clear();
    sheetFlags.clear();
    sheetPart = 0;
    sheetAudioPart = 0;
    final items = sheetItems(0);
    sheetCurrent = items.isEmpty ? 1 : items.first.number;
    sheetAudioSeconds = 0;
    sheetAudioDone = false;
    // Recording + time to check answers (10 min for a full test).
    final extra = testId.isNotEmpty ? 600 : 180;
    sheetLimit = ((sheetAudioTotal + extra) / 60).ceil() * 60;
    _deadline = DateTime.now().add(Duration(seconds: sheetLimit));
    return true;
  }

  static bool _resumeSheet(Map<String, dynamic> saved) {
    if (!_freshSheet(saved.s('testId'), saved.s('setId'))) return false;
    sheetAnswers.addAll(_answersFrom(saved['answers']));
    final flags = saved['flags'];
    if (flags is List) {
      for (final f in flags) {
        final n = f is int ? f : int.tryParse('$f');
        if (n != null) sheetFlags.add(n);
      }
    }
    final part = saved.i('part');
    sheetPart = part >= 0 && part < sheetSets.length ? part : 0;
    final ap = saved.i('audioPart');
    sheetAudioPart = ap >= 0 && ap < sheetSets.length ? ap : 0;
    final cur = saved.i('current');
    if (sheetItems(sheetPart).any((r) => r.contains(cur))) sheetCurrent = cur;
    sheetAudioSeconds = saved.d('audioSec');
    sheetAudioDone = saved.b('audioDone');
    final rem = saved.i('remainingSec');
    _deadline = DateTime.now().add(
      Duration(seconds: rem > 0 && rem <= sheetLimit ? rem : sheetLimit),
    );
    return true;
  }

  static bool _savedMatches(Map<String, dynamic> saved, String testId, String setId) =>
      testId.isNotEmpty ? saved.s('testId') == testId : (setId.isNotEmpty && saved.s('setId') == setId);

  /// Opens the answer sheet for [testId] or [setId] (resuming saved progress
  /// for it), or - without an id - keeps the open session / resumes the
  /// saved one / starts the next full test.
  static void openSheet({String? testId, String? setId, bool fresh = false}) {
    if (!_mine()) sheetActive = false;
    final saved = listeningSaved(Store.I, sheetKey);
    final tid = testId ?? '';
    final sid = setId ?? '';
    if (tid.isNotEmpty || sid.isNotEmpty) {
      if (!fresh && sheetActive && (tid.isNotEmpty ? sheetTestId == tid : sheetSetId == sid)) {
        return;
      }
      if (!fresh && saved != null && _savedMatches(saved, tid, sid) && _resumeSheet(saved)) {
        return;
      }
      if (_freshSheet(tid, sid)) return;
    }
    if (sheetActive) return;
    if (saved != null && _resumeSheet(saved)) return;
    _freshSheet(nextTestId(), '');
  }

  static void saveSheet() {
    if (!sheetActive || sheetRefId.isEmpty || !_mine()) return;
    persistListeningKv(<String, Object?>{
      sheetKey: <String, dynamic>{
        if (sheetIsTest) 'testId': sheetTestId else 'setId': sheetSetId,
        'title': sheetTitle,
        'answers': _answersTo(sheetAnswers),
        'flags': (sheetFlags.toList()..sort()),
        'current': sheetCurrent,
        'part': sheetPart,
        'audioPart': sheetAudioPart,
        'audioSec': sheetAudioSeconds,
        'audioDone': sheetAudioDone,
        'remainingSec': sheetRemaining,
      },
      'resume': <String, dynamic>{
        'label': 'Resume $sheetTitle',
        'route': Routes.listeningAnswerSheet,
        'args': <String, dynamic>{
          if (sheetIsTest) 'testId': sheetTestId else 'setId': sheetSetId,
        },
      },
    });
  }

  /// Scores the answer sheet and records a 'test' (or 'mini') attempt.
  static Attempt submitSheet() {
    final first = sheetSets.isEmpty ? <String, dynamic>{} : sheetSets.first.$1;
    final a = _scoreAttempt(
      kind: sheetIsTest ? 'test' : 'mini',
      refId: sheetRefId,
      title: sheetTitle,
      sets: sheetSets,
      answers: sheetAnswers,
      durationSec: sheetLimit - sheetRemaining,
      extra: <String, dynamic>{
        if (sheetIsTest) 'testId': sheetTestId else 'setId': sheetSetId,
        if (!sheetIsTest) 'part': first.i('part'),
        'source': 'sheet',
      },
    );
    sheetActive = false;
    final kv = Store.I.data.kv;
    final saved = kv[sheetKey];
    if (saved is Map &&
        (sheetIsTest ? saved['testId'] == sheetTestId : saved['setId'] == sheetSetId)) {
      kv.remove(sheetKey);
    }
    _clearResume(Routes.listeningAnswerSheet);
    Store.I.addAttempt(a);
    return a;
  }

  static int get sheetRemaining {
    final s = _deadline.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Derived listening stats (landing / library / mini list)
// ─────────────────────────────────────────────────────────────────────────────

class ListeningStats {
  ListeningStats._();

  /// Part → (right, seen) across all scored attempts.
  static Map<int, (int, int)> partTotals(Store store) {
    final out = <int, (int, int)>{};
    void add(int part, int right, int seen) {
      if (part <= 0 || seen <= 0) return;
      final cur = out[part] ?? (0, 0);
      out[part] = (cur.$1 + right, cur.$2 + seen);
    }

    for (final a in store.attemptsFor(skill: Skill.listening)) {
      if (a.kind == 'lesson') continue;
      final parts = a.data['parts'];
      if (parts is List && parts.isNotEmpty) {
        for (final p in parts) {
          if (p is Map) {
            final m = p.cast<String, dynamic>();
            add(m.i('part'), m.i('correct'), m.i('total'));
          }
        }
      } else {
        final part = a.data['part'];
        if (part is num) add(part.toInt(), a.score ?? 0, a.total ?? 0);
      }
    }
    return out;
  }

  /// Part with the lowest share of correct answers (null if no data).
  static int? weakestPart(Store store) {
    int? worst;
    var rate = 2.0;
    partTotals(store).forEach((part, v) {
      final r = v.$1 / v.$2;
      if (r < rate) {
        rate = r;
        worst = part;
      }
    });
    return worst;
  }

  /// Distinct refIds with a scored attempt, filtered by [test].
  static Set<String> doneRefs(Store store, bool Function(Attempt a) test) => <String>{
        for (final a in store.attemptsFor(skill: Skill.listening))
          if (a.kind != 'lesson' && test(a)) a.refId,
      };

  /// Bank sets with at least one attempt.
  static Set<String> doneSets(Store store) {
    final ids = <String>{for (final s in Content.listeningSets) s.s('id')};
    return doneRefs(store, (a) => ids.contains(a.refId));
  }

  /// Bank tests with at least one attempt.
  static Set<String> doneTests(Store store) {
    final ids = <String>{for (final t in Content.listeningTests) t.s('id')};
    return doneRefs(store, (a) => ids.contains(a.refId));
  }

  static int lessonsDone(Store store) => store
      .attemptsFor(skill: Skill.listening, kind: 'lesson')
      .map((a) => a.refId)
      .toSet()
      .length;
}
