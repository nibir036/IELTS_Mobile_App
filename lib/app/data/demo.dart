import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

/// Demo data for the design build. Everything the screens show comes from
/// `assets/demo/demo_data.json` - no database or network.
///
/// Top-level keys: `user`, `access`, `home`, `writing`, `speaking`,
/// `reading`, `listening`, `mock`, `resources`.
///
/// ```dart
/// final w = Demo.section('writing');
/// final essays = w.l('essays');          // List<Map<String, dynamic>>
/// Text(essays.first.s('title'));
/// ```
class Demo {
  Demo._();

  static Map<String, dynamic> _data = <String, dynamic>{};
  static Map<String, dynamic> _readingBank = <String, dynamic>{};
  static Map<String, dynamic> _sentenceBank = <String, dynamic>{};
  static Map<String, dynamic> _listeningBank = <String, dynamic>{};
  static Map<String, dynamic> _writingBank = <String, dynamic>{};
  static Map<String, dynamic> _speakingBank = <String, dynamic>{};
  static Map<String, dynamic> _resourcesBank = <String, dynamic>{};
  static Map<String, dynamic> _testsBank = <String, dynamic>{};

  static Future<void> load() async {
    await Future.wait<void>(<Future<void>>[
      _loadMain(),
      _loadReadingBank(),
      _loadListeningBank(),
      _loadWritingBank(),
      _loadSpeakingBank(),
      _loadResourcesBank(),
      _loadTestsBank(),
      _loadGuides(),
      _loadCourses(),
      _loadSentenceBank(),
    ]);
  }

  static final Map<String, Map<String, dynamic>> _guides = <String, Map<String, dynamic>>{};

  /// Study guides (assets/content/<module>_guide.json: {title, subtitle,
  /// chapters: [{id, title, blocks}]}). Missing file → no guide.
  static Future<void> _loadGuides() async {
    for (final m in const <String>['reading', 'writing', 'speaking', 'grammar', 'listening', 'vocab']) {
      try {
        final raw = await rootBundle.loadString('assets/content/${m}_guide.json');
        _guides[m] = await compute(_decode, raw);
      } catch (_) {
        _guides.remove(m);
      }
    }
  }

  static final Map<String, Map<String, dynamic>> _courses = <String, Map<String, dynamic>>{};

  /// Bite-sized courses (assets/content/lessons/<module>.json, built by
  /// tool/build_lessons.py: {module, title, stages: [{id, title, lessons}]}).
  static Future<void> _loadCourses() async {
    for (final m in const <String>['writing', 'speaking', 'reading', 'listening', 'grammar', 'vocab']) {
      try {
        final raw = await rootBundle.loadString('assets/content/lessons/$m.json');
        _courses[m] = await compute(_decode, raw);
      } catch (_) {
        _courses.remove(m);
      }
    }
  }

  /// Course of [module]; empty map when it has none yet.
  static Map<String, dynamic> course(String module) => _courses[module] ?? const <String, dynamic>{};

  /// Guide of [module] ('reading', …); empty map when there is none.
  static Map<String, dynamic> guide(String module) => _guides[module] ?? const <String, dynamic>{};

  static Future<void> _loadMain() async {
    final raw = await rootBundle.loadString('assets/demo/demo_data.json');
    // ~800 KB of JSON: parse it off the UI thread (a no-op isolate on web).
    _data = await compute(_decode, raw);
  }

  /// Reading question bank (~2 MB, built by tool/build_reading_bank_asset.py).
  /// Missing or broken file → empty bank; the rest of the app still works.
  static Future<void> _loadReadingBank() async {
    try {
      final raw = await rootBundle.loadString('assets/content/reading_bank.json');
      _readingBank = await compute(_decode, raw);
    } catch (_) {
      _readingBank = <String, dynamic>{};
    }
  }

  /// Sentence Builder bank (built by tool/build_sentence_bank.py):
  /// `{instruction, setSize, total, categories: [{id, title, subtitle, icon,
  /// count, sets: [{id, title, drills}]}]}`. Missing file → empty.
  static Future<void> _loadSentenceBank() async {
    try {
      final raw = await rootBundle.loadString('assets/content/sentence_bank.json');
      _sentenceBank = await compute(_decode, raw);
    } catch (_) {
      _sentenceBank = <String, dynamic>{};
    }
  }

  static Map<String, dynamic> get sentenceBank => _sentenceBank;

  /// `{passages, lessons, tests}` of the reading question bank.
  static Map<String, dynamic> get readingBank => _readingBank;

  /// Listening question bank (~570 KB, built by tool/import_listening_bank.py
  /// from the Eleven v4 question-bank PDF). Missing file → empty bank; the
  /// listening screens then fall back to the demo sets.
  static Future<void> _loadListeningBank() async {
    try {
      final raw = await rootBundle.loadString('assets/content/listening_bank.json');
      _listeningBank = await compute(_decode, raw);
    } catch (_) {
      _listeningBank = <String, dynamic>{};
    }
  }

