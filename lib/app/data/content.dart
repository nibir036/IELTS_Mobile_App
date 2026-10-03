import 'demo.dart';
import 'res_bank.dart';

/// Typed-ish access to the practice content bank (`demo_data.json → content`,
/// built from `assets/demo/content/*.json`, see CONTENT_SCHEMA.md).
///
/// Content is the same for every student; per-student progress lives in
/// `Store`. All getters return empty maps/lists when something is missing,
/// never null.
class Content {
  Content._();

  static Map<String, dynamic> get _root => Demo.section('content');

  static Map<String, dynamic> _byId(List<Map<String, dynamic>> list, String? id) {
    if (id == null) return <String, dynamic>{};
    for (final m in list) {
      if (m.s('id') == id) return m;
    }
    return <String, dynamic>{};
  }

  // ── Reading ───────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> get readingPassages =>
      _root.m('reading').l('passages');
  /// Full reading tests: Academic Reading Test 1–10 (`rt_w01`…, from the
  /// tests bank), or the demo tests rt_01–rt_03 without it.
  static List<Map<String, dynamic>> get readingTests {
    final t = Demo.testsBank.m('reading').l('tests');
    return t.isNotEmpty ? t : readingDemoTests;
  }

  /// The original demo tests (still opened by older attempts).
  static List<Map<String, dynamic>> get readingDemoTests => _root.m('reading').l('tests');

  /// Passages of the full tests (rt_w01_p1 …).
  static List<Map<String, dynamic>> get readingTestBankPassages => Demo.testsBank.m('reading').l('passages');

  /// Library passage, full-test passage or question-bank set.
  static Map<String, dynamic> readingPassage(String? id) {
    final p = _byId(readingPassages, id);
    if (p.isNotEmpty || id == null) return p;
    final t = _byId(readingTestBankPassages, id);
    if (t.isNotEmpty) return t;
    return bankPassage(id);
  }

  /// Full test (rt_w…, or a demo rt_) or short practice test (rpt_).
  static Map<String, dynamic> readingTest(String? id) {
    final t = _byId(readingTests, id);
    if (t.isNotEmpty || id == null) return t;
    final d = _byId(readingDemoTests, id);
    if (d.isNotEmpty) return d;
    return _byId(readingPracticeTests, id);
  }

  // ── Reading question bank (assets/content/reading_bank.json) ──────────────

  /// 280 short passages, each practising ONE question type (rb_<type>_NN).
  static List<Map<String, dynamic>> get readingBankPassages =>
      Demo.readingBank.l('passages');

  /// 14 "How to attempt …" lessons, one per question type (bank order).
  static List<Map<String, dynamic>> get readingTypeLessons =>
      Demo.readingBank.l('lessons');

  /// 20 short practice tests (rpt_NN): three bank sets, Part 1 → 3.
  static List<Map<String, dynamic>> get readingPracticeTests =>
      Demo.readingBank.l('tests');

  static Map<String, Map<String, dynamic>> _bankIndex = <String, Map<String, dynamic>>{};
  static int _bankIndexedCount = -1;

  /// Question-bank set by id (fast lookup; empty map if unknown).
  static Map<String, dynamic> bankPassage(String id) {
    final all = readingBankPassages;
    if (_bankIndexedCount != all.length) {
      _bankIndex = <String, Map<String, dynamic>>{for (final p in all) p.s('id'): p};
      _bankIndexedCount = all.length;
    }
    return _bankIndex[id] ?? <String, dynamic>{};
  }

  static bool isBankPassage(String? id) => id != null && bankPassage(id).isNotEmpty;

  static bool isPracticeTest(String? id) =>
      id != null && _byId(readingPracticeTests, id).isNotEmpty;

  /// Question types of the bank in lesson order ('mcq', 'tfng' … 'short_answer').
  static List<String> get bankQuestionTypes =>
      <String>[for (final l in readingTypeLessons) l.s('questionType')];

