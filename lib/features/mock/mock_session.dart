import 'dart:math' as math;

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/services/ai_service.dart';
import '../../app/services/voice_recorder.dart';
import 'mock_content.dart';

export 'mock_content.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers (content lives in mock_content.dart, re-exported here)
// ─────────────────────────────────────────────────────────────────────────────

/// The student's finished mocks, newest first.
List<Attempt> mockAttempts() => Store.I.attemptsFor(skill: Skill.mock, kind: 'mock');

/// The mock test id an attempt was taken on (`data.mockId`, else refId).
String mockIdOf(Attempt a) {
  final id = a.data['mockId'];
  if (id is String && id.isNotEmpty) return id;
  return a.refId;
}

/// Mocks taken on one test, newest first.
List<Attempt> mockAttemptsOn(String mockId) =>
    mockAttempts().where((a) => mockIdOf(a) == mockId).toList();

/// First test the student hasn't taken yet (or the first test).
String mockDefaultId() {
  final tests = mockTests();
  for (final t in tests) {
    if (mockAttemptsOn(t.s('id')).isEmpty) return t.s('id');
  }
  return tests.isEmpty ? '' : tests.first.s('id');
}

/// "07" from "Mock Test 07".
String mockNumberLabel(Attempt a) {
  final m = RegExp(r'(\d+)\s*$').firstMatch(a.title);
  return m == null ? '–' : m.group(1)!;
}

/// "Mock Test 08"- the title the student's next mock will get.
String mockNextTitle() => mockTitleFor(mockAttempts().length + 1);

String mockTitleFor(int n) => 'Mock Test ${n.toString().padLeft(2, '0')}';

/// Section band stored on a mock attempt (null if missing).
double? mockSectionBand(Attempt a, String skill) {
  final s = a.data['sections'];
  if (s is Map && s[skill] is num) return (s[skill] as num).toDouble();
  return null;
}

/// Mocks taken before [a] (older), newest first.
List<Attempt> mockOlderThan(Attempt a) =>
    mockAttempts().where((x) => x.createdAt.isBefore(a.createdAt)).toList();

/// "9:00 AM" from "09:00".
String mockTimeLabel(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1].padLeft(2, '0');
  final suffix = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $suffix';
}

/// "+0.5", "-0.5", "±0.0".
String mockSigned(double v) {
  if (v.abs() < 0.001) return '±0.0';
  return v > 0 ? '+${v.toStringAsFixed(1)}' : '-${v.abs().toStringAsFixed(1)}';
}

/// The next scheduled (not done, today or later) mock task, if any.
Map<String, dynamic>? mockNextScheduledTask(Store store) {
  final today = Store.dateKey(DateTime.now());
  final list = store.tasks
      .where((t) =>
          t['skill'] == Skill.mock &&
          t['done'] != true &&
          '${t['date']}'.compareTo(today) >= 0)
      .toList()
    ..sort((a, b) => '${a['date']} ${a['time']}'.compareTo('${b['date']} ${b['time']}'));
  return list.isEmpty ? null : list.first;
}

// ─────────────────────────────────────────────────────────────────────────────
// In-flight session (G2 → G8)
// ─────────────────────────────────────────────────────────────────────────────

/// Answers of the mock that is currently being taken. Static so it survives
/// the route replacements between sections. Reset when a mock starts (G2),
/// discarded on exit (G11), turned into an [Attempt] by [finish] (G8).
class MockSession {
  MockSession._();

  static bool active = false;

  /// The mock test being taken (mt_a …), see `Content.mockTests`.
  static String mockId = '';
  static String title = '';
  static DateTime startedAt = DateTime.now();

  /// The composition of the mock being taken.
  static Map<String, dynamic> get mock => mockTest(mockId);

  /// Listening question number (1–40) → answer: a letter, typed text, or
  /// "A,C" for a choose-TWO item (stored under its first number).
  static final Map<int, String> listening = <int, String>{};

  /// Reading question number (1–40) → answer (letter / key / typed text).
  static final Map<int, String> reading = <int, String>{};

  /// Writing task index (0 = Task 1, 1 = Task 2) → text.
  static final Map<int, String> writing = <int, String>{};

  /// Speaking part number → seconds spoken (real recording length when the
  /// microphone was used, simulated seconds otherwise).
  static final Map<int, int> speakingSec = <int, int>{};

