// Content bank integrity (assets/demo/demo_data.json → "content") and the
// demo account's seed history. Every rule here was checked against the
// current data with python before being encoded.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/data/content.dart';
import 'package:nexted_ielts_app/app/data/demo.dart';
import 'package:nexted_ielts_app/app/data/store.dart';
import 'package:nexted_ielts_app/features/home/search_index.dart';
import 'package:nexted_ielts_app/features/listening/bank.dart';
import 'package:nexted_ielts_app/features/reading/session.dart';

/// Ids of a collection, failing on duplicates.
void expectUniqueIds(String name, List<Map<String, dynamic>> list) {
  final seen = <String>{};
  final dupes = <String>[];
  for (final m in list) {
    final id = m.s('id');
    expect(id, isNotEmpty, reason: '$name has an item without an id');
    if (!seen.add(id)) dupes.add(id);
  }
  expect(dupes, isEmpty, reason: '$name has duplicate ids');
}

bool hasAnswer(Object? a) {
  if (a == null) return false;
  if (a is String) return a.trim().isNotEmpty;
  if (a is List) return a.isNotEmpty && a.every((e) => '$e'.trim().isNotEmpty);
  return true; // numbers (quiz option index)
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Demo.load();
  });

  group('collections', () {
    test('are present and non-empty', () {
      expect(Content.readingPassages, isNotEmpty);
      expect(Content.readingTests, isNotEmpty);
      expect(Content.listeningSets, isNotEmpty);
      expect(Content.listeningTests, isNotEmpty);
      expect(Content.writingTask1, isNotEmpty);
      expect(Content.writingTask2, isNotEmpty);
      expect(Content.part1Topics, isNotEmpty);
      expect(Content.cueCards, isNotEmpty);
      expect(Content.mockTests, isNotEmpty);
      expect(Content.quizzes, isNotEmpty);
    });

    test('ids are unique per collection', () {
      final res = Demo.section('content').m('resources');
      final all = <String, List<Map<String, dynamic>>>{
        'reading.passages': Content.readingPassages,
        'reading.tests': Content.readingTests,
        'listening.sets': Content.listeningSets,
        'listening.tests': Content.listeningTests,
        'writing.task1': Content.writingTask1,
        'writing.task2': Content.writingTask2,
        'speaking.part1Topics': Content.part1Topics,
        'speaking.cueCards': Content.cueCards,
        'mock.tests': Content.mockTests,
        'resources.quizzes': Content.quizzes,
        'resources.phrasalVerbs': res.l('phrasalVerbs'),
        'resources.idioms': res.l('idioms'),
      };
      all.forEach(expectUniqueIds);
      // Writing prompts are looked up across both tasks by id.
      expectUniqueIds('writing (task1 + task2)', <Map<String, dynamic>>[
        ...Content.writingTask1,
        ...Content.writingTask2,
      ]);
    });
  });

  group('reading', () {
    test('every test has 3 existing passages totalling 40 questions', () {
      for (final t in Content.readingTests) {
        final id = t.s('id');
        final ids = t.ls('passages');
        expect(ids.length, 3, reason: id);
        for (final pid in ids) {
          expect(Content.readingPassage(pid), isNotEmpty, reason: '$id → $pid missing');
        }
        final parts = Content.readingTestPassages(id);
        expect(parts.length, ids.length, reason: id);
        var total = 0;
        for (final (p, offset) in parts) {
          expect(offset, total, reason: '$id offset of ${p.s('id')}');
          total += Content.passageQuestionCount(p);
        }
        expect(total, 40, reason: id);
      }
    });

    test('questions are numbered 1..n within each passage', () {
      for (final p in Content.readingPassages) {
        final nums = <int>[
          for (final g in p.l('groups'))
            for (final q in g.l('questions')) q.i('number'),
        ];
        expect(nums, List<int>.generate(nums.length, (i) => i + 1), reason: p.s('id'));
      }
    });

    test('every question has a valid answer', () {
      for (final p in Content.readingPassages) {
        for (final g in p.l('groups')) {
          final type = g.s('type');
          for (final q in g.l('questions')) {
            final where = '${p.s('id')} Q${q.i('number')} ($type)';
            final a = q['answer'];
            expect(hasAnswer(a), isTrue, reason: '$where has no answer');
            switch (type) {
              case 'tfng':
              case 'ynng':
              case 'matching':
                expect(g.ls('options'), contains(a), reason: where);
              case 'heading':
                expect(g.l('headings').map((h) => h.s('key')), contains(a), reason: where);
              case 'mcq':
                expect(q.l('options').map((o) => o.s('key')), contains(a), reason: where);
              case 'gap':
                if (q.containsKey('accepted')) {
                  expect(Scoring.matches('$a', q['accepted']), isTrue, reason: '$where answer not in accepted');
                }
            }
          }
        }
      }
    });

    test('evidence phrase appears verbatim in its paragraph', () {
      final problems = <String>[];
      for (final p in Content.readingPassages) {
        final paras = <String, String>{
          for (final para in p.l('paragraphs')) para.s('letter'): para.s('text').toLowerCase(),
        };
        for (final g in p.l('groups')) {
          for (final q in g.l('questions')) {
            final where = '${p.s('id')} Q${q.i('number')}';
            final letter = q.s('evidenceParagraph');
            final ev = q.s('evidence');
            if (letter.isEmpty || ev.isEmpty) {
              problems.add('$where: missing evidence');
            } else if (!paras.containsKey(letter)) {
              problems.add('$where: no paragraph $letter');
            } else if (!paras[letter]!.contains(ev.toLowerCase())) {
              problems.add('$where: "$ev" not in paragraph $letter');
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('listening', () {
    test('every test has 4 existing sets (Parts 1–4) totalling 40 questions', () {
      for (final t in Content.listeningTests) {
        final id = t.s('id');
        final ids = t.ls('sets');
        expect(ids.length, 4, reason: id);
        for (final sid in ids) {
          expect(Content.listeningSet(sid), isNotEmpty, reason: '$id → $sid missing');
        }
        final sets = Content.listeningTestSets(id);
        expect(sets.length, 4, reason: id);
        expect(sets.map((e) => e.$1.i('part')).toList(), <int>[1, 2, 3, 4], reason: id);
        var total = 0;
        for (final (s, offset) in sets) {
          expect(offset, total, reason: '$id offset of ${s.s('id')}');
          expect(Content.setQuestionCount(s), 10, reason: s.s('id'));
          total += Content.setQuestionCount(s);
        }
        expect(total, 40, reason: id);
      }
    });

    test('each set\'s audio asset exists on disk (bank recordings may be pending)', () {
      for (final s in <Map<String, dynamic>>[...Content.listeningDemoSets, ...Content.listeningBankSets]) {
        final audio = s.s('audio');
        expect(audio, isNotEmpty, reason: '${s.s('id')} has no audio');
        expect(Content.setAudio(s), audio);
        if (s.s('audioStatus') == 'pending') continue;
        expect(File(audio).existsSync(), isTrue, reason: '${s.s('id')}: $audio missing');
      }
      expect(File('assets/audio/listening_placeholder.mp3').existsSync(), isTrue);
    });

    test('questions are numbered 1..n within each set (multi counts twice)', () {
      for (final s in <Map<String, dynamic>>[...Content.listeningDemoSets, ...Content.listeningBankSets]) {
        final nums = <int>[];
        for (final g in s.l('groups')) {
          for (final q in g.l('questions')) {
            nums.add(q.i('number'));
            if (g.i('pick') > 1) {
              for (var k = 1; k < g.i('pick'); k++) {
                nums.add(q.i('number') + k);
              }
            }
          }
        }
        expect(nums, List<int>.generate(nums.length, (i) => i + 1), reason: s.s('id'));
      }
    });

    test('every question has a valid answer', () {
      for (final s in <Map<String, dynamic>>[...Content.listeningDemoSets, ...Content.listeningBankSets]) {
        for (final g in s.l('groups')) {
          final type = g.s('type');
          for (final q in g.l('questions')) {
            final where = '${s.s('id')} Q${q.i('number')} ($type)';
            final a = q['answer'];
            expect(hasAnswer(a), isTrue, reason: '$where has no answer');
            if (type == 'mcq' || type == 'multi' || type == 'matching' || type == 'map') {
              final opts = q.l('options').isNotEmpty ? q.l('options') : g.l('options');
              final keys = opts.map((o) => o.s('key')).toSet();
              final given = a is List ? a.map((e) => '$e').toList() : <String>['$a'];
              for (final k in given) {
                expect(keys, contains(k), reason: where);
              }
              if (type == 'multi') {
                expect(given.length, g.i('pick'), reason: where);
              }
            }
            if (listeningTypedGroup(type) && q.containsKey('accepted')) {
              expect(Scoring.matches('$a', q['accepted']), isTrue, reason: '$where answer not in accepted');
            }
          }
        }
      }
    });

    test('transcripts are present', () {
      for (final s in <Map<String, dynamic>>[...Content.listeningDemoSets, ...Content.listeningBankSets]) {
        expect(s.l('transcript'), isNotEmpty, reason: s.s('id'));
      }
    });
  });

  group('listening question bank', () {
    const known = <String>{'form', 'notes', 'sentence', 'short', 'mcq', 'multi', 'matching', 'map', 'table', 'summary'};

    test('32 sets: every part has each of the 8 formats once, 20 questions each', () {
      final sets = Content.listeningBankSets;
      expect(sets.length, 32);
      for (var part = 1; part <= 4; part++) {
        final codes = sets.where((x) => x.i('part') == part).map((x) => x.s('formatCode')).toList()..sort();
        expect(codes, (kListeningFormats.map((f) => f.$1).toList()..sort()), reason: 'Part $part');
      }
      for (final s in sets) {
        expect(Content.setQuestionCount(s), 20, reason: s.s('code'));
        expect(s.m('answerKey').length, 20, reason: s.s('code'));
        expect(Content.listeningSet(s.s('id')).s('code'), s.s('code'));
      }
    });

    test('group types are known and carry what the screens need', () {
      for (final s in Content.listeningBankSets) {
        for (final g in s.l('groups')) {
          final where = '${s.s('code')} ${g.s('id')}';
          expect(known, contains(g.s('type')), reason: where);
          switch (g.s('type')) {
            case 'map':
              expect(g.l('options').length, 10, reason: where);
              expect(g.s('layout'), isNotEmpty, reason: where);
            case 'table':
              expect(g.ls('columns'), isNotEmpty, reason: where);
              for (final q in g.l('questions')) {
                expect(jsonEncode(g['rows']), contains('(${q.i('number')})___'), reason: '$where Q${q.i('number')}');
              }
            case 'summary':
              for (final q in g.l('questions')) {
                expect(g.s('summary'), contains('(${q.i('number')})___'), reason: '$where Q${q.i('number')}');
                expect(q.s('text'), contains('______'), reason: '$where Q${q.i('number')}');
              }
            case 'matching':
              expect(g.l('options'), isNotEmpty, reason: where);
            case 'short':
              for (final q in g.l('questions')) {
                expect(q.s('text'), isNotEmpty, reason: where);
              }
          }
        }
      }
    });

    test('transcript lines are in time order and every speaker has a voice', () {
      for (final s in Content.listeningBankSets) {
        final lines = s.l('transcript');
        final names = s.l('speakers').map((p) => p.s('name')).toSet();
        for (var i = 0; i < lines.length; i++) {
          expect(names, contains(lines[i].s('speaker')), reason: '${s.s('code')} line ${i + 1}');
          if (i > 0) expect(lines[i].d('start'), greaterThan(lines[i - 1].d('start')));
          expect(lines[i].s('text'), isNot(contains('[')), reason: '${s.s('code')}: tag left in transcript');
        }
        expect(s.d('durationSeconds'), greaterThan(lines.last.d('start')));
      }
    });
  });

  group('listening map images', () {
    test('every map / plan group has its drawing on disk', () {
      final maps = <Map<String, dynamic>>[
        for (final set in Content.listeningBankSets)
          for (final g in set.l('groups'))
            if (g.s('type') == 'map') g,
      ];
      expect(maps.length, 8);
      for (final g in maps) {
        expect(g.s('image'), startsWith('assets/listening/maps/'));
        expect(File(g.s('image')).existsSync(), isTrue, reason: g.s('image'));
      }
    });
  });

  group('writing question bank', () {
    test('140 Task 1 (7 types × 20) and 120 Task 2 (6 types × 20) questions', () {
      final t1 = Content.writingBankTask1;
      final t2 = Content.writingBankTask2;
      expect(t1.length, 140);
      expect(t2.length, 120);
      for (final type in <String>['line', 'bar', 'pie', 'table', 'map', 'process', 'mixed']) {
        expect(t1.where((x) => x.s('type') == type).length, 20, reason: type);
      }
      for (final type in <String>['opinion', 'discussion', 'advantages', 'problem', 'two-part', 'positive-negative']) {
        expect(t2.where((x) => x.s('type') == type).length, 20, reason: type);
      }
    });

    test('every Task 1 question has its visual on disk and its data', () {
      for (final x in Content.writingBankTask1) {
        expect(File(x.s('image')).existsSync(), isTrue, reason: '${x.s('id')} ${x.s('image')}');
        expect(x.s('dataText'), isNotEmpty, reason: x.s('id'));
        expect(x.m('visual').l('panels'), isNotEmpty, reason: x.s('id'));
      }
    });

    test('every question has Band 6, 7 and 8 samples long enough for the task', () {
      for (final x in <Map<String, dynamic>>[...Content.writingBankTask1, ...Content.writingBankTask2]) {
        final samples = x.l('samples');
        expect(samples.map((s) => s.i('band')).toList(), <int>[6, 7, 8], reason: x.s('id'));
        final min = x.i('task') == 1 ? 150 : 250;
        for (final s in samples) {
          expect(s.i('words'), greaterThanOrEqualTo(min), reason: '${x.s('id')} band ${s.i('band')}');
          expect(s.s('why'), isNotEmpty, reason: '${x.s('id')} band ${s.i('band')}');
          expect(s.ls('paragraphs').length, greaterThanOrEqualTo(3), reason: '${x.s('id')} band ${s.i('band')}');
        }
        expect(x.m('modelAnswer').d('band'), 8, reason: x.s('id'));
      }
    });
  });

  group('speaking question bank', () {
    final mark = RegExp(r'\[\[(.+?)\]\]');

    bool fromGuide(Map<String, dynamic> x) => x.s('source') == 'guide';

    test('62 Part 1 topics × 5 + 3 from the guide, 200 + 7 cue cards, 60 Part 3 topics × 8', () {
      expect(Content.speakingBankPart1.where((t) => !fromGuide(t)).length, 62);
      expect(Content.speakingBankPart1.where(fromGuide).length, 3);
      for (final t in Content.speakingBankPart1) {
        final n = fromGuide(t) ? 3 : 5;
        expect(t.l('samples').length, n, reason: t.s('id'));
        expect(t.ls('questions').length, n, reason: t.s('id'));
      }
      expect(Content.speakingBankCards.where((c) => !fromGuide(c)).length, 200);
      expect(Content.speakingBankCards.where(fromGuide).length, 7);
      expectUniqueIds('cue cards', Content.speakingBankCards);
      expectUniqueIds('part 1 topics', Content.speakingBankPart1);
      expect(Content.part3Topics.length, 60);
      for (final t in Content.part3Topics) {
        expect(t.l('questions').length, 8, reason: t.s('id'));
      }
      expect(Content.part1Topics.first.s('id'), Content.speakingBankPart1.first.s('id'));
      expect(Content.cueCards.length, Content.speakingBankCards.length);
    });

    test('cue cards: 4 bullets, a 2-minute sample, 2 follow-ups (guide cards: notes), linked Part 3', () {
      for (final c in Content.speakingBankCards) {
        final guide = fromGuide(c);
        expect(c.ls('bullets').length, 4, reason: c.s('id'));
        expect(c.m('sample').i('words'), inInclusiveRange(240, guide ? 360 : 290), reason: c.s('id'));
        expect(c.l('followUps').length, guide ? 0 : 2, reason: c.s('id'));
        if (guide) expect(c.ls('notes'), isNotEmpty, reason: c.s('id'));
        expect(c.ls('part3'), isNotEmpty, reason: c.s('id'));
        expect(c.l('part3Samples').length, c.ls('part3').length, reason: c.s('id'));
        for (final id in c.ls('part3Topics')) {
          expect(Content.part3Topic(id), isNotEmpty, reason: '${c.s('id')} → $id');
        }
      }
    });

    test('every marked word has a dictionary entry', () {
      final vocab = Content.speakingVocab;
      final answers = <String>[
        for (final t in Content.speakingBankPart1.where((t) => !fromGuide(t)))
          for (final x in t.l('samples')) x.s('answer'),
        for (final c in Content.speakingBankCards.where((c) => !fromGuide(c))) ...[
          c.m('sample').s('answer'),
          for (final x in c.l('followUps')) x.s('answer'),
        ],
        for (final t in Content.part3Topics)
          for (final x in t.l('questions')) x.s('answer'),
      ];
      expect(answers.length, 310 + 600 + 480);
      for (final a in answers) {
        expect(a, isNot(contains('—')));
        for (final m in mark.allMatches(a)) {
          final e = vocab.m(m.group(1)!.toLowerCase());
          expect(e.s('headword'), isNotEmpty, reason: m.group(1));
          expect(e.s('ipa'), startsWith('/'), reason: m.group(1));
          expect(e.s('meaning'), isNotEmpty, reason: m.group(1));
        }
      }
    });

    test('demo topics and cards still resolve by id (mock tests)', () {
      for (final t in Content.speakingDemoPart1) {
        expect(Content.part1Topic(t.s('id')).s('topic'), t.s('topic'));
      }
      for (final c in Content.speakingDemoCards) {
        expect(Content.cueCard(c.s('id')).s('title'), c.s('title'));
      }
    });
  });

  group('writing & speaking', () {
    test('prompts have text', () {
      for (final w in <Map<String, dynamic>>[...Content.writingTask1, ...Content.writingTask2]) {
        expect(w.s('prompt').trim(), isNotEmpty, reason: w.s('id'));
        expect(Content.writingPrompt(w.s('id')).s('id'), w.s('id'));
      }
    });

    test('part 1 topics have questions, cue cards have bullets', () {
      for (final p in Content.part1Topics) {
        expect(p.ls('questions'), isNotEmpty, reason: p.s('id'));
      }
      for (final c in Content.cueCards) {
        expect(c.ls('bullets'), isNotEmpty, reason: c.s('id'));
        expect(c.s('title').isNotEmpty || c.s('prompt').isNotEmpty, isTrue, reason: c.s('id'));
      }
    });
  });

  group('mock tests', () {
    test('reference existing listening/reading tests, prompts, topic and cue card', () {
      for (final m in Content.mockTests) {
        final id = m.s('id');
        expect(Content.listeningTest(m.s('listeningTest')), isNotEmpty, reason: '$id listeningTest');
        expect(Content.readingTest(m.s('readingTest')), isNotEmpty, reason: '$id readingTest');
        final t1 = m.s('task1');
        final t2 = m.s('task2');
        expect(Content.writingPrompt(t1), isNotEmpty, reason: '$id task1 $t1');
        expect(Content.writingPrompt(t2), isNotEmpty, reason: '$id task2 $t2');
        final sp = m.m('speaking');
        expect(Content.part1Topic(sp.s('part1')), isNotEmpty, reason: '$id part1');
        expect(Content.cueCard(sp.s('cueCard')), isNotEmpty, reason: '$id cueCard');
      }
    });
  });

  group('quizzes', () {
    test('each quiz has questions with options and an in-range answer', () {
      for (final quiz in Content.quizzes) {
        final qs = quiz.l('questions');
        expect(qs, isNotEmpty, reason: quiz.s('id'));
        for (final q in qs) {
          final opts = q.ls('options');
          expect(opts, isNotEmpty, reason: '${quiz.s('id')}/${q.s('id')}');
          final a = q['answer'];
          expect(a, isA<int>(), reason: '${quiz.s('id')}/${q.s('id')}');
          expect(a as int, inInclusiveRange(0, opts.length - 1), reason: '${quiz.s('id')}/${q.s('id')}');
        }
      }
    });

    test('phrasal verbs and idioms are present', () {
      final res = Demo.section('content').m('resources');
      expect(res.l('phrasalVerbs'), isNotEmpty);
      expect(res.l('idioms'), isNotEmpty);
    });
  });

  group('demo seed', () {
    List<Map<String, dynamic>> seedAttempts() =>
        Demo.all.l('accounts').first.m('data').l('attempts');

    test('demo account seed exists with attempts', () {
      final accounts = Demo.all.l('accounts');
      expect(accounts, isNotEmpty);
      expect(accounts.first.m('account').s('phone'), '1734519208');
      expect(seedAttempts(), isNotEmpty);
    });

    test('seed attempt ids are unique', () {
      expectUniqueIds('seed attempts', seedAttempts());
    });

    test('attempt refIds resolve to bank content', () {
      bool inList(List<Map<String, dynamic>> l, String id) => l.any((m) => m.s('id') == id);
      final listeningLessons = Demo.section('listening').l('lessons');
      final readingLessons = Demo.section('reading').l('lessons');
      final problems = <String>[];
      for (final a in seedAttempts()) {
        final ref = a.s('refId');
        if (ref.isEmpty) continue;
        final key = '${a.s('skill')}/${a.s('kind')}';
        final bool? ok = switch (key) {
          'listening/test' => Content.listeningTest(ref).isNotEmpty,
          'listening/mini' => Content.listeningSet(ref).isNotEmpty,
          'listening/lesson' => inList(listeningLessons, ref),
          'reading/test' => Content.readingTest(ref).isNotEmpty,
          'reading/mini' => Content.readingPassage(ref).isNotEmpty,
          'reading/lesson' => inList(readingLessons, ref),
          'writing/task1' => Content.writingPrompt(ref).isNotEmpty,
          'writing/task2' => Content.writingPrompt(ref).isNotEmpty,
          'speaking/part1' => Content.part1Topic(ref).isNotEmpty,
          'speaking/part2' => Content.cueCard(ref).isNotEmpty,
          // Part 3 practises a cue card's discussion; the D2 mock interview
          // uses the fixed id 'mock_interview'.
          'speaking/part3' => Content.cueCard(ref).isNotEmpty || ref == 'mock_interview',
          'mock/mock' => Content.mockTest(ref).isNotEmpty,
          'vocab/quiz' => Content.quiz(ref).isNotEmpty,
          _ => null, // drills, pronunciation, sessions: not bank content
        };
        if (ok == false) problems.add('${a.s('id')} ($key) → $ref');
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('band-scored seed attempts use half bands', () {
      for (final a in seedAttempts()) {
        final b = a['band'];
        if (b is num) {
          expect((b * 2) % 1, 0, reason: a.s('id'));
          expect(b.toDouble(), inInclusiveRange(0.0, 9.0), reason: a.s('id'));
        }
      }
    });
  });

  group('reading question bank', () {
    test('set-lesson titles are titles only (no body sentence run into them)', () {
      for (final p in Content.readingBankPassages) {
        final title = p.m('lesson').s('title');
        expect(title.length, lessThanOrEqualTo(90), reason: '${p.s('id')}: $title');
        expect(title.trimRight().endsWith(':'), isFalse, reason: '${p.s('id')}: $title');
      }
    });

    test('is loaded: 280 sets, 14 type lessons, 20 short tests', () {
      expect(Content.readingBankPassages.length, 280);
      expect(Content.readingTypeLessons.length, 14);
      expect(Content.readingPracticeTests.length, 20);
      expectUniqueIds('reading bank', Content.readingBankPassages);
      for (final type in Content.bankQuestionTypes) {
        expect(Content.bankSetsOf(type).length, 20, reason: type);
      }
    });

    test('bank ids resolve through the normal reading lookups', () {
      expect(Content.readingPassage('rb_mcq_01'), isNotEmpty);
      expect(Content.readingTest('rpt_01'), isNotEmpty);
      expect(ReadingRefs.isBank('rb_mcq_01'), isTrue);
      expect(ReadingRefs.isShortTest('rpt_01'), isTrue);
      expect(ReadingRefs.isTest('rpt_01'), isTrue);
      expect(ReadingRefs.isBankContent('rt_01'), isFalse);
      expect(ReadingRefs.isBankContent('rp_01'), isFalse);
    });

    test('questions are numbered 1..n and every stored answer scores as correct', () {
      final problems = <String>[];
      for (final p in Content.readingBankPassages) {
        final id = p.s('id');
        final items = ReadingRefs.items(id);
        final nums = <int>[for (final it in items) it.number];
        if (nums.toString() != List<int>.generate(nums.length, (i) => i + 1).toString()) {
          problems.add('$id numbering $nums');
        }
        if (items.length != Content.passageQuestionCount(p)) problems.add('$id count');
        for (final it in items) {
          final where = '$id Q${it.number} (${it.type})';
          if (!ReadingRefs.isCorrect(it, it.answer)) problems.add('$where: answer "${it.answer}" not scored correct');
          final letters = ReadingRefs.letters(it);
          if (letters.isNotEmpty && !letters.contains(it.answer)) problems.add('$where: ${it.answer} not in $letters');
          if (ReadingRefs.questionText(it) == 'Question ${it.number}') problems.add('$where: no question text / gap line');
        }
      }
      expect(problems, isEmpty, reason: problems.take(20).join('\n'));
    });

    test('a wrong or empty answer is never scored correct', () {
      for (final p in Content.readingBankPassages) {
        for (final it in ReadingRefs.items(p.s('id'))) {
          expect(ReadingRefs.isCorrect(it, ''), isFalse);
          expect(ReadingRefs.isCorrect(it, 'zzqx'), isFalse, reason: '${p.s('id')} Q${it.number}');
        }
      }
    });

    test('short tests: passages exist and question numbers run 1..questionCount', () {
      for (final t in Content.readingPracticeTests) {
        final id = t.s('id');
        for (final pid in t.ls('passages')) {
          expect(Content.bankPassage(pid), isNotEmpty, reason: '$id → $pid');
        }
        final nums = <int>[for (final it in ReadingRefs.items(id)) it.number];
        expect(nums, List<int>.generate(t.i('questionCount'), (i) => i + 1), reason: id);
        expect(ReadingRefs.minutes(id), t.i('minutes'), reason: id);
      }
    });

    test('diagram sets point to an image that exists', () {
      for (final p in Content.bankSetsOf('diagram_label')) {
        final path = p.s('diagram');
        expect(path, isNotEmpty, reason: p.s('id'));
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('gap markers are renumbered in tests', () {
      expect(ReadingRefs.renumber('beside the (1) ______ and (12) ______', 13),
          'beside the (14) ______ and (25) ______');
    });
  });

  group('translated content (l10n)', () {
    test('every listed language covers the reading bank', () {
      final index = (jsonDecode(File('assets/content/l10n/index.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final bank = (jsonDecode(File('assets/content/reading_bank.json').readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final langs = <String>[for (final l in (index['reading'] as List? ?? const <Object>[])) '$l'];
      for (final lang in langs) {
        final tr = (jsonDecode(File('assets/content/l10n/$lang/reading.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        final passages = tr.m('passages');
        for (final p in bank.l('passages')) {
          final t = passages.m(p.s('id'));
          expect(t.m('lesson').s('text'), isNotEmpty, reason: '$lang ${p.s('id')} lesson');
          for (final g in p.l('groups')) {
            for (final q in g.l('questions')) {
              expect(t.m('explanations').s('${q.i('number')}'), isNotEmpty,
                  reason: '$lang ${p.s('id')} q${q.i('number')}');
            }
          }
        }
        for (final l in bank.l('lessons')) {
          final t = tr.m('typeLessons').m(l.s('id'));
          expect(t.l('sections').length, l.l('sections').length, reason: '$lang ${l.s('id')} sections');
        }
        final demo = (jsonDecode(File('assets/demo/demo_data.json').readAsStringSync()) as Map).cast<String, dynamic>();
        for (final p in demo.m('content').m('reading').l('passages')) {
          for (final g in p.l('groups')) {
            for (final q in g.l('questions')) {
              if (q.s('explanation').isEmpty) continue;
              expect(passages.m(p.s('id')).m('explanations').s('${q.i('number')}'), isNotEmpty,
                  reason: '$lang ${p.s('id')} q${q.i('number')}');
            }
          }
        }
        final wg = (jsonDecode(File('assets/content/writing_guide.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        final wtr = (jsonDecode(File('assets/content/l10n/$lang/writing.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        for (final c in wg.l('chapters')) {
          final t = wtr.m('guide').m(c.s('id'));
          expect((t['blocks'] as List?)?.length, (c['blocks'] as List).length, reason: '$lang writing ${c.s('id')}');
          for (final b in c['blocks'] as List) {
            if (b is List && b.first == 'img') {
              expect(File('${b[1]}').existsSync(), isTrue, reason: '${c.s('id')} ${b[1]}');
            }
          }
        }
        for (final a in demo.m('resources').l('articles').where((a) => a.s('series') == 'writing')) {
          expect(wtr.m('tips').m(a.s('id')).l('tips').length, a.l('tips').length, reason: '$lang tips ${a.s('id')}');
        }
        final gg = (jsonDecode(File('assets/content/grammar_guide.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        final gtr = (jsonDecode(File('assets/content/l10n/$lang/grammar.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        expect(gg.l('chapters').length, greaterThanOrEqualTo(20));
        var exerciseItems = 0;
        for (final c in gg.l('chapters')) {
          final t = gtr.m('guide').m(c.s('id'));
          final en = c['blocks'] as List;
          final tr = t['blocks'] as List;
          expect(tr.length, en.length, reason: '$lang grammar ${c.s('id')}');
          for (var i = 0; i < en.length; i++) {
            expect((tr[i] as List).first, (en[i] as List).first, reason: '$lang grammar ${c.s('id')} block $i');
            if ((en[i] as List).first != 'exercise') continue;
            final a = ((en[i] as List)[1] as Map)['items'] as List;
            final b = ((tr[i] as List)[1] as Map)['items'] as List;
            expect(b.length, a.length);
            for (var j = 0; j < a.length; j++) {
              exerciseItems++;
              expect((b[j] as Map)['answer'], (a[j] as Map)['answer'], reason: '${c.s('id')} item ${j + 1}');
              expect('${(a[j] as Map)['answer']}'.trim(), isNotEmpty);
            }
          }
        }
        expect(exerciseItems, 258);
        final sg = (jsonDecode(File('assets/content/speaking_guide.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        final str = (jsonDecode(File('assets/content/l10n/$lang/speaking.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        for (final c in sg.l('chapters')) {
          final t = str.m('guide').m(c.s('id'));
          expect((t['blocks'] as List?)?.length, (c['blocks'] as List).length, reason: '$lang speaking ${c.s('id')}');
        }
        for (final a in demo.m('resources').l('articles').where((a) => a.s('series') == 'speaking')) {
          expect(str.m('tips').m(a.s('id')).l('tips').length, a.l('tips').length, reason: '$lang tips ${a.s('id')}');
        }
        // Listening Guide (15 chapters) + Vocabulary Lessons (the full book, 49): same block layout; drills keep their answers.
        for (final (module, file, count) in <(String, String, int)>[
          ('listening', 'listening_guide', 15),
          ('vocab', 'vocab_guide', 49),
        ]) {
          final en = (jsonDecode(File('assets/content/$file.json').readAsStringSync()) as Map).cast<String, dynamic>();
          final bn = (jsonDecode(File('assets/content/l10n/$lang/$module.json').readAsStringSync()) as Map)
              .cast<String, dynamic>();
          expect(en.l('chapters').length, count, reason: module);
          for (final c in en.l('chapters')) {
            final a = c['blocks'] as List;
            final b = bn.m('guide').m(c.s('id'))['blocks'] as List?;
            expect(b?.length, a.length, reason: '$lang $module ${c.s('id')}');
            for (var i = 0; i < a.length; i++) {
              expect((b![i] as List).first, (a[i] as List).first, reason: '$module ${c.s('id')} block $i');
              if ((a[i] as List).first == 'exercise') {
                final x = ((a[i] as List)[1] as Map)['items'] as List;
                final y = ((b[i] as List)[1] as Map)['items'] as List;
                for (var j = 0; j < x.length; j++) {
                  expect((y[j] as Map)['answer'], (x[j] as Map)['answer'], reason: '${c.s('id')} item $j');
                }
              }
            }
          }
        }
        for (final a in demo.m('resources').l('articles').where((a) => a.s('id').startsWith('lt_'))) {
          final ltr = (jsonDecode(File('assets/content/l10n/$lang/listening.json').readAsStringSync()) as Map)
              .cast<String, dynamic>();
          expect(ltr.m('tips').m(a.s('id')).l('tips').length, a.l('tips').length, reason: '$lang tips ${a.s('id')}');
        }
        // Easy Bangla meaning for every Resources bank word.
        final meanings = ((jsonDecode(File('assets/content/l10n/$lang/resources.json').readAsStringSync()) as Map)
                .cast<String, dynamic>())
            .m('meanings');
        expect(meanings.length, greaterThan(6800));
        expect(meanings.values.every((v) => '$v'.trim().isNotEmpty), isTrue);
        final guide = (jsonDecode(File('assets/content/reading_guide.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
        for (final c in guide.l('chapters')) {
          final t = tr.m('guide').m(c.s('id'));
          expect((t['blocks'] as List?)?.length, (c['blocks'] as List).length, reason: '$lang guide ${c.s('id')}');
        }
      }
    });
  });

  group('search', () {
    test('indexes every module and finds the right thing first', () {
      final types = <String>{for (final e in SearchIndex.entries) e.s('type')};
      for (final t in <String>['Reading', 'Listening', 'Writing', 'Speaking', 'Lesson', 'Guide', 'Tips', 'Vocab']) {
        expect(types, contains(t));
      }
      expect(SearchIndex.search('weather changed your plans').first.s('title'),
          'Describe a time when the weather changed your plans');
      expect(SearchIndex.search('lump in your throat').first.s('category'), 'vocab');
      expect(SearchIndex.search('inference').any((e) => e.s('type') == 'Reading'), isTrue);
      expect(SearchIndex.search('A.R.E').any((e) => e.s('type') == 'Guide'), isTrue);
      expect(SearchIndex.search('cohesion').any((e) => e.s('category') == 'lessons'), isTrue);
      for (final e in SearchIndex.entries) {
        expect(<String>['practice', 'lessons', 'vocab', 'mine'], contains(e.s('category')), reason: e.s('title'));
        if (e.s('route').isNotEmpty) expect(e.s('route'), startsWith('/'), reason: e.s('title'));
      }
    });
  });
}
