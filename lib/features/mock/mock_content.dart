import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock test compositions (content bank → `Content.mockTests`)
//
// A mock test is a composition: listeningTest (4 sets), readingTest
// (3 passages), Writing task1 + task2, Speaking part1 topic + cue card (its
// part3 list is Part 3). The UI copy / timings / plan templates stay in the
// mock section's JSON part (`Demo.section('mock')`).
// ─────────────────────────────────────────────────────────────────────────────

/// The mock section's UI copy, checks, timings and plan templates.
Map<String, dynamic> get mockContent => Demo.section('mock');

/// The real mock tests of the bank (mt_a, mt_b, mt_c …).
List<Map<String, dynamic>> mockTests() => Content.mockTests;

/// A mock test by id (falls back to the first one).
Map<String, dynamic> mockTest(String? id) {
  final m = Content.mockTest(id);
  if (m.isNotEmpty) return m;
  final all = mockTests();
  return all.isEmpty ? <String, dynamic>{} : all.first;
}

/// "Mock Test A".
String mockTestName(Map<String, dynamic> mock) {
  final title = mock.s('title');
  if (title.isNotEmpty) return title;
  return mock.s('letter').isEmpty ? 'Mock test' : 'Mock Test ${mock.s('letter')}';
}

/// Listening sets of the mock with their question offsets (Parts 1–4).
List<(Map<String, dynamic>, int)> mockListeningSets(Map<String, dynamic> mock) =>
    Content.listeningTestSets(mock.s('listeningTest'));

/// Reading passages of the mock with their question offsets.
List<(Map<String, dynamic>, int)> mockReadingPassages(Map<String, dynamic> mock) =>
    Content.readingTestPassages(mock.s('readingTest'));

Map<String, dynamic> mockTask1(Map<String, dynamic> mock) =>
    Content.writingPrompt(mock.s('task1'));

Map<String, dynamic> mockTask2(Map<String, dynamic> mock) =>
    Content.writingPrompt(mock.s('task2'));

Map<String, dynamic> mockPart1Topic(Map<String, dynamic> mock) =>
    Content.part1Topic(mock.m('speaking').s('part1'));

Map<String, dynamic> mockCueCard(Map<String, dynamic> mock) =>
    Content.cueCard(mock.m('speaking').s('cueCard'));

// ─────────────────────────────────────────────────────────────────────────────
// Flattened questions
// ─────────────────────────────────────────────────────────────────────────────

/// A lettered / keyed option (A–H, i–x, TRUE/FALSE/NOT GIVEN).
class MockOption {
  const MockOption(this.key, this.text);

  final String key;
  final String text;
}

/// One answerable item. A `multi` (choose TWO) item spans 2 numbers; its
/// answer is stored as "A,C" under its first number.
class MockQuestion {
  const MockQuestion({
    required this.number,
    required this.span,
    required this.kind,
    required this.text,
    this.label = '',
    this.before = '',
    this.after = '',
    this.options = const <MockOption>[],
    this.answers = const <String>[],
    this.accepted = const <String>[],
  });

  /// Global display number (first number for a `multi` item).
  final int number;
  final int span;

  /// 'choice' | 'multi' | 'text'.
  final String kind;
  final String text;

  /// Form completion: label, text before and after the blank.
  final String label;
  final String before;
  final String after;

  /// Per-question options (mcq / multi). Empty → the group's shared options.
  final List<MockOption> options;

  /// Correct keys (choice: 1 key, multi: `span` keys).
  final List<String> answers;

  /// Accepted typed answers (text).
  final List<String> accepted;

  List<int> get numbers => <int>[for (var i = 0; i < span; i++) number + i];
  int get lastNumber => number + span - 1;
}

/// One question group of a listening set / reading passage, renumbered.
class MockGroup {
  const MockGroup({
    required this.id,
    required this.type,
    required this.title,
    required this.instruction,
    required this.heading,
    required this.unitIndex,
    required this.questions,
    this.formTitle = '',
    this.formSubtitle = '',
    this.shared = const <MockOption>[],
    this.image = '',
  });