  /// The strategy lesson of a question type.
  static Map<String, dynamic> typeLesson(String type) {
    for (final l in readingTypeLessons) {
      if (l.s('questionType') == type) return l;
    }
    return <String, dynamic>{};
  }

  /// "Matching Headings" for 'headings' (falls back to the key).
  static String typeName(String type) {
    final n = typeLesson(type).s('name');
    return n.isEmpty ? type : n;
  }

  /// The 20 sets of one question type, set 01 → 20.
  static List<Map<String, dynamic>> bankSetsOf(String type) {
    final out = <Map<String, dynamic>>[
      for (final p in readingBankPassages)
        if (p.s('questionType') == type) p,
    ];
    out.sort((a, b) => a.i('bankSet').compareTo(b.i('bankSet')));
    return out;
  }

  /// Number of questions in a passage (sums its groups; a "choose TWO"
  /// question with `numbers: [6, 7]` counts as two).
  static int passageQuestionCount(Map<String, dynamic> passage) {
    var n = 0;
    for (final g in passage.l('groups')) {
      for (final q in g.l('questions')) {
        final nums = q['numbers'];
        n += nums is List && nums.isNotEmpty ? nums.length : 1;
      }
    }
    return n;
  }

  /// The passages of a full test with their global question offset:
  /// passage 1 → offset 0 (Q1–13), passage 2 → 13 (Q14–26), passage 3 → 26.
  /// Display number = local `number` + offset.
  static List<(Map<String, dynamic>, int)> readingTestPassages(String? testId) {
    final out = <(Map<String, dynamic>, int)>[];
    var offset = 0;
    for (final pid in readingTest(testId).ls('passages')) {
      final p = readingPassage(pid);
      if (p.isEmpty) continue;
      out.add((p, offset));
      offset += passageQuestionCount(p);
    }
    return out;
  }

  // ── Listening ─────────────────────────────────────────────────────────────

  /// 32 question-bank sets (P1-FN … P4-SA: 4 parts × 8 formats, 20
  /// questions each) from `assets/content/listening_bank.json`.
  static List<Map<String, dynamic>> get listeningBankSets => Demo.listeningBank.l('sets');

  /// Bank notes, production guide, set index and part intros.
  static Map<String, dynamic> get listeningBankMeta => Demo.listeningBank.m('meta');

  /// The original 10-question sets with recorded audio (ls_01 …). Full tests,
  /// mock tests and the diagnostic are built from these.
  static List<Map<String, dynamic>> get listeningDemoSets =>
      _root.m('listening').l('sets');

  /// Practice sets shown in the lists (Part practice, Mini practice, search):
  /// the question bank, or the demo sets when the bank is missing.
  static List<Map<String, dynamic>> get listeningSets {
    final bank = listeningBankSets;
    return bank.isNotEmpty ? bank : listeningDemoSets;
  }

  /// Full listening tests: Listening Test 1–4 (`lt_w01`…, from the tests
  /// bank), or the demo tests lt_01 / lt_02 without it.
  static List<Map<String, dynamic>> get listeningTests {
    final t = Demo.testsBank.m('listening').l('tests');
    return t.isNotEmpty ? t : listeningDemoTests;
  }

  /// The original demo tests (still opened by older attempts).
  static List<Map<String, dynamic>> get listeningDemoTests => _root.m('listening').l('tests');

  /// The parts of the full tests (lt_w01_p1 …; one recording each, no
  /// transcript — `transcriptStatus: 'none'`).
  static List<Map<String, dynamic>> get listeningFullTestParts => Demo.testsBank.m('listening').l('sets');

  /// Any listening set by id (bank `lb_…`, full-test part `lt_w…` or demo `ls_…`).
  static Map<String, dynamic> listeningSet(String? id) {
    final b = _byId(listeningBankSets, id);
    if (b.isNotEmpty) return b;
    final t = _byId(listeningFullTestParts, id);
    return t.isNotEmpty ? t : _byId(listeningDemoSets, id);
  }

