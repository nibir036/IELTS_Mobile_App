import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// Lists every canvas screen by code (A1 … H11) so each one can be opened
/// directly and checked against the design in Day and Night.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppScreen(
      children: [
        const TopBar(title: 'Screen gallery', subtitle: '75 screens · Day & Night'),
        const Row(
          children: [
            Expanded(child: BrandWordmark(size: 36)),
            ThemeToggle(),
          ],
        ),
        for (final row in ScreenCatalog.rows.entries)
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${row.key} · ${row.value}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                for (final s in ScreenCatalog.all.where((s) => s.code.startsWith(row.key)))
                  ListRow(
                    divider: true,
                    leading: LetterBadge(s.code, size: 38, fontSize: 12),
                    title: s.title,
                    trailing: Icon(AppIcons.chevronRight, color: t.textMuted),
                    onTap: () => context.push(s.route),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