  /// Speaking part number → microphone recording (path + WAV bytes).
  static final Map<int, Recording> recordings = <int, Recording>{};

  static void _clear() {
    listening.clear();
    reading.clear();
    writing.clear();
    speakingSec.clear();
    recordings.clear();
  }

  /// Starts a fresh mock on [id] (or the default test).
  static void start([String? id]) {
    _clear();
    final want = id ?? '';
    mockId = want.isNotEmpty && Content.mockTest(want).isNotEmpty ? want : mockDefaultId();
    title = mockNextTitle();
    startedAt = DateTime.now();
    active = true;
  }

  /// Starts a session if none is running (sections opened directly).
  static void ensure() {
    if (!active) start();
  }

  /// Exit mid-mock: nothing is recorded.
  static void discard() {
    _clear();
    active = false;
  }


  // ── Scoring (G8) ─────────────────────────────────────────────────────────

  static const List<String> _writingKeys = <String>['TA', 'CC', 'LR', 'GRA'];
  static const List<String> _speakingKeys = <String>['FC', 'LR', 'GRA', 'P'];

  /// The number the mock being scored will get ("Mock Test 08" → 8).
  static int get nextNumber => mockAttempts().length + 1;

  /// AI lists may hold strings or small objects - keep readable strings.
  static List<String> _texts(dynamic v) {
    final out = <String>[];
    if (v is! List) return out;
    for (final e in v) {
      if (e is String) {
        if (e.trim().isNotEmpty) out.add(e.trim());
      } else if (e is Map) {
        final m = e.cast<String, dynamic>();
        String text = '';
        for (final k in const <String>['text', 'note', 'tip', 'message', 'suggestion', 'title']) {
          if (m.s(k).trim().isNotEmpty) {
            text = m.s(k).trim();
            break;
          }
        }
        if (text.isNotEmpty) out.add(text);
      }
    }
    return out;
  }

  static double _critBand(Map<String, dynamic> crit, String key, double fallback) {
    final v = crit[key];
    if (v is num) return Store.roundBand(v.toDouble());
    return fallback;
  }

  /// Listening + Reading, rule-based (answers vs the bank key). Available
  /// at once. → {listeningBand, listeningCorrect, listeningTotal,
  ///    listeningByPart, readingBand, readingCorrect, readingTotal}
  static Map<String, dynamic> scoreObjective() {
    final m = mock;
    final byPart = <String, List<int>>{};
    var lCorrect = 0;
    var lTotal = 0;
    for (final g in mockListeningGroups(m)) {
      final row = byPart.putIfAbsent(g.heading, () => <int>[0, 0]);
      for (final q in g.questions) {
        final c = mockMarks(q, listening[q.number]);
        lCorrect += c;
        lTotal += q.span;
        row[0] += c;
        row[1] += q.span;
      }
    }
    final lBand = lTotal == 0 ? 0.0 : Scoring.listeningBand(lCorrect, lTotal);

    var rCorrect = 0;
    var rTotal = 0;
    for (final g in mockReadingGroups(m)) {
      for (final q in g.questions) {
        rCorrect += mockMarks(q, reading[q.number]);
        rTotal += q.span;
      }
    }
    final rBand = rTotal == 0 ? 0.0 : Scoring.readingBand(rCorrect, rTotal);

    return <String, dynamic>{
      'listeningBand': lBand,
      'listeningCorrect': lCorrect,
      'listeningTotal': lTotal,
      'listeningByPart': <Map<String, dynamic>>[
        for (final e in byPart.entries)
          <String, dynamic>{'label': e.key, 'correct': e.value[0], 'total': e.value[1]},
      ],
      'readingBand': rBand,
      'readingCorrect': rCorrect,
      'readingTotal': rTotal,
    };
  }

  /// All speaking questions of the mock (Part 1 → cue card → Part 3).
  static List<String> speakingQuestions() {
    final m = mock;
    final cue = mockCueCard(m);
    return <String>[
      ...mockPart1Topic(m).ls('questions'),
      if (cue.s('prompt').isNotEmpty) cue.s('prompt'),
      ...cue.ls('part3'),
    ];
  }

  /// Expected speaking seconds across Parts 1–3 (config).
  static int get _expectedSpeakingSec {
    final e = mockContent.m('speaking').i('expectedSeconds');
    return e > 0 ? e : 660;
  }

