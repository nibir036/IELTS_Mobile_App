import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/speak_button.dart';
import '../reading/widgets.dart' show boldSpans;

// Speaking question bank helpers (assets/content/speaking_bank.json):
// sample answers carry vocabulary marks as `[[word]]`; each mark's lower-case
// text is a key of `Content.speakingVocab`.

final RegExp _mark = RegExp(r'\[\[(.+?)\]\]');

/// True when the speaking question bank is loaded.
bool get hasSpeakingBank => Content.speakingBankCards.isNotEmpty;

/// Sample answer text without the vocabulary marks.
String plainSample(String marked) =>
    marked.replaceAllMapped(_mark, (m) => m.group(1) ?? '');

/// Vocabulary keys marked in [marked], in order (no repeats).
List<String> sampleVocabKeys(String marked) {
  final out = <String>[];
  for (final m in _mark.allMatches(marked)) {
    final k = (m.group(1) ?? '').toLowerCase();
    if (k.isNotEmpty && !out.contains(k)) out.add(k);
  }
  return out;
}

/// Word count of a sample answer.
int sampleWordCount(String marked) =>
    RegExp(r"[A-Za-z0-9'’-]+").allMatches(plainSample(marked)).length;

/// Vocabulary entry for a key (empty map if unknown).
Map<String, dynamic> speakingWord(String key) =>
    Content.speakingVocab.m(key.toLowerCase());

/// Note shown above sample answers (one speaker's persona).
String get speakingSampleNote {
  final n = Content.speakingBankMeta.s('sampleNote');
  return n.isNotEmpty
      ? n
      : 'Use sample answers for ideas, structure and vocabulary, then answer with your own experience.';
}

/// "Band 7.5–8" style label for a part (1, 2 or 3).
String speakingSampleBand(int part) =>
    Content.speakingBankMeta.m('bands').s('part$part');

/// Tag chip colours of the cue card categories (bank and demo names).
Color cueCategoryTint(String category) {
  switch (category) {
    case 'Places':
      return const Color(0xFFDCE6FF);
    case 'Objects':
    case 'Media':
      return const Color(0xFFFFC9B8);
    case 'Events':
      return const Color(0xFFE9EFFF);
    case 'Experiences':
      return const Color(0xFFDCE6FF);
    case 'Activities & Ideas':
      return const Color(0xFFDDF0E4);
    // Part 1 / Part 3 bank categories (topic vaults).
    case 'Lifestyle & Habits':
    case 'Education & Work':
      return const Color(0xFFDCE6FF);
    case 'Interests & Hobbies':
    case 'Technology & Media':
      return const Color(0xFFFFC9B8);
    case 'Daily Life & Opinions':
    case 'Environment & Cities':
      return const Color(0xFFDDF0E4);
    case 'Entertainment & Culture':
    case 'Culture & Lifestyle':
      return const Color(0xFFE9EFFF);
    default:
      return const Color(0xFFFFE2D8);
  }
}

/// A pronunciation-practice word (pronunciation screen shape) built from a
/// vocabulary entry. Phrases have no syllables; their words are shown instead.
Map<String, dynamic> pronunciationWordFor(String key) {
  final e = speakingWord(key);
  if (e.isEmpty) return <String, dynamic>{};
  final head = e.s('headword');
  final syl = e.l('syllables');
  final stressed = syl.where((x) => x['stress'] == true).map((x) => x.s('text')).join();
  return <String, dynamic>{
    'id': 'pv_${key.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
    'word': head,
    'ipa': e.s('ipa'),
    'pos': e.s('pos'),
    'syllables': syl.isNotEmpty
        ? <Map<String, dynamic>>[
            for (final x in syl)
              <String, dynamic>{
                'text': x['stress'] == true ? x.s('text').toUpperCase() : x.s('text'),
                'state': x['stress'] == true ? 'stress' : 'normal',
              },
          ]
        : <Map<String, dynamic>>[
            for (final w in head.split(' '))
              <String, dynamic>{'text': w, 'state': 'normal'},
          ],
    'feedback': '',
    'errorBars': <int>[],
    'match': 0.7,
    'retryMatch': 0.82,
    'tip': stressed.isNotEmpty
        ? 'Put the stress on “${stressed.toUpperCase()}”. ${e.s('meaning')}'
        : e.s('meaning'),
    'retryTip': 'Clearer. Now say it inside a full sentence.',
  };
}

Map<String, List<String>>? _pronTopics;

