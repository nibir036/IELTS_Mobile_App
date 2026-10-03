import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/l10n.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import 'widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reading question bank: 14 question types × 20 sets (easy → hard), a
// "How to attempt" lesson per type and 20 short practice tests.
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _tones = <String>['pink', 'lavender', 'rose', 'mist'];

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Opens a bank set or short test: straight in when it is new or in
/// progress, otherwise a sheet to review the last result or try again.
void openReadingRef(BuildContext context, String id) {
  final store = Store.I;
  final last = latestReadingAttempt(store, id);
  final saved = readingInProgress(store);
  if (last == null || (saved != null && saved.s('refId') == id)) {
    context.push(Routes.readingPassage, args: readingArgsFor(id));
    return;
  }
  showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          const SizedBox(height: 4),
          Text(
            ReadingRefs.title(id),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          Text(
            'Band ${Store.formatBand(last.band)} · ${Store.shortDate(last.createdAt)} · '
            '${last.score ?? 0}/${last.total ?? 0}',
            style: TextStyle(fontSize: 13, color: ctx.tk.textMuted),
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Review solutions',
            onTap: () {
              Navigator.of(ctx).pop();
              context.push(Routes.readingSolution, args: <String, dynamic>{'attemptId': last.id});
            },
          ),
          SoftButton(
            label: 'Practise again',
            expand: true,
            onTap: () {
              Navigator.of(ctx).pop();
              ReadingSession.start(id);
              context.push(Routes.readingPassage);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

/// One set / short test in a list: number tile, title, meta and status.
class ReadingRefRow extends StatelessWidget {
  const ReadingRefRow({
    super.key,
    required this.badge,
    required this.number,
    required this.title,
    required this.meta,
    this.last,
    this.inProgress = false,
    this.onTap,
  });

  final String badge;
  final int number;
  final String title;
  final String meta;
  final Attempt? last;
  final bool inProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final a = last;
    final tone = inProgress || a == null ? 'pink' : 'lavender';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
        child: Row(
          spacing: 12,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: toneBg(t, tone),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(badge, style: TextStyle(fontSize: 10, height: 1, color: toneMuted(t, tone))),
                  Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: toneFg(t, tone),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            if (a != null && !inProgress)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${a.score ?? 0}/${a.total ?? 0}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    Store.shortDate(a.createdAt),
                    style: TextStyle(fontSize: 11, color: t.textMuted),
                  ),
                ],
              )
            else
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: inProgress ? t.primary : kPink,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  inProgress ? 'In progress' : 'Not started',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: inProgress ? t.onPrimary : kInk,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Plain "back + title" row used on the bank lists.
class _BankTopBar extends StatelessWidget {
  const _BankTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 10,
      children: [
        IconBox(
          icon: AppIcons.back,
          tooltip: 'Back',
          iconSize: 18,
          bg: t.surface,
          onTap: () => context.back(),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

Widget _bankMissing(BuildContext context) => const EmptyState(
      title: 'Question bank not available',
      message: 'The question bank could not be loaded. Restart the app and try again.',
      icon: AppIcons.reading,
    );

/// Practice by question type: the 14 types and the short practice tests.
class ReadingBankScreen extends StatelessWidget {
  const ReadingBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final types = Content.bankQuestionTypes;
    final done = ReadingStats.bankDone(store);
    final total = Content.readingBankPassages.length;
    final practised = ReadingStats.bankTypesPractised(store);
    final nTests = Content.readingPracticeTests.length;
    final testsDone = ReadingStats.practiceTestsDone(store).length;
    final labelColor = t.isNight ? t.heroText : t.textSoft;
    double ratio(int a, int b) => b <= 0 ? 0.0 : (a / b).clamp(0.0, 1.0).toDouble();

    return AppScreen(
      gap: 12,
      children: [
        const _BankTopBar(title: 'Question bank'),
        Text('Reading / Practice by question type', style: TextStyle(fontSize: 12, color: t.textMuted)),
        if (types.isEmpty || total == 0)
          _bankMissing(context)
        else ...[
          HeroCard(
            radius: 28,
            padding: const EdgeInsets.all(18),
            gradient: t.isNight
                ? null
                : const LinearGradient(
                    begin: Alignment(-0.64, -0.77),
                    end: Alignment(0.64, 0.77),
                    colors: [kLavender, kPink],
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                Text('Sets done', style: TextStyle(fontSize: 13, color: labelColor)),
                Text(
                  '${done.length}/$total',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.8,
                    height: 1.1,
                    color: t.heroText,
                  ),
                ),
                Text(
                  '${practised.length} of ${types.length} question types practised',
                  style: TextStyle(fontSize: 13, color: labelColor),
                ),
                const SizedBox(height: 10),
                ProgressBar(value: ratio(done.length, total), onHero: true),
              ],
            ),
          ),
          ModuleRow(
            item: <String, dynamic>{
              'title': 'Short practice tests',
              'count': '$testsDone/$nTests done',
              'subtitle': '3 passages · easy → hard · 15–25 questions',
              'tone': 'mist',
              'icon': 'test',
              'progress': ratio(testsDone, nTests),
            },
            onTap: () => context.push(Routes.readingPracticeTests),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Question types',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textMuted),
            ),
          ),
          for (var i = 0; i < types.length; i++)
            Builder(builder: (context) {
              final type = types[i];
              final sets = Content.bankSetsOf(type);
              final d = sets.where((p) => done.contains(p.s('id'))).length;
              var minQ = 0;
              var maxQ = 0;
              for (final p in sets) {
                final n = Content.passageQuestionCount(p);
                if (minQ == 0 || n < minQ) minQ = n;
                if (n > maxQ) maxQ = n;
              }
              final range = minQ == maxQ ? '$minQ' : '$minQ–$maxQ';
              return ModuleRow(
                item: <String, dynamic>{
                  'title': Content.typeName(type),
                  'count': '$d/${sets.length}',
                  'subtitle': '${sets.length} sets · $range questions each · lesson',
                  'tone': _tones[i % _tones.length],
                  'icon': 'mini',
                  'progress': ratio(d, sets.length),
                },
                onTap: () => context.push(Routes.readingType, args: <String, dynamic>{'type': type}),
              );
            }),
        ],
      ],
    );
  }
}

/// Lesson ids already opened ("How to attempt …").
List<String> readTypeLessons(Store store) {
  final v = store.kv<List>('reading.typeLessonsRead');
  return v == null ? <String>[] : <String>[for (final e in v) '$e'];
}

/// One question type: its lesson and its 20 sets, filterable by difficulty.
class ReadingTypeScreen extends StatefulWidget {
  const ReadingTypeScreen({super.key});

  @override
  State<ReadingTypeScreen> createState() => _ReadingTypeScreenState();
}

class _ReadingTypeScreenState extends State<ReadingTypeScreen> with ContentLangListener {
  static const List<String> _levels = <String>['', 'easy', 'medium', 'hard'];
  String _type = '';
  int _filter = 0;
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final want = context.routeArgs['type'];
    final types = Content.bankQuestionTypes;
    _type = want is String && types.contains(want) ? want : (types.isEmpty ? '' : types.first);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final sets = Content.bankSetsOf(_type);
    if (_type.isEmpty || sets.isEmpty) {
      return AppScreen(
        gap: 12,
        children: [const _BankTopBar(title: 'Question type'), _bankMissing(context)],
      );
    }
    final lesson = ContentL10n.typeLesson(Content.typeLesson(_type));
    final done = ReadingStats.bankDone(store);
    final saved = readingInProgress(store);
    final read = readTypeLessons(store).contains(_type);
    final level = _levels[_filter];
    final shown = <Map<String, dynamic>>[
      for (final p in sets)
        if (level.isEmpty || p.s('difficulty') == level) p,
    ];
    final doneCount = sets.where((p) => done.contains(p.s('id'))).length;
    final intro = lesson.l('sections').isEmpty ? '' : lesson.l('sections').first.s('text');

    return AppScreen(
      gap: 12,
      children: [
        ReadingHeader(
          title: Content.typeName(_type),
          subtitle: '${sets.length} sets · $doneCount done',
          onBack: () => context.back(),
        ),
        if (lesson.isNotEmpty)
          HeroCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            gradient: t.isNight
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEEEFFD), kPink],
                  ),
            onTap: () => context.push(
              Routes.readingTypeLesson,
              args: <String, dynamic>{'type': _type},
            ),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Icon(AppIcons.bulb, size: 14, color: t.heroText),
                          Flexible(
                            child: Text(
                              read ? 'Lesson · read' : 'Start here · lesson',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: t.heroMuted),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        lesson.s('title'),
                        textDirection: ContentL10n.currentLang.direction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: t.heroText,
                        ),
                      ),
                      if (intro.isNotEmpty)
                        Text(
                          intro,
                          textDirection: ContentL10n.currentLang.direction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, height: 1.35, color: t.heroMuted),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: t.isNight ? t.heroChip : t.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.forward, size: 18, color: t.heroText),
                ),
              ],
            ),
          ),
        ChipRow(
          labels: const <String>['All', 'Easy', 'Medium', 'Hard'],
          selected: _filter,
          onChanged: (i) => setState(() => _filter = i),
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  level.isEmpty
                      ? 'Easy 01–06 · Medium 07–14 · Hard 15–20'
                      : '${shown.length} ${_cap(level).toLowerCase()} sets',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              for (final p in shown)
                ReadingRefRow(
                  badge: 'Set',
                  number: p.i('bankSet'),
                  title: p.s('title'),
                  meta: '${_cap(p.s('difficulty'))} · ${p.s('topic')} · '
                      '${Content.passageQuestionCount(p)} Q · ${ReadingRefs.minutes(p.s('id'))} min',
                  last: latestReadingAttempt(store, p.s('id')),
                  inProgress: saved != null && saved.s('refId') == p.s('id'),
                  onTap: () => openReadingRef(context, p.s('id')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 20 short practice tests (Part 1 easy + Part 2 medium + Part 3 hard).
class ReadingPracticeTestsScreen extends StatelessWidget {
  const ReadingPracticeTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final tests = Content.readingPracticeTests;
    final saved = readingInProgress(store);
    final done = ReadingStats.practiceTestsDone(store);
    return AppScreen(
      gap: 12,
      children: [
        ReadingHeader(
          title: 'Short practice tests',
          subtitle: '${tests.length} tests · ${done.length} done',
          onBack: () => context.back(),
        ),
        if (tests.isEmpty)
          _bankMissing(context)
        else ...[
          Text(
            'Each test has three passages from the question bank, easy to hard, '
            'with a different question type in each. Timed at 1.5 minutes per question.',
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted),
          ),
          AppCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final x in tests)
                  ReadingRefRow(
                    badge: 'Test',
                    number: x.i('number'),
                    title: <String>[
                      for (final ty in x.ls('questionTypes')) Content.typeName(ty),
                    ].join(' · '),
                    meta: '${x.i('questionCount')} questions · ${ReadingRefs.minutes(x.s('id'))} min',
                    last: latestReadingAttempt(store, x.s('id')),
                    inProgress: saved != null && saved.s('refId') == x.s('id'),
                    onTap: () => openReadingRef(context, x.s('id')),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