  /// The AI evaluation of both writing tasks, shared by the two
  /// [scoreWriting] calls (one request, one AI-graded attempt).
  static Future<Map<String, dynamic>?>? _aiWriting;

  static Future<Map<String, dynamic>?> _evaluateWritingTest() {
    final t1 = (writing[0] ?? '').trim();
    final t2 = (writing[1] ?? '').trim();
    final p1 = mockTask1(mock).s('prompt');
    final p2 = mockTask2(mock).s('prompt');
    if (t1.isEmpty && t2.isEmpty) return Future<Map<String, dynamic>?>.value(null);
    // Only one task written: grade that one on its own.
    if (t1.isEmpty || t2.isEmpty) {
      final task = t1.isEmpty ? 2 : 1;
      return AiService.evaluateWriting(
        task: task,
        prompt: task == 1 ? p1 : p2,
        text: task == 1 ? t1 : t2,
        title: '$title · Writing',
        context: 'mock',
      ).then((r) => r == null ? null : <String, dynamic>{'task$task': r});
    }
    return AiService.evaluateWritingTest(
      task1Prompt: p1,
      task1Text: t1,
      task2Prompt: p2,
      task2Text: t2,
      title: '$title · Writing',
      testId: mockId,
      context: 'mock',
    );
  }

  /// Writing task [task] (1 | 2): AI evaluation, falling back to the demo
  /// scorer. → {band, TA, CC, LR, GRA, words, summary, strengths, feedback,
  ///    issues, source}
  static Future<Map<String, dynamic>> scoreWriting(int task) async {
    final text = writing[task - 1] ?? '';
    final demo = Scoring.writing(text, task: task);
    final fallback = <String, dynamic>{...demo, 'summary': '', 'source': 'demo'};
    if (text.trim().isEmpty) return fallback;
    Map<String, dynamic>? both;
    try {
      both = await (_aiWriting ??= _evaluateWritingTest());
    } catch (_) {
      both = null;
    }
    final r = both?['task$task'] is Map ? (both!['task$task'] as Map).cast<String, dynamic>() : null;
    if (r == null || r['band'] is! num) return fallback;
    final band = Store.roundBand(r.d('band'));
    final crit = r.m('criteria');
    return <String, dynamic>{
      'band': band,
      for (final k in _writingKeys) k: _critBand(crit, k, band),
      'words': r['words'] is num ? r.i('words') : demo.i('words'),
      'summary': r.s('summary'),
      'strengths': _texts(r['strengths']),
      'feedback': _texts(r['feedback']),
      'issues': r.l('issues'),
      'source': 'ai',
    };
  }

  /// Speaking question text per part, for the evaluator.
  static String _partQuestion(int part) {
    final cue = mockCueCard(mock);
    if (part == 1) return mockPart1Topic(mock).ls('questions').join('\n');
    if (part == 2) {
      final bullets = cue.ls('bullets');
      return <String>[
        cue.s('prompt'),
        if (bullets.isNotEmpty) 'You should say: ${bullets.join('; ')}',
      ].where((s) => s.trim().isNotEmpty).join('\n');
    }
    return cue.ls('part3').join('\n');
  }

