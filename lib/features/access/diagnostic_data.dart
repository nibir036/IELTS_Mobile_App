import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/routes.dart';
import '../../app/services/ai_service.dart';
import '../mock/mock_content.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Short onboarding diagnostic (≈45 min): content picks, grading, scoring and
// loading a finished diagnostic back for the result screen.
//
// Copy / config: `assets/demo/parts/access.json → diagnostic`.
// Content: the bank (`Content.*`). Results: one Attempt per assessed skill,
// kind 'diagnostic', all sharing `data.diagnosticId`.
// ─────────────────────────────────────────────────────────────────────────────

/// Graded listening / reading answers.
class DiagnosticGrade {
  DiagnosticGrade({
    required this.correct,
    required this.total,
    required this.answers,
    required this.review,
  });

  /// Question numbers answered correctly.
  final List<int> correct;
  final int total;

  /// Given answers keyed by question number ('1': 'Fairfax'); a choose-TWO
  /// item is stored one letter per number, like the listening practice.
  final Map<String, dynamic> answers;

  /// Answer key rows {n, given, answer, ok} for "Review answers".
  final List<Map<String, dynamic>> review;

  int get score => correct.length;
  bool get anyAnswered => answers.isNotEmpty;
}

/// One finished diagnostic loaded from the student's attempts.
class DiagnosticSummary {
  DiagnosticSummary({required this.id, required this.attempts, required this.date});

  final String id;

  /// Skill → attempt (only the assessed skills).
  final Map<String, Attempt> attempts;
  final DateTime date;

  double? band(String skill) => attempts[skill]?.band;

  /// Bands of the assessed skills, in L-R-W-S order.
  List<double> get assessedBands => <double>[
        for (final s in Skill.core)
          if (attempts[s]?.band != null) attempts[s]!.band!,
      ];

  double? get overall {
    final b = assessedBands;
    return b.isEmpty ? null : Scoring.overall(b);
  }
}

class Diagnostic {
  Diagnostic._();

  static const String kind = 'diagnostic';

  static Map<String, dynamic> get data => Demo.section('access').m('diagnostic');
  static Map<String, dynamic> get config => data.m('test');
  static Map<String, dynamic> get resultCopy => data.m('result');

  /// Copy for one step: {title, part, intro}.
  static Map<String, dynamic> step(String skill) => config.m('steps').m(skill);

  static const Map<String, int> _defaultMinutes = <String, int>{
    Skill.listening: 10,
    Skill.reading: 15,
    Skill.writing: 15,
    Skill.speaking: 5,
  };

  /// Time limit of a section in minutes (from `diagnosticTest.sections`).
  static int minutesFor(String skill) {
    for (final s in data.m('diagnosticTest').l('sections')) {
      if (s.s('id') == skill && s.i('minutes') > 0) return s.i('minutes');
    }
    return _defaultMinutes[skill] ?? 10;
  }

  /// Whole diagnostic length in minutes (45).
  static int get totalMinutes {
    final m = data.m('diagnosticTest').i('totalMinutes');
    if (m > 0) return m;
    var sum = 0;
    for (final s in Skill.core) {
      sum += minutesFor(s);
    }
    return sum;
  }

  static int get writingMinWords {
    final v = config.i('writingMinWords');
    return v > 0 ? v : 120;
  }

  static int get speakingMaxSeconds {
    final v = config.i('speakingMaxSeconds');
    return v > 0 ? v : 45;
  }

  static int get speakingQuestionCount {
    final v = config.i('speakingQuestions');
    return v > 0 ? v : 2;
  }

  static int get speakingExpectedSeconds {
    final v = config.i('speakingExpectedSeconds');
    return v > 0 ? v : 30;
  }

  // ── content picks ─────────────────────────────────────────────────────────

  static Set<String> _refs(String skill) => <String>{
        for (final a in Store.I.attemptsFor(skill: skill)) a.refId,
      };

  /// First recorded Part 1 set (question bank) the student hasn't attempted,
  /// else the configured fallback (lb_p1_fn).
  static Map<String, dynamic> pickListeningSet() {
    final done = _refs(Skill.listening);
    for (final s in Content.listeningSets) {
      if (s.i('part') == 1 && s.s('audio').isNotEmpty && !done.contains(s.s('id'))) return s;
    }
    final fbId = config.s('listeningFallbackSet');
    final fb = Content.listeningSet(fbId.isEmpty ? 'lb_p1_fn' : fbId);
    if (fb.isNotEmpty) return fb;
    final all = Content.listeningSets;
    return all.isEmpty ? <String, dynamic>{} : all.first;
  }

