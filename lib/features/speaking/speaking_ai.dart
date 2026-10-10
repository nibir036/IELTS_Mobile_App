import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/services/ai_service.dart';
import '../../app/services/entitlements.dart';
import '../../app/widgets/kit.dart';
import '../home/upgrade_sheet.dart';
import 'widgets.dart';

/// Recording bytes kept in memory for this app session (keyed by path) so a
/// pending upload can be retried from D9 without re-reading the file.
final Map<String, Uint8List> speakingAudioCache = <String, Uint8List>{};

/// One recorded answer.
class SpeakingClip {
  SpeakingClip({required this.path, required this.durationSec, this.bytes});

  final String path;
  final int durationSec;
  final Uint8List? bytes;

  Uint8List? get audio => bytes ?? speakingAudioCache[path];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'durationSec': durationSec,
      };

  static SpeakingClip fromJson(Map<String, dynamic> j) =>
      SpeakingClip(path: j.s('path'), durationSec: j.i('durationSec'));
}

/// Everything needed to score a finished speaking session (and to retry it
/// later from the upload queue).
class SpeakingJob {
  SpeakingJob({
    required this.kind,
    required this.title,
    required this.refId,
    required this.part,
    required this.questions,
    required this.clips,
    required this.spokenSec,
    required this.expectedSec,
    required this.seed,
    required this.durationSec,
    this.cueCard,
    this.cardTitle = '',
    this.test = false,
  });

  final String kind;
  final String title;
  final String refId;

  /// 1, 2 or 3 (mock interview → 3).
  final int part;

  /// [{q, spokenSec}] - one per question asked.
  final List<Map<String, dynamic>> questions;

  /// Recordings, in answer order (may be empty for simulated practice).
  final List<SpeakingClip> clips;
  final int spokenSec;
  final int expectedSec;
  final int seed;
  final int durationSec;
  final String? cueCard;
  final String cardTitle;
  final bool test;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'title': title,
        'refId': refId,
        'part': part,
        'questions': questions,
        'clips': [for (final c in clips) c.toJson()],
        'spokenSec': spokenSec,
        'expectedSec': expectedSec,
        'seed': seed,
        'durationSec': durationSec,
        'cueCard': cueCard,
        'cardTitle': cardTitle,
        'test': test,
      };

  static SpeakingJob fromJson(Map<String, dynamic> j) => SpeakingJob(
        kind: j.s('kind'),
        title: j.s('title'),
        refId: j.s('refId'),
        part: j.i('part'),
        questions: j.l('questions'),
        clips: [for (final c in j.l('clips')) SpeakingClip.fromJson(c)],
        spokenSec: j.i('spokenSec'),
        expectedSec: j.i('expectedSec'),
        seed: j.i('seed'),
        durationSec: j.i('durationSec'),
        cueCard: j['cueCard'] is String ? j['cueCard'] as String : null,
        cardTitle: j.s('cardTitle'),
        test: j.b('test'),
      );

  List<String> get questionTexts => [for (final q in questions) q.s('q')];
}

/// Result of [processSpeaking]: the saved attempt, or `pending` when the
/// upload failed and the session was queued in kv for D9.
class SpeakingOutcome {
  SpeakingOutcome({this.attempt, this.pending = false, this.audioMissing = false, this.failure});

  final Attempt? attempt;
  final bool pending;

  /// True when the recordings were no longer in memory (retry after restart).
  final bool audioMissing;

  /// Not scored (free allowance used, no audio, AI error). No attempt is
  /// saved - the app never shows a made-up score.
  final ScoringFailed? failure;
}

/// Free plan: a used-up speaking practice part / test (before recording).
String? speakingBlockedFor({required int part, String refId = ''}) =>
    Entitlements.I.blockSpeaking(part: part, refId: refId);

