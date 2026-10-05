import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../course/course_widgets.dart';
import 'sentence_builder_screen.dart';
import 'writing_data.dart';

/// Routes.sentenceBuilder: with `{'set': id}` or `{'attemptId': id}` it runs
/// / shows that set; without args it opens the bank of categories.
class SentenceBuilderEntry extends StatelessWidget {
  const SentenceBuilderEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final args = context.routeArgs;
    final direct = args['set'] is String || args['attemptId'] is String;
    if (direct || !SentenceBank.available) return const SentenceBuilderScreen();
    return const SentenceBankScreen();
  }
}

/// Sentence Builder bank: categories of linking-word drills, each split into
/// sets of 10.
class SentenceBankScreen extends StatefulWidget {
  const SentenceBankScreen({super.key});

  @override
  State<SentenceBankScreen> createState() => _SentenceBankScreenState();
}

class _SentenceBankScreenState extends State<SentenceBankScreen> {
  /// The one open category (accordion); null = none.
  String? _open;
  bool _seeded = false;

  void _start(String setId) =>
      context.push(Routes.sentenceBuilder, args: <String, dynamic>{'set': setId});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final best = SentenceBank.best(store);
    final cats = SentenceBank.categories;
    final resume = SentenceBank.resume(store);
    if (!_seeded) {
      _seeded = true;
      _open = resume?.category.s('id');
    }
    final setsTotal = SentenceBank.setCount;
    final setsDone = best.keys.where((id) => SentenceBank.find(id) != null).length;

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: 'Sentence Builder',
          subtitle: '${SentenceBank.total} sentences · ${cats.length} categories',
          onBack: () => context.back(),
        ),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      resume == null ? 'ALL SETS DONE' : (setsDone == 0 ? 'START HERE' : 'CONTINUE'),
                      style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: t.peach, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      resume?.title ?? 'You finished every set',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 19, height: 1.2, fontWeight: FontWeight.w600, color: t.heroText),
                    ),
                    Text(
                      'Join two sentences with the right linking word.',
                      style: TextStyle(fontSize: 12.5, color: t.heroMuted),
                    ),
                    ProgressBar(value: setsTotal == 0 ? 0 : setsDone / setsTotal, onHero: true),
                    Text('$setsDone of $setsTotal sets done', style: TextStyle(fontSize: 12, color: t.heroMuted)),
                    if (resume != null)
                      SizedBox(
                        width: 160,
                        child: PrimaryButton(
                          label: setsDone == 0 ? 'Start' : 'Continue',
                          height: 44,
                          trailing: AppIcons.forward,
                          onTap: () => _start(resume.id),
                        ),
                      ),
                  ],
                ),
              ),
              const Nexi(NexiPose.writing, height: 110),
            ],
          ),
        ),
        for (final c in cats)
          _CategoryCard(
            category: c,
            best: best,
            open: _open == c.s('id'),
            onToggle: () => setState(() => _open = _open == c.s('id') ? null : c.s('id')),
            onSet: _start,
          ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.best,
    required this.open,
    required this.onToggle,
    required this.onSet,
  });

  final Map<String, dynamic> category;
  final Map<String, int> best;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onSet;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final sets = category.l('sets');
    final done = sets.where((s) => best.containsKey(s.s('id'))).length;
    final complete = sets.isNotEmpty && done == sets.length;
    final (badgeBg, badgeFg) = tintBadge(t);
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                spacing: 12,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: complete ? t.peach : badgeBg,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      complete ? AppIcons.check : lessonIcon(category.s('icon')),
                      size: 21,
                      color: complete ? kOnPeach : badgeFg,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          '${category.i('count')} sentences · $done/${sets.length} sets',
                          style: TextStyle(fontSize: 11.5, color: t.textMuted, letterSpacing: 0.3),
                        ),
                        Text(
                          category.s('title'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25),
                        ),
                        Text(
                          category.s('subtitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: t.textMuted),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: Icon(AppIcons.chevronDown, size: 20, color: t.textMuted),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            child: PeachBar(value: sets.isEmpty ? 0 : done / sets.length, height: 4),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity, height: 4)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in sets)
                          _SetChip(
                            title: s.s('title'),
                            size: s.l('drills').length,
                            score: best[s.s('id')],
                            onTap: () => onSet(s.s('id')),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({required this.title, required this.size, required this.score, required this.onTap});

  final String title;
  final int size;
  final int? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final done = score != null;
    final perfect = done && score! >= size;
    return Material(
      color: perfect ? t.peach : (done ? t.peach.withValues(alpha: t.isNight ? 0.18 : 0.22) : t.glassFill),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: done ? Colors.transparent : t.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (perfect) const Icon(AppIcons.check, size: 15, color: kOnPeach),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: perfect ? kOnPeach : t.text,
                ),
              ),
              Text(
                done ? '$score/$size' : '$size',
                style: TextStyle(fontSize: 12, color: perfect ? kOnPeach : t.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
