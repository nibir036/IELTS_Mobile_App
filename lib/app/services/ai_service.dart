import 'dart:convert';
import 'dart:typed_data';

import 'api_client.dart';
import 'config.dart';

/// One recorded answer sent to the speaking evaluator.
class SpeakingSegment {
  SpeakingSegment({
    required this.id,
    required this.partNumber,
    required this.questionText,
    required this.bytes,
    this.label = '',
    this.format = 'wav',
  });

  final String id;
  final int partNumber;
  final String questionText;
  final String label;
  final Uint8List bytes;
  final String format;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'partNumber': partNumber,
        'label': label.isEmpty ? id : label,
        'questionText': questionText,
        'audioBase64': base64Encode(bytes),
        'format': format,
      };
}

/// Real AI through the API server (writing: Gemini; speaking: the speaking
/// service - Groq Whisper + RunPod + Groq LLM) with a graceful fallback.
///
/// Every method returns `null` when no backend is configured or the call
/// fails - the caller then uses its built-in demo scorer. [lastError] holds
/// the last failure message (for a small "offline scoring" hint in the UI).
///
/// All successful results carry `'source': 'ai'`.
/// AI scoring didn't happen: [code] 'upgrade_required' (free allowance used,
/// [feature] says which), 'network', 'too_short', 'needs_rerecording' …
class ScoringFailed implements Exception {
  ScoringFailed(this.message, {this.code = '', this.feature = ''});

  final String message;
  final String code;
  final String feature;

  bool get upgrade => code == 'upgrade_required';

  @override
  String toString() => message;
}

class AiService {
  AiService._();

  static String? lastError;

  /// Error code of the last failure ('upgrade_required', 'needs_rerecording',
  /// 'network', …).
  static String lastErrorCode = '';

  /// Called with the error code after a failed request (notifications use
  /// 'upgrade_required').
  static void Function(String code)? onFailure;

  /// AI scoring needs the API server and a signed-in account.
  static bool get available => AppConfig.hasApi && ApiClient.signedIn;

  /// With 'upgrade_required': which free allowance is used up.
  static String lastErrorFeature = '';

  static void _fail(Object e) {
    lastError = '$e';
    lastErrorCode = e is ApiException ? e.code : '';
    lastErrorFeature = e is ApiException ? e.feature : '';
    onFailure?.call(lastErrorCode);
  }

  /// The last failure was a used-up free allowance.
  static bool get upgradeNeeded => lastErrorCode == 'upgrade_required';

  /// The last failure as an exception for the screens (no made-up score is
  /// ever shown instead).
  static ScoringFailed failure([String fallback = 'We couldn’t score this right now. Please try again.']) {
    final msg = (lastError ?? '').trim();
    if (!available) {
      return ScoringFailed('You need to be online and signed in to get AI feedback.', code: 'network');
    }
    return ScoringFailed(
      msg.isEmpty ? fallback : msg,
      code: lastErrorCode,
      feature: lastErrorFeature,
    );
  }