/// Pronunciation-trainer topics: the bank's question categories ("Education &
/// Work", "Places" …) → the vocabulary marked in their sample answers.
/// Largest topics first.
Map<String, List<String>> pronunciationTopics() {
  final cached = _pronTopics;
  if (cached != null && cached.isNotEmpty) return cached;
  final groups = <String, Set<String>>{};
  void collect(Object? o, Set<String> into) {
    if (o is String) {
      for (final k in sampleVocabKeys(o)) {
        if (speakingWord(k).isNotEmpty) into.add(k);
      }
    } else if (o is Map) {
      for (final v in o.values) {
        collect(v, into);
      }
    } else if (o is List) {
      for (final v in o) {
        collect(v, into);
      }
    }
  }

  for (final list in <List<Map<String, dynamic>>>[
    Content.speakingBankPart1,
    Content.speakingBankCards,
    Content.part3Topics,
  ]) {
    for (final topic in list) {
      final label = topic.s('categoryLabel');
      if (label.isEmpty) continue;
      collect(topic, groups.putIfAbsent(label, () => <String>{}));
    }
  }
  final entries = groups.entries.where((e) => e.value.length >= 10).toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  return _pronTopics = <String, List<String>>{
    for (final e in entries) e.key: (e.value.toList()..sort()),
  };
}

/// The day's pronunciation set: [count] bank entries (mostly single words,
/// a couple of phrases), the same all day and different tomorrow. With
/// [topic] they come from that topic's vocabulary only.
List<String> dailyPronunciationKeys(DateTime day, {String? topic, int count = 10}) {
  final pool = topic == null
      ? (Content.speakingVocab.keys.toList()..sort())
      : List<String>.of(pronunciationTopics()[topic] ?? const <String>[]);
  if (pool.isEmpty) return <String>[];
  var seed = day.year * 10000 + day.month * 100 + day.day;
  for (final c in (topic ?? '').codeUnits) {
    seed = (seed * 31 + c) & 0x7fffffff;
  }
  final rng = math.Random(seed);
  pool.shuffle(rng);
  final words = pool.where((k) => !k.contains(' ')).toList();
  final phrases = pool.where((k) => k.contains(' ')).toList();
  final nPhrases = math.min(2, phrases.length);
  return <String>[
    ...words.take(count - nPhrases),
    ...phrases.take(count - math.min(count - nPhrases, words.length)),
  ];
}

/// Opens pronunciation practice for vocabulary [keys] (max 12 words).
void practiseSpeakingWords(BuildContext context, List<String> keys, {String? title}) {
  final list = keys.where((k) => speakingWord(k).isNotEmpty).take(12).toList();
  if (list.isEmpty) return;
  context.push(Routes.pronunciation, args: {
    'vocab': list,
    if (title != null) 'title': title,
  });
}

/// Paragraph of sample-answer text; `[[marks]]` are underlined and open the
/// word sheet when tapped.
class MarkedText extends StatefulWidget {
  const MarkedText(
    this.text, {
    super.key,
    this.fontSize = 15,
    this.height = 1.55,
    this.color,
    this.markColor,
  });

  final String text;
  final double fontSize;
  final double height;
  final Color? color;
  final Color? markColor;

  @override
  State<MarkedText> createState() => _MarkedTextState();
}

class _MarkedTextState extends State<MarkedText> {
  final List<TapGestureRecognizer> _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _taps) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    for (final r in _taps) {
      r.dispose();
    }
    _taps.clear();
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _mark.allMatches(widget.text)) {
      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      final word = m.group(1) ?? '';
      final known = speakingWord(word).isNotEmpty;
      TapGestureRecognizer? tap;
      if (known) {
        tap = TapGestureRecognizer()..onTap = () => showSpeakingWord(context, word);
        _taps.add(tap);
      }
      spans.add(
        TextSpan(
          text: word,
          recognizer: tap,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: widget.markColor ?? (widget.color ?? t.text),
            decoration: TextDecoration.underline,
            decorationColor: t.iconAccent,
            decorationThickness: 2,
          ),
        ),
      );
      last = m.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: widget.fontSize,
          height: widget.height,
          color: widget.color ?? t.text,
        ),
        children: spans,
      ),
    );
  }
}