/// Free plan: the speaking allowance this job would use is gone.
String? speakingBlocked(SpeakingJob job) {
  final e = Entitlements.I;
  if (job.kind == 'diagnostic') return e.diagnosticUsedUp ? 'diagnostic' : null;
  if (job.kind == 'mock') return null; // the mock checks itself when it starts
  return e.blockSpeaking(part: job.part, refId: job.refId);
}

/// Scores the recordings with the speaking service (through the API
/// server). No fallback score: when it can't be scored the outcome carries
/// [SpeakingOutcome.failure] and nothing is saved.
///
/// [onStage] receives the label for the processing overlay and a 0..1
/// progress. With [queueOnUploadFail] the session is saved to
/// [kPendingUploadKey] when an upload fails while the backend is configured;
/// otherwise a failed upload returns `pending: true` without touching kv.
Future<SpeakingOutcome> processSpeaking(
  SpeakingJob job, {
  void Function(String stage, double progress)? onStage,
  bool queueOnUploadFail = true,
}) async {
  final audio = <Map<String, dynamic>>[
    for (final c in job.clips)
      <String, dynamic>{'path': c.path, 'key': null, 'durationSec': c.durationSec},
  ];
  final withBytes = <int>[
    for (var i = 0; i < job.clips.length; i++)
      if (job.clips[i].audio != null) i,
  ];
  final audioMissing = job.clips.isNotEmpty && withBytes.isEmpty;

  if (!AiService.available) return SpeakingOutcome(failure: AiService.failure());
  if (withBytes.isEmpty) {
    return SpeakingOutcome(
      audioMissing: audioMissing,
      failure: ScoringFailed(
        audioMissing
            ? 'The recording is no longer on this phone. Please record your answer again.'
            : 'Nothing was recorded. Please record your answer again.',
        code: 'no_audio',
      ),
    );
  }
  final blocked = speakingBlocked(job);
  if (blocked != null) {
    return SpeakingOutcome(
      failure: ScoringFailed('Your free allowance for this is used.', code: 'upgrade_required', feature: blocked),
    );
  }

  // The speaking service (same as the website): VAD → Groq Whisper →
  // RunPod pronunciation → Groq LLM examiner. The server keeps the
  // recordings and stores the graded attempt under our id.
  final id = Store.newId('att');
  final questions = job.questionTexts;
  String questionFor(int i) {
    if (job.part == 2 && (job.cueCard ?? '').trim().isNotEmpty) return job.cueCard!.trim();
    if (i < questions.length && questions[i].trim().isNotEmpty) return questions[i].trim();
    return job.cardTitle.isNotEmpty ? job.cardTitle : job.title;
  }

  final segments = <SpeakingSegment>[
    for (var n = 0; n < withBytes.length; n++)
      SpeakingSegment(
        id: 'q${withBytes[n] + 1}',
        partNumber: job.part == 1 || job.part == 2 ? job.part : 3,
        label: 'Part ${job.part} · Q${withBytes[n] + 1}',
        questionText: questionFor(withBytes[n]),
        bytes: job.clips[withBytes[n]].audio!,
      ),
  ];
  final eval = await AiService.speakingSession(
    mode: job.kind,
    title: job.title,
    refId: job.refId.isEmpty ? null : job.refId,
    durationSec: job.durationSec,
    attemptId: id,
    segments: segments,
    onProgress: onStage,
  );
  if (eval == null && AiService.lastErrorCode == 'network') {
    // Couldn't reach the server: keep the session for D9 (retry).
    if (queueOnUploadFail) queueSpeakingJob(job);
    return SpeakingOutcome(pending: true);
  }
  onStage?.call('Scoring…', 1);
  if (eval == null) {
    return SpeakingOutcome(failure: AiService.failure('We couldn’t score your answers right now. Please try again.'));
  }
  unawaited(Entitlements.I.refresh());

  // Recording keys (playback on other devices) and per-answer transcripts.
  final keys = <String, String>{
    for (final r in (eval['recordings'] as List?) ?? const <Object>[])
      if (r is Map) '${r['id']}': '${r['key']}',
  };
  for (final i in withBytes) {
    final key = keys['q${i + 1}'];
    if (key != null && key.isNotEmpty) audio[i]['key'] = key;
  }
  final bySegment = <String, String>{
    for (final s in (eval['segments'] as List?) ?? const <Object>[])
      if (s is Map) '${s['id']}': '${s['transcript'] ?? ''}'.trim(),
  };
  final texts = <String>[
    for (final i in withBytes)
      if ((bySegment['q${i + 1}'] ?? '').isNotEmpty) bySegment['q${i + 1}']!,
  ];
  final a = _save(
    job,
    audio,
    texts.isEmpty ? null : _TranscriptInput(texts, const <Map<String, dynamic>>[]),
    eval,
    id: id,
  );
  return SpeakingOutcome(attempt: a);
}

