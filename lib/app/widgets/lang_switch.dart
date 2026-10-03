import 'package:flutter/material.dart';

import '../data/l10n.dart';
import '../theme/tokens.dart';
import 'app_icons.dart';

/// Dropdown to switch the language of lessons and explanations (the choice
/// is shared with AI feedback). Hidden while [module] has English only.
class ContentLangSwitch extends StatelessWidget {
  const ContentLangSwitch({super.key, this.module = 'reading'});

  final String module;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ValueListenableBuilder<String>(
      valueListenable: ContentL10n.lang,
      builder: (context, code, _) {
        final langs = ContentL10n.available(module);
        if (langs.length < 2) return const SizedBox.shrink();
        final current = langs.firstWhere((l) => l.code == code, orElse: () => langs.first);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: PopupMenuButton<String>(
            tooltip: 'Explanation language',
            initialValue: current.code,
            position: PopupMenuPosition.under,
            color: t.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (c) {
              if (c != current.code) ContentL10n.set(c);
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              for (final l in langs)
                PopupMenuItem<String>(
                  value: l.code,
                  height: 44,
                  child: Row(
                    spacing: 10,
                    children: [
                      SizedBox(
                        width: 18,
                        child: l.code == current.code
                            ? Icon(AppIcons.check, size: 18, color: t.text)
                            : null,
                      ),
                      Text(
                        l.native,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: l.code == current.code ? FontWeight.w600 : FontWeight.w400,
                          color: t.text,
                        ),
                      ),
                      if (l.code != 'en')
                        Text(l.english, style: TextStyle(fontSize: 12, color: t.textMuted)),
                    ],
                  ),
                ),
            ],
            child: Container(
              height: 40,
              padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: t.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Icon(AppIcons.translate, size: 18, color: t.textMuted),
                  Text(
                    current.native,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: t.text),
                  ),
                  Icon(AppIcons.chevronDown, size: 18, color: t.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rebuilds a screen when the content language changes.
mixin ContentLangListener<T extends StatefulWidget> on State<T> {
  void _onLang() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ContentL10n.lang.addListener(_onLang);
  }

  @override
  void dispose() {
    ContentL10n.lang.removeListener(_onLang);
    super.dispose();
  }
}