  /// Unique within the mock: `{set or passage id}_{group id}`.
  final String id;

  /// form | gap | mcq | multi | matching | tfng | ynng | heading | map | summary.
  final String type;
  final String title;
  final String instruction;

  /// "Part 1" (listening) / "Passage 1" (reading).
  final String heading;

  /// 0-based index of the set / passage inside the mock section.
  final int unitIndex;
  final List<MockQuestion> questions;
  final String formTitle;
  final String formSubtitle;

  /// Shared options: matching box, list of headings, TRUE/FALSE/NOT GIVEN.
  final List<MockOption> shared;

  /// Plan / map picture of a labelling group (asset path), or ''.
  final String image;

  int get first => questions.isEmpty ? 0 : questions.first.number;
  int get last => questions.isEmpty ? 0 : questions.last.lastNumber;
  int get count => questions.fold<int>(0, (s, q) => s + q.span);

  String get range => first == last ? 'Question $first' : 'Questions $first–$last';

  bool contains(int n) => n >= first && n <= last;
}

List<MockOption> _options(dynamic v) {
  final out = <MockOption>[];
  if (v is! List) return out;
  for (final e in v) {
    if (e is Map) {
      final m = e.cast<String, dynamic>();
      out.add(MockOption(m.s('key'), m.s('text')));
    } else if (e != null) {
      out.add(MockOption('$e', ''));
    }
  }
  return out;
}

List<String> _answerList(dynamic v) {
  if (v is List) return <String>[for (final e in v) '$e'];
  if (v == null) return <String>[];
  return <String>['$v'];
}

/// Groups of one set / passage with numbers shifted by [offset].
List<MockGroup> mockGroupsOf(
  Map<String, dynamic> unit, {
  required int offset,
  required int unitIndex,
  required String heading,
}) {
  final out = <MockGroup>[];
  for (final g in unit.l('groups')) {
    final type = g.s('type');
    final pick = g.i('pick') > 1 ? g.i('pick') : 1;
    final shared = type == 'heading' ? _options(g['headings']) : _options(g['options']);
    final questions = <MockQuestion>[];
    for (final q in g.l('questions')) {
      final number = q.i('number') + offset;
      final answers = _answerList(q['answer']);
      switch (type) {
        case 'form':
        case 'gap':
          final acc = q.ls('accepted');
          questions.add(MockQuestion(
            number: number,
            span: 1,
            kind: 'text',
            text: q.s('text'),
            label: q.s('label'),
            before: q.s('before'),
            after: q.s('after'),
            answers: answers,
            accepted: acc.isEmpty ? answers : acc,
          ));
        case 'multi':
          questions.add(MockQuestion(
            number: number,
            span: pick,
            kind: 'multi',
            text: q.s('text'),
            options: _options(q['options']),
            answers: answers,
          ));
        default:
          questions.add(MockQuestion(
            number: number,
            span: 1,
            kind: 'choice',
            text: q.s('text'),
            options: _options(q['options']),
            answers: answers,
          ));
      }
    }
    out.add(MockGroup(
      id: '${unit.s('id')}_${g.s('id')}',
      type: type,
      title: g.s('title'),
      instruction: g.s('instruction'),
      heading: heading,
      unitIndex: unitIndex,
      questions: questions,
      formTitle: g.s('formTitle'),
      formSubtitle: g.s('formSubtitle'),
      shared: shared,
      image: g.s('image'),
    ));
  }
  return out;
}

/// Listening groups of the mock, Parts 1–4, numbered 1–40.
List<MockGroup> mockListeningGroups(Map<String, dynamic> mock) {
  final sets = mockListeningSets(mock);
  final out = <MockGroup>[];
  for (var i = 0; i < sets.length; i++) {
    final set = sets[i].$1;
    final part = set.i('part') > 0 ? set.i('part') : i + 1;
    out.addAll(mockGroupsOf(set, offset: sets[i].$2, unitIndex: i, heading: 'Part $part'));
  }
  return out;
}

