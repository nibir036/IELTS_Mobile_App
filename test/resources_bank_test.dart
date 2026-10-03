// Resources bank (assets/content/resources_bank.json, tool/import_resources_bank.py):
// counts as imported, unique ids, generated quizzes and the merged phrase lists.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/data/content.dart';
import 'package:nexted_ielts_app/app/data/demo.dart';
import 'package:nexted_ielts_app/app/data/res_bank.dart';
import 'package:nexted_ielts_app/features/home/search_index.dart';
import 'package:nexted_ielts_app/features/resources/quiz_rounds.dart';
import 'package:nexted_ielts_app/features/resources/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Demo.load();
  });

  test('bank sizes match the source files', () {
    expect(ResBank.vocab.length, 1382);
    expect(ResBank.idioms.length, 1159); // 588 from the source files + 571 added J–Z
    expect(ResBank.phrasalVerbs.length, 1258);
    expect(ResBank.irregularVerbs.length, 175);
    expect(ResBank.connectorGroups.length, 14);
    expect(ResBank.connectorGroups.fold<int>(0, (n, g) => n + g.l('items').length), 106);
    expect(ResBank.academicWords.length, 686);
    expect(ResBank.topics.length, 23);
    expect(ResBank.topics.fold<int>(0, (n, t) => n + t.l('items').length), 2095);
    expect(phraseItems('topicVocab').length, 2095);
  });

  test('every word is complete and every id unique', () {
    final seen = <String>{};
    for (final w in ResBank.allWords) {
      expect(seen.add(w.s('id')), isTrue, reason: 'duplicate id ${w.s('id')}');
      expect(w.s('word'), isNotEmpty);
      expect(w.s('definition'), isNotEmpty, reason: w.s('id'));
      expect(w.ls('examples').where((e) => e.isNotEmpty), isNotEmpty, reason: w.s('id'));
    }
    for (final v in ResBank.vocab) {
      expect(v.s('ipa'), startsWith('/'), reason: v.s('word'));
      expect(v.ls('examples').length, 2, reason: v.s('word'));
      expect(v.d('band'), inInclusiveRange(4.5, 9), reason: v.s('word'));
    }
    for (final v in ResBank.irregularVerbs) {
      for (final k in <String>['base', 'past', 'participle', 'meaning', 'example']) {
        expect(v.s(k), isNotEmpty, reason: '${v.s('base')} $k');
      }
    }
  });

  test('academic day quizzes are generated with one correct option', () {
    expect(ResBank.academicDays, 35);
    final quiz = Content.quiz(ResBank.academicQuizId(3));
    final words = ResBank.academicDay(3);
    expect(quiz.l('questions').length, words.length);
    for (var i = 0; i < words.length; i++) {
      final q = quiz.l('questions')[i];
      expect(q.ls('options').length, 4);
      expect(q.ls('options').toSet().length, 4);
      expect(q.ls('options')[q.i('answer')], words[i].s('definition'));
    }
    expect(Content.quiz('aw_day_999'), isEmpty);
  });

  test('phrase lists merge the curated IELTS notes into the bank', () {
    final pv = phraseItems('phrasalVerbs');
    expect(pv.length, greaterThanOrEqualTo(1258));
    final curated = Demo.section('content').m('resources').l('phrasalVerbs');
    for (final c in curated) {
      expect(pv.any((p) => p.s('id') == c.s('id')), isTrue, reason: 'curated ${c.s('id')} kept');
    }
    expect(pv.where((p) => p.s('topic').isNotEmpty).length, greaterThanOrEqualTo(curated.length));
  });

  test('Part 3 topics carry their one-line description; speaking words find bank extras', () {
    expect(Content.part3Topics.length, 60);
    for (final t in Content.part3Topics) {
      expect(t.s('description'), isNotEmpty, reason: t.s('id'));
    }
    expect(Content.part3Topics.first.s('description'), 'Famous or local figures who inspire others through their actions.');
    expect(ResBank.vocabFor('Absorb')?.ls('examples').length, 2);
  });

  test('word of the day, saved words and search use the bank', () {
    final wod = ResBank.wordOfTheDay(const <String, dynamic>{}, now: DateTime(2026, 10, 2));
    expect(wod.s('word'), isNotEmpty);
    expect(ResBank.wordOfTheDay(const <String, dynamic>{}, now: DateTime(2026, 10, 2)).s('id'), wod.s('id'));
    expect(ResBank.wordOfTheDay(const <String, dynamic>{}, now: DateTime(2026, 10, 3)).s('id'), isNot(wod.s('id')));
    expect(resolveWord('vb_absorb')?.s('word'), 'Absorb');
    SearchIndex.reset();
    final hits = SearchIndex.search('a blessing in disguise');
    expect(hits.first.s('resWord'), 'id_a_blessing_in_disguise');
  });

  test('generated vault decks: valid rounds with 4 distinct options and the right answer', () {
    final decks = ResBank.quizDecks;
    expect(decks.map((d) => d.s('id')), containsAll(<String>['b6', 'b7', 'b8', 'syn', 'idiom', 'pv', 'link', 'topic']));
    expect(totalQuizRounds, greaterThan(500));
    for (final d in decks) {
      for (final n in <int>[1, d.i('rounds')]) {
        final id = ResBank.deckRoundId(d.s('id'), n);
        expect(ResBank.parseRoundId(id), (d.s('id'), n));
        final quiz = Content.quiz(id);
        expect(quiz.s('id'), id);
        final qs = quiz.l('questions');
        expect(qs.length, inInclusiveRange(4, ResBank.roundSize), reason: id);
        for (final q in qs) {
          expect(q.ls('options').length, 4, reason: '$id ${q.s('word')}');
          expect(q.ls('options').toSet().length, 4, reason: '$id ${q.s('word')}');
          expect(q.ls('options')[q.i('answer')], q.s('meaningShort'), reason: id);
        }
        // same round twice → same questions and option order
        expect(Content.quiz(id).l('questions').first.ls('options'), qs.first.ls('options'));
      }
      expect(Content.quiz(ResBank.deckRoundId(d.s('id'), d.i('rounds') + 1)), isEmpty);
    }
    expect(Content.quiz('gq_nope_1'), isEmpty);
    expect(Content.quiz('gq_b7_x'), isEmpty);
  });
}
