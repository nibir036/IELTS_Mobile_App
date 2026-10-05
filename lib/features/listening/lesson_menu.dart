import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// One row of the lesson menu sheet (shared by Listening F6 and Reading E6).
class LessonMenuEntry {
  const LessonMenuEntry({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    this.done = false,
    this.current = false,
    this.locked = false,
  });

  final String id;
  final int number;
  final String title;
  final String subtitle;
  final bool done;
  final bool current;
  final bool locked;
}

/// Result of the lesson menu: open another lesson, restart or mark done.
class LessonMenuAction {
  const LessonMenuAction._(this.kind, [this.lessonId = '']);

  const LessonMenuAction.open(String id) : this._('open', id);
  static const restart = LessonMenuAction._('restart');
  static const markDone = LessonMenuAction._('done');

  final String kind;
  final String lessonId;
}

/// Bottom sheet listing every lesson (done / current / next / locked) plus
/// "Restart this lesson" and "Mark as done". Returns the chosen action.
Future<LessonMenuAction?> showLessonMenu(
  BuildContext context, {
  required List<LessonMenuEntry> entries,
  required bool currentDone,
}) {
  return showAppSheet<LessonMenuAction>(
    context,
    _LessonMenuSheet(entries: entries, currentDone: currentDone),
  );
}

class _LessonMenuSheet extends StatelessWidget {
  const _LessonMenuSheet({required this.entries, required this.currentDone});

  final List<LessonMenuEntry> entries;
  final bool currentDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final doneCount = entries.where((e) => e.done).length;
    final maxList = MediaQuery.of(context).size.height * 0.5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lessons',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '$doneCount of ${entries.length} done',
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxList),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _EntryRow(
                    entry: entries[i],
                    divider: i > 0,
                    onTap: () {
                      final e = entries[i];
                      if (e.locked) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(content: Text('Finish Lesson ${e.number - 1} to unlock this one')),
                          );
                        return;
                      }
                      Navigator.of(context).pop(LessonMenuAction.open(e.id));
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: SoftButton(
                label: 'Restart lesson',
                leading: AppIcons.refresh,
                height: 52,
                radius: 18,
                expand: true,
                onTap: () => Navigator.of(context).pop(LessonMenuAction.restart),
              ),
            ),
            Expanded(
              child: PrimaryButton(
                label: currentDone ? 'Done' : 'Mark as done',
                leading: AppIcons.check,
                height: 52,
                radius: 18,
                fontSize: 14,
                enabled: !currentDone,
                onTap: currentDone
                    ? null
                    : () => Navigator.of(context).pop(LessonMenuAction.markDone),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.divider, this.onTap});

  final LessonMenuEntry entry;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final e = entry;
    Color bg;
    Color fg;
    Color? border;
    if (e.done) {
      bg = t.peach;
      fg = kOnPeach;
    } else if (e.current) {
      bg = t.surface;
      fg = t.text;
      border = t.text;
    } else {
      bg = t.surfaceAlt;
      fg = t.textMuted;
    }
    final Widget badge = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
      child: e.done
          ? Icon(AppIcons.check, size: 16, color: fg)
          : (e.locked
              ? Icon(AppIcons.lock, size: 15, color: fg)
              : Text(
                  '${e.number}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: fg),
                )),
    );
    return Opacity(
      opacity: e.locked ? 0.55 : 1,
      child: ListRow(
        title: 'Lesson ${e.number} · ${e.title}',
        subtitle: e.subtitle,
        leading: badge,
        divider: divider,
        trailing: e.current
            ? const Tag('Current', tone: TagTone.accent)
            : Icon(
                e.locked ? AppIcons.lock : AppIcons.chevronRight,
                size: 18,
                color: t.textMuted,
              ),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Listening lessons (content: listening.json → lessons; progress: attempts
// kind 'lesson' + kv 'listening.lesson.<id>').
// ─────────────────────────────────────────────────────────────────────────────

class ListeningLessons {
  ListeningLessons._();

  static List<Map<String, dynamic>> get all => Demo.section('listening').l('lessons');

  static int indexOf(String id) => all.indexWhere((l) => l.s('id') == id);

  static Map<String, dynamic>? byId(String id) {
    final lessons = all;
    final i = lessons.indexWhere((l) => l.s('id') == id);
    return i < 0 ? null : lessons[i];
  }

  /// 1-based position of a lesson in the course.
  static int numberOf(String id) => indexOf(id) + 1;

  static String savedKey(String id) => 'listening.lesson.$id';

  static Set<String> doneIds(Store store) => <String>{
        for (final a in store.attemptsFor(skill: Skill.listening, kind: 'lesson')) a.refId,
      };

  static bool inProgress(Store store, String id) => store.kv<Map>(savedKey(id)) != null;

  static Attempt? latest(Store store, String id) {
    for (final a in store.attemptsFor(skill: Skill.listening, kind: 'lesson')) {
      if (a.refId == id) return a;
    }
    return null;
  }

  /// Lesson to open without args: one in progress, else the first not done.
  static String defaultId(Store store) {
    final lessons = all;
    if (lessons.isEmpty) return '';
    final done = doneIds(store);
    for (final l in lessons) {
      final id = l.s('id');
      if (!done.contains(id) && inProgress(store, id)) return id;
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
    return <LessonMenuEntry>[
      for (var i = 0; i < lessons.length; i++)
        () {
          final id = lessons[i].s('id');
          final isDone = done.contains(id);
          final started = inProgress(store, id);
          final open = i == 0 || isDone || started || id == currentId ||
              done.contains(lessons[i - 1].s('id'));
          final last = latest(store, id);
          String sub;
          if (last != null) {
            sub = 'Done · ${last.score ?? 0}/${last.total ?? 0} · ${Store.shortDate(last.createdAt)}';
          } else if (id == currentId || started) {
            sub = 'In progress';
          } else if (open) {
            sub = 'Up next';
          } else {
            sub = 'Locked';
          }
          return LessonMenuEntry(
            id: id,
            number: i + 1,
            title: lessons[i].s('title'),
            subtitle: sub,
            done: isDone,
            current: id == currentId,
            locked: !open,
          );
        }(),
    ];
  }
}
