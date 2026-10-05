import 'package:flutter/material.dart';

import '../routes.dart';
import 'demo.dart';
import 'l10n.dart';
import 'store.dart';

/// Bite-sized courses: module → stages → lessons → steps
/// (assets/content/lessons/<module>.json, built by tool/build_lessons.py),
/// plus the student's lesson progress and XP (Store kv `lessons.done`,
/// synced with the account like other kv state).
class Lessons {
  Lessons._();

  static const String _key = 'lessons.done';

  /// Modules that have a course.
  static const List<String> modules = <String>['writing', 'speaking', 'reading', 'listening', 'grammar', 'vocab'];

  /// "Writing", "Vocabulary" …
  static String name(String module) => switch (module) {
        'writing' => 'Writing',
        'speaking' => 'Speaking',
        'reading' => 'Reading',
        'listening' => 'Listening',
        'grammar' => 'Grammar',
        'vocab' => 'Vocabulary',
        _ => module,
      };

  /// The course map of [module].
  static String route(String module) => switch (module) {
        'speaking' => Routes.speakingCourse,
        'reading' => Routes.readingCourse,
        'listening' => Routes.listeningCourse,
        'grammar' => Routes.grammarCourse,
        'vocab' => Routes.vocabCourse,
        _ => Routes.writingCourse,
      };

  /// The full study guide the course is built from.
  static String guideRoute(String module) => switch (module) {
        'speaking' => Routes.speakingGuide,
        'reading' => Routes.readingGuide,
        'listening' => Routes.listeningGuide,
        'grammar' => Routes.grammarGuide,
        'vocab' => Routes.vocabGuide,
        _ => Routes.writingGuide,
      };

  static Map<String, dynamic> course(String module) => Demo.course(module);

  static List<Map<String, dynamic>> stages(String module) => course(module).l('stages');

  static bool has(String module) => stages(module).isNotEmpty;

  /// Every lesson of [module] in order.
  static List<Map<String, dynamic>> all(String module) => <Map<String, dynamic>>[
        for (final s in stages(module)) ...s.l('lessons'),
      ];

  /// Where [lessonId] sits: its stage, the lesson, and their positions.
  static LessonRef? find(String lessonId) {
    for (final module in modules) {
      final st = stages(module);
      for (var si = 0; si < st.length; si++) {
        final ls = st[si].l('lessons');
        for (var li = 0; li < ls.length; li++) {
          if (ls[li].s('id') == lessonId) {
            return LessonRef(module: module, stage: st[si], lesson: ls[li], stageIndex: si, lessonIndex: li);
          }
        }
      }
    }
    return null;
  }

  /// The lesson after [lessonId] in its course (crossing into the next
  /// stage), or null at the end.
  static LessonRef? next(String lessonId) {
    final at = find(lessonId);
    if (at == null) return null;
    final ls = all(at.module);
    final i = ls.indexWhere((l) => l.s('id') == lessonId);
    if (i < 0 || i + 1 >= ls.length) return null;
    return find(ls[i + 1].s('id'));
  }

  /// First lesson not finished yet (null when the course is complete).
  static LessonRef? resume(Store store, String module) {
    for (final l in all(module)) {
      if (!isDone(store, l.s('id'))) return find(l.s('id'));
    }
    return null;
  }

  // ── progress ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _done(Store store) {
    final v = store.kv<Map>(_key);
    return v == null ? <String, dynamic>{} : v.cast<String, dynamic>();
  }

  static bool isDone(Store store, String lessonId) => _done(store).containsKey(lessonId);

  /// Lessons finished (in [module] when given).
  static int doneCount(Store store, {String? module}) {
    final d = _done(store);
    if (module == null) return d.length;
    return d.values.where((v) => v is Map && v['module'] == module).length;
  }

  static int doneIn(Store store, Map<String, dynamic> stage) =>
      stage.l('lessons').where((l) => isDone(store, l.s('id'))).length;

  static bool stageDone(Store store, Map<String, dynamic> stage) {
    final ls = stage.l('lessons');
    return ls.isNotEmpty && doneIn(store, stage) == ls.length;
  }

  /// Total XP from finished lessons.
  static int xp(Store store) {
    var n = 0;
    for (final v in _done(store).values) {
      if (v is Map && v['xp'] is num) n += (v['xp'] as num).toInt();
    }
    return n;
  }

  /// Days on which a lesson was finished (for the study streak).
  static Set<DateTime> days(Store store) => <DateTime>{
        for (final v in _done(store).values)
          if (v is Map && v['at'] is String && DateTime.tryParse(v['at'] as String) != null)
            DateUtils.dateOnly(DateTime.parse(v['at'] as String).toLocal()),
      };

  /// Finished lessons (with the time) in completion order - milestones use
  /// this to date the badge.
  static List<DateTime> completions(Store store) {
    final out = <DateTime>[
      for (final v in _done(store).values)
        if (v is Map && v['at'] is String && DateTime.tryParse(v['at'] as String) != null)
          DateTime.parse(v['at'] as String),
    ]..sort();
    return out;
  }

  /// Records [ref] as finished (first time only: XP isn't counted twice).
  static void complete(LessonRef ref, {int minutes = 0}) {
    final store = Store.I;
    final id = ref.lesson.s('id');
    if (isDone(store, id)) return;
    store.setKv(_key, <String, dynamic>{
      ..._done(store),
      id: <String, dynamic>{
        'module': ref.module,
        'stage': ref.stage.s('id'),
        'xp': ref.lesson.i('xp') > 0 ? ref.lesson.i('xp') : 20,
        'minutes': minutes,
        'at': DateTime.now().toUtc().toIso8601String(),
      },
    });
    store.tickPlanTasks(id);
  }

  /// Resets one lesson (review mode doesn't need it; kept for "start over").
  static void forget(String lessonId) {
    final d = _done(Store.I)..remove(lessonId);
    Store.I.setKv(_key, d);
  }
}

