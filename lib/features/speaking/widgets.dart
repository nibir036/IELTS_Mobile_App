import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'bank.dart';

export 'bank.dart';

/// Speaking content (assets/demo/parts/speaking.json) — same for everyone.
Map<String, dynamic> speakingData() => Demo.section('speaking');

// ── per-user keys (Store kv) ────────────────────────────────────────────────

/// Bookmarked cue card ids (string set).
const String kSavedCardsKey = 'speaking.savedCards';

/// A recording waiting to upload: {title, cardTitle, spokenSec, sizeMb,
/// progress, recordedAt, attempt: {Attempt json without createdAt}}.
const String kPendingUploadKey = 'speaking.pendingUpload';

/// Number of Part 1 questions answered so far (int).
const String kPart1AnsweredKey = 'speaking.part1Answered';

/// Pronunciation tries: {wordId: [score 0..1, …]}.
const String kPronScoresKey = 'speaking.pronScores';

/// Part 2 preparation notes for a cue card (list of strings).
String cueNotesKey(String cardId) => 'speaking.notes.$cardId';

/// Short card title for list rows / attempt titles:
/// "Describe a quiet place you like to visit" → "A quiet place you like to visit".
String shortCueTitle(String title) {
  var s = title.trim();
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  if (s.startsWith('Describe ')) s = s.substring(9);
  if (s.isEmpty) return title;
  return s[0].toUpperCase() + s.substring(1);
}

/// All cue cards from the content bank (`Content.cueCards`), each with the
/// display fields the screens use: `number` (1-based position in the bank),
/// `category` (= topic), `prompts` (= bullets) and `shortTitle`.
List<Map<String, dynamic>> allCueCards() {
  final bank = Content.cueCards;
  return <Map<String, dynamic>>[
    for (var i = 0; i < bank.length; i++) _decorateCard(bank[i], i + 1),
  ];
}

Map<String, dynamic> _decorateCard(Map<String, dynamic> c, int number) => <String, dynamic>{
      ...c,
      'number': number,
      'category': c.s('topic'),
      'prompts': c.ls('bullets'),
      'shortTitle': shortCueTitle(c.s('title')),
    };

/// Finds a cue card by id (bank or demo; falls back to the first card of the
/// bank).
Map<String, dynamic> findCueCard(String? id) {
  final cards = allCueCards();
  if (id != null && id.isNotEmpty) {
    for (final c in cards) {
      if (c.s('id') == id) return c;
    }
    final other = Content.cueCard(id);
    if (other.isNotEmpty) return _decorateCard(other, 1);
  }
  return cards.isEmpty ? <String, dynamic>{} : cards.first;
}

/// Cue card id from route args: `{'cardId'}` (or the older `{'id'}`).
String? cueCardArg(BuildContext context) {
  final args = context.routeArgs;
  final a = args['cardId'];
  if (a is String && a.isNotEmpty) return a;
  final b = args['id'];
  if (b is String && b.isNotEmpty) return b;
  return null;
}

/// Topic chips of the vault for the demo cards, in order.
const List<String> kCueTopics = <String>[
  'People',
  'Places',
  'Objects',
  'Events',
  'Experiences',
  'Media',
];

/// Vault topic chips: the bank's categories, or [kCueTopics].
List<String> cueTopics() {
  if (!hasSpeakingBank) return kCueTopics;
  return <String>[
    for (final c in Content.speakingBankMeta.l('part2Categories')) c.s('label'),
  ];
}

/// Next Part 1 topic for rotation: the first topic the student has no Part 1
/// answer for, otherwise cycles by the number of Part 1 sessions.
Map<String, dynamic> nextPart1Topic() {
  final topics = Content.part1Topics;
  if (topics.isEmpty) return <String, dynamic>{};
  final done = <String>{
    for (final a in Store.I.attemptsFor(skill: Skill.speaking, kind: 'part1')) a.refId,
  };
  for (final tp in topics) {
    if (!done.contains(tp.s('id'))) return tp;
  }
  final n = Store.I.attemptsFor(skill: Skill.speaking, kind: 'part1').length;
  return topics[n % topics.length];
}

/// Card for a Part 3 discussion chosen by rotation: the first cue card the
/// student has no Part 3 answer for, otherwise cycles by count.
Map<String, dynamic> nextPart3Card() {
  final cards = allCueCards();
  if (cards.isEmpty) return <String, dynamic>{};
  final part3 = Store.I.attemptsFor(skill: Skill.speaking, kind: 'part3');
  final done = <String>{for (final a in part3) a.refId};
  for (final c in cards) {
    if (!done.contains(c.s('id'))) return c;
  }
  return cards[part3.length % cards.length];
}

