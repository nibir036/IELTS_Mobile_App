import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../listening/lesson_menu.dart' show LessonMenuEntry;

/// Reading lessons (content: reading.json → lessons; progress: attempts kind
/// 'lesson' + kv 'reading.lessonProgress' {lessonId, index, correct,
/// elapsedSec} for the one lesson in progress).
class ReadingLessons {
  ReadingLessons._();

  static const progressKey = 'reading.lessonProgress';

  static List<Map<String, dynamic>> get all => Demo.section('reading').l('lessons');

  static int indexOf(String id) => all.indexWhere((l) => l.s('id') == id);

  static Map<String, dynamic>? byId(String id) {
    final lessons = all;
    final i = lessons.indexWhere((l) => l.s('id') == id);
    return i < 0 ? null : lessons[i];
  }

  /// 1-based position of a lesson in the course.
  static int numberOf(String id) => indexOf(id) + 1;

  static Set<String> doneIds(Store store) => <String>{
        for (final a in store.attemptsFor(skill: Skill.reading, kind: 'lesson')) a.refId,
      };

  /// Id of the lesson with saved progress ('' if none).
  static String inProgressId(Store store) {
    final saved = store.kv<Map>(progressKey);
    if (saved == null) return '';
    final v = saved['lessonId'];
    return v is String ? v : '';
  }

  static Attempt? latest(Store store, String id) {
    for (final a in store.attemptsFor(skill: Skill.reading, kind: 'lesson')) {
      if (a.refId == id) return a;
    }
    return null;
  }

  /// Lesson to open without args: the one in progress, else the first not done.
  static String defaultId(Store store) {
    final lessons = all;
    if (lessons.isEmpty) return '';
    final done = doneIds(store);
    final started = inProgressId(store);
    if (started.isNotEmpty && !done.contains(started) && indexOf(started) >= 0) {
      return started;
    }
    for (final l in lessons) {
      if (!done.contains(l.s('id'))) return l.s('id');
    }
    return lessons.first.s('id');
  }

  /// Menu rows: a lesson is open when it is the first, already done or
  /// started, or the lesson before it is done.
  static List<LessonMenuEntry> menu(Store store, String currentId) {
    final lessons = all;
    final done = doneIds(store);
    final started = inProgressId(store);
    final out = <LessonMenuEntry>[];
    for (var i = 0; i < lessons.length; i++) {
      final id = lessons[i].s('id');
      final isDone = done.contains(id);
      final open = i == 0 ||
          isDone ||
          id == started ||
          id == currentId ||
          done.contains(lessons[i - 1].s('id'));
      final last = latest(store, id);
      String sub;
      if (last != null) {
        sub = 'Done · ${last.score ?? 0}/${last.total ?? 0} · ${Store.shortDate(last.createdAt)}';
      } else if (id == currentId || id == started) {
        sub = 'In progress';
      } else if (open) {
        sub = 'Up next';
      } else {
        sub = 'Locked';
      }
      out.add(LessonMenuEntry(
        id: id,
        number: i + 1,
        title: lessons[i].s('title'),
        subtitle: sub,
        done: isDone,
        current: id == currentId,
        locked: !open,
      ));
    }
    return out;
  }
}