  static Map<String, dynamic> listeningTest(String? id) {
    final t = _byId(listeningTests, id);
    return t.isNotEmpty ? t : _byId(listeningDemoTests, id);
  }

  /// Questions in a set (a `multi` group with pick 2 counts as 2).
  static int setQuestionCount(Map<String, dynamic> set) {
    var n = 0;
    for (final g in set.l('groups')) {
      final pick = g.i('pick');
      for (final _ in g.l('questions')) {
        n += pick > 1 ? pick : 1;
      }
    }
    return n;
  }

  /// Sets of a full test with their global question offset (Part 1 → 0,
  /// Part 2 → 10, Part 3 → 20, Part 4 → 30).
  static List<(Map<String, dynamic>, int)> listeningTestSets(String? testId) {
    final out = <(Map<String, dynamic>, int)>[];
    var offset = 0;
    for (final sid in listeningTest(testId).ls('sets')) {
      final s = listeningSet(sid);
      if (s.isEmpty) continue;
      out.add((s, offset));
      offset += setQuestionCount(s);
    }
    return out;
  }

  /// Asset path of a set's audio (falls back to the placeholder).
  static String setAudio(Map<String, dynamic> set) {
    final a = set.s('audio');
    return a.isEmpty ? 'assets/audio/listening_placeholder.mp3' : a;
  }

  // ── Writing ───────────────────────────────────────────────────────────────

  /// Writing question bank (assets/content/writing_bank.json): 140 Task 1
  /// questions (wb1_<type>_NN, with the rendered visual and its data) and 120
  /// Task 2 questions (wb2_<type>_NN), each with Band 6 / 7 / 8 samples.
  static List<Map<String, dynamic>> get writingBankTask1 => Demo.writingBank.l('task1');
  static List<Map<String, dynamic>> get writingBankTask2 => Demo.writingBank.l('task2');
  static Map<String, dynamic> get writingBankMeta => Demo.writingBank.m('meta');

  /// The original demo prompts (t1_… / t2_…, with ideas); mock tests and the
  /// diagnostic use these.
  static List<Map<String, dynamic>> get writingDemoTask1 => _root.m('writing').l('task1');
  static List<Map<String, dynamic>> get writingDemoTask2 => _root.m('writing').l('task2');

  /// Practice prompts: the question bank, or the demo prompts without it.
  static List<Map<String, dynamic>> get writingTask1 {
    final b = writingBankTask1;
    return b.isNotEmpty ? b : writingDemoTask1;
  }

  static List<Map<String, dynamic>> get writingTask2 {
    final b = writingBankTask2;
    return b.isNotEmpty ? b : writingDemoTask2;
  }

  /// Full writing tests: Writing Test 1–10 {id, number, title, task1, task2}.
  static List<Map<String, dynamic>> get writingTests => Demo.testsBank.m('writing').l('tests');
  static Map<String, dynamic> writingTest(String? id) => _byId(writingTests, id);

  /// Task 1 / Task 2 prompts of the full writing tests (wt_01_t1 …).
  static List<Map<String, dynamic>> get writingTestPrompts => Demo.testsBank.m('writing').l('prompts');

  /// Any writing prompt by id (bank, full test or demo).
  static Map<String, dynamic> writingPrompt(String? id) {
    for (final list in <List<Map<String, dynamic>>>[
      writingBankTask1,
      writingBankTask2,
      writingTestPrompts,
      writingDemoTask1,
      writingDemoTask2,
    ]) {
      final a = _byId(list, id);
      if (a.isNotEmpty) return a;
    }
    return <String, dynamic>{};
  }

  // ── Speaking ──────────────────────────────────────────────────────────────