/// Reading groups of the mock, Passages 1–3, numbered 1–40.
List<MockGroup> mockReadingGroups(Map<String, dynamic> mock) {
  final passages = mockReadingPassages(mock);
  final out = <MockGroup>[];
  for (var i = 0; i < passages.length; i++) {
    out.addAll(mockGroupsOf(
      passages[i].$1,
      offset: passages[i].$2,
      unitIndex: i,
      heading: 'Passage ${i + 1}',
    ));
  }
  return out;
}

/// Total question count of some groups (a pick-2 item counts 2).
int mockQuestionTotal(List<MockGroup> groups) =>
    groups.fold<int>(0, (s, g) => s + g.count);

/// Selected keys of a `multi` answer ("A,C" → [A, C]).
List<String> mockMultiKeys(String? stored) {
  if (stored == null || stored.trim().isEmpty) return <String>[];
  return stored.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

/// Question numbers that have an answer.
Set<int> mockAnsweredNumbers(List<MockGroup> groups, Map<int, String> answers) {
  final out = <int>{};
  for (final g in groups) {
    for (final q in g.questions) {
      final v = answers[q.number] ?? '';
      if (q.kind == 'multi') {
        final n = mockMultiKeys(v).length;
        for (var i = 0; i < q.span && i < n; i++) {
          out.add(q.number + i);
        }
      } else if (v.trim().isNotEmpty) {
        out.add(q.number);
      }
    }
  }
  return out;
}

/// Marks for one question (0..span) against the bank answer.
int mockMarks(MockQuestion q, String? given) {
  final v = (given ?? '').trim();
  if (v.isEmpty) return 0;
  switch (q.kind) {
    case 'text':
      return Scoring.matches(v, q.accepted) ? 1 : 0;
    case 'multi':
      final key = q.answers.map((e) => e.toUpperCase()).toSet();
      final sel = mockMultiKeys(v).map((e) => e.toUpperCase()).toSet();
      final c = sel.where(key.contains).length;
      return c > q.span ? q.span : c;
    default:
      for (final a in q.answers) {
        if (a.trim().toLowerCase() == v.toLowerCase()) return 1;
      }
      return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section labels computed from the composition
// ─────────────────────────────────────────────────────────────────────────────

/// Seconds of listening audio (sum of the sets' durations).
int mockListeningAudioSeconds(Map<String, dynamic> mock) {
  var s = 0;
  for (final e in mockListeningSets(mock)) {
    final d = e.$1.i('durationSeconds');
    s += d > 0 ? d : 180;
  }
  return s;
}

/// Listening section timer: the audio plus the transfer/check time.
int mockListeningSeconds(Map<String, dynamic> mock) {
  final extra = mockContent.m('timing').i('listeningExtraSeconds');
  return mockListeningAudioSeconds(mock) + (extra > 0 ? extra : 120);
}

/// Section note for the G2 / G4 section list, from the real composition.
String mockSectionNote(Map<String, dynamic> section, Map<String, dynamic> mock) {
  switch (section.s('key')) {
    case 'listening':
      final sets = mockListeningSets(mock);
      if (sets.isEmpty) return section.s('note');
      return 'Audio plays once · ${sets.length} parts · '
          '${mockQuestionTotal(mockListeningGroups(mock))} questions';
    case 'reading':
      final ps = mockReadingPassages(mock);
      if (ps.isEmpty) return section.s('note');
      return '${ps.length} passages · ${mockQuestionTotal(mockReadingGroups(mock))} questions';
    default:
      return section.s('note');
  }
}

/// Section time label; Listening is computed from the audio length.
String mockSectionTime(Map<String, dynamic> section, Map<String, dynamic> mock, {bool short = false}) {
  if (section.s('key') == 'listening' && mockListeningSets(mock).isNotEmpty) {
    final audio = (mockListeningAudioSeconds(mock) / 60).ceil();
    final extra = (mockListeningSeconds(mock) - mockListeningAudioSeconds(mock)) ~/ 60;
    return short ? '${audio + extra} min' : '$audio+$extra min';
  }
  return section.s(short ? 'shortTimeLabel' : 'timeLabel');
}
