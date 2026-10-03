import 'package:flutter/material.dart';

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

/// E4 · Reading AI Solution & Paragraph Locator.
class ReadingSolutionScreen extends StatefulWidget {
  const ReadingSolutionScreen({super.key});

  @override
  State<ReadingSolutionScreen> createState() => _ReadingSolutionScreenState();
}

class _ReadingSolutionScreenState extends State<ReadingSolutionScreen> with ContentLangListener {
  int _index = 0;
  bool _argsRead = false;
  Attempt? _attempt;
  String _refId = '';
  List<ReadingItem> _items = <ReadingItem>[];
  final Map<int, String> _answers = <int, String>{};
  final Set<int> _correct = <int>{};

  bool _isCorrect(ReadingItem it) => _correct.contains(it.number);

  void _load(Attempt? a) {
    _attempt = a;
    _answers.clear();
    _correct.clear();
    _items = <ReadingItem>[];
    if (a == null) return;
    final d = a.data;
    final ref = d.s('testId').isNotEmpty
        ? d.s('testId')
        : (d.s('passageId').isNotEmpty ? d.s('passageId') : a.refId);
    _refId = ref;
    _items = ReadingRefs.items(ref);
    final given = d['answers'];
    if (given is Map) {
      given.forEach((k, v) {
        final n = int.tryParse('$k');
        if (n != null && v != null) _answers[n] = '$v';
      });
    }
    final ok = d['correct'];
    if (ok is List) {
      for (final c in ok) {
        if (c is num) _correct.add(c.toInt());
      }
    } else {
      for (final it in _items) {
        if (ReadingRefs.isCorrect(it, _answers[it.number] ?? '')) _correct.add(it.number);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final store = Store.I;
    final attemptId = context.routeArgs['attemptId'];
    Attempt? a = store.attemptById(attemptId is String ? attemptId : null);
    if (a == null || a.skill != Skill.reading || a.kind == 'lesson') {
      a = null;
      for (final x in store.attemptsFor(skill: Skill.reading)) {
        if (x.kind != 'lesson' && ReadingRefs.exists(x.refId)) {
          a = x;
          break;
        }
      }
    }
    _load(a);
    final wanted = context.routeArgs['question'];
    if (wanted is int) {
      for (var i = 0; i < _items.length; i++) {
        if (_items[i].number == wanted) _index = i;
      }
      return;
    }
    _index = _firstWrong(0);
  }

  /// First wrong question in passage [part] at or after the start (or the
  /// first question of that part if all are right).
  int _firstWrong(int part) {
    var first = -1;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].part != part) continue;
      if (first < 0) first = i;
      if (!_isCorrect(_items[i])) return i;
    }
    return first < 0 ? 0 : first;
  }

  Map<String, dynamic> _paragraphOf(Map<String, dynamic> passage, String letter) {
    for (final p in passage.l('paragraphs')) {
      if (p.s('letter') == letter) return p;
    }
    return <String, dynamic>{};
  }

  /// 1-based sentence of [text] containing [phrase] (0 if not found).
  int _sentenceNo(String text, String phrase) {
    var i = 0;
    for (final m in sentencePattern.allMatches(text)) {
      final s = m.group(0) ?? '';
      if (s.trim().isEmpty) continue;
      i++;
      if (phrase.isNotEmpty && s.contains(phrase)) return i;
    }
    return 0;
  }

  /// Correct heading text for a paragraph when the passage has a heading
  /// question on it ('' otherwise).
  String _headingFor(Map<String, dynamic> passage, String letter) {
    for (final g in passage.l('groups')) {
      if (g.s('type') != 'heading') continue;
      for (final q in g.l('questions')) {
        if (q.s('paragraph') != letter) continue;
        for (final h in g.l('headings')) {
          if (h.s('key') == q.s('answer')) return h.s('text');
        }
      }
    }
    return '';
  }

  void _openParagraph(Map<String, dynamic> passage, String letter, String evidence) {
    final t = context.tk;
    final p = _paragraphOf(passage, letter);
    final heading = _headingFor(passage, letter);
    showAppSheet<void>(
      context,
      SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              const SizedBox(height: 4),
              Text(
                'Paragraph $letter',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              Text(
                heading.isNotEmpty ? heading : passage.s('title'),
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
              PassageParagraph(
                letter: letter,
                text: p.s('text'),
                highlights: <HighlightSpec>[
                  if (evidence.isNotEmpty)
                    HighlightSpec(evidence, highlightColor(t, 'evidence')),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final attempt = _attempt;
    final qs = _items;
    if (attempt == null || qs.isEmpty) {
      return AppScreen(
        gap: 16,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        children: [
          ReadingHeader(title: 'Solutions', onBack: () => context.back()),
          EmptyState(
            title: attempt == null ? 'No reading results yet' : 'Test not available',
            message: attempt == null
                ? 'Finish a reading test to see AI solutions and where each answer is in the passage.'
                : 'This attempt was made on a test that is no longer in the library.',
            icon: AppIcons.reading,
            actionLabel: 'Browse reading tests',
            onAction: () => context.replace(Routes.readingLibrary),
          ),
        ],
      );
    }
    if (_index < 0 || _index >= qs.length) _index = 0;
    final it = qs[_index];
    final q = it.q;
    final n = it.number;
    final passage = it.passage;
    final isTest = ReadingRefs.isTest(_refId);
    final partCount = ReadingRefs.parts(_refId).length;
    final correct = _isCorrect(it);
    final yours = _answers[n] ?? '';
    final letter = q.s('evidenceParagraph');
    final para = _paragraphOf(passage, letter);
    final evidence = q.s('evidence');
    final evidenceSentence = sentenceContaining(para.s('text'), evidence);
    final sentenceNo = _sentenceNo(para.s('text'), evidence);
    final heading = _headingFor(passage, letter);
    final bank = ReadingRefs.isBankContent(_refId);
    final explanation = ContentL10n.explanation(passage.s('id'), q.i('number'), fallback: q.s('explanation'));
    final setLesson = ContentL10n.passageLesson(passage.s('id'), passage.m('lesson'));
    final wrongFg = t.isNight ? const Color(0xFF625C66) : t.warning;
    final isFirst = _index == 0;
    final isLast = _index == qs.length - 1;
    final partItems = <int>[
      for (var i = 0; i < qs.length; i++)
        if (qs[i].part == it.part) i,
    ];

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: SoftButton(
              label: isFirst ? 'Passage' : 'Q${qs[_index - 1].number}',
              height: 56,
              radius: 18,
              fontSize: 15,
              expand: true,
              bg: t.surface,
              onTap: () {
                if (isFirst) {
                  _openParagraph(passage, letter, evidence);
                } else {
                  setState(() => _index--);
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: isLast
                  ? (bank ? 'Done' : 'Back to library')
                  : 'Next · Q${qs[_index + 1].number}',
              trailing: AppIcons.forward,
              height: 56,
              radius: 18,
              fontSize: 15,
              onTap: () {
                if (isLast) {
                  if (bank) {
                    context.back();
                  } else {
                    context.replace(Routes.readingLibrary);
                  }
                } else {
                  setState(() => _index++);
                }
              },
            ),
          ),
        ],
      ),
      children: [
        ReadingHeader(
          title: isTest ? 'Solutions · Passage ${it.part + 1}' : 'Solutions',
          subtitle: '${attempt.title} · Band ${Store.formatBand(attempt.band)}',
          onBack: () => context.back(),
          trailing: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_correct.length}/${qs.length}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: t.onPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        if (isTest && partCount > 1)
          PassageSwitcher(
            count: partCount,
            index: it.part,
            onChanged: (p) => setState(() => _index = _firstWrong(p)),
            sublabels: <String>[
              for (var p = 0; p < partCount; p++)
                '${qs.where((x) => x.part == p && _isCorrect(x)).length}'
                    '/${qs.where((x) => x.part == p).length}',
            ],
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (final i in partItems)
                _NavChip(
                  number: qs[i].number,
                  current: i == _index,
                  wrong: !_isCorrect(qs[i]),
                  onTap: () => setState(() => _index = i),
                ),
            ],
          ),
        ),
        // Question + answers
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      'Question $n · ${it.group.s('title')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ),
                  Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: correct ? kLavender : kPink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      correct ? 'Correct' : (yours.trim().isEmpty ? 'Unanswered' : 'Incorrect'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: correct ? kInk : wrongFg,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                ReadingRefs.questionText(it),
                style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: correct
                              ? t.border
                              : (t.isNight ? const Color(0xFF5C2A20) : t.accentStrong),
                        ),
                      ),
                      child: _AnswerBox(
                        label: 'Your answer',
                        value: ReadingRefs.answerLabel(it, yours),
                        icon: correct ? AppIcons.check : AppIcons.close,
                        labelColor: t.textMuted,
                        valueColor: correct ? t.text : (t.isNight ? t.textMuted : t.warning),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _AnswerBox(
                        label: 'Correct answer',
                        value: ReadingRefs.correctLabel(it),
                        icon: AppIcons.check,
                        labelColor: t.isNight ? t.heroMuted : const Color(0xFFB5B5B5),
                        valueColor: t.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Paragraph locator
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                spacing: 8,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: t.isNight ? t.surfaceAlt2 : t.successSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(AppIcons.target, size: 16, color: t.text),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sentenceNo > 0
                              ? 'Paragraph $letter, sentence $sentenceNo'
                              : 'Paragraph $letter',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Answer located in the passage',
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: t.isNight ? t.surfaceAlt2 : t.surface,
                    shape: StadiumBorder(side: BorderSide(color: t.border)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openParagraph(passage, letter, evidence),
                      child: const SizedBox(
                        height: 32,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Center(child: Text('Open', style: TextStyle(fontSize: 12))),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              PassageParagraph(
                text: evidenceSentence.isEmpty ? evidence : evidenceSentence,
                prefix: '…',
                fontSize: 14,
                lineHeight: 1.5,
                color: t.textMuted,
                highlights: <HighlightSpec>[
                  HighlightSpec(evidence, highlightColor(t, 'evidence')),
                ],
              ),
            ],
          ),
        ),
        const ContentLangSwitch(),
        // Why
        HeroCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          gradient: t.isNight
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEEEFFD), kPink],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(AppIcons.sparkle, size: 16, color: t.heroText),
                  Expanded(
                    child: Text(
                      'Why it’s ${ReadingRefs.correctShort(it)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.heroText,
                      ),
                    ),
                  ),
                ],
              ),
              ContentDirection(
                child: Text.rich(
                  TextSpan(children: boldSpans(explanation)),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: t.isNight ? t.heroText : t.textSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (setLesson.s('text').isNotEmpty) _SetLessonCard(lesson: setLesson),
        // Paragraph map
        AppCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                spacing: 8,
                children: [
                  Text('Paragraph map', style: TextStyle(fontSize: 12, color: t.textMuted)),
                  Expanded(
                    child: Text(
                      heading.isNotEmpty ? 'Heading: $heading' : passage.s('title'),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ),
                ],
              ),
              Row(
                spacing: 6,
                children: [
                  for (final p in passage.l('paragraphs'))
                    Expanded(
                      child: _MapTile(
                        letter: p.s('letter'),
                        active: p.s('letter') == letter,
                        onTap: () => _openParagraph(
                          passage,
                          p.s('letter'),
                          p.s('letter') == letter ? evidence : '',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerBox extends StatelessWidget {
  const _AnswerBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
        Row(
          spacing: 6,
          children: [
            Icon(icon, size: 16, color: valueColor),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.number,
    required this.current,
    required this.wrong,
    this.onTap,
  });

  final int number;
  final bool current;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg = t.surface;
    Color fg = t.text;
    var weight = FontWeight.w400;
    if (current) {
      bg = t.primary;
      fg = t.onPrimary;
      weight = FontWeight.w600;
    } else if (wrong) {
      bg = kPink;
      fg = t.isNight ? const Color(0xFF625C66) : t.warning;
      weight = FontWeight.w500;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(fontSize: 13, fontWeight: weight, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({required this.letter, required this.active, this.onTap});

  final String letter;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final fg = active ? t.onPrimary : t.textMuted;
    return Material(
      color: active ? t.primary : t.surfaceAlt2,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              if (active) Icon(AppIcons.pin, size: 12, color: fg),
              Text(
                letter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The short skill lesson attached to a bank set ("Lesson for this set").
class _SetLessonCard extends StatelessWidget {
  const _SetLessonCard({required this.lesson});

  final Map<String, dynamic> lesson;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final example = lesson.s('example');
    return ContentDirection(
      child: AppCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 6,
              children: [
                Icon(AppIcons.bulb, size: 16, color: t.textMuted),
                Text('Lesson for this set', style: TextStyle(fontSize: 12, color: t.textMuted)),
              ],
            ),
            Text(
              lesson.s('title'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            Text(
              lesson.s('text'),
              style: TextStyle(fontSize: 13, height: 1.5, color: t.textSoft),
            ),
            if (example.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.isNight ? t.surfaceAlt2 : kLavender.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  example,
                  style: TextStyle(fontSize: 13, height: 1.5, color: t.textSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
