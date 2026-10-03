import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/speak_button.dart';
import 'quiz_rounds.dart';
import 'widgets.dart';

/// H5 · Vocabulary Quiz — Question. Route args: `{'quizId'}` (a round of
/// `Content.quizzes`; default the next round not yet played / quiz_band7).
class VocabQuizScreen extends StatefulWidget {
  const VocabQuizScreen({super.key});

  @override
  State<VocabQuizScreen> createState() => _VocabQuizScreenState();
}

class _VocabQuizScreenState extends State<VocabQuizScreen> {
  Map<String, dynamic> _quiz = <String, dynamic>{};
  List<Map<String, dynamic>> _questions = <Map<String, dynamic>>[];
  List<bool?> _results = <bool?>[];
  List<int?> _chosen = <int?>[];
  bool _loaded = false;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    // Round from `{'quizId'}` (default: next round not yet played).
    _quiz = Content.quiz(quizIdArg(context));
    _questions = _quiz.l('questions');
    _results = List<bool?>.filled(_questions.length, null);
    _chosen = List<int?>.filled(_questions.length, null);
  }

  int _index = 0;
  int? _picked;

  int get _score => _results.where((r) => r == true).length;

  void _pick(int i) {
    if (_picked != null || _index >= _questions.length) return;
    final answer = _questions[_index].i('answer');
    setState(() {
      _picked = i;
      _chosen[_index] = i;
      _results[_index] = i == answer;
    });
  }

  void _next() {
    if (_picked == null) return;
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _picked = null;
      });
      return;
    }
    _clock.stop();
    final elapsed = _clock.elapsed.inSeconds;
    final answers = <Map<String, dynamic>>[
      for (var i = 0; i < _questions.length; i++)
        <String, dynamic>{
          'qId': _questions[i].s('id'),
          'wordId': _questions[i].s('wordId'),
          'chosen': _chosen[i] ?? -1,
          'correct': _results[i] == true,
        },
    ];
    // Missed words go to "Learning" (unless already mastered).
    var added = 0;
    for (final a in answers) {
      final id = a.s('wordId');
      if (a.b('correct') || id.isEmpty) continue;
      if (wordMasteryOf(Store.I, id) == 'new') {
        setWordMastery(id, 'learning');
        added++;
      }
    }
    final attempt = Store.I.addAttempt(
      Attempt(
        id: Store.newId('att'),
        skill: Skill.vocab,
        kind: 'quiz',
        title: _quiz.s('title'),
        refId: _quiz.s('id'),
        score: _score,
        total: _questions.length,
        durationSec: elapsed < 60 ? 60 : elapsed,
        createdAt: DateTime.now(),
        data: <String, dynamic>{
          'answers': answers,
          'elapsedSec': elapsed,
          'addedToLearning': added,
        },
      ),
    );
    context.replace(
      Routes.vocabQuizScore,
      args: <String, dynamic>{'attemptId': attempt.id},
    );
  }

  Color _segmentColor(int i) {
    final t = context.tk;
    if (i == _index && _picked == null) return ResPalette.rose;
    final r = _results[i];
    if (r == true) return t.fill;
    if (r == false) return t.alert;
    return t.isNight ? t.surface : t.border;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (_questions.isEmpty) {
      return AppScreen(
        children: [
          const TopBar(title: 'Vocabulary quiz'),
          Text('No questions yet.', style: TextStyle(color: t.textMuted)),
        ],
      );
    }
    final q = _questions[_index];
    final options = q.ls('options');
    final answer = q.i('answer');
    final answered = _picked != null;
    final last = _index + 1 >= _questions.length;
    final wordSaved = isWordSaved(context.store, q.s('wordId'));

    return AppScreen(
      gap: 12,
      footer: PrimaryButton(
        label: last ? 'See my score' : 'Next question',
        trailing: AppIcons.forward,
        height: 56,
        radius: 18,
        enabled: answered,
        onTap: _next,
      ),
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.close,
              tooltip: 'Quit quiz',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _quiz.s('title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                  Text(
                    'Question ${_index + 1} of ${_questions.length}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.isNight ? t.surface : t.raised,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$_score ✓',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        Row(
          spacing: 3,
          children: [
            for (var i = 0; i < _questions.length; i++)
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: _segmentColor(i),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _quiz.s('prompt'),
                      style: TextStyle(
                        fontSize: 13,
                        color: t.isNight ? t.heroText : t.textSoft,
                      ),
                    ),
                  ),
                  SpeakButton(
                    text: q.s('word'),
                    size: 40,
                    radius: 14,
                    iconSize: 18,
                    bg: t.isNight ? ResPalette.creamChip : ResPalette.white,
                    fg: ResPalette.ink,
                  ),
                ],
              ),
              Text(
                q.s('word'),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1,
                  height: 1.05,
                  color: t.heroText,
                ),
              ),
              Text(
                q.s('phonetic').isEmpty ? q.s('partOfSpeech') : '${q.s('partOfSpeech')} · ${q.s('phonetic')}',
                style: TextStyle(
                  fontSize: 13,
                  color: t.isNight ? t.heroText : t.textSoft,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            for (var i = 0; i < options.length; i++)
              _AnswerTile(
                letter: String.fromCharCode(65 + i),
                label: options[i],
                state: !answered
                    ? _AnswerState.idle
                    : (i == answer
                        ? _AnswerState.correct
                        : (i == _picked ? _AnswerState.wrong : _AnswerState.idle)),
                onTap: () => _pick(i),
              ),
          ],
        ),
        if (answered)
          AppCard(
            radius: 18,
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Example: ',
                          style: TextStyle(fontWeight: FontWeight.w600, color: t.text),
                        ),
                        TextSpan(text: q.s('example')),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: t.isNight ? t.text : t.textSoft,
                    ),
                  ),
                ),
                IconBox(
                  icon: wordSaved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                  tooltip: 'Save word',
                  size: 36,
                  radius: 12,
                  iconSize: 16,
                  bg: t.surfaceAlt2,
                  onTap: () {
                    final now = toggleSavedWord(q.s('wordId'));
                    context.toast(now ? 'Saved to your words' : 'Removed from saved words');
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _AnswerState { idle, correct, wrong }

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String label;
  final _AnswerState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Color bg = t.surface;
    Color fg = t.text;
    BorderSide side = BorderSide.none;
    Color badgeBg = t.surfaceAlt2;
    Widget badge = Text(letter, style: TextStyle(fontSize: 13, color: t.text));
    String? note;
    Color noteColor = t.textMuted;
    switch (state) {
      case _AnswerState.correct:
        bg = t.primary;
        fg = t.onPrimary;
        badgeBg = t.onPrimary;
        badge = Icon(AppIcons.check, size: 16, color: t.primary);
        note = 'Correct';
        noteColor = t.onPrimary.withValues(alpha: 0.7);
      case _AnswerState.wrong:
        bg = t.dangerSoft;
        fg = t.dangerText;
        side = BorderSide(
          color: t.isNight ? const Color(0xFF5C2A20) : ResPalette.blush,
        );
        badgeBg = t.surface;
        badge = Icon(AppIcons.close, size: 16, color: t.dangerText);
        note = 'Your answer';
        noteColor = t.dangerText;
      case _AnswerState.idle:
        break;
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              spacing: 10,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: badge,
                ),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 15, color: fg)),
                ),
                if (note != null)
                  Text(note, style: TextStyle(fontSize: 12, color: noteColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
