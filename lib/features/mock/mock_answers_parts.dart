import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'mock_session.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data for the mock answer review (G12 · MockAnswersScreen)
// ─────────────────────────────────────────────────────────────────────────────

/// A snapshot of one mock's answers: a recorded attempt, or the mock that is
/// being scored right now (G8, before the attempt exists).
class MockReview {
  MockReview({
    required this.title,
    required this.date,
    required this.mock,
    required this.data,
    required this.listening,
    required this.reading,
    required this.essays,
    required this.recordings,
    required this.spokenSec,
    required this.transcripts,
    this.attempt,
  });

  final String title;
  final DateTime date;

  /// The mock test composition (Content.mockTest).
  final Map<String, dynamic> mock;

  /// The attempt's data (empty while the mock is still being scored).
  final Map<String, dynamic> data;
  final Attempt? attempt;

  /// Question number → the student's answer. Null = not recorded.
  final Map<int, String>? listening;
  final Map<int, String>? reading;

  /// Task (1 | 2) → essay text ('' = not recorded).
  final Map<int, String> essays;

  /// Speaking part → recording path (only parts with a recording).
  final Map<int, String> recordings;

  /// Speaking part → seconds spoken.
  final Map<int, int> spokenSec;

  /// Speaking part → transcript.
  final Map<int, String> transcripts;

  static Map<int, String>? _answers(Map<String, dynamic> data, String key) {
    final all = data['answers'];
    if (all is! Map) return null;
    final v = all[key];
    if (v is! Map) return null;
    final out = <int, String>{};
    for (final e in v.entries) {
      final n = int.tryParse('${e.key}');
      final value = e.value;
      if (n != null && value != null) out[n] = '$value';
    }
    return out;
  }

  factory MockReview.fromAttempt(Attempt a) {
    final data = a.data;
    final w = data.m('writing');
    final sp = data.m('speaking');
    final recs = <int, String>{};
    for (final e in sp.m('recordings').entries) {
      final n = int.tryParse(e.key);
      final v = e.value;
      if (n != null && v is Map) {
        final path = v['path'];
        if (path is String && path.isNotEmpty) recs[n] = path;
      }
    }
    final tx = <int, String>{};
    for (final e in sp.m('transcripts').entries) {
      final n = int.tryParse(e.key);
      final v = e.value;
      if (n != null && v is String && v.trim().isNotEmpty) tx[n] = v.trim();
    }
    final secs = <int, int>{};
    for (final e in data.m('speakingSec').entries) {
      final n = int.tryParse(e.key);
      final v = e.value;
      if (n != null && v is num) secs[n] = v.toInt();
    }
    return MockReview(
      title: a.title,
      date: a.createdAt,
      mock: mockTest(mockIdOf(a)),
      data: data,
      attempt: a,
      listening: _answers(data, 'listening'),
      reading: _answers(data, 'reading'),
      essays: <int, String>{1: w.s('task1'), 2: w.s('task2')},
      recordings: recs,
      spokenSec: secs,
      transcripts: tx,
    );
  }

  /// The mock in progress (copied, so it survives the session being recorded).
  factory MockReview.fromSession() {
    final recs = <int, String>{};
    for (final e in MockSession.recordings.entries) {
      if (e.value.path.isNotEmpty) recs[e.key] = e.value.path;
    }
    return MockReview(
      title: MockSession.title,
      date: MockSession.startedAt,
      mock: MockSession.mock,
      data: <String, dynamic>{},
      listening: Map<int, String>.from(MockSession.listening),
      reading: Map<int, String>.from(MockSession.reading),
      essays: <int, String>{
        1: MockSession.writing[0] ?? '',
        2: MockSession.writing[1] ?? '',
      },
      recordings: recs,
      spokenSec: Map<int, int>.from(MockSession.speakingSec),
      transcripts: <int, String>{},
    );
  }

