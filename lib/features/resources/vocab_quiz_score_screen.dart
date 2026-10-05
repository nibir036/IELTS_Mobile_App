import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'quiz_rounds.dart';

/// H6 · Vocabulary Quiz - Round Score. Reads the vocab quiz attempt passed as
/// `attemptId` (fallback: the latest one); empty state if there is none.
/// "New round" starts the next round of `Content.quizzes`.
class VocabQuizScoreScreen extends StatelessWidget {
  const VocabQuizScoreScreen({super.key});

  static int _longestStreak(List<Map<String, dynamic>> review) {
    var best = 0;
    var run = 0;
    for (final r in review) {
      if (r.b('correct')) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final attempt =
        store.resolveAttempt(context.routeArgs, skill: Skill.vocab, kind: 'quiz');
    if (attempt == null) {
      return AppScreen(
        children: [
          const TopBar(title: 'Vocabulary quiz'),
          EmptyState(
            title: 'No quiz rounds yet',
            message: 'Finish a vocabulary quiz to see your score and the words to review.',
            icon: AppIcons.translate,
            actionLabel: 'Start quiz',
            onAction: () => context.replace(Routes.vocabQuiz),
          ),
        ],
      );
    }
    final quizId = attempt.refId;
    final review = <Map<String, dynamic>>[
      for (final a in attempt.data.l('answers'))
        <String, dynamic>{
          // Phrase practice rounds (phrasal verbs / idioms) store the
          // word and meaning on the answer itself.
          'word': a.s('word').isNotEmpty
              ? a.s('word')
              : quizQuestionById(quizId, a.s('qId')).s('word'),
          'meaning': a.s('meaning').isNotEmpty
              ? a.s('meaning')
              : quizQuestionById(quizId, a.s('qId')).s('meaningShort'),
          'correct': a.b('correct'),
        },
    ];
    final nextId = nextQuizId(store, quizId);
    final score = attempt.score ?? review.where((r) => r.b('correct')).length;
    final total = attempt.total ?? review.length;
    final secs = attempt.data.containsKey('elapsedSec')
        ? attempt.data.i('elapsedSec')
        : attempt.durationSec;
    final time = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final wrong = review.where((r) => !r.b('correct')).length;
    final streak = '${_longestStreak(review)} in a row';
    final newWords = '$wrong';
    final learningNote = '${attempt.data.i('addedToLearning')} added to Learning';
    // "Best so far": no earlier try of this round scored higher (share of total).
    var best = true;
    for (final other in quizAttemptsFor(store, quizId)) {
      if (other.id == attempt.id || other.createdAt.isAfter(attempt.createdAt)) continue;
      final os = other.score ?? 0;
      final ot = other.total ?? 0;
      if (ot > 0 && total > 0 && os / ot > score / total) best = false;
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      footerPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      gap: 12,
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Back to list',
              height: 56,
              fontSize: 15,
              expand: true,
              bg: t.raised,
              onTap: () => context.back(),
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: 'New round',
              height: 56,
              radius: 999,
              fontSize: 15,
              onTap: () => context.replace(
                Routes.vocabQuiz,
                args: <String, dynamic>{'quizId': nextId},
              ),
            ),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.close,
              tooltip: 'Close',
              size: 56,
              radius: 20,
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Round complete',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (Content.quiz(quizId).isNotEmpty)
                    Text(
                      Content.quiz(quizId).s('level'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
        HeroCard(
          radius: 32,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your score'.toUpperCase(),
                          style: TextStyle(
                              fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: t.peach),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '$score'),
                              TextSpan(
                                text: '/$total',
                                style: TextStyle(
                                  fontSize: 28,
                                  letterSpacing: 0,
                                  color: t.heroMuted,
                                ),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w300,
                            height: 1,
                            letterSpacing: -2,
                            color: t.heroText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (best)
                    Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: kPeachGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Best so far',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kOnPeach,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(child: _Stat(label: 'Time', value: time)),
                  Expanded(child: _Stat(label: 'Streak', value: streak)),
                  Expanded(child: _Stat(label: 'New words', value: newWords)),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Review',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ),
                    Text(
                      learningNote,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              for (final r in review) _ReviewRow(data: r),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.heroChip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: t.heroMuted)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: t.heroText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ok = data.b('correct');
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Row(
        spacing: 10,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ok
                  ? t.primary
                  : (t.isNight ? t.dangerSoft : t.alert.withValues(alpha: 0.12)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ok ? AppIcons.check : AppIcons.close,
              size: 14,
              color: ok ? t.onPrimary : t.alert,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              data.s('word'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              data.s('meaning'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