  static Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (!available) return null;
    try {
      final r = await ApiClient.postJson(path, body, timeout: timeout);
      lastError = null;
      lastErrorCode = '';
      return r;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  /// Writing evaluation (Gemini, strict IELTS examiner).
  /// → {source, band, criteria{TA,CC,LR,GRA}, criteriaFeedback{…}, words,
  ///    summary, strengths[], feedback[], enhancedSnippet,
  ///    issues[{original, suggestion, type, note}], attempt}
  ///
  /// [attemptId] is the id the app will store the result under, so the
  /// server's graded attempt and the local one are the same record.
  /// [context]: 'practice' | 'mock' | 'diagnostic'.
  static Future<Map<String, dynamic>?> evaluateWriting({
    required int task,
    required String prompt,
    required String text,
    String? attemptId,
    String? promptId,
    String? title,
    int? durationSec,
    String context = 'practice',
  }) =>
      _post('/v1/writing/evaluate', <String, dynamic>{
        'task': task,
        'prompt': prompt,
        'text': text,
        'attemptId': ?attemptId,
        'promptId': ?promptId,
        'title': ?title,
        'durationSec': ?durationSec,
        'context': context,
      });

  /// Both writing tasks in one evaluation (one AI-graded attempt; Task 2
  /// weighs double). → {source, band, task1: {…}, task2: {…}, attempt}
  /// with each task shaped like [evaluateWriting].
  static Future<Map<String, dynamic>?> evaluateWritingTest({
    required String task1Prompt,
    required String task1Text,
    required String task2Prompt,
    required String task2Text,
    String? title,
    String? testId,
    int? durationSec,
    String context = 'mock',
  }) =>
      _post(
        '/v1/writing/evaluate',
        <String, dynamic>{
          'task1': <String, dynamic>{'prompt': task1Prompt, 'text': task1Text},
          'task2': <String, dynamic>{'prompt': task2Prompt, 'text': task2Text},
          'title': ?title,
          'testId': ?testId,
          'durationSec': ?durationSec,
          'context': context,
        },
        timeout: const Duration(seconds: 120),
      );

  /// Band-8 rewrite. → {source, text, changes[{from, to, why}]}
  static Future<Map<String, dynamic>?> rewriteWriting({
    required int task,
    required String prompt,
    required String text,
    double targetBand = 8,
  }) =>
      _post('/v1/writing/rewrite', <String, dynamic>{
        'task': task,
        'prompt': prompt,
        'text': text,
        'targetBand': targetBand,
      });

  /// Full speaking evaluation by the speaking service: submits the recorded
  /// answers, then polls until the report is ready (usually 30–90 s).
  /// → mapped evaluation {band, criteria{FC,LR,GRA,P}, criteriaFeedback,
  ///    summary, feedback[], perPartFeedback[], errors[], strengths[],
  ///    fluency, pronunciation, segments[{id, part, transcript, …}]}
  /// plus 'attemptId'. Null on failure ([lastError] / [lastErrorCode] say why;
  /// 'needs_rerecording' when an answer had no detectable speech).
  static Future<Map<String, dynamic>?> speakingSession({
    required String mode,
    required String title,
    required List<SpeakingSegment> segments,
    String? refId,
    int? durationSec,
    String? attemptId,
    void Function(String stage, double progress)? onProgress,
    Duration maxWait = const Duration(minutes: 6),
  }) async {
    if (!available || segments.isEmpty) return null;
    onProgress?.call('Uploading…', 0.05);
    final start = await _post(
      '/v1/speaking/sessions',
      <String, dynamic>{
        'mode': mode,
        'title': title,
        'refId': ?refId,
        'durationSec': ?durationSec,
        'attemptId': ?attemptId,
        'segments': [for (final s in segments) s.toJson()],
      },
      timeout: const Duration(seconds: 180),
    );
    final id = start == null ? null : start['attemptId'];
    if (id is! String || id.isEmpty) return null;
    // Server-side copies of the recordings: [{id (segment), key}].
    final recordings = start!['recordings'] is List ? start['recordings'] as List : const <Object>[];

    final began = DateTime.now();
    var misses = 0;
    while (DateTime.now().difference(began) < maxWait) {
      final waited = DateTime.now().difference(began).inSeconds;
      // Most reports land within ~90 s; the bar creeps towards 95 %.
      onProgress?.call(
        waited < 15 ? 'Transcribing…' : 'Scoring…',
        0.25 + 0.7 * (1 - 1 / (1 + waited / 45)),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
      Map<String, dynamic> r;
      try {
        r = await ApiClient.get('/v1/speaking/sessions/$id');
        misses = 0;
      } catch (e) {
        // A dropped poll is retried; the session keeps running on the server.
        if (e is ApiException && !e.isNetwork && e.status != 502) {
          _fail(e);
          return null;
        }
        if (++misses >= 5) {
          _fail(e);
          return null;
        }
        continue;
      }
      final status = '${r['status'] ?? ''}';
      if (status == 'processing') continue;
      if (status == 'completed' && r['evaluation'] is Map) {
        lastError = null;
        lastErrorCode = '';
        onProgress?.call('Scoring…', 1);
        return <String, dynamic>{
          ...(r['evaluation'] as Map).cast<String, dynamic>(),
          'attemptId': id,
          'recordings': recordings,
        };
      }
      lastError = '${r['message'] ?? 'Speaking evaluation failed. Please try again.'}';
      lastErrorCode = status;
      onFailure?.call(lastErrorCode);
      return null;
    }
    lastError = 'The evaluation is taking longer than usual. It will appear in your history when it is ready.';
    lastErrorCode = 'timeout';
    return null;
  }

  /// One-word pronunciation score (Goodness of Pronunciation against the
  /// target word). → {source, word, heard, score 0–100, tip,
  ///    phonemes: [{phoneme, score 0–100 | null}]}
  static Future<Map<String, dynamic>?> scorePronunciation({
    required String word,
    required Uint8List bytes,
    String format = 'wav',
  }) =>
      _post('/v1/pronunciation/score', <String, dynamic>{
        'word': word,
        'audioBase64': base64Encode(bytes),
        'format': format,
      });

  /// AI speaking partner (community rooms). [history] is the conversation so
  /// far, oldest first: `{'role': 'partner' | 'student', 'content': text}`.
  /// → {source, feedback, suggestion, question} - short feedback on the
  /// student's last answer and one Part 3 style follow-up question.
  static Future<Map<String, dynamic>?> partnerReply({
    required List<Map<String, String>> history,
    String? topic,
    List<String> questions = const <String>[],
  }) =>
      _post('/v1/chat/partner', <String, dynamic>{
        'history': history,
        'topic': ?topic,
        'questions': questions,
      });

  /// Stores a recording in R2. → key (or null offline).
  static Future<String?> uploadRecording(Uint8List bytes, {String ext = 'wav'}) async {
    if (!available) return null;
    try {
      final r = await ApiClient.putBytes(
        '/v1/uploads?ext=$ext',
        bytes,
        contentType: ext == 'wav' ? 'audio/wav' : 'application/octet-stream',
      );
      lastError = null;
      final key = r['key'];
      return key is String ? key : null;
    } catch (e) {
      _fail(e);
      return null;
    }
  }
}