  /// `{meta, sets}` of the listening question bank.
  static Map<String, dynamic> get listeningBank => _listeningBank;

  /// Writing question bank (~3.8 MB: 140 Task 1 + 120 Task 2 questions with
  /// Band 6/7/8 sample answers), built by tool/import_writing_bank.py.
  /// Missing file → empty bank; writing falls back to the demo prompts.
  static Future<void> _loadWritingBank() async {
    try {
      final raw = await rootBundle.loadString('assets/content/writing_bank.json');
      _writingBank = await compute(_decode, raw);
    } catch (_) {
      _writingBank = <String, dynamic>{};
    }
  }

  /// `{meta, task1, task2}` of the writing question bank.
  static Map<String, dynamic> get writingBank => _writingBank;

  /// Speaking question bank (~2.4 MB: 62 Part 1 topics, 200 cue cards,
  /// 60 Part 3 topics, sample answers and a vocabulary dictionary), built by
  /// tool/import_speaking_bank.py. Missing file → empty bank; speaking falls
  /// back to the demo topics and cards.
  static Future<void> _loadSpeakingBank() async {
    try {
      final raw = await rootBundle.loadString('assets/content/speaking_bank.json');
      _speakingBank = await compute(_decode, raw);
    } catch (_) {
      _speakingBank = <String, dynamic>{};
    }
  }

  /// `{meta, part1Topics, cueCards, part3Topics, vocab}` of the speaking bank.
  static Map<String, dynamic> get speakingBank => _speakingBank;

  /// Resources bank (~900 KB: vocabulary bank, idioms, phrasal verbs,
  /// irregular verbs, linking words, academic words), built by
  /// tool/import_resources_bank.py. Missing file → empty bank; the resource
  /// screens fall back to the demo lists.
  static Future<void> _loadResourcesBank() async {
    try {
      final raw = await rootBundle.loadString('assets/content/resources_bank.json');
      _resourcesBank = await compute(_decode, raw);
    } catch (_) {
      _resourcesBank = <String, dynamic>{};
    }
  }

  /// `{vocab, idioms, phrasalVerbs, irregularVerbs, connectors, academicWords}`.
  static Map<String, dynamic> get resourcesBank => _resourcesBank;

  /// Full tests (~380 KB: Listening 1–4, Reading 1–10, Writing 1–10,
  /// Speaking 1–10, Full Mock 1–4), built by tool/import_web_tests.py from the
  /// website. Missing file → the demo tests and mocks are used.
  static Future<void> _loadTestsBank() async {
    try {
      final raw = await rootBundle.loadString('assets/content/tests_bank.json');
      _testsBank = await compute(_decode, raw);
    } catch (_) {
      _testsBank = <String, dynamic>{};
    }
  }

  /// `{listening: {tests, sets}, reading: {tests, passages}, writing: {tests,
  /// prompts}, speaking: {tests, part1Topics, cueCards, part3Topics}, mock: {tests}}`.
  static Map<String, dynamic> get testsBank => _testsBank;

  /// Whole JSON (read-only use).
  static Map<String, dynamic> get all => _data;

  /// One top-level section, e.g. `Demo.section('speaking')`.
  static Map<String, dynamic> section(String key) => _data.m(key);

  /// The signed-in demo student (name, initials, phone, bands, exam date …).
  static Map<String, dynamic> get user => _data.m('user');
}

Map<String, dynamic> _decode(String raw) =>
    (jsonDecode(raw) as Map).cast<String, dynamic>();

/// Null-safe, forgiving accessors for decoded JSON maps.
extension JsonMapX on Map<String, dynamic> {
  /// String (empty if missing).
  String s(String k) {
    final v = this[k];
    return v == null ? '' : '$v';
  }

  /// Number as double (0 if missing).
  double d(String k) {
    final v = this[k];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  /// Number as int (0 if missing).
  int i(String k) {
    final v = this[k];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Bool (false if missing).
  bool b(String k) => this[k] == true;

  /// Nested object (empty if missing).
  Map<String, dynamic> m(String k) {
    final v = this[k];
    if (v is Map) return v.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// List of objects (empty if missing).
  List<Map<String, dynamic>> l(String k) {
    final v = this[k];
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// List of strings (empty if missing).
  List<String> ls(String k) {
    final v = this[k];
    if (v is List) return v.map((e) => '$e').toList();
    return <String>[];
  }

  /// List of numbers as doubles (empty if missing).
  List<double> ld(String k) {
    final v = this[k];
    if (v is List) {
      return v.map((e) => e is num ? e.toDouble() : 0.0).toList();
    }
    return <double>[];
  }
}