/// Total Part 1 questions in the bank.
int part1QuestionCount() {
  var n = 0;
  for (final tp in Content.part1Topics) {
    n += tp.ls('questions').length;
  }
  return n;
}

/// Total Part 3 questions in the bank (discussion topics, or the demo cards'
/// questions without the bank).
int part3QuestionCount() {
  var n = 0;
  if (Content.part3Topics.isNotEmpty) {
    for (final tp in Content.part3Topics) {
      n += tp.l('questions').length;
    }
    return n;
  }
  for (final c in Content.cueCards) {
    n += c.ls('part3').length;
  }
  return n;
}

/// Criterion keys and names, in report order.
const List<(String, String)> kSpeakingCriteria = <(String, String)>[
  ('FC', 'Fluency & Coherence'),
  ('LR', 'Lexical Resource'),
  ('GRA', 'Grammatical Range & Accuracy'),
  ('P', 'Pronunciation'),
];

/// Summary line for a band (content templates).
String speakingSummary(double band) {
  final list = speakingData().m('feedback').l('summaries');
  for (final s in list) {
    if (band >= s.d('minBand')) return s.s('text');
  }
  return '';
}

/// Two "do this next" tips for the two weakest criteria.
List<String> speakingFeedback(Map<String, dynamic> criteria) {
  final tips = speakingData().m('feedback').m('tips');
  final keys = kSpeakingCriteria.map((c) => c.$1).toList()
    ..sort((a, b) => criteria.d(a).compareTo(criteria.d(b)));
  final out = <String>[];
  for (final k in keys.take(2)) {
    final l = tips.ls(k);
    if (l.isNotEmpty) out.add(l.first);
  }
  return out;
}

/// Builds (does not save) a demo-scored speaking [Attempt].
/// [durationSec] is the real elapsed time (minimum 60 s). [extra] is merged
/// into `data` last (audio list, real transcript, source …).
Attempt buildSpeakingAttempt({
  required String kind,
  required String title,
  required String refId,
  required int spokenSec,
  required int expectedSec,
  required int seed,
  required int durationSec,
  List<Map<String, dynamic>> questions = const <Map<String, dynamic>>[],
  bool test = false,
  Map<String, dynamic>? extra,
}) {
  final s = Scoring.speaking(spokenSec, expectedSec: expectedSec, seed: seed);
  final criteria = <String, dynamic>{
    'FC': s['FC'],
    'LR': s['LR'],
    'GRA': s['GRA'],
    'P': s['P'],
  };
  final band = s.d('band');
  return Attempt(
    id: Store.newId('att'),
    skill: Skill.speaking,
    kind: kind,
    title: title,
    refId: refId,
    band: band,
    durationSec: durationSec < 60 ? 60 : durationSec,
    createdAt: DateTime.now(),
    data: <String, dynamic>{
      'source': 'demo',
      'spokenSec': spokenSec,
      'expectedSec': expectedSec,
      'questions': questions,
      'criteria': criteria,
      'summary': speakingSummary(band),
      'feedback': speakingFeedback(criteria),
      'transcript': <String, dynamic>{
        'demo': true,
        'paragraphs': speakingData().m('transcript').l('paragraphs'),
      },
      if (test) 'test': true,
      ...?extra,
    },
  );
}

/// Scores a finished speaking answer (demo AI), saves it as an [Attempt] and
/// returns it. [durationSec] is the real elapsed time (minimum 60 s).
Attempt recordSpeakingAttempt({
  required String kind,
  required String title,
  required String refId,
  required int spokenSec,
  required int expectedSec,
  required int seed,
  required int durationSec,
  List<Map<String, dynamic>> questions = const <Map<String, dynamic>>[],
  bool test = false,
  Map<String, dynamic>? extra,
}) {
  final attempt = buildSpeakingAttempt(
    kind: kind,
    title: title,
    refId: refId,
    spokenSec: spokenSec,
    expectedSec: expectedSec,
    seed: seed,
    durationSec: durationSec,
    questions: questions,
    test: test,
    extra: extra,
  );
  return Store.I.addAttempt(attempt);
}

/// Seconds the student actually spoke in [a] (falls back to durationSec).
int spokenSecOf(Attempt a) {
  final v = a.data['spokenSec'];
  if (v is num && v > 0) return v.toInt();
  return a.durationSec;
}