  /// Speaking question bank (assets/content/speaking_bank.json).
  static Map<String, dynamic> get speakingBankMeta => Demo.speakingBank.m('meta');
  static List<Map<String, dynamic>> get speakingBankPart1 => Demo.speakingBank.l('part1Topics');
  static List<Map<String, dynamic>> get speakingBankCards => Demo.speakingBank.l('cueCards');

  /// Part 3 discussion topics (bank only): {id, topic, category,
  /// categoryLabel, questions: [{q, tag, tagLabel, answer}]}.
  static List<Map<String, dynamic>> get part3Topics => Demo.speakingBank.l('part3Topics');
  static Map<String, dynamic> part3Topic(String? id) {
    final a = _byId(part3Topics, id);
    return a.isNotEmpty ? a : _byId(Demo.testsBank.m('speaking').l('part3Topics'), id);
  }

  /// Full speaking tests: Speaking Test 1–10 {id, number, title, part1,
  /// cueCard, part3: [Part 3 topic ids], description}.
  static List<Map<String, dynamic>> get speakingTests => Demo.testsBank.m('speaking').l('tests');
  static Map<String, dynamic> speakingTest(String? id) => _byId(speakingTests, id);

  /// Vocabulary dictionary: key (lower-case marked form) → entry.
  static Map<String, dynamic> get speakingVocab => Demo.speakingBank.m('vocab');

  /// The original demo topics / cards (mock tests and the diagnostic use them).
  static List<Map<String, dynamic>> get speakingDemoPart1 => _root.m('speaking').l('part1Topics');
  static List<Map<String, dynamic>> get speakingDemoCards => _root.m('speaking').l('cueCards');

  /// Practice topics / cards: the question bank, or the demo ones without it.
  static List<Map<String, dynamic>> get part1Topics {
    final b = speakingBankPart1;
    return b.isNotEmpty ? b : speakingDemoPart1;
  }

  static List<Map<String, dynamic>> get cueCards {
    final b = speakingBankCards;
    return b.isNotEmpty ? b : speakingDemoCards;
  }

  /// Any Part 1 topic / cue card by id (bank or demo).
  static Map<String, dynamic> part1Topic(String? id) {
    final a = _byId(speakingBankPart1, id);
    if (a.isNotEmpty) return a;
    final t = _byId(Demo.testsBank.m('speaking').l('part1Topics'), id);
    return t.isNotEmpty ? t : _byId(speakingDemoPart1, id);
  }

  static Map<String, dynamic> cueCard(String? id) {
    final a = _byId(speakingBankCards, id);
    if (a.isNotEmpty) return a;
    final t = _byId(Demo.testsBank.m('speaking').l('cueCards'), id);
    return t.isNotEmpty ? t : _byId(speakingDemoCards, id);
  }

  // ── Mock & quizzes ────────────────────────────────────────────────────────

  /// Full mock tests: Full Mock Test 1–4 (mt_01…, from the tests bank), or the
  /// demo mocks mt_a–mt_c without it.
  static List<Map<String, dynamic>> get mockTests {
    final t = Demo.testsBank.m('mock').l('tests');
    return t.isNotEmpty ? t : mockDemoTests;
  }

  /// The original demo mocks (still opened by older attempts).
  static List<Map<String, dynamic>> get mockDemoTests => _root.m('mock').l('tests');

  static Map<String, dynamic> mockTest(String? id) {
    final t = _byId(mockTests, id);
    return t.isNotEmpty ? t : _byId(mockDemoTests, id);
  }

  static List<Map<String, dynamic>> get quizzes => _root.m('resources').l('quizzes');
  /// A content quiz, or a generated one (academic study day `aw_day_N`).
  static Map<String, dynamic> quiz(String? id) {
    final q = _byId(quizzes, id);
    if (q.isNotEmpty || id == null) return q;
    final day = ResBank.academicDayQuiz(id);
    return day.isNotEmpty ? day : ResBank.deckQuiz(id);
  }
}