class LessonRef {
  const LessonRef({
    required this.module,
    required this.stage,
    required this.lesson,
    required this.stageIndex,
    required this.lessonIndex,
  });

  final String module;
  final Map<String, dynamic> stage;
  final Map<String, dynamic> lesson;
  final int stageIndex;
  final int lessonIndex;

  String get id => lesson.s('id');
  int get stageLessons => stage.l('lessons').length;
}

/// Text from lesson JSON in the explanation language:
/// a plain string · `{"en": …, "bn": …}` · `{"ref": [chapter, block], "en": …}`
/// (a guide heading, translated with the guide) · `{"chapterTitle": id,
/// "en": …}` (a guide chapter title). `"part": n` adds " · Part n".
String lessonText(Object? v, {String module = 'writing'}) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is! Map) return '$v';
  final m = v.cast<String, dynamic>();
  final lang = ContentL10n.current;
  var out = '';
  if (lang != 'en') {
    final direct = m[lang];
    if (direct is String && direct.isNotEmpty) {
      out = direct;
    } else if (m['ref'] is List && (m['ref'] as List).length == 2) {
      final ref = m['ref'] as List;
      final ch = _chapter(module, '${ref[0]}');
      final idx = ref[1];
      if (ch != null && idx is num) {
        final blocks = ContentL10n.guideChapter(ch, module: module)['blocks'];
        if (blocks is List && idx.toInt() < blocks.length) {
          final b = blocks[idx.toInt()];
          if (b is List && b.length > 1 && b[1] is String) {
            out = _unnumber(b[1] as String, heading: true);
          }
        }
      }
    } else if (m['chapterTitle'] is String) {
      final ch = _chapter(module, m['chapterTitle'] as String);
      if (ch != null) out = _unnumber(ContentL10n.guideChapter(ch, module: module).s('title'));
    }
  }
  if (out.isEmpty) out = m.s('en');
  final part = m['part'];
  if (part is num && part > 1) out = '$out · Part ${part.toInt()}';
  return out;
}

/// Drops the guide's own numbering ("2. …", "২. …", and for headings
/// "2 The …") - lessons are numbered by the course.
String _unnumber(String t, {bool heading = false}) {
  var out = t.trim().replaceFirst(RegExp(r'^[0-9০-৯०-९٠-٩]+(\.[0-9০-৯०-९٠-٩]+)*[.।]\s+'), '');
  if (heading) out = out.replaceFirst(RegExp(r'^[0-9০-৯०-९٠-٩]+([.][0-9০-৯०-९٠-٩]+)*[.।]?\s+'), '');
  return out.trim();
}

Map<String, dynamic>? _chapter(String module, String id) {
  for (final c in Demo.guide(module).l('chapters')) {
    if (c.s('id') == id) return c;
  }
  return null;
}

/// Guide blocks [from, to) of [chapter] in the explanation language
/// (English when the chapter isn't translated).
List<List<dynamic>> lessonBlocks(String module, String chapter, int from, int to) {
  final ch = _chapter(module, chapter);
  if (ch == null) return const <List<dynamic>>[];
  final blocks = ContentL10n.guideChapter(ch, module: module)['blocks'];
  if (blocks is! List) return const <List<dynamic>>[];
  final end = to.clamp(0, blocks.length).toInt();
  final start = from.clamp(0, end).toInt();
  return <List<dynamic>>[
    for (final b in blocks.sublist(start, end))
      if (b is List && b.isNotEmpty) b,
  ];
}