  /// Section band stored on the attempt (null while scoring / missing).
  double? band(String skill) {
    final a = attempt;
    if (a == null) return null;
    return mockSectionBand(a, skill);
  }
}

/// Result of one question.
enum MockMark { correct, partial, wrong, blank, unknown }

/// Listening or Reading of one mock: numbered groups, the bank units they
/// came from (sets / passages with offsets) and the student's answers.
class MockObjective {
  MockObjective({
    required this.listening,
    required this.groups,
    required this.units,
    required this.answers,
  });

  final bool listening;
  final List<MockGroup> groups;
  final List<(Map<String, dynamic>, int)> units;
  final Map<int, String>? answers;

  late final Map<int, Map<String, dynamic>> _raw = _buildRaw();

  Map<int, Map<String, dynamic>> _buildRaw() {
    final out = <int, Map<String, dynamic>>{};
    for (final u in units) {
      for (final g in u.$1.l('groups')) {
        for (final q in g.l('questions')) {
          out[q.i('number') + u.$2] = q;
        }
      }
    }
    return out;
  }

  bool get recorded => answers != null;

  /// The bank row of a question (explanation, evidence …).
  Map<String, dynamic> raw(int number) => _raw[number] ?? <String, dynamic>{};

  String given(MockQuestion q) => (answers?[q.number] ?? '').trim();

  int marksOf(MockQuestion q) => recorded ? mockMarks(q, given(q)) : 0;

  MockMark markOf(MockQuestion q) {
    if (!recorded) return MockMark.unknown;
    if (given(q).isEmpty) return MockMark.blank;
    final m = mockMarks(q, given(q));
    if (m >= q.span) return MockMark.correct;
    return m > 0 ? MockMark.partial : MockMark.wrong;
  }

  int get total => mockQuestionTotal(groups);

  int get correct {
    var c = 0;
    for (final g in groups) {
      for (final q in g.questions) {
        c += marksOf(q);
      }
    }
    return c;
  }

  /// Question numbers answered but not scored (a half-right pick-2 counts 1).
  int get wrong {
    var c = 0;
    for (final g in groups) {
      for (final q in g.questions) {
        final m = markOf(q);
        if (m == MockMark.wrong || m == MockMark.partial) c += q.span - marksOf(q);
      }
    }
    return c;
  }

  int get blank {
    var c = 0;
    for (final g in groups) {
      for (final q in g.questions) {
        if (markOf(q) == MockMark.blank) c += q.span;
      }
    }
    return c;
  }

  /// Transcript lines tagged with this question's answer, with the phrases
  /// to highlight.
  List<(Map<String, dynamic>, List<String>)> transcriptFor(MockQuestion q, int unitIndex) {
    final out = <(Map<String, dynamic>, List<String>)>[];
    if (unitIndex < 0 || unitIndex >= units.length) return out;
    final set = units[unitIndex].$1;
    final offset = units[unitIndex].$2;
    final numbers = q.numbers;
    for (final line in set.l('transcript')) {
      final phrases = <String>[];
      for (final tag in line.l('answerTags')) {
        if (numbers.contains(tag.i('question') + offset)) phrases.add(tag.s('after'));
      }
      if (phrases.isNotEmpty) out.add((line, phrases));
    }
    return out;
  }

  /// Text of a passage paragraph ("C").
  String paragraph(int unitIndex, String letter) {
    if (unitIndex < 0 || unitIndex >= units.length || letter.isEmpty) return '';
    for (final p in units[unitIndex].$1.l('paragraphs')) {
      if (p.s('letter') == letter) return p.s('text');
    }
    return '';
  }

