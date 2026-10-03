import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/speak_button.dart';
import '../reading/widgets.dart' show boldSpans;
import 'widgets.dart';

/// Bottom sheet with a Resources-bank word: headword, pronunciation, IPA,
/// part of speech and band, definition, examples, synonyms / word family,
/// register; save it and mark it Known / Learning.
Future<void> showResWord(BuildContext context, String id) {
  final w = ResBank.word(id);
  if (w == null) return Future<void>.value();
  return showAppSheet<void>(context, _ResWordSheet(word: w));
}

class _ResWordSheet extends StatelessWidget {
  const _ResWordSheet({required this.word});

  final Map<String, dynamic> word;

  static const Map<String, String> _kinds = <String, String>{
    'vocab': 'IELTS vocabulary',
    'phrasal': 'Phrasal verb',
    'idiom': 'Idiom',
    'linking': 'Linking word',
    'academic': 'Academic word',
    'topic': 'Topic vocabulary',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final id = word.s('id');
    final saved = isWordSaved(store, id);
    final status = wordMasteryOf(store, id);
    final band = ResBank.bandLabel(word.d('band'));
    final syn = word.ls('synonyms');
    final fam = word.ls('family');
    final meta = <String>[
      if (word.s('ipa').isNotEmpty) word.s('ipa'),
      if (word.s('partOfSpeech').isNotEmpty) word.s('partOfSpeech'),
    ].join(' · ');
    final body = TextStyle(fontSize: 15, height: 1.45, color: t.text);

    Widget chips(String label, List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: t.textMuted)),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final x in items) Tag(x, height: 28, fontSize: 13)]),
          ],
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        const SizedBox(height: 4),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(
                word.s('word'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: -0.4),
              ),
            ),
            SpeakButton(text: word.s('word'), size: 40, radius: 14, bg: t.surfaceAlt2),
            IconBox(
              icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
              tooltip: saved ? 'Remove from saved words' : 'Save to my words',
              size: 40,
              radius: 14,
              iconSize: 18,
              bg: saved ? t.primary : t.surfaceAlt2,
              fg: saved ? t.onPrimary : t.text,
              onTap: () {
                final now = toggleSavedWord(id);
                context.toast(now ? 'Saved to your words' : 'Removed from saved words');
              },
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 14, color: t.textMuted)),
            Tag(_kinds[word.s('kind')] ?? '', height: 24),
            if (band.isNotEmpty) Tag(band, tone: TagTone.accent, height: 24),
            if (word.s('register').isNotEmpty) Tag(word.s('register'), tone: TagTone.outline, height: 24),
            if (word.s('group').isNotEmpty) Tag(word.s('group'), tone: TagTone.outline, height: 24),
          ],
        ),
        Text(word.s('definition'), style: body.copyWith(fontSize: 16)),
        TrMeaning(id, fontSize: 15),
        for (final ex in word.ls('examples').where((e) => e.isNotEmpty))
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(AppIcons.quote, size: 16, color: t.textMuted),
                Expanded(child: Text.rich(TextSpan(children: boldSpans(ex)), style: body.copyWith(fontSize: 14))),
              ],
            ),
          ),
        if (syn.isNotEmpty) chips('Synonyms', syn),
        if (fam.isNotEmpty) chips('Word family', fam),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: ResMiniPill(
                label: 'Known',
                height: 44,
                bold: status == 'mastered',
                bg: status == 'mastered' ? t.primary : t.surfaceAlt2,
                fg: status == 'mastered' ? t.onPrimary : t.text,
                onTap: () => setWordMastery(id, status == 'mastered' ? 'new' : 'mastered'),
              ),
            ),
            Expanded(
              child: ResMiniPill(
                label: 'Learning',
                height: 44,
                bold: status == 'learning',
                bg: status == 'learning' ? ResPalette.pink : t.surfaceAlt2,
                fg: status == 'learning' ? ResPalette.ink : t.text,
                onTap: () => setWordMastery(id, status == 'learning' ? 'new' : 'learning'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
        ),
      ),
    );
  }
}