  /// Speaking: the speaking service scores one recording per part (Groq
  /// Whisper transcripts, pronunciation, one band across Parts 1–3); falls
  /// back to the demo scorer (spoken seconds).
  /// → {band, FC, LR, GRA, P, summary, feedback, errors,
  ///    transcripts{part: text}, keys{part: r2Key}, source}
  static Future<Map<String, dynamic>> scoreSpeaking() async {
    final spoken = speakingSec.values.fold<int>(0, (s, v) => s + v);
    final demo = Scoring.speaking(
      spoken,
      expectedSec: _expectedSpeakingSec,
      seed: nextNumber,
    );

    final entries = recordings.entries
        .where((e) => e.value.bytes != null && e.value.bytes!.isNotEmpty)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final keys = <String, dynamic>{};
    final transcripts = <String, dynamic>{};
    Map<String, dynamic>? r;
    if (entries.isNotEmpty && AiService.available) {
      try {
        r = await AiService.speakingSession(
          mode: 'mock',
          title: '$title · Speaking',
          refId: mockId,
          durationSec: spoken,
          segments: <SpeakingSegment>[
            for (final e in entries)
              SpeakingSegment(
                id: 'part${e.key}',
                partNumber: e.key < 1 ? 1 : (e.key > 3 ? 3 : e.key),
                label: 'Part ${e.key}',
                questionText: _partQuestion(e.key).isEmpty ? 'Part ${e.key}' : _partQuestion(e.key),
                bytes: e.value.bytes!,
                format: e.value.format,
              ),
          ],
        );
      } catch (_) {
        r = null;
      }
      if (r != null) {
        for (final rec in (r['recordings'] as List?) ?? const <Object>[]) {
          if (rec is Map) keys['${rec['id']}'.replaceFirst('part', '')] = '${rec['key']}';
        }
        for (final s in (r['segments'] as List?) ?? const <Object>[]) {
          if (s is! Map) continue;
          final text = '${s['transcript'] ?? ''}'.trim();
          if (text.isNotEmpty) transcripts['${s['id']}'.replaceFirst('part', '')] = text;
        }
      }
    }

    if (r == null || r['band'] is! num) {
      return <String, dynamic>{
        ...demo,
        'summary': '',
        'transcripts': transcripts,
        'keys': keys,
        'source': 'demo',
      };
    }
    final band = Store.roundBand(r.d('band'));
    final crit = r.m('criteria');
    return <String, dynamic>{
      'band': band,
      for (final k in _speakingKeys) k: _critBand(crit, k, band),
      'summary': r.s('summary'),
      'feedback': _texts(r['feedback']),
      'errors': r.l('errors'),
      'transcripts': transcripts,
      'keys': keys,
      'source': 'ai',
    };
  }

  /// Records the mock [Attempt] from the section results and ends the
  /// session. [w1]/[w2] come from [scoreWriting], [sp] from [scoreSpeaking].
  static Attempt record({
    required Map<String, dynamic> objective,
    required Map<String, dynamic> w1,
    required Map<String, dynamic> w2,
    required Map<String, dynamic> sp,
  }) {
    final store = Store.I;
    final lBand = objective.d('listeningBand');
    final rBand = objective.d('readingBand');

    // Writing - Task 2 weighs double.
    final wBand = Store.roundBand((w1.d('band') + 2 * w2.d('band')) / 3);
    final wCrit = <String, dynamic>{
      for (final k in _writingKeys) k: Store.roundBand((w1.d(k) + 2 * w2.d(k)) / 3),
    };
    final wSource = w1.s('source') == 'ai' && w2.s('source') == 'ai' ? 'ai' : 'demo';
    final wSummary = <String>[
      if (w1.s('summary').trim().isNotEmpty) 'Task 1 · ${w1.s('summary').trim()}',
      if (w2.s('summary').trim().isNotEmpty) 'Task 2 · ${w2.s('summary').trim()}',
    ].join('\n');

    final sBand = sp.d('band');
    final spoken = speakingSec.values.fold<int>(0, (s, v) => s + v);
    final number = nextNumber;

    final overall = Scoring.overall(<double>[lBand, rBand, wBand, sBand]);
    final average = (lBand + rBand + wBand + sBand) / 4;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;

    // A scheduled mock for today (or overdue) counts as done.
    final today = Store.dateKey(DateTime.now());
    for (final t in store.tasks) {
      if (t['skill'] == Skill.mock &&
          t['done'] != true &&
          '${t['date']}'.compareTo(today) <= 0) {
        t['done'] = true;
      }
    }

    final a = Attempt(
      id: Store.newId('att'),
      skill: Skill.mock,
      kind: 'mock',
      title: mockTitleFor(number),
      refId: mockId,
      band: overall,
      durationSec: math.max(60, elapsed),
      createdAt: DateTime.now(),
      data: <String, dynamic>{
        'mockId': mockId,
        'mockTitle': mockTestName(mock),
        'sections': <String, dynamic>{
          'listening': lBand,
          'reading': rBand,
          'writing': wBand,
          'speaking': sBand,
        },
        'source': <String, dynamic>{
          'writing': wSource,
          'speaking': sp.s('source') == 'ai' ? 'ai' : 'demo',
        },
        'overall': overall,
        'average': average,
        'listeningScore': <String, dynamic>{
          'correct': objective.i('listeningCorrect'),
          'total': objective.i('listeningTotal'),
        },
        'readingScore': <String, dynamic>{
          'correct': objective.i('readingCorrect'),
          'total': objective.i('readingTotal'),
        },
        'listeningByPart': objective.l('listeningByPart'),
        'answers': <String, dynamic>{
          'listening': <String, dynamic>{
            for (final e in listening.entries) '${e.key}': e.value,
          },
          'reading': <String, dynamic>{
            for (final e in reading.entries) '${e.key}': e.value,
          },
        },
        'writing': <String, dynamic>{
          'task1': writing[0] ?? '',
          'task2': writing[1] ?? '',
          'task1Band': w1.d('band'),
          'task2Band': w2.d('band'),
          'task1Words': w1.i('words'),
          'task2Words': w2.i('words'),
          'task1Source': w1.s('source'),
          'task2Source': w2.s('source'),
          'task1Criteria': <String, dynamic>{for (final k in _writingKeys) k: w1.d(k)},
          'task2Criteria': <String, dynamic>{for (final k in _writingKeys) k: w2.d(k)},
          'task1Summary': w1.s('summary'),
          'task2Summary': w2.s('summary'),
          'strengths': <String>[...w1.ls('strengths'), ...w2.ls('strengths')],
          'feedback': <String>[...w1.ls('feedback'), ...w2.ls('feedback')],
          'task1Issues': w1.l('issues'),
          'task2Issues': w2.l('issues'),
        },
        'writingCriteria': wCrit,
        'writingSummary': wSummary,
        'speakingCriteria': <String, dynamic>{
          for (final k in _speakingKeys) k: sp.d(k),
        },
        'speakingSummary': sp.s('summary').trim(),
        'speaking': <String, dynamic>{
          'feedback': sp.ls('feedback'),
          'errors': sp.l('errors'),
          'transcripts': sp.m('transcripts'),
          'recordingKeys': sp.m('keys'),
          'recordings': <String, dynamic>{
            for (final e in recordings.entries)
              '${e.key}': <String, dynamic>{
                'path': e.value.path,
                'durationSec': e.value.durationSec,
                'format': e.value.format,
              },
          },
        },
        'speakingSec': <String, dynamic>{
          for (final e in speakingSec.entries) '${e.key}': e.value,
        },
        'spokenSec': spoken,
      },
    );
    _clear();
    active = false;
    return store.addAttempt(a, notify: false);
  }

