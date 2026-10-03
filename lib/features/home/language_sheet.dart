import 'package:flutter/material.dart';

import '../../app/data/l10n.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/kit.dart';

/// Explanation + AI feedback language, stored per account in
/// `Store.I.kv('feedbackLanguage')` (ApiClient forwards it to the backend).
/// Thin wrapper over [ContentL10n], which also switches lessons and answer
/// explanations to that language (English where not translated yet).
class FeedbackLanguage {
  FeedbackLanguage._();

  static const String kvKey = ContentL10n.kvKey;

  static String get current => ContentL10n.current;

  static Future<void> set(String code) => ContentL10n.set(code);

  /// Copies a logged-out choice onto the account that just signed in, then
  /// follows that account's language.
  static void applyPending() {
    ContentL10n.applyPending();
    ContentL10n.syncFromAccount();
  }

  static String label(String code) {
    final l = contentLang(code);
    return l.code == 'en' ? 'English' : '${l.native} (${l.english})';
  }

  /// Short text for the login-screen pill.
  static String get pillLabel => current == 'en' ? 'English' : 'English · ${contentLang(current).native}';
}

/// "Language" sheet: app language (English only) + AI feedback language.
Future<void> showLanguageSheet(BuildContext context) {
  return showAppSheet<void>(context, const _LanguageSheet());
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet();

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late String _code;

  @override
  void initState() {
    super.initState();
    _code = FeedbackLanguage.current;
  }

  void _pick(String code) {
    setState(() => _code = code);
    FeedbackLanguage.set(code);
  }

  String? _subtitle(ContentLang l) {
    if (l.code == 'en') return null;
    final ready = ContentL10n.available('reading').any((x) => x.code == l.code);
    final where = l.regions.isEmpty ? '' : '${l.regions} · ';
    return ready ? '${where}Examples stay in English' : '${where}AI feedback now · lessons coming soon';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          const SizedBox(height: 4),
          const Text(
            'Language',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          Text('App language', style: TextStyle(fontSize: 13, color: t.textMuted)),
          const OptionTile(
            label: 'English',
            selected: true,
            subtitle: 'The app is in English, like the IELTS test itself.',
          ),
          const SizedBox(height: 2),
          Text(
            'Explanations & AI feedback',
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
          Text(
            'Lessons, answer explanations and AI band reports use this language. Passages, questions and your answers are always in English.',
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textSoft),
          ),
          for (final l in kContentLangs)
            OptionTile(
              label: FeedbackLanguage.label(l.code),
              subtitle: _subtitle(l),
              selected: _code == l.code,
              onTap: () => _pick(l.code),
            ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Done',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
