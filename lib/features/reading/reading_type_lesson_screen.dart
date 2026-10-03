import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import 'exhibits.dart';
import 'reading_bank_screen.dart';
import 'widgets.dart';

final RegExp _numbered = RegExp(r'^(\d+)\.\s+(.*)$');

/// "How to attempt …" strategy lesson for one question type.
class ReadingTypeLessonScreen extends StatefulWidget {
  const ReadingTypeLessonScreen({super.key});

  @override
  State<ReadingTypeLessonScreen> createState() => _ReadingTypeLessonScreenState();
}

class _ReadingTypeLessonScreenState extends State<ReadingTypeLessonScreen> with ContentLangListener {
  String _type = '';
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final want = context.routeArgs['type'];
    final types = Content.bankQuestionTypes;
    _type = want is String && types.contains(want) ? want : (types.isEmpty ? '' : types.first);
    final read = readTypeLessons(Store.I);
    if (_type.isNotEmpty && !read.contains(_type)) {
      persistKv(<String, Object?>{
        'reading.typeLessonsRead': <String>[...read, _type],
      });
    }
  }

  Widget _paragraph(String line, AppTokens t) {
    final m = _numbered.firstMatch(line);
    if (m == null) {
      return Text(line, style: TextStyle(fontSize: 14, height: 1.5, color: t.textSoft));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.isNight ? t.surfaceAlt2 : kLavender,
            shape: BoxShape.circle,
          ),
          child: Text(
            m.group(1)!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.isNight ? t.text : kInk,
            ),
          ),
        ),
        Expanded(
          child: Text(
            m.group(2)!,
            style: TextStyle(fontSize: 14, height: 1.5, color: t.textSoft),
          ),
        ),
      ],
    );
  }

  List<Widget> _body(Map<String, dynamic> section, AppTokens t) {
    final paras = <String>[
      for (final line in section.s('text').split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final exhibits = section.l('exhibits');
    // Exhibits quote the English test paper: always left-to-right.
    Widget exhibit(Map<String, dynamic> e) => Directionality(
          textDirection: TextDirection.ltr,
          child: ReadingExhibit(kind: e.s('kind'), data: e),
        );
    final layout = section.l('layout');
    if (layout.isEmpty) {
      return <Widget>[
        for (final p in paras) _paragraph(p, t),
        for (final e in exhibits) exhibit(e),
      ];
    }
    final out = <Widget>[];
    for (final l in layout) {
      if (l.containsKey('paragraph')) {
        final i = l.i('paragraph');
        if (i >= 0 && i < paras.length) out.add(_paragraph(paras[i], t));
      } else if (l.containsKey('exhibit')) {
        final i = l.i('exhibit');
        if (i >= 0 && i < exhibits.length) out.add(exhibit(exhibits[i]));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final english = Content.typeLesson(_type);
    final lesson = english.isEmpty ? english : ContentL10n.typeLesson(english);
    if (lesson.isEmpty) {
      return AppScreen(
        gap: 12,
        children: [
          ReadingHeader(title: 'Lesson', onBack: () => context.back()),
          const EmptyState(
            title: 'Lesson not available',
            message: 'The question bank could not be loaded. Restart the app and try again.',
            icon: AppIcons.school,
          ),
        ],
      );
    }
    final sections = lesson.l('sections');
    final sets = Content.bankSetsOf(_type);
    final done = ReadingStats.bankDone(store);
    Map<String, dynamic>? next;
    for (final p in sets) {
      if (!done.contains(p.s('id'))) {
        next = p;
        break;
      }
    }
    next ??= sets.isEmpty ? null : sets.first;
    final start = next;

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      footer: start == null
          ? null
          : PrimaryButton(
              label: 'Start Set ${start.i('bankSet')} · ${start.s('difficulty')}',
              trailing: AppIcons.forward,
              height: 54,
              radius: 18,
              fontSize: 15,
              onTap: () => openReadingRef(context, start.s('id')),
            ),
      children: [
        ReadingHeader(
          title: lesson.s('title'),
          subtitle: '${lesson.s('name')} · ${sections.length} parts',
          onBack: () => context.back(),
        ),
        const ContentLangSwitch(),
        for (var i = 0; i < sections.length; i++)
          ContentDirection(
            child: AppCard(
              radius: 24,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: toneBg(t, i.isEven ? 'pink' : 'lavender'),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          sections[i].s('heading'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  ..._body(sections[i], t),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