  /// An easy passage the student hasn't attempted (configured ids first).
  static Map<String, dynamic> pickReadingPassage() {
    final candidates = <Map<String, dynamic>>[];
    for (final id in config.ls('readingPassages')) {
      final p = Content.readingPassage(id);
      if (p.isNotEmpty) candidates.add(p);
    }
    for (final p in Content.readingPassages) {
      if (p.s('difficulty') == 'easy' && !candidates.any((c) => c.s('id') == p.s('id'))) {
        candidates.add(p);
      }
    }
    if (candidates.isEmpty) {
      final all = Content.readingPassages;
      return all.isEmpty ? <String, dynamic>{} : all.first;
    }
    final done = _refs(Skill.reading);
    for (final p in candidates) {
      if (!done.contains(p.s('id'))) return p;
    }
    return candidates.first;
  }

  static Map<String, dynamic> _pickById(
    List<String> ids,
    List<Map<String, dynamic>> bank,
    String skill,
  ) {
    final candidates = <Map<String, dynamic>>[];
    for (final id in ids) {
      for (final m in bank) {
        if (m.s('id') == id) candidates.add(m);
      }
    }
    if (candidates.isEmpty) candidates.addAll(bank);
    if (candidates.isEmpty) return <String, dynamic>{};
    final done = _refs(skill);
    for (final c in candidates) {
      if (!done.contains(c.s('id'))) return c;
    }
    return candidates.first;
  }

  /// A short Task 2 prompt the student hasn't written on.
  static Map<String, dynamic> pickWritingPrompt() =>
      _pickById(config.ls('writingPrompts'), Content.writingDemoTask2, Skill.writing);

  /// A Part 1 topic the student hasn't answered.
  static Map<String, dynamic> pickSpeakingTopic() =>
      _pickById(config.ls('speakingTopics'), Content.speakingDemoPart1, Skill.speaking);

  /// The first [speakingQuestionCount] questions of [topic].
  static List<String> speakingQuestions(Map<String, dynamic> topic) {
    final qs = topic.ls('questions');
    final n = speakingQuestionCount;
    return qs.length > n ? qs.sublist(0, n) : qs;
  }

  // ── grading ───────────────────────────────────────────────────────────────

  static String _keyText(MockQuestion q) {
    if (q.kind == 'text') {
      if (q.answers.isNotEmpty) return q.answers.first;
      return q.accepted.isNotEmpty ? q.accepted.first : '';
    }
    return q.answers.join(', ');
  }

  /// Marks [answers] (number → value; a choose-TWO item holds "A,C" under
  /// its first number) against [groups].
  static DiagnosticGrade grade(List<MockGroup> groups, Map<int, String> answers) {
    final correct = <int>[];
    final stored = <String, dynamic>{};
    final review = <Map<String, dynamic>>[];
    var total = 0;
    for (final g in groups) {
      for (final q in g.questions) {
        final given = (answers[q.number] ?? '').trim();
        if (q.kind == 'multi') {
          final sel = mockMultiKeys(given).map((e) => e.toUpperCase()).toList();
          final key = q.answers.map((e) => e.toUpperCase()).toSet();
          final used = <String>{};
          for (var i = 0; i < q.span; i++) {
            final n = q.number + i;
            final v = i < sel.length ? sel[i] : '';
            final ok = v.isNotEmpty && key.contains(v) && used.add(v);
            if (v.isNotEmpty) stored['$n'] = v;
            if (ok) correct.add(n);
            review.add(<String, dynamic>{'n': n, 'given': v, 'answer': _keyText(q), 'ok': ok});
          }
          total += q.span;
        } else {
          final ok = mockMarks(q, given) > 0;
          if (given.isNotEmpty) stored['${q.number}'] = given;
          if (ok) correct.add(q.number);
          review.add(<String, dynamic>{
            'n': q.number,
            'given': given,
            'answer': _keyText(q),
            'ok': ok,
          });
          total += 1;
        }
      }
    }
    correct.sort();
    return DiagnosticGrade(correct: correct, total: total, answers: stored, review: review);
  }

  /// The diagnostic uses about a quarter of a real paper (10 listening and
  /// ~13 reading questions instead of 40 each). The official conversion
  /// tables are defined on a raw score out of 40, so the raw score is scaled
  /// to /40 first (raw40 = round(correct × 40 / total)) and then converted.
  /// A short sample is noisier than a full paper, which is why the result
  /// screen calls it an estimate.
  static int scaledTo40(int correct, int total) =>
      total <= 0 ? 0 : (correct * 40 / total).round();