/// The speaking answer (Part 1/2/3, not pronunciation) a result screen shows:
/// `routeArgs['attemptId']` or the newest one. Null for a new student.
Attempt? resolveSpeakingAnswer(BuildContext context) {
  final store = context.store;
  final byId = store.attemptById(context.routeArgs['attemptId'] as String?);
  if (byId != null && byId.skill == Skill.speaking && byId.kind != 'pronunciation') {
    return byId;
  }
  for (final a in store.attemptsFor(skill: Skill.speaking)) {
    if (a.kind != 'pronunciation') return a;
  }
  return null;
}

/// Transcript stats: (fillers, long pauses, words per minute).
(int, int, int) transcriptStats(Attempt a) {
  final stats = a.data['stats'];
  if (stats is Map) {
    final m = stats.cast<String, dynamic>();
    return (m.i('fillers'), m.i('pauses'), m.i('wpm'));
  }
  var fillers = 0;
  var pauses = 0;
  var words = 0;
  final tr = a.data['transcript'];
  final paragraphs = tr is Map ? tr.cast<String, dynamic>().l('paragraphs') : <Map<String, dynamic>>[];
  for (final p in paragraphs) {
    for (final tok in p.l('tokens')) {
      final type = tok.s('type');
      if (type == 'filler') fillers++;
      if (type == 'pause') {
        pauses++;
        continue;
      }
      words += RegExp(r"[A-Za-z']+").allMatches(tok.s('text')).length;
    }
  }
  final sec = spokenSecOf(a);
  final wpm = sec <= 0 ? 0 : (words * 60 / sec).round().clamp(60, 180).toInt();
  return (fillers, pauses, wpm);
}

/// Opens the practice again for an attempt (Part 2 → recording, Part 1/3 →
/// the Q&A flow, test → mock interview).
void reRecordAttempt(BuildContext context, Attempt? a, {bool replace = false}) {
  String route;
  Map<String, dynamic> args;
  if (a == null || a.kind == 'part2') {
    route = Routes.speakingRecording;
    args = <String, dynamic>{'cardId': a?.refId ?? ''};
  } else if (a.data['test'] == true) {
    route = Routes.speakingPart13;
    args = <String, dynamic>{'mock': true};
  } else if (a.kind == 'part1') {
    route = Routes.speakingPart13;
    args = <String, dynamic>{
      'part': 1,
      if (Content.part1Topic(a.refId).isNotEmpty) 'topicId': a.refId,
    };
  } else {
    route = Routes.speakingPart13;
    args = <String, dynamic>{
      'part': 3,
      if (Content.cueCard(a.refId).isNotEmpty) 'cardId': a.refId,
      if (Content.part3Topic(a.refId).isNotEmpty) 'part3TopicId': a.refId,
    };
  }
  if (replace) {
    context.replace(route, args: args);
  } else {
    context.push(route, args: args);
  }
}

/// Goes back to the Speaking hub if it is in the stack, otherwise opens it.
void openHub(BuildContext context) {
  final nav = Navigator.of(context);
  var found = false;
  nav.popUntil((r) {
    if (r.settings.name == Routes.speakingHub) {
      found = true;
      return true;
    }
    return r.isFirst;
  });
  if (!found) nav.pushNamed(Routes.speakingHub);
}

