import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/promo_cards.dart';
import '../../app/widgets/vivid.dart';

/// "Tools": our own tools, one tap from the dashboard, as a row of quiet
/// cards you can swipe. Custom cards added in the content (place
/// `ielts_home`, see [PromoCards]) appear here first.
class SignatureTools extends StatelessWidget {
  const SignatureTools({super.key});

  @override
  Widget build(BuildContext context) {
    final items = PromoCards.forPlace(context, PromoPlace.ielts, <PromoItem>[
      PromoItem(
        id: 'vocab_quiz',
        title: 'Vocab Quiz',
        subtitle: 'Quick rounds, scored as you go',
        cta: 'Play',
        tone: Vivid.vocab,
        icon: AppIcons.quiz,
        onTap: () => context.push(Routes.vocabQuiz),
      ),
      PromoItem(
        id: 'writing_booster',
        title: 'Linking Booster',
        subtitle: 'Stronger sentences for Writing',
        cta: 'Build',
        tone: Vivid.writing,
        icon: AppIcons.link,
        onTap: () => context.push(Routes.sentenceBuilder),
      ),
      PromoItem(
        id: 'pronunciation',
        title: 'Pronunciation',
        subtitle: 'See which sounds to fix',
        cta: 'Train',
        tone: Vivid.speaking,
        icon: AppIcons.voice,
        onTap: () => context.push(Routes.pronunciation),
      ),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        const SectionHeader('Tools'),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => PopIn(
              delayMs: 60 * i.clamp(0, 6),
              from: 0.92,
              child: _ToolCard(item: items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.item});

  final PromoItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: '${item.title}. ${item.subtitle}',
      child: AppCard(
        width: 150,
        radius: 22,
        padding: const EdgeInsets.all(14),
        onTap: item.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VividIcon(item.icon ?? AppIcons.sparkle, tone: item.tone, size: 38, iconSize: 20, radius: 12),
            const Spacer(),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.text),
            ),
            const SizedBox(height: 2),
            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.3, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