class _TranscriptInput {
  _TranscriptInput(this.texts, this.results);
  final List<String> texts;
  final List<Map<String, dynamic>> results;
}

Attempt _save(
  SpeakingJob job,
  List<Map<String, dynamic>> audio,
  _TranscriptInput? tr,
  Map<String, dynamic>? eval, {
  String? id,
}) {
  final extra = <String, dynamic>{'audio': audio};
  final errors = eval == null ? <Map<String, dynamic>>[] : _errorsOf(eval);
  if (tr != null) {
    final paragraphs = buildTranscriptParagraphs(tr.texts, errors);
    var aiFillers = 0;
    var aiPauses = 0;
    var aiWords = 0;
    for (final r in tr.results) {
      aiFillers += r.i('fillers');
      aiPauses += r.i('pauses');
      aiWords += r.i('words');
    }
    var fillers = 0;
    var pauses = 0;
    var words = 0;
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
    if (aiFillers > fillers) fillers = aiFillers;
    if (aiPauses > pauses) pauses = aiPauses;
    if (aiWords > words) words = aiWords;
    final sec = job.spokenSec <= 0 ? 1 : job.spokenSec;
    extra['transcript'] = <String, dynamic>{
      'text': tr.texts.join('\n\n'),
      'demo': false,
      'paragraphs': paragraphs,
    };
    extra['stats'] = <String, dynamic>{
      'fillers': fillers,
      'pauses': pauses,
      'wpm': (words * 60 / sec).round(),
    };
  }
  if (eval != null) {
    final crit = eval.m('criteria');
    final band = _band(eval['band']) ?? 0;
    extra['source'] = 'ai';
    extra['criteria'] = <String, dynamic>{
      for (final c in kSpeakingCriteria) c.$1: _band(crit[c.$1]) ?? band,
    };
    final summary = eval.s('summary');
    if (summary.isNotEmpty) extra['summary'] = summary;
    final feedback = _stringsOf(eval['feedback']);
    if (feedback.isNotEmpty) extra['feedback'] = feedback;
    extra['errors'] = errors;
    if (eval['criteriaFeedback'] is Map) extra['criteriaFeedback'] = eval['criteriaFeedback'];
    final perPart = _stringsOf(eval['perPartFeedback']);
    if (perPart.isNotEmpty) extra['perPartFeedback'] = perPart;
    // Full report details (D6): what went well, fluency patterns and the
    // sounds to work on, each quoted from the answer.
    if (eval['strengths'] is List) extra['aiStrengths'] = eval['strengths'];
    if (eval['fluency'] is Map) extra['fluencyReport'] = eval['fluency'];
    if (eval['pronunciation'] is Map) extra['pronunciationReport'] = eval['pronunciation'];
    // Only what the AI said: no sample summary, tips or transcript.
    extra.putIfAbsent('summary', () => '');
    extra.putIfAbsent('feedback', () => <String>[]);
    extra.putIfAbsent('transcript', () => <String, dynamic>{'text': '', 'demo': false, 'paragraphs': <Object>[]});
  }
  final a = buildSpeakingAttempt(
    kind: job.kind,
    title: job.title,
    refId: job.refId,
    spokenSec: job.spokenSec,
    expectedSec: job.expectedSec,
    seed: job.seed,
    durationSec: job.durationSec,
    questions: job.questions,
    test: job.test,
    extra: extra,
  );
  final Attempt out;
  if (id != null || (eval != null && _band(eval['band']) != null)) {
    out = Attempt(
      id: id ?? a.id,
      skill: a.skill,
      kind: a.kind,
      title: a.title,
      refId: a.refId,
      band: (eval == null ? null : _band(eval['band'])) ?? a.band,
      durationSec: a.durationSec,
      createdAt: a.createdAt,
      data: a.data,
    );
  } else {
    out = a;
  }
  return Store.I.addAttempt(out);
}

