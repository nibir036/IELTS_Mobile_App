import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// E2 · Reading Passage View (tap a sentence to highlight it).
class ReadingPassageScreen extends StatefulWidget {
  const ReadingPassageScreen({super.key});

  @override
  State<ReadingPassageScreen> createState() => _ReadingPassageScreenState();
}

class _ReadingPassageScreenState extends State<ReadingPassageScreen> {
  Timer? _ticker;
  bool _opened = false;
  bool _finished = false;

  /// Selected sentence: paragraph letter + sentence text.
  String? _selLetter;
  String? _selSentence;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (ReadingSession.active && ReadingSession.remainingSeconds <= 0) {
        _timeUp();
        return;
      }
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    ReadingSession.open(context.routeArgs);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    ReadingSession.save();
    super.dispose();
  }

  void _timeUp() {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    final a = ReadingSession.submit();
    context.toast('Time is up · answers submitted');
    context.replace(Routes.readingSolution, args: <String, dynamic>{'attemptId': a.id});
  }

  void _showPart(int i) {
    setState(() {
      ReadingSession.showPart(i);
      _selLetter = null;
      _selSentence = null;
    });
    ReadingSession.save();
  }

  void _toQuestions([int? number]) {
    if (number != null) ReadingSession.focus(number);
    context.replace(Routes.readingQuestions);
  }

  void _tapSentence(String letter, String sentence) {
    setState(() {
      if (_selLetter == letter && _selSentence == sentence) {
        _selLetter = null;
        _selSentence = null;
      } else {
        _selLetter = letter;
        _selSentence = sentence;
      }
    });
  }

  void _removeInSelection() {
    final letter = _selLetter;
    final sentence = _selSentence;
    if (letter == null || sentence == null) return;
    ReadingSession.highlightsFor(ReadingSession.passageId).removeWhere(
      (h) => h.s('paragraph') == letter && sentence.contains(h.s('phrase')),
    );
  }

  void _apply(String color) {
    final letter = _selLetter;
    final sentence = _selSentence;
    if (letter == null || sentence == null) return;
    setState(() {
      _removeInSelection();
      ReadingSession.highlightsFor(ReadingSession.passageId).add(<String, dynamic>{
        'paragraph': letter,
        'phrase': sentence,
        'color': color,
      });
      _selLetter = null;
      _selSentence = null;
    });
    ReadingSession.save();
  }

  void _clear() {
    setState(() {
      _removeInSelection();
      _selLetter = null;
      _selSentence = null;
    });
    ReadingSession.save();
  }

  Future<void> _note() async {
    final t = context.tk;
    final letter = _selLetter ?? '';
    final sentence = _selSentence ?? '';
    var text = '';
    final saved = await showAppSheet<bool>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const SizedBox(height: 4),
          const Text('Add a note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Text(
            _selSentence ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
          AppTextField(
            hint: 'Write your note…',
            maxLines: 3,
            onChanged: (v) => text = v,
          ),
          Builder(
            builder: (ctx) => PrimaryButton(
              label: 'Save note',
              onTap: () => Navigator.of(ctx).pop(true),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      if (text.trim().isEmpty) {
        context.toast('Write something to save a note');
        return;
      }
      Store.I.kvListAdd('reading.notes.${ReadingSession.passageId}', <String, dynamic>{
        'paragraph': letter,
        'sentence': sentence,
        'note': text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      context.toast('Note saved');
      setState(() {
        _selLetter = null;
        _selSentence = null;
      });
    }
  }

  List<HighlightSpec> _specsFor(String letter, AppTokens t) => <HighlightSpec>[
        for (final h in ReadingSession.highlightsFor(ReadingSession.passageId))
          if (h.s('paragraph') == letter)
            HighlightSpec(h.s('phrase'), highlightColor(t, h.s('color'))),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final passage = ReadingSession.passage;
    final numbers = ReadingSession.partNumbers;
    final hasSelection = _selSentence != null;
    final isTest = ReadingSession.isTest;
    final count = ReadingSession.partCount;

    return AppScreen(
      scroll: false,
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      children: [
        ReadingHeader(
          title: isTest
              ? 'Passage ${ReadingSession.part + 1} of $count'
              : ReadingRefs.modeLabel(ReadingSession.refId),
          subtitle: isTest
              ? ReadingSession.title
              : '${passage.s('topic')} · ${ReadingRefs.minutes(ReadingSession.refId)} min',
          onBack: () => context.back(),
          trailing: TimerPill(seconds: ReadingSession.remainingSeconds),
        ),
        if (isTest && count > 1)
          PassageSwitcher(
            count: count,
            index: ReadingSession.part,
            onChanged: _showPart,
          ),
        ReadingTabs(
          labels: ['Passage', 'Questions ${ReadingSession.partRange}'],
          index: 0,
          onChanged: (i) {
            if (i == 1) _toQuestions();
          },
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: t.surface,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      key: ValueKey<String>('passage-${ReadingSession.passageId}'),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            passage.s('title'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (passage.s('passageNote').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              passage.s('passageNote'),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                                color: t.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 14,
                            children: [
                              for (final p in ReadingSession.paragraphs)
                                PassageParagraph(
                                  letter: p.s('letter'),
                                  text: p.s('text'),
                                  highlights: _specsFor(p.s('letter'), t),
                                  selected: _selLetter == p.s('letter') ? _selSentence : null,
                                  onSentenceTap: (s) => _tapSentence(p.s('letter'), s),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [t.surface.withValues(alpha: 0), t.surface],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasSelection)
                    Positioned(
                      top: 180,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _PenToolbar(
                          onYellow: () => _apply('yellow'),
                          onPink: () => _apply('pink'),
                          onNote: _note,
                          onClear: _clear,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 5,
                  children: [
                    for (final n in numbers)
                      _NumberChip(
                        number: n,
                        answered: ReadingSession.isAnswered(n),
                        current: n == ReadingSession.current,
                        onTap: () => _toQuestions(n),
                      ),
                  ],
                ),
              ),
            ),
            IconBox(
              icon: AppIcons.forward,
              tooltip: 'Next',
              radius: 14,
              bg: t.peach,
              fg: kOnPeach,
              onTap: () => _toQuestions(),
            ),
          ],
        ),
      ],
    );
  }
}

class _PenToolbar extends StatelessWidget {
  const _PenToolbar({
    required this.onYellow,
    required this.onPink,
    required this.onNote,
    required this.onClear,
  });

  final VoidCallback onYellow;
  final VoidCallback onPink;
  final VoidCallback onNote;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget btn(String label, Widget child, VoidCallback onTap) => Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(width: 40, height: 40, child: Center(child: child)),
            ),
          ),
        );
    Widget dot(Color c, {Color? border}) => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: border == null ? null : Border.all(color: border, width: 1.5),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          btn(
            'Highlight yellow',
            dot(t.isNight ? kInk : const Color(0xFFFFC9B8)),
            onYellow,
          ),
          btn(
            'Highlight pink',
            dot(kPink, border: t.isNight ? kInk : null),
            onPink,
          ),
          btn('Add note', Icon(AppIcons.note, size: 18, color: t.onPrimary), onNote),
          btn('Clear highlight', Icon(AppIcons.close, size: 18, color: t.onPrimary), onClear),
        ],
      ),
    );
  }
}

class _NumberChip extends StatelessWidget {
  const _NumberChip({
    required this.number,
    required this.answered,
    required this.current,
    this.onTap,
  });

  final int number;
  final bool answered;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final filled = answered && !current;
    return Material(
      color: filled ? t.primary : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: current ? BorderSide(color: t.text, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 36,
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                color: filled ? t.onPrimary : t.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
