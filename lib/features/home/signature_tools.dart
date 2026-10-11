import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// "Dive Right In": our own tools, one tap from the dashboard.
class SignatureTools extends StatelessWidget {
  const SignatureTools({super.key});

  static const List<(IconData, String, String, String)> _tools = <(IconData, String, String, String)>[
    (AppIcons.quiz, 'Vocab Quiz', 'Quick rounds of IELTS words, scored as you go', Routes.vocabQuiz),
    (AppIcons.link, 'Writing Booster · Linking', 'Build stronger sentences with the right linking words', Routes.sentenceBuilder),
    (AppIcons.voice, 'Pronunciation Trainer', 'Say a word and see exactly which sounds to fix', Routes.pronunciation),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              spacing: 8,
              children: [
                Icon(AppIcons.sparkle, size: 18, color: t.peach),
                const Expanded(
                  child: Text(
                    'Dive Right In',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          for (final (icon, title, sub, route) in _tools)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(route),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    spacing: 12,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: t.peach, borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, size: 22, color: kOnPeach),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          spacing: 2,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              sub,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, height: 1.3, color: t.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(AppIcons.forward, size: 18, color: t.textMuted),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