double? _band(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<String> _stringsOf(Object? v) {
  if (v is! List) return <String>[];
  final out = <String>[];
  for (final e in v) {
    if (e is String && e.trim().isNotEmpty) {
      out.add(e.trim());
    } else if (e is Map) {
      final m = e.cast<String, dynamic>();
      final text = m.s('text').isNotEmpty
          ? m.s('text')
          : (m.s('tip').isNotEmpty ? m.s('tip') : m.s('note'));
      if (text.isNotEmpty) out.add(text);
    }
  }
  return out;
}

List<Map<String, dynamic>> _errorsOf(Map<String, dynamic> eval) {
  final raw = eval['errors'];
  if (raw is! List) return <Map<String, dynamic>>[];
  return <Map<String, dynamic>>[
    for (final e in raw)
      if (e is Map)
        <String, dynamic>{
          'original': '${e['original'] ?? ''}',
          // The examiner sometimes "corrects" a phrase to itself.
          'suggestion': '${e['suggestion'] ?? ''}'.trim().toLowerCase() ==
                  '${e['original'] ?? ''}'.trim().toLowerCase()
              ? ''
              : '${e['suggestion'] ?? ''}',
          'type': '${e['type'] ?? ''}',
          'note': '${e['note'] ?? ''}',
        },
  ];
}

/// [processSpeaking], and when it can't be scored: the reason in a sheet
/// with "Try again" (same recordings) or "See Pro plans". Null when the
/// student gives up (nothing saved, no made-up score).
Future<SpeakingOutcome?> processSpeakingOrExplain(
  BuildContext context,
  SpeakingJob job, {
  void Function(String stage, double progress)? onStage,
  bool queueOnUploadFail = true,
}) async {
  while (true) {
    final out = await processSpeaking(job, onStage: onStage, queueOnUploadFail: queueOnUploadFail);
    final failure = out.failure;
    if (failure == null) return out;
    if (!context.mounted) return null;
    final again = await showAppSheet<bool>(
      context,
      Builder(
        builder: (ctx) => ScoringFailedPanel(
          failure: failure,
          onRetry: failure.code == 'no_audio' ? null : () => Navigator.of(ctx).pop(true),
          backLabel: 'Close',
          onBack: () => Navigator.of(ctx).pop(false),
        ),
      ),
    );
    if (again != true || !context.mounted) return null;
  }
}

/// Saves [job] as the pending upload (retried from D9 when back online).
void queueSpeakingJob(SpeakingJob job) {
  var bytes = 0;
  for (final c in job.clips) {
    bytes += c.audio?.length ?? 0;
  }
  Store.I.setKv(kPendingUploadKey, <String, dynamic>{
    'title': job.title,
    'cardTitle': job.cardTitle.isNotEmpty ? job.cardTitle : job.title,
    'spokenSec': job.spokenSec,
    'sizeMb': double.parse((bytes / 1000000).toStringAsFixed(1)),
    'progress': 0.0,
    'recordedAt': clockTime(DateTime.now()),
    'job': job.toJson(),
  });
}

/// "8:12 PM".
String clockTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

// ── transcript tokens (D5) ──────────────────────────────────────────────────

const Set<String> _fillerWords = <String>{
  'um', 'umm', 'ummm', 'uh', 'uhh', 'uhm', 'er', 'err', 'erm', 'ah', 'ahh', 'hmm', 'mm',
};

/// Turns real answer texts into D5 paragraphs: `{faded, tokens: [{type,
/// text, note}]}` with fillers, "..." pauses and the AI's `errors[].original`
/// spans (type `error`) highlighted.
List<Map<String, dynamic>> buildTranscriptParagraphs(
  List<String> texts,
  List<Map<String, dynamic>> errors,
) {
  final used = <int>{};
  final out = <Map<String, dynamic>>[];
  for (final text in texts) {
    if (text.trim().isEmpty) continue;
    // Error spans (first unused match per error, no overlaps).
    final spans = <(int, int, Map<String, dynamic>)>[];
    final lower = text.toLowerCase();
    for (var e = 0; e < errors.length; e++) {
      if (used.contains(e)) continue;
      final orig = errors[e].s('original').trim();
      if (orig.isEmpty) continue;
      var from = 0;
      while (true) {
        final at = lower.indexOf(orig.toLowerCase(), from);
        if (at < 0) break;
        final end = at + orig.length;
        final overlaps = spans.any((s) => at < s.$2 && end > s.$1);
        if (!overlaps) {
          spans.add((at, end, errors[e]));
          used.add(e);
          break;
        }
        from = at + 1;
      }
    }
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    final tokens = <Map<String, dynamic>>[];
    var pos = 0;
    for (final s in spans) {
      if (s.$1 > pos) tokens.addAll(_plainTokens(text, pos, s.$1));
      final e = s.$3;
      final suggestion = e.s('suggestion');
      final note = e.s('note');
      final parts = <String>[
        if (suggestion.isNotEmpty) 'Try: “$suggestion”',
        if (note.isNotEmpty) note,
      ];
      tokens.add(<String, dynamic>{
        'type': 'error',
        'text': text.substring(s.$1, s.$2),
        'note': parts.join('-'),
      });
      pos = s.$2;
    }
    if (pos < text.length) tokens.addAll(_plainTokens(text, pos, text.length));
    out.add(<String, dynamic>{'faded': false, 'tokens': tokens});
  }
  return out;
}

/// Splits `text[start, end)` into text / filler / pause tokens.
List<Map<String, dynamic>> _plainTokens(String text, int start, int end) {
  final seg = text.substring(start, end);
  final out = <Map<String, dynamic>>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isEmpty) return;
    out.add(<String, dynamic>{'type': 'text', 'text': buf.toString()});
    buf.clear();
  }

  final re = RegExp(r"(\.\.\.+|…)|([A-Za-z']+)");
  var pos = 0;
  for (final m in re.allMatches(seg)) {
    if (m.start > pos) buf.write(seg.substring(pos, m.start));
    final word = m.group(2);
    if (m.group(1) != null) {
      flush();
      out.add(<String, dynamic>{
        'type': 'pause',
        'text': '‖',
        'note': 'Pause - link your ideas instead of stopping.',
      });
    } else if (word != null && _isFiller(seg, m.start, m.end, word.toLowerCase())) {
      flush();
      out.add(<String, dynamic>{
        'type': 'filler',
        'text': word,
        'note': 'Filler - try a short silent pause instead.',
      });
    } else {
      buf.write(m.group(0));
    }
    pos = m.end;
  }
  if (pos < seg.length) buf.write(seg.substring(pos));
  flush();
  return out;
}

bool _isFiller(String seg, int start, int end, String lower) {
  if (_fillerWords.contains(lower)) return true;
  if (lower != 'like') return false;
  // "like" as a filler: set off by a comma ("…, like, …" / "Like, I …").
  var i = end;
  while (i < seg.length && seg[i] == ' ') {
    i++;
  }
  if (i < seg.length && seg[i] == ',') return true;
  var j = start - 1;
  while (j >= 0 && seg[j] == ' ') {
    j--;
  }
  return j >= 0 && seg[j] == ',';
}