/// Bottom sheet with a vocabulary entry: headword, IPA, stress, meaning,
/// example, synonyms and a link to pronunciation practice.
Future<void> showSpeakingWord(BuildContext context, String key) {
  final e = speakingWord(key);
  if (e.isEmpty) return Future<void>.value();
  return showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) {
        final t = ctx.tk;
        final syl = e.l('syllables');
        final syn = e.ls('synonyms');
        // The Resources vocabulary bank has 880 of these words with two more
        // examples, a band and a register.
        final rb = ResBank.vocabFor(e.s('headword'));
        final band = rb == null ? '' : ResBank.bandLabel(rb.d('band'));
        final more = rb == null ? <String>[] : rb.ls('examples');
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const SizedBox(height: 4),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Text(
                    e.s('headword'),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, letterSpacing: -0.4),
                  ),
                ),
                Tag(e.s('level'), tone: TagTone.accent),
                if (band.isNotEmpty) Tag(band, tone: TagTone.outline),
                SpeakButton(text: e.s('headword'), size: 36, radius: 12, iconSize: 18, bg: t.surfaceAlt2),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(e.s('ipa'), style: TextStyle(fontSize: 16, color: t.textMuted)),
                Text(e.s('pos'), style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: t.textMuted)),
              ],
            ),
            if (syl.length > 1)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final x in syl)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: x['stress'] == true ? t.primary : t.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        x['stress'] == true ? x.s('text').toUpperCase() : x.s('text'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: x['stress'] == true ? FontWeight.w600 : FontWeight.w400,
                          color: x['stress'] == true ? t.onPrimary : t.text,
                        ),
                      ),
                    ),
                ],
              ),
            Text(e.s('meaning'), style: const TextStyle(fontSize: 16, height: 1.45)),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Icon(AppIcons.quote, size: 16, color: t.textMuted),
                  Expanded(
                    child: Text(
                      e.s('example'),
                      style: TextStyle(fontSize: 14, height: 1.45, color: t.text),
                    ),
                  ),
                ],
              ),
            ),
            if (more.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    'More examples${rb!.s('register').isEmpty ? '' : ' · ${rb.s('register')}'}',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                  for (final x in more)
                    Text.rich(
                      TextSpan(children: boldSpans('• $x')),
                      style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textSoft),
                    ),
                ],
              ),
            if (syn.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Similar:', style: TextStyle(fontSize: 13, color: t.textMuted)),
                  for (final s in syn) Tag(s, tone: TagTone.outline),
                ],
              ),
            const SizedBox(height: 2),
            SoftButton(
              label: 'Practise saying it',
              leading: AppIcons.mic,
              expand: true,
              onTap: () {
                Navigator.of(ctx).pop();
                practiseSpeakingWords(context, <String>[key], title: e.s('headword'));
              },
            ),
          ],
            ),
          ),
        );
      },
    ),
  );
}

/// Sheet with the sample answer to one question (Part 1 / Part 3 sessions).
Future<void> showSampleAnswerSheet(
  BuildContext context, {
  required String question,
  required String answer,
  String? label,
}) {
  return showAppSheet<void>(
    context,
    Builder(
      builder: (ctx) {
        final t = ctx.tk;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                const SizedBox(height: 4),
                Text(
                  label ?? 'Sample answer',
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
                Text(question, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500, height: 1.3)),
                MarkedText(answer, fontSize: 16),
                Text(
                  'Tap an underlined word for its meaning. $speakingSampleNote',
                  style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// One question + sample answer card (samples screen).
class SampleQuestionCard extends StatelessWidget {
  const SampleQuestionCard({
    super.key,
    required this.number,
    required this.question,
    required this.answer,
    this.tag,
  });

  final int number;
  final String question;
  final String answer;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              LetterBadge('$number', size: 28, radius: 9, fontSize: 12),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.35),
                ),
              ),
            ],
          ),
          if (tag != null && tag!.isNotEmpty)
            Align(alignment: Alignment.centerLeft, child: Tag(tag!, tone: TagTone.soft, height: 24)),
          MarkedText(answer),
          Text(
            '${sampleWordCount(answer)} words',
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Route args of the sample answers for a speaking attempt (kind part1 /
/// part2 / part3 + refId), or null when the item is not in the bank.
Map<String, dynamic>? sampleArgsFor(String kind, String refId) {
  final card = Content.speakingBankCards.where((c) => c.s('id') == refId).firstOrNull;
  if (kind == 'part1') {
    final tp = Content.speakingBankPart1.where((c) => c.s('id') == refId).firstOrNull;
    return tp == null ? null : <String, dynamic>{'part': 1, 'topicId': refId};
  }
  if (kind == 'part2') {
    return card == null ? null : <String, dynamic>{'part': 2, 'cardId': refId};
  }
  if (kind == 'part3') {
    if (Content.part3Topic(refId).isNotEmpty) return <String, dynamic>{'part': 3, 'topicId': refId};
    final links = card?.ls('part3Topics') ?? const <String>[];
    return links.isEmpty ? null : <String, dynamic>{'part': 3, 'topicId': links.first};
  }
  return null;
}
