import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// Vocabulary quiz rounds: the starter rounds from the content bank
/// (`Content.quizzes`) and the decks generated from the Resources bank
/// (`ResBank.quizDecks`, round ids `gq_<deck>_<n>`), with the student's
/// results per round (vocab `quiz` attempts, refId = quiz id).

/// Round used when the student has not played anything yet.
const String kDefaultQuizId = 'quiz_band7';

/// The student's quiz attempts for one round (newest first).
List<Attempt> quizAttemptsFor(Store s, String quizId) => s
    .attemptsFor(skill: Skill.vocab, kind: 'quiz')
    .where((a) => a.refId == quizId)
    .toList();

/// Best score of a round, or null if it was never played.
Attempt? bestQuizAttempt(Store s, String quizId) {
  Attempt? best;
  for (final a in quizAttemptsFor(s, quizId)) {
    final b = best;
    if (b == null || (a.score ?? 0) > (b.score ?? 0)) best = a;
  }
  return best;
}

/// Every quiz round: starter rounds plus all generated deck rounds.
int get totalQuizRounds =>
    Content.quizzes.length + ResBank.quizDecks.fold<int>(0, (n, d) => n + d.i('rounds'));

/// Rounds of [deck] the student has played at least once.
int playedDeckRounds(Store s, Map<String, dynamic> deck) {
  var n = 0;
  for (var r = 1; r <= deck.i('rounds'); r++) {
    if (quizAttemptsFor(s, ResBank.deckRoundId(deck.s('id'), r)).isNotEmpty) n++;
  }
  return n;
}

/// Next round of a generated deck after round [after] (cyclic, 0 = from the
/// start), preferring one the student has not played yet.
String nextDeckRoundId(Store s, String deck, {int after = 0}) {
  final d = ResBank.quizDecks.where((x) => x.s('id') == deck).firstOrNull;
  if (d == null) return kDefaultQuizId;
  final total = d.i('rounds');
  for (var k = 1; k <= total; k++) {
    final id = ResBank.deckRoundId(deck, (after + k - 1) % total + 1);
    if (quizAttemptsFor(s, id).isEmpty) return id;
  }
  return ResBank.deckRoundId(deck, after % total + 1);
}

/// Next round after [currentId]: inside the same deck for a generated round,
/// otherwise in starter-bank order (cyclic), preferring unplayed rounds.
String nextQuizId(Store s, String currentId) {
  final gen = ResBank.parseRoundId(currentId);
  if (gen != null) return nextDeckRoundId(s, gen.$1, after: gen.$2);
  final quizzes = Content.quizzes;
  if (quizzes.isEmpty) return currentId;
  final start = quizzes.indexWhere((q) => q.s('id') == currentId);
  for (var k = 1; k <= quizzes.length; k++) {
    final q = quizzes[(start + k) % quizzes.length];
    if (quizAttemptsFor(s, q.s('id')).isEmpty) return q.s('id');
  }
  return quizzes[(start + 1) % quizzes.length].s('id');
}

/// Round to start when none is given: quiz_band7 for a new student,
/// otherwise the next round not yet played after the latest one.
String defaultQuizId(Store s) {
  final quizzes = Content.quizzes;
  if (quizzes.isEmpty) return kDefaultQuizId;
  final last = s.latest(skill: Skill.vocab, kind: 'quiz');
  if (last == null) {
    return Content.quiz(kDefaultQuizId).isNotEmpty ? kDefaultQuizId : quizzes.first.s('id');
  }
  return nextQuizId(s, last.refId);
}

/// Quiz id from route args (`{'quizId'}`), else [defaultQuizId].
String quizIdArg(BuildContext context) {
  final v = context.routeArgs['quizId'];
  if (v is String && Content.quiz(v).isNotEmpty) return v;
  return defaultQuizId(Store.I);
}

/// Finds a quiz question by id across all rounds (for older attempts that
/// point at a round that no longer exists).
Map<String, dynamic> quizQuestionById(String quizId, String qId) {
  for (final q in Content.quiz(quizId).l('questions')) {
    if (q.s('id') == qId) return q;
  }
  for (final quiz in Content.quizzes) {
    for (final q in quiz.l('questions')) {
      if (q.s('id') == qId) return q;
    }
  }
  return <String, dynamic>{};
}

/// Bottom sheet: the starter rounds (title, level, best score) and the
/// generated decks (rounds played). Tapping a starter round starts it; tapping
/// a deck starts its next unplayed round.
Future<void> showQuizRoundPicker(BuildContext context) {
  return showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) {
        final t = ctx.tk;
        final store = ctx.store;
        final quizzes = Content.quizzes;
        final decks = ResBank.quizDecks;
        final next = defaultQuizId(store);
        void start(String id) {
          Navigator.of(ctx).pop();
          context.push(Routes.vocabQuiz, args: <String, dynamic>{'quizId': id});
        }

        Widget heading(String text) => Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textMuted)),
            );

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                const Text(
                  'Choose a quiz round',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                Text(
                  '$totalQuizRounds rounds · 10 words each',
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
                if (quizzes.isNotEmpty) heading('Starter rounds'),
                for (var i = 0; i < quizzes.length; i++)
                  _RoundRow(
                    quiz: quizzes[i],
                    best: bestQuizAttempt(store, quizzes[i].s('id')),
                    upNext: quizzes[i].s('id') == next,
                    divider: i > 0,
                    onTap: () => start(quizzes[i].s('id')),
                  ),
                if (decks.isNotEmpty) heading('Word bank decks'),
                for (var i = 0; i < decks.length; i++)
                  _DeckRow(
                    deck: decks[i],
                    played: playedDeckRounds(store, decks[i]),
                    divider: i > 0,
                    onTap: () => start(nextDeckRoundId(store, decks[i].s('id'))),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.deck, required this.played, required this.divider, required this.onTap});

  final Map<String, dynamic> deck;
  final int played;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final rounds = deck.i('rounds');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: divider ? Border(top: BorderSide(color: t.divider)) : null,
        ),
        child: Row(
          spacing: 12,
          children: [
            IconCircle(AppIcons.quiz, size: 40, iconSize: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    deck.s('title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$rounds rounds · $played played',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.quiz,
    required this.best,
    required this.upNext,
    required this.divider,
    required this.onTap,
  });

  final Map<String, dynamic> quiz;
  final Attempt? best;
  final bool upNext;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final b = best;
    final total = quiz.l('questions').length;
    final bestText = b == null
        ? 'Not played'
        : 'Best ${b.score ?? 0}/${b.total ?? total}';
    var title = quiz.s('title');
    const prefix = 'Vocabulary quiz · ';
    if (title.startsWith(prefix)) title = title.substring(prefix.length);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: divider ? Border(top: BorderSide(color: t.divider)) : null,
        ),
        child: Row(
          spacing: 12,
          children: [
            IconCircle(AppIcons.quiz, size: 40, iconSize: 16),
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
                    '${quiz.s('level')} · $total questions · $bestText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            if (upNext)
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.peach,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Up next',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kOnPeach),
                ),
              ),
            Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
          ],
        ),
      ),
    );
  }
}