  String unitTitle(int unitIndex) {
    if (unitIndex < 0 || unitIndex >= units.length) return '';
    return units[unitIndex].$1.s('title');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text helpers
// ─────────────────────────────────────────────────────────────────────────────

/// The question as read in the paper (form lines get their blank back).
String mockQuestionText(MockQuestion q) {
  if (q.kind == 'text' && (q.label.isNotEmpty || q.text.isEmpty)) {
    return <String>[
      if (q.label.isNotEmpty) '${q.label}:',
      if (q.before.isNotEmpty) q.before,
      '______',
      if (q.after.isNotEmpty) q.after,
    ].join(' ');
  }
  return q.text;
}

String _optionLabel(MockQuestion q, MockGroup g, String key) {
  final k = key.trim();
  for (final o in <MockOption>[...q.options, ...g.shared]) {
    if (o.key.toLowerCase() == k.toLowerCase()) {
      return o.text.isEmpty ? o.key : '${o.key} · ${o.text}';
    }
  }
  return k;
}

/// The student's answer, readable ('' when blank).
String mockGivenLabel(MockQuestion q, MockGroup g, String value) {
  final v = value.trim();
  if (v.isEmpty) return '';
  switch (q.kind) {
    case 'text':
      return v;
    case 'multi':
      return mockMultiKeys(v).map((k) => _optionLabel(q, g, k)).join('; ');
    default:
      return _optionLabel(q, g, v);
  }
}

/// The key, readable.
String mockCorrectLabel(MockQuestion q, MockGroup g) {
  if (q.answers.isEmpty) return '–';
  switch (q.kind) {
    case 'text':
      return q.answers.first;
    case 'multi':
      return q.answers.map((k) => _optionLabel(q, g, k)).join('; ');
    default:
      return _optionLabel(q, g, q.answers.first);
  }
}

/// Accepted alternatives of a typed answer (other than the key itself).
String mockAlsoAccepted(MockQuestion q) {
  if (q.kind != 'text' || q.answers.isEmpty) return '';
  final main = Scoring.norm(q.answers.first);
  final seen = <String>{main};
  final out = <String>[];
  for (final a in q.accepted) {
    final n = Scoring.norm(a);
    if (n.isEmpty || seen.contains(n)) continue;
    seen.add(n);
    out.add(a);
  }
  return out.join(', ');
}

/// "**bold**" markdown → spans.
List<TextSpan> mockBoldSpans(String text, TextStyle base) {
  final parts = text.split('**');
  return <TextSpan>[
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        TextSpan(
          text: parts[i],
          style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w600) : base,
        ),
  ];
}

/// [text] with every phrase of [phrases] (case-insensitive, first match)
/// in [hi].
List<TextSpan> mockHighlightSpans(
  String text,
  List<String> phrases,
  TextStyle base,
  TextStyle hi,
) {
  final lower = text.toLowerCase();
  final ranges = <(int, int)>[];
  for (final p in phrases) {
    final phrase = p.trim().toLowerCase();
    if (phrase.isEmpty) continue;
    final start = lower.indexOf(phrase);
    if (start < 0) continue;
    final end = start + phrase.length;
    final overlaps = ranges.any((r) => start < r.$2 && end > r.$1);
    if (!overlaps) ranges.add((start, end));
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final out = <TextSpan>[];
  var at = 0;
  for (final r in ranges) {
    if (r.$1 > at) out.add(TextSpan(text: text.substring(at, r.$1), style: base));
    out.add(TextSpan(text: text.substring(r.$1, r.$2), style: hi));
    at = r.$2;
  }
  if (at < text.length) out.add(TextSpan(text: text.substring(at), style: base));
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// One reviewed question: number, question, the student's answer, the key,
/// a result tag and optional details (explanation / transcript).
class MockAnswerRow extends StatelessWidget {
  const MockAnswerRow({
    super.key,
    required this.number,
    required this.question,
    required this.mark,
    required this.given,
    required this.correct,
    this.alsoAccepted = '',
    this.marksLabel = '',
    this.open = false,
    this.onToggle,
    this.detailsLabel = 'explanation',
    this.details = const <Widget>[],
  });

  final String number;
  final String question;
  final MockMark mark;

  /// The student's answer ('' = blank).
  final String given;
  final String correct;
  final String alsoAccepted;

  /// "1/2" for a half-right choose-TWO item.
  final String marksLabel;
  final bool open;
  final VoidCallback? onToggle;
  final String detailsLabel;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final body = t.isNight ? t.text : t.textSoft;
    Color badgeBg;
    Color badgeFg;
    Widget? tag;
    switch (mark) {
      case MockMark.correct:
        badgeBg = t.successSoft;
        badgeFg = t.success;
        tag = const Tag('Correct', tone: TagTone.success, icon: AppIcons.check, height: 24, fontSize: 11);
      case MockMark.partial:
        badgeBg = t.dangerSoft;
        badgeFg = t.dangerText;
        tag = Tag('$marksLabel correct', tone: TagTone.danger, height: 24, fontSize: 11);
      case MockMark.wrong:
        badgeBg = t.dangerSoft;
        badgeFg = t.dangerText;
        tag = const Tag('Wrong', tone: TagTone.danger, icon: AppIcons.close, height: 24, fontSize: 11);
      case MockMark.blank:
        badgeBg = t.surfaceAlt2;
        badgeFg = t.textMuted;
        tag = const Tag('Blank', tone: TagTone.outline, height: 24, fontSize: 11);
      case MockMark.unknown:
        badgeBg = t.surfaceAlt2;
        badgeFg = t.text;
        tag = null;
    }

    final label = TextStyle(fontSize: 12, color: t.textMuted);
    final wrongish = mark == MockMark.wrong || mark == MockMark.partial;
    final Widget yours;
    if (mark == MockMark.unknown) {
      yours = Text(
        'Your answer not recorded',
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: t.textMuted),
      );
    } else {
      yours = Text.rich(
        TextSpan(
          children: <TextSpan>[
            TextSpan(text: 'Your answer  ', style: label),
            TextSpan(
              text: given.isEmpty ? '(no answer)' : given,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: given.isEmpty ? FontWeight.w400 : FontWeight.w500,
                color: given.isEmpty
                    ? t.textMuted
                    : (wrongish ? t.dangerText : t.success),
                decoration: mark == MockMark.wrong ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: t.dangerText,
              ),
            ),
          ],
        ),
      );
    }
    final showKey = !(mark == MockMark.correct && given.toLowerCase() == correct.toLowerCase());

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 30),
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(9)),
            child: Text(
              number,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badgeFg),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text(
                        question.isEmpty ? 'Question $number' : question,
                        style: TextStyle(fontSize: 14, height: 1.4, color: body),
                      ),
                    ),
                    ?tag,
                  ],
                ),
                yours,
                if (showKey)
                  Text.rich(
                    TextSpan(
                      children: <TextSpan>[
                        TextSpan(text: 'Correct answer  ', style: label),
                        TextSpan(
                          text: correct,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: t.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (alsoAccepted.isNotEmpty)
                  Text('Also accepted: $alsoAccepted', style: label),
                if (details.isNotEmpty)
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        spacing: 4,
                        children: [
                          Text(
                            open ? 'Hide $detailsLabel' : 'Show $detailsLabel',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.text),
                          ),
                          Icon(
                            open ? AppIcons.chevronUp : AppIcons.chevronDown,
                            size: 16,
                            color: t.text,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (open) ...details,
                const SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft inner box used for transcripts, evidence and essays.
class MockReviewBox extends StatelessWidget {
  const MockReviewBox({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: t.surfaceAlt2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          if (title != null)
            Text(
              title!,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textMuted),
            ),
          child,
        ],
      ),
    );
  }
}

/// Criterion tile ("TA 6.0").
class MockCriterionTile extends StatelessWidget {
  const MockCriterionTile({
    super.key,
    required this.label,
    required this.value,
    this.onHero = false,
  });

  final String label;
  final String value;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: onHero ? t.heroChip : t.surfaceAlt2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        spacing: 2,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: onHero ? t.heroMuted : t.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: onHero ? t.heroText : t.text,
            ),
          ),
        ],
      ),
    );
  }
}