  static double listeningBand(DiagnosticGrade g) =>
      Scoring.listeningBand(scaledTo40(g.score, g.total));

  static double readingBand(DiagnosticGrade g) =>
      Scoring.readingBand(scaledTo40(g.score, g.total));

  // ── writing ───────────────────────────────────────────────────────────────

  static const String _aiNote =
      '(Diagnostic task: the candidate was asked to write ONE well-developed '
      'paragraph of about 120–150 words giving their view, in 15 minutes. '
      'Judge the language and reasoning shown; do not penalise the length or '
      'the missing introduction and conclusion.)';

  static int wordCount(String text) => RegExp(r"[A-Za-z0-9']+").allMatches(text).length;

  static List<String> _strings(Object? v) {
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

  /// Scores the paragraph with the AI examiner (same endpoint as the Writing
  /// section), falling back to the offline `Scoring.writing` heuristic.
  /// → {band, criteria{TA,CC,LR,GRA}, words, feedback, summary, source}
  static Future<Map<String, dynamic>> scoreWriting(
    Map<String, dynamic> prompt,
    String text,
  ) async {
    Map<String, dynamic>? r;
    final id = Store.newId('att');
    try {
      r = await AiService.evaluateWriting(
        task: 2,
        prompt: '${prompt.s('prompt')}\n\n$_aiNote',
        text: text,
        attemptId: id,
        promptId: prompt.s('id'),
        title: title(Skill.writing),
        context: 'diagnostic',
      ).timeout(const Duration(seconds: 95));
    } catch (_) {
      r = null;
    }
    final words = wordCount(text);
    if (r != null && r['band'] is num) {
      final overall = Store.roundBand(r.d('band'));
      final crit = r.m('criteria');
      double cb(String k) {
        final v = crit[k];
        return v is num ? Store.roundBand(v.toDouble()) : overall;
      }

      return <String, dynamic>{
        'band': overall,
        'criteria': <String, dynamic>{'TA': cb('TA'), 'CC': cb('CC'), 'LR': cb('LR'), 'GRA': cb('GRA')},
        'words': r['words'] is num ? r.i('words') : words,
        'feedback': _strings(r['feedback']),
        'summary': r.s('summary'),
        'source': 'ai',
        // The server's graded copy uses this id; saveWriting keeps it.
        'attemptId': id,
      };
    }
    // Offline: the heuristic is tuned for full essays (Task 2 expects 250
    // words in 4 paragraphs). One paragraph is judged against the Task 1
    // length threshold (150 words), which is much closer to the 120+ words
    // asked for here; feedback about essay length / paragraphing is replaced.
    final s = Scoring.writing(text, task: 1);
    final min = writingMinWords;
    final feedback = <String>[
      if (words < min) 'Aim for at least $min words — you wrote $words.',
      for (final f in _strings(s['feedback']))
        if (!f.startsWith('Write at least') && !f.startsWith('Organise your answer')) f,
    ];
    return <String, dynamic>{
      'band': s.d('band'),
      'criteria': <String, dynamic>{'TA': s['TA'], 'CC': s['CC'], 'LR': s['LR'], 'GRA': s['GRA']},
      'words': words,
      'feedback': feedback,
      'summary': '',
      'source': 'demo',
    };
  }

  // ── saving & loading ─────────────────────────────────────────────────────

  static String title(String skill) => 'Diagnostic · ${Skill.label(skill)}';

  /// Saves the Listening attempt (same data shape as listening practice, so
  /// F8 can open it) and returns it.
  static Attempt saveListening(
    String id,
    Map<String, dynamic> set,
    DiagnosticGrade g,
    int durationSec,
  ) =>
      Store.I.addAttempt(
        Attempt(
          id: Store.newId('att'),
          skill: Skill.listening,
          kind: kind,
          title: title(Skill.listening),
          refId: set.s('id'),
          band: listeningBand(g),
          score: g.score,
          total: g.total,
          durationSec: durationSec,
          createdAt: DateTime.now(),
          data: <String, dynamic>{
            'diagnosticId': id,
            'setId': set.s('id'),
            'answers': g.answers,
            'correct': g.correct,
            'total': g.total,
            'raw40': scaledTo40(g.score, g.total),
            'parts': <Map<String, dynamic>>[
              <String, dynamic>{
                'setId': set.s('id'),
                'part': set.i('part'),
                'from': 1,
                'to': g.total,
                'correct': g.score,
                'total': g.total,
              },
            ],
            'review': g.review,
          },
        ),
        notify: false,
      );

  /// Saves the Reading attempt (same data shape as reading practice, so E4
  /// can open it) and returns it.
  static Attempt saveReading(
    String id,
    Map<String, dynamic> passage,
    DiagnosticGrade g,
    int durationSec,
  ) =>
      Store.I.addAttempt(
        Attempt(
          id: Store.newId('att'),
          skill: Skill.reading,
          kind: kind,
          title: title(Skill.reading),
          refId: passage.s('id'),
          band: readingBand(g),
          score: g.score,
          total: g.total,
          durationSec: durationSec,
          createdAt: DateTime.now(),
          data: <String, dynamic>{
            'diagnosticId': id,
            'passageId': passage.s('id'),
            'answers': g.answers,
            'correct': g.correct,
            'total': g.total,
            'raw40': scaledTo40(g.score, g.total),
            'passages': <String>[passage.s('id')],
            'flagged': <int>[],
            'review': g.review,
          },
        ),
        notify: false,
      );

  /// Saves the Writing attempt from a [scoreWriting] result (same data shape
  /// as the Writing section, so C5 can open it) and returns it.
  static Attempt saveWriting(
    String id,
    Map<String, dynamic> prompt,
    String text,
    Map<String, dynamic> r,
    int durationSec,
  ) =>
      Store.I.addAttempt(
        Attempt(
          id: r.s('attemptId').isNotEmpty ? r.s('attemptId') : Store.newId('att'),
          skill: Skill.writing,
          kind: kind,
          title: title(Skill.writing),
          refId: prompt.s('id'),
          band: r.d('band'),
          durationSec: durationSec,
          createdAt: DateTime.now(),
          data: <String, dynamic>{
            'diagnosticId': id,
            'text': text,
            'prompt': prompt.s('prompt'),
            'promptId': prompt.s('id'),
            'task': 2,
            'criteria': r['criteria'],
            'words': r['words'],
            'feedback': r['feedback'],
            'summary': r['summary'],
            'source': r['source'],
          },
        ),
        notify: false,
      );

  /// Records the diagnostic on the profile (bands + done flag).
  static void saveProfile(String id, Map<String, double?> bands) {
    final assessed = bands.values.whereType<double>().toList();
    Store.I.updateProfile(<String, dynamic>{
      'diagnostic': 'diagnostic',
      'diagnosticDone': true,
      'diagnosticId': id,
      'diagnosticBands': <String, dynamic>{
        for (final s in Skill.core) s: bands[s],
        'overall': assessed.isEmpty ? null : Scoring.overall(assessed),
        'date': DateTime.now().toIso8601String(),
      },
    });
  }

  /// The diagnostic in `args['diagnosticId']`, else the newest one.
  static DiagnosticSummary? load(Map<String, dynamic> args) {
    final store = Store.I;
    var id = args['diagnosticId'] is String ? args['diagnosticId'] as String : '';
    if (id.isEmpty) {
      for (final a in store.attempts) {
        if (a.kind == kind && a.data.s('diagnosticId').isNotEmpty) {
          id = a.data.s('diagnosticId');
          break;
        }
      }
    }
    if (id.isEmpty) return null;
    final bySkill = <String, Attempt>{};
    DateTime? date;
    for (final a in store.attempts) {
      if (a.kind != kind || a.data.s('diagnosticId') != id) continue;
      bySkill.putIfAbsent(a.skill, () => a);
      if (date == null || a.createdAt.isAfter(date)) date = a.createdAt;
    }
    if (bySkill.isEmpty || date == null) return null;
    return DiagnosticSummary(id: id, attempts: bySkill, date: date);
  }

  /// Practice route of a skill (config key → route).
  static String routeFor(String key) => switch (key) {
        'listeningLanding' => Routes.listeningLanding,
        'readingLanding' => Routes.readingLanding,
        'writingSelector' => Routes.writingSelector,
        'speakingHub' => Routes.speakingHub,
        'mockSystemCheck' => Routes.mockSystemCheck,
        'schedule' => Routes.schedule,
        Skill.listening => Routes.listeningLanding,
        Skill.reading => Routes.readingLanding,
        Skill.writing => Routes.writingSelector,
        Skill.speaking => Routes.speakingHub,
        _ => Routes.home,
      };
}