/// "m:ss".
String clockShort(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

/// "mm:ss".
String clockLong(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

/// Band as "6.5".
String bandText(double v) => v.toStringAsFixed(1);

/// Pops back to the Speaking hub if it is in the stack, otherwise to the
/// first route.
void backToHub(BuildContext context) {
  Navigator.of(context).popUntil(
    (r) => r.settings.name == Routes.speakingHub || r.isFirst,
  );
}

/// Fixed-height bar waveform with exact pixel heights from the artboard.
/// Bars in [highlightFrom]..[highlightTo] (inclusive) use [highlightColor].
/// When [progress] is set (0..1), bars after it are drawn faded.
class BarWave extends StatelessWidget {
  const BarWave({
    super.key,
    required this.heights,
    required this.color,
    this.height = 36,
    this.barWidth = 4,
    this.gap = 4,
    this.highlightFrom = -1,
    this.highlightTo = -1,
    this.highlightColor,
    this.progress,
  });

  final List<double> heights;
  final Color color;
  final double height;
  final double barWidth;
  final double gap;
  final int highlightFrom;
  final int highlightTo;
  final Color? highlightColor;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final n = heights.length;
    return SizedBox(
      height: height,
      child: ClipRect(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              Padding(
                padding: EdgeInsets.only(right: i == n - 1 ? 0 : gap),
                child: Container(
                  width: barWidth,
                  height: heights[i].clamp(2.0, height).toDouble(),
                  decoration: BoxDecoration(
                    color: _barColor(i, n),
                    borderRadius: BorderRadius.circular(barWidth / 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _barColor(int i, int n) {
    Color c = color;
    if (highlightColor != null && i >= highlightFrom && i <= highlightTo) {
      c = highlightColor!;
    }
    final p = progress;
    if (p != null && n > 0 && (i / n) >= p) {
      c = c.withValues(alpha: 0.35);
    }
    return c;
  }
}

/// Filled pill with a label (vault and recordings filter chips).
class FlatChip extends StatelessWidget {
  const FlatChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.bg,
    required this.fg,
    this.height = 40,
    this.fontSize = 14,
    this.borderColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;
  final double height;
  final double fontSize;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(fontSize: fontSize, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button with a caption underneath (recording controls).
class CaptionedButton extends StatelessWidget {
  const CaptionedButton({
    super.key,
    required this.child,
    required this.caption,
    required this.onTap,
    required this.size,
    required this.bg,
    this.captionColor,
    this.shadow,
    this.semanticLabel,
  });

  final Widget child;
  final String caption;
  final VoidCallback onTap;
  final double size;
  final Color bg;
  final Color? captionColor;
  final List<BoxShadow>? shadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Semantics(
          button: true,
          label: semanticLabel ?? caption,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadow),
            child: Material(
              color: bg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, child: Center(child: child)),
            ),
          ),
        ),
        Text(
          caption,
          style: TextStyle(fontSize: 12, color: captionColor ?? t.textMuted),
        ),
      ],
    );
  }
}

/// Live waveform: one slot per bar, 0 = not recorded yet, otherwise the
/// microphone level (0..1) captured while the playhead was on that bar.
/// Recorded bars use [playedColor] (default `t.fill`), the rest [color].
class LevelWave extends StatelessWidget {
  const LevelWave({
    super.key,
    required this.levels,
    this.height = 48,
    this.color,
    this.playedColor,
  });

  final List<double> levels;
  final double height;
  final Color? color;
  final Color? playedColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 3,
        children: [
          for (final v in levels)
            Expanded(
              child: Container(
                height: v <= 0 ? height * 0.12 : height * (0.14 + 0.86 * v.clamp(0.0, 1.0).toDouble()),
                decoration: BoxDecoration(
                  color: v <= 0 ? (color ?? t.border) : (playedColor ?? t.fill),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Puts [level] into the bar slot for [fraction] (0..1) of [levels].
void pushLevel(List<double> levels, double fraction, double level) {
  if (levels.isEmpty) return;
  final slot = (fraction * levels.length).floor().clamp(0, levels.length - 1).toInt();
  final v = level < 0.02 ? 0.02 : level;
  if (v > levels[slot]) levels[slot] = v;
}

/// "Microphone is off" dialog. Returns true when the student chooses to
/// practise without recording (simulated timer flow).
Future<bool> showMicOffDialog(BuildContext context) async {
  final r = await showAppDialog<bool>(
    context,
    Builder(
      builder: (ctx) {
        final t = ctx.tk;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: t.surfaceAlt, shape: BoxShape.circle),
                child: Icon(AppIcons.mic, size: 24, color: t.iconAccent),
              ),
            ),
            const Text(
              'Microphone is off',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Text(
              'IELTS AI can\'t use your microphone. Turn it on in Settings to '
              'record and get your answer transcribed and scored.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted),
            ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: 'Practise without recording',
              radius: 999,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            Center(
              child: LinkText(
                'Not now',
                color: t.textMuted,
                onTap: () => Navigator.of(ctx).pop(false),
              ),
            ),
          ],
        );
      },
    ),
  );
  return r == true;
}

/// Full-screen "Transcribing… / Scoring…" overlay shown while the AI works.
class SpeakingProcessingOverlay extends StatelessWidget {
  const SpeakingProcessingOverlay({super.key, required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.bg.withValues(alpha: 0.92),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: t.iconAccent,
                  backgroundColor: t.surfaceAlt,
                ),
              ),
              Text(
                stage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              Text(
                'Keep this screen open — it usually takes under a minute.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
