// Unit tests for the demo scorer (`Scoring` in lib/app/data/store.dart).
//
// Expectations follow what the code implements: the official IELTS
// raw-score → band tables for Listening and Academic / General Training
// Reading, and "nearest half band" rounding (.25 rounds up to .5, .75 rounds
// up to the next whole band) for the overall band and the criteria bands.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexted_ielts_app/app/data/store.dart';

/// True when [v] is a whole or half band (x.0 / x.5).
bool isHalfBand(double v) => (v * 2) == (v * 2).roundToDouble();

void main() {
  group('Scoring.listeningBand (raw /40)', () {
    // Every edge of the table: lowest raw score of each band and the raw
    // score just below it.
    const cases = <int, double>{
      40: 9.0, 39: 9.0, 38: 8.5, 37: 8.5, 36: 8.0, 35: 8.0,
      34: 7.5, 32: 7.5, 31: 7.0, 30: 7.0, 29: 6.5, 26: 6.5,
      25: 6.0, 23: 6.0, 22: 5.5, 18: 5.5, 17: 5.0, 16: 5.0,
      15: 4.5, 13: 4.5, 12: 4.0, 11: 4.0, 10: 3.5, 8: 3.5,
      7: 3.0, 6: 3.0, 5: 2.5, 4: 2.5, 3: 2.0, 1: 2.0, 0: 0.0,
    };
    cases.forEach((raw, band) {
      test('$raw/40 → $band', () {
        expect(Scoring.listeningBand(raw), band);
        expect(Scoring.listeningBand(raw, 40), band);
      });
    });

    test('never decreases as the raw score rises', () {
      var prev = -1.0;
      for (var raw = 0; raw <= 40; raw++) {
        final b = Scoring.listeningBand(raw);
        expect(b, greaterThanOrEqualTo(prev), reason: 'raw $raw');
        prev = b;
      }
    });

    test('partial tests are scaled to 40', () {
      expect(Scoring.listeningBand(10, 10), 9.0); // → 40
      expect(Scoring.listeningBand(5, 10), 5.5); // → 20
      expect(Scoring.listeningBand(7, 10), 6.5); // → 28
      expect(Scoring.listeningBand(8, 10), 7.5); // → 32
      expect(Scoring.listeningBand(0, 10), 0.0);
    });

    test('total 0 does not divide by zero', () {
      expect(Scoring.listeningBand(0, 0), 0.0);
    });
  });

  group('Scoring.readingBand Academic (raw /40)', () {
    const cases = <int, double>{
      40: 9.0, 39: 9.0, 38: 8.5, 37: 8.5, 36: 8.0, 35: 8.0,
      34: 7.5, 33: 7.5, 32: 7.0, 30: 7.0, 29: 6.5, 27: 6.5,
      26: 6.0, 23: 6.0, 22: 5.5, 19: 5.5, 18: 5.0, 15: 5.0,
      14: 4.5, 13: 4.5, 12: 4.0, 10: 4.0, 9: 3.5, 8: 3.5,
      7: 3.0, 6: 3.0, 5: 2.5, 4: 2.5, 3: 2.0, 1: 2.0, 0: 0.0,
    };
    cases.forEach((raw, band) {
      test('$raw/40 → $band', () {
        expect(Scoring.readingBand(raw), band);
        expect(Scoring.readingBand(raw, 40, false), band);
      });
    });

    test('partial tests are scaled to 40', () {
      expect(Scoring.readingBand(13, 13), 9.0);
      expect(Scoring.readingBand(10, 20), 5.5); // → 20
      expect(Scoring.readingBand(0, 13), 0.0);
    });
  });

  group('Scoring.readingBand General Training (raw /40)', () {
    const cases = <int, double>{
      40: 9.0, 39: 8.5, 38: 8.0, 37: 8.0, 36: 7.5, 35: 7.0,
      34: 7.0, 33: 6.5, 32: 6.5, 31: 6.0, 30: 6.0, 29: 5.5,
      27: 5.5, 26: 5.0, 23: 5.0, 22: 4.5, 19: 4.5, 18: 4.0,
      15: 4.0, 14: 3.5, 12: 3.5, 11: 3.0, 9: 3.0, 8: 2.5,
      6: 2.5, 5: 2.0, 1: 2.0, 0: 0.0,
    };
    cases.forEach((raw, band) {
      test('$raw/40 → $band', () {
        expect(Scoring.readingBand(raw, 40, true), band);
      });
    });

    test('GT needs more correct answers than Academic for the same band', () {
      for (var raw = 0; raw <= 40; raw++) {
        expect(
          Scoring.readingBand(raw, 40, true),
          lessThanOrEqualTo(Scoring.readingBand(raw)),
          reason: 'raw $raw',
        );
      }
    });
  });

  group('Scoring.overall (IELTS rounding)', () {
    test('empty list → 0', () {
      expect(Scoring.overall(<double>[]), 0);
    });
    test('exact average stays', () {
      expect(Scoring.overall(<double>[7, 7, 7, 7]), 7.0);
      expect(Scoring.overall(<double>[6.5, 6.5, 6.5, 6.5]), 6.5);
    });
    test('.125 rounds down to the whole band', () {
      expect(Scoring.overall(<double>[6, 6, 6, 6.5]), 6.0); // 6.125
    });
    test('.25 rounds up to the half band', () {
      expect(Scoring.overall(<double>[6, 6, 6, 7]), 6.5); // 6.25
      expect(Scoring.overall(<double>[6.5, 6.5, 5.0, 7.0]), 6.5); // 6.25
    });
    test('.375 and .625 round to the half band', () {
      expect(Scoring.overall(<double>[7, 6.5, 6, 6]), 6.5); // 6.375
      expect(Scoring.overall(<double>[6.5, 6.5, 6.5, 7]), 6.5); // 6.625
    });
    test('.75 rounds up to the next whole band', () {
      expect(Scoring.overall(<double>[6.5, 6.5, 7, 7]), 7.0); // 6.75
      expect(Scoring.overall(<double>[8.5, 9, 9, 8.5]), 9.0); // 8.75
    });
    test('.875 rounds up to the next whole band', () {
      expect(Scoring.overall(<double>[6.5, 7, 7, 7]), 7.0); // 6.875
    });
  });

  group('Store.roundBand / formatBand', () {
    test('nearest half band, half-way values round up', () {
      expect(Store.roundBand(6.24), 6.0);
      expect(Store.roundBand(6.25), 6.5);
      expect(Store.roundBand(6.74), 6.5);
      expect(Store.roundBand(6.75), 7.0);
      expect(Store.roundBand(7.0), 7.0);
    });
    test('clamped to 0..9', () {
      expect(Store.roundBand(-3), 0.0);
      expect(Store.roundBand(9.6), 9.0);
      expect(Store.roundBand(12), 9.0);
    });
    test('formatBand', () {
      expect(Store.formatBand(null), '–');
      expect(Store.formatBand(7), '7.0');
      expect(Store.formatBand(6.5), '6.5');
    });
  });

  group('Scoring.writing', () {
    const shortText = 'I think it is good.';
    const essay = 'In recent years, many people have argued that governments '
        'should invest more money in public transport rather than in new '
        'roads. This essay will discuss both views before giving my opinion.'
        '\n\n'
        'On the one hand, building roads can reduce congestion in the short '
        'term. Moreover, drivers pay considerable taxes, so it is reasonable '
        'that their needs are considered. For example, rural communities '
        'often depend entirely on private vehicles.'
        '\n\n'
        'On the other hand, investment in buses and trains benefits a far '
        'larger share of the population. Furthermore, public transport '
        'produces less pollution per passenger. As a result, cities such as '
        'Copenhagen have become cleaner and more pleasant places to live.'
        '\n\n'
        'In conclusion, although roads remain necessary, I believe that '
        'public transport deserves the greater share of funding, because its '
        'benefits are shared more widely and last much longer.';

    test('returns every criterion as a half band in 3..9', () {
      for (final text in <String>[shortText, essay]) {
        for (final task in <int>[1, 2]) {
          final r = Scoring.writing(text, task: task);
          for (final k in <String>['band', 'TA', 'CC', 'LR', 'GRA']) {
            final v = r[k] as double;
            expect(isHalfBand(v), isTrue, reason: '$k = $v');
            expect(v, inInclusiveRange(3.0, 9.0), reason: '$k = $v');
          }
          expect(r['feedback'], isA<List<String>>());
        }
      }
    });

    test('empty / very short text scores band 3.0', () {
      final r = Scoring.writing('', task: 2);
      expect(r['band'], 3.0);
      expect(r['words'], 0);
      expect((r['feedback'] as List).first, 'Write at least 250 words - you wrote 0.');
      expect(Scoring.writing(shortText, task: 1)['band'], 3.0);
      expect(Scoring.writing(shortText, task: 1)['words'], 5);
    });

    test('band = mean of TA/CC/LR/GRA rounded to the nearest half band', () {
      final r = Scoring.writing(essay, task: 2);
      final mean = ((r['TA'] as double) +
              (r['CC'] as double) +
              (r['LR'] as double) +
              (r['GRA'] as double)) /
          4;
      expect(r['band'], Store.roundBand(mean));
    });

    test('counts words and asks for the task minimum', () {
      final r1 = Scoring.writing(essay, task: 1);
      final r2 = Scoring.writing(essay, task: 2);
      expect(r1['words'], r2['words']);
      final n = r2['words'] as int;
      expect(n, greaterThan(20));
      expect(n, lessThan(250));
      expect((r2['feedback'] as List).any((f) => '$f'.contains('250 words')), isTrue);
    });

    test('is deterministic', () {
      expect(Scoring.writing(essay, task: 2), Scoring.writing(essay, task: 2));
    });

    test('a developed essay beats a one-liner', () {
      expect(
        Scoring.writing(essay, task: 2)['band'] as double,
        greaterThan(Scoring.writing(shortText, task: 2)['band'] as double),
      );
    });
  });

  group('Scoring.speaking', () {
    test('silence with seed 0', () {
      final r = Scoring.speaking(0, expectedSec: 120, seed: 0);
      expect(r['FC'], 4.0);
      expect(r['LR'], 4.5);
      expect(r['GRA'], 3.5);
      expect(r['P'], 4.5);
      expect(r['band'], 4.0); // 4.125 → 4.0
    });

    test('every criterion is a half band in 3..9 and band = rounded mean', () {
      for (final sec in <int>[0, 15, 45, 90, 120, 150, 600]) {
        for (final seed in <int>[0, 1, 2, 3, 7, 42]) {
          final r = Scoring.speaking(sec, expectedSec: 120, seed: seed);
          for (final k in <String>['band', 'FC', 'LR', 'GRA', 'P']) {
            final v = r[k] as double;
            expect(isHalfBand(v), isTrue, reason: '$k = $v ($sec s, seed $seed)');
            expect(v, inInclusiveRange(3.0, 9.0), reason: '$k = $v');
          }
          final mean = ((r['FC'] as double) +
                  (r['LR'] as double) +
                  (r['GRA'] as double) +
                  (r['P'] as double)) /
              4;
          expect(r['band'], Store.roundBand(mean));
        }
      }
    });

    test('speaking longer never lowers the band (same seed)', () {
      for (final seed in <int>[0, 1, 2, 3, 4]) {
        var prev = 0.0;
        for (final sec in <int>[0, 20, 40, 60, 80, 100, 120, 140]) {
          final b = Scoring.speaking(sec, expectedSec: 120, seed: seed)['band'] as double;
          expect(b, greaterThanOrEqualTo(prev), reason: '$sec s, seed $seed');
          prev = b;
        }
      }
    });

    test('length ratio is capped (1.2 × expected)', () {
      expect(
        Scoring.speaking(1000, expectedSec: 120, seed: 3),
        Scoring.speaking(5000, expectedSec: 120, seed: 3),
      );
    });

    test('expectedSec 0 does not divide by zero', () {
      final r = Scoring.speaking(10, expectedSec: 0);
      expect(r['band'], isA<double>());
    });
  });

  group('Scoring.norm', () {
    test('lower-cases, trims and collapses spaces', () {
      expect(Scoring.norm('  Museum  '), 'museum');
      expect(Scoring.norm('City   Hall'), 'city hall');
      expect(Scoring.norm('CITY  HALL '), 'city hall');
    });
    test('drops a leading article', () {
      expect(Scoring.norm('The Museum'), 'museum');
      expect(Scoring.norm('a bicycle'), 'bicycle');
      expect(Scoring.norm('An Apple'), 'apple');
    });
    test('keeps words that merely start with an article', () {
      expect(Scoring.norm('Theatre'), 'theatre');
      expect(Scoring.norm('another'), 'another');
      expect(Scoring.norm('Anchor'), 'anchor');
    });
    test('only the first article is removed, not inner ones', () {
      expect(Scoring.norm('the end of the road'), 'end of the road');
    });
    test('strips punctuation', () {
      expect(Scoring.norm('6.30'), '630');
      expect(Scoring.norm('6:30'), '630');
      expect(Scoring.norm("O'Neill!"), 'oneill');
      expect(Scoring.norm('£25'), '25');
    });
    test('empty stays empty', () {
      expect(Scoring.norm(''), '');
      expect(Scoring.norm('   '), '');
      expect(Scoring.norm('!!!'), '');
      expect(Scoring.norm('  The Museum '), 'museum');
      expect(Scoring.norm('well-known'), 'well known');
      expect(Scoring.norm('city\thall'), 'city hall');
    });
  });

  group('Scoring.matches', () {
    test('exact and case-insensitive', () {
      expect(Scoring.matches('Fairfax', 'Fairfax'), isTrue);
      expect(Scoring.matches('fairfax', 'Fairfax'), isTrue);
      expect(Scoring.matches('FAIRFAX ', 'Fairfax'), isTrue);
    });
    test('article on either side', () {
      expect(Scoring.matches('the museum', 'museum'), isTrue);
      expect(Scoring.matches('museum', 'the museum'), isTrue);
    });
    test('pipe-separated alternatives', () {
      expect(Scoring.matches('the museum', 'museum|art gallery'), isTrue);
      expect(Scoring.matches('Art Gallery', 'museum|art gallery'), isTrue);
      expect(Scoring.matches('library', 'museum|art gallery'), isFalse);
    });
    test('accepted list (content bank "accepted")', () {
      const accepted = <String>['6.30', '6:30', 'half past six'];
      expect(Scoring.matches('6.30', accepted), isTrue);
      expect(Scoring.matches('6:30', accepted), isTrue);
      expect(Scoring.matches('Half past six', accepted), isTrue);
      expect(Scoring.matches('7.30', accepted), isFalse);
    });
    test('non-string list items are compared as text', () {
      expect(Scoring.matches('12', <Object>[12]), isTrue);
      expect(Scoring.matches('B', <Object>['A', 'B']), isTrue);
    });
    test('blank answers never match', () {
      expect(Scoring.matches('', ''), isFalse);
      expect(Scoring.matches('   ', 'museum'), isFalse);
      expect(Scoring.matches('!!!', '!!!'), isFalse);
    });
    test('null accepted never matches', () {
      expect(Scoring.matches('museum', null), isFalse);
    });
    test('plural or misspelling does not match', () {
      expect(Scoring.matches('museums', 'museum'), isFalse);
      expect(Scoring.matches('musuem', 'museum'), isFalse);
    });
  });
}
