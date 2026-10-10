// Full tests from the website (assets/content/tests_bank.json, tool/import_web_tests.py):
// Listening 1–9, Reading 1–16, Writing 1–16, Speaking 1–16 and Full Mock 1–9.
// Mock N uses Listening N with Reading/Writing/Speaking N (N ≤ 4) or N + 6 (N ≥ 5).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/data/content.dart';
import 'package:nexted_ielts_app/app/data/demo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Demo.load();
  });

  bool hasAnswer(dynamic a) => a != null && '$a'.trim().isNotEmpty;

  test('counts and names', () {
    expect(Content.listeningTests.map((t) => t.s('title')), <String>[
      for (var i = 1; i <= 9; i++) 'Listening Test $i',
    ]);
    expect(Content.readingTests.length, 16);
    expect(Content.readingTests.first.s('title'), 'Academic Reading Test 1');
    expect(Content.writingTests.length, 16);
    expect(Content.speakingTests.length, 16);
    expect(Content.mockTests.map((m) => m.s('title')), <String>[
      for (var i = 1; i <= 9; i++) 'Full Mock Test $i',
    ]);
    // the old demo tests still resolve for attempts taken on them
    expect(Content.listeningTest('lt_01'), isNotEmpty);
    expect(Content.readingTest('rt_01'), isNotEmpty);
    expect(Content.mockTest('mt_a'), isNotEmpty);
  });

  test('listening: 4 parts × 10 questions, recordings and plans on disk', () {
    for (final t in Content.listeningTests) {
      final sets = Content.listeningTestSets(t.s('id'));
      expect(sets.map((e) => e.$1.i('part')).toList(), <int>[1, 2, 3, 4], reason: t.s('id'));
      for (final (s, _) in sets) {
        expect(Content.setQuestionCount(s), 10, reason: s.s('id'));
        expect(File(s.s('audio')).existsSync(), isTrue, reason: s.s('audio'));
        final nums = <int>[
          for (final g in s.l('groups'))
            for (final q in g.l('questions'))
              for (var k = 0; k < (g.i('pick') > 1 ? g.i('pick') : 1); k++) q.i('number') + k,
        ];
        expect(nums, List<int>.generate(10, (i) => i + 1), reason: s.s('id'));
        for (final g in s.l('groups')) {
          if (g.s('type') == 'map') expect(File(g.s('image')).existsSync(), isTrue, reason: g.s('image'));
          for (final q in g.l('questions')) {
            final where = '${s.s('id')} Q${q.i('number')} (${g.s('type')})';
            expect(hasAnswer(q['answer']), isTrue, reason: where);
            switch (g.s('type')) {
              case 'mcq':
                expect(q.l('options').map((o) => o.s('key')), contains(q.s('answer')), reason: where);
              case 'multi':
                final keys = q.l('options').map((o) => o.s('key')).toSet();
                final picks = (q['answer'] as List).map((e) => '$e').toList();
                expect(picks.length, g.i('pick'), reason: where);
                for (final a in picks) {
                  expect(keys, contains(a), reason: where);
                }
              case 'map':
              case 'matching':
                expect(g.l('options').map((o) => o.s('key')), contains(q.s('answer')), reason: where);
              case 'form':
              case 'table':
                expect(q.s('label'), isNotEmpty, reason: where);
                expect(q.ls('accepted'), contains(q.s('answer')), reason: where);
              case 'summary':
                expect(g.s('summary'), contains('(${q.i('number')})___'), reason: where);
                expect(q.ls('accepted'), contains(q.s('answer')), reason: where);
              case 'gap':
              case 'notes':
                expect(q.s('text'), contains('______'), reason: where);
                expect(q.ls('accepted'), contains(q.s('answer')), reason: where);
              default:
                fail('unexpected type $where');
            }
          }
        }
      }
    }
  });

  test('reading: 3 passages, 40 questions, every answer valid', () {
    for (final t in Content.readingTests) {
      var total = 0;
      for (final (p, offset) in Content.readingTestPassages(t.s('id'))) {
        expect(offset, total);
        expect(p.l('paragraphs').length, greaterThanOrEqualTo(4), reason: p.s('id'));
        expect(p.s('topic'), isNotEmpty, reason: p.s('id'));
        final letters = p.l('paragraphs').map((x) => x.s('letter')).toSet();
        for (final g in p.l('groups')) {
          for (final q in g.l('questions')) {
            final where = '${p.s('id')} Q${q.i('number')} (${g.s('type')})';
            expect(hasAnswer(q['answer']), isTrue, reason: where);
            switch (g.s('type')) {
              case 'tfng':
              case 'ynng':
                expect(g.ls('options'), contains(q.s('answer')), reason: where);
              case 'gap':
                expect(q.s('text'), contains('______'), reason: where);
                expect(q.ls('accepted'), contains(q.s('answer')), reason: where);
              case 'heading':
                expect(g.l('headings').map((h) => h.s('key')), contains(q.s('answer')), reason: where);
                expect(letters, contains(q.s('paragraph')), reason: where);
              case 'matching':
                expect(letters, contains(q.s('answer')), reason: where);
              case 'mcq':
                expect(q.l('options').map((o) => o.s('key')), contains(q.s('answer')), reason: where);
              case 'summary':
                expect(g.l('options').map((o) => o.s('key')), contains(q.s('answer')), reason: where);
                expect(g.s('text'), contains('(${q.i('number')}) ______'), reason: where);
              default:
                fail('unexpected type $where');
            }
          }
        }
        total += Content.passageQuestionCount(p);
      }
      expect(total, 40, reason: t.s('id'));
    }
  });

  test('writing: Task 1 picture + Task 2 question per test', () {
    for (final t in Content.writingTests) {
      final t1 = Content.writingPrompt(t.s('task1'));
      final t2 = Content.writingPrompt(t.s('task2'));
      expect(t1.i('task'), 1, reason: t.s('id'));
      expect(t2.i('task'), 2, reason: t.s('id'));
      expect(File(t1.s('image')).existsSync(), isTrue, reason: t1.s('image'));
      expect(t1.s('prompt'), contains('Summarise the information'));
      expect(t2.s('question'), isNotEmpty);
      expect(t1.s('title'), isNotEmpty);
    }
  });

  test('speaking: Part 1 topics, cue card and Part 3 resolve', () {
    for (final t in Content.speakingTests) {
      final p1 = Content.part1Topic(t.s('part1'));
      final card = Content.cueCard(t.s('cueCard'));
      expect(p1.ls('questions').length, greaterThanOrEqualTo(9), reason: t.s('id'));
      expect(card.ls('bullets').length, 4, reason: t.s('id'));
      expect(card.ls('part3'), isNotEmpty, reason: t.s('id'));
      for (final id in t.ls('part3')) {
        expect(Content.part3Topic(id).l('questions'), isNotEmpty, reason: id);
      }
    }
  });

  test('mocks combine test N of every module', () {
    for (final m in Content.mockTests) {
      final n = m.i('number');
      String two(int x) => x.toString().padLeft(2, '0');
      expect(m.s('listeningTest'), 'lt_w${two(n)}');
      expect(Content.listeningTest(m.s('listeningTest')), isNotEmpty);
      final k = n <= 4 ? n : n + 6;
      expect(Content.readingTest(m.s('readingTest')).s('title'), 'Academic Reading Test $k');
      expect(Content.writingPrompt(m.s('task1')), isNotEmpty);
      expect(Content.writingPrompt(m.s('task2')), isNotEmpty);
      expect(Content.part1Topic(m.m('speaking').s('part1')), isNotEmpty);
      expect(Content.cueCard(m.m('speaking').s('cueCard')), isNotEmpty);
    }
  });
}