  /// Records the session with the offline demo scorer only (used if the
  /// async scoring fails unexpectedly).
  static Attempt finishOffline() {
    Map<String, dynamic> w(int task) => <String, dynamic>{
          ...Scoring.writing(writing[task - 1] ?? '', task: task),
          'summary': '',
          'source': 'demo',
        };
    final spoken = speakingSec.values.fold<int>(0, (s, v) => s + v);
    final sp = <String, dynamic>{
      ...Scoring.speaking(spoken, expectedSec: _expectedSpeakingSec, seed: nextNumber),
      'summary': '',
      'source': 'demo',
    };
    return record(objective: scoreObjective(), w1: w(1), w2: w(2), sp: sp);
  }

  static Future<Attempt>? _pending;

  /// Scores the whole session (writing tasks in parallel, then speaking) and
  /// records the attempt. [onStep] is called with the index of each G8 step
  /// (0 Writing Task 1 · 1 Writing Task 2 · 2 Speaking) as it finishes.
  /// Calling it again while scoring is running returns the same future.
  static Future<Attempt> finishAsync({void Function(int step, Map<String, dynamic> result)? onStep}) {
    final running = _pending;
    if (running != null) return running;
    final f = _finish(onStep);
    _pending = f;
    f.then<void>(
      (_) {
        _pending = null;
      },
      onError: (Object e, StackTrace st) {
        _pending = null;
      },
    );
    return f;
  }

  static Future<Attempt> _finish(void Function(int step, Map<String, dynamic> result)? onStep) async {
    _aiWriting = null;
    final objective = scoreObjective();
    final writingF = Future.wait<Map<String, dynamic>>(<Future<Map<String, dynamic>>>[
      scoreWriting(1).then((r) {
        onStep?.call(0, r);
        return r;
      }),
      scoreWriting(2).then((r) {
        onStep?.call(1, r);
        return r;
      }),
    ]);
    final speakingF = scoreSpeaking().then((r) {
      onStep?.call(2, r);
      return r;
    });
    final w = await writingF;
    final sp = await speakingF;
    return record(objective: objective, w1: w[0], w2: w[1], sp: sp);
  }
}
