import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;

import 'packs/content_packs.dart';

/// The app's content: UI text and demo data (pack `ui`, also bundled as
/// `assets/demo/demo_data.json`), the question banks, guides and courses.
/// They come from the server's database as content packs kept on the device
/// ([PackStore]); a pack that isn't here yet reads as an empty map.
///
/// Top-level keys of the UI pack: `user`, `access`, `home`, `writing`,
/// `speaking`, `reading`, `listening`, `mock`, `resources`.
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

  static final Map<String, Map<String, dynamic>> _guides = <String, Map<String, dynamic>>{};
  static final Map<String, Map<String, dynamic>> _courses = <String, Map<String, dynamic>>{};

  /// Goes up each time content is (re)loaded: caches built from it compare
  /// this to know when to rebuild.
  static int generation = 0;

  /// Reads every pack kept on the device (call once at start-up).
  static Future<void> load() async {
    await PackStore.I.init();
    PackStore.I.onPacksChanged(reload);
    await reload(null);
  }

  /// Reloads [keys] (all packs when null), e.g. after a newer version of a
  /// pack was downloaded.
  static Future<void> reload(Set<String>? keys) async {
    bool want(String k) => keys == null || keys.contains(k);
    await Future.wait<void>(<Future<void>>[
      if (want(Packs.ui)) _read(Packs.ui).then((m) => _data = m),
      if (want(Packs.bank('reading'))) _read(Packs.bank('reading')).then((m) => _readingBank = m),
      if (want(Packs.bank('listening'))) _read(Packs.bank('listening')).then((m) => _listeningBank = m),
      if (want(Packs.bank('writing'))) _read(Packs.bank('writing')).then((m) => _writingBank = m),
      if (want(Packs.bank('speaking'))) _read(Packs.bank('speaking')).then((m) => _speakingBank = m),
      if (want(Packs.bank('resources'))) _read(Packs.bank('resources')).then((m) => _resourcesBank = m),
      if (want(Packs.bank('tests'))) _read(Packs.bank('tests')).then((m) => _testsBank = m),
      if (want(Packs.bank('sentence'))) _read(Packs.bank('sentence')).then((m) => _sentenceBank = m),
      for (final g in Packs.guides)
        if (want(Packs.guide(g)))
          _read(Packs.guide(g)).then((m) {
            if (m.isEmpty) {
              _guides.remove(g);
            } else {
              _guides[g] = m;
            }
          }),
      for (final c in Packs.courses)
        if (want(Packs.course(c)))
          _read(Packs.course(c)).then((m) {
            if (m.isEmpty) {
              _courses.remove(c);
            } else {
              _courses[c] = m;
            }
          }),
    ]);
    generation++;
  }

  /// One pack as a map; missing or broken → empty (the screens fall back).
  static Future<Map<String, dynamic>> _read(String key) async {
    try {
      final raw = await PackStore.I.read(key);
      if (raw == null || raw.isEmpty) return <String, dynamic>{};
      // Up to ~4 MB of JSON: parse it off the UI thread (a no-op isolate on web).
      return await compute(_decode, raw);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Course of [module]; empty map when it has none yet.
  static Map<String, dynamic> course(String module) => _courses[module] ?? const <String, dynamic>{};

  /// Guide of [module] ('reading', …); empty map when there is none.
  static Map<String, dynamic> guide(String module) => _guides[module] ?? const <String, dynamic>{};

  /// Sentence Builder bank: `{instruction, setSize, total, categories:
  /// [{id, title, subtitle, icon, count, sets: [{id, title, drills}]}]}`.
  static Map<String, dynamic> get sentenceBank => _sentenceBank;

  /// `{passages, lessons, tests}` of the reading question bank.
  static Map<String, dynamic> get readingBank => _readingBank;

  /// `{meta, sets}` of the listening question bank.
  static Map<String, dynamic> get listeningBank => _listeningBank;

  /// `{meta, task1, task2}` of the writing question bank (140 Task 1 + 120
  /// Task 2 questions with Band 6/7/8 sample answers).
  static Map<String, dynamic> get writingBank => _writingBank;

  /// `{meta, part1Topics, cueCards, part3Topics, vocab}` of the speaking bank.
  static Map<String, dynamic> get speakingBank => _speakingBank;

  /// `{vocab, idioms, phrasalVerbs, irregularVerbs, connectors, academicWords}`.
  static Map<String, dynamic> get resourcesBank => _resourcesBank;

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
