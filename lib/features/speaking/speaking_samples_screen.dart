import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// D12 · Speaking sample answers for one item of the question bank.
/// Args: `{'part': 1, 'topicId'}` (Part 1 topic, 5 questions),
/// `{'part': 2, 'cardId'}` (cue card monologue + rounding-off questions +
/// linked Part 3 topics) or `{'part': 3, 'topicId'}` (8 discussion questions).
/// Underlined words open the vocabulary sheet. Arrows step through the part.
class SpeakingSamplesScreen extends StatefulWidget {
  const SpeakingSamplesScreen({super.key});

  @override
  State<SpeakingSamplesScreen> createState() => _SpeakingSamplesScreenState();
}

class _SpeakingSamplesScreenState extends State<SpeakingSamplesScreen> {
  int _part = 1;
  String _id = '';
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final a = context.routeArgs;
    final p = a['part'];
    _part = p is num && p >= 1 && p <= 3 ? p.toInt() : 1;
    final id = (a['topicId'] ?? a['cardId'] ?? '').toString();
    final list = _items();
    _id = list.any((x) => x.s('id') == id) ? id : (list.isEmpty ? '' : list.first.s('id'));
  }

  List<Map<String, dynamic>> _items() {
    switch (_part) {
      case 2:
        return Content.speakingBankCards;
      case 3:
        return Content.part3Topics;
      default:
        return Content.speakingBankPart1;
    }
  }

  void _step(int by) {
    final list = _items();
    final i = list.indexWhere((x) => x.s('id') == _id);
    final j = i + by;
    if (j < 0 || j >= list.length) return;
    setState(() => _id = list[j].s('id'));
  }

  List<String> _vocabKeys(Map<String, dynamic> item) {
    final keys = <String>[];
    void add(String s) {
      for (final k in sampleVocabKeys(s)) {
        if (!keys.contains(k)) keys.add(k);
      }
    }

    if (_part == 1) {
      for (final x in item.l('samples')) {
        add(x.s('answer'));
      }
    } else if (_part == 2) {
      add(item.m('sample').s('answer'));
      for (final x in item.l('followUps')) {
        add(x.s('answer'));
      }
    } else {
      for (final x in item.l('questions')) {
        add(x.s('answer'));
      }
    }
    return keys;
  }

  void _practise(Map<String, dynamic> item) {
    switch (_part) {
      case 2:
        context.push(Routes.cueCard, args: {'cardId': item.s('id')});
      case 3:
        context.push(Routes.speakingPart13, args: {'part': 3, 'part3TopicId': item.s('id')});
      default:
        context.push(Routes.speakingPart13, args: {'part': 1, 'topicId': item.s('id')});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final list = _items();
    final pos = list.indexWhere((x) => x.s('id') == _id);
    final item = pos < 0 ? <String, dynamic>{} : list[pos];
    if (item.isEmpty) {
      return AppScreen(
        children: [
          const TopBar(title: 'Sample answers'),
          EmptyState(
            icon: AppIcons.library,
            title: 'No sample answers yet',
            message: 'The speaking question bank is not installed in this build.',
            actionLabel: 'Back to Speaking',
            onAction: () => context.back(),
          ),
        ],
      );
    }
    final title = _part == 2 ? item.s('title') : item.s('topic');
    final keys = _vocabKeys(item);
    final band = speakingSampleBand(_part);
    final subtitle = <String>[
      'Part $_part',
      item.s('categoryLabel'),
      if (band.isNotEmpty) band,
    ].join(' · ');

    final body = <Widget>[];
    if (_part == 1) {
      final s = item.l('samples');
      for (var i = 0; i < s.length; i++) {
        body.add(SampleQuestionCard(number: i + 1, question: s[i].s('q'), answer: s[i].s('answer')));
      }
    } else if (_part == 3) {
      final s = item.l('questions');
      for (var i = 0; i < s.length; i++) {
        body.add(
          SampleQuestionCard(
            number: i + 1,
            question: s[i].s('q'),
            answer: s[i].s('answer'),
            tag: s[i].s('tagLabel'),
          ),
        );
      }
    } else {
      body.addAll(_cardBody(context, item));
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 12,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      footer: PrimaryButton(
        label: _part == 2 ? 'Practise this cue card' : 'Practise this topic',
        leading: AppIcons.mic,
        height: 56,
        radius: 18,
        fontSize: 15,
        onTap: () => _practise(item),
      ),
      children: [
        Row(
          spacing: 8,
          children: [
            IconBox(icon: AppIcons.back, iconSize: 18, tooltip: 'Back', onTap: () => context.back()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sample answers', style: TextStyle(fontSize: 12, color: t.textMuted)),
                  Text(
                    '${pos + 1} of ${list.length}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.chevronLeft,
              iconSize: 20,
              tooltip: 'Previous',
              onTap: pos > 0 ? () => _step(-1) : null,
            ),
            IconBox(
              icon: AppIcons.chevronRight,
              iconSize: 20,
              tooltip: 'Next',
              onTap: pos < list.length - 1 ? () => _step(1) : null,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500, height: 1.15, letterSpacing: -0.4),
            ),
            Text(subtitle, style: TextStyle(fontSize: 13, color: t.textMuted)),
            if (_part == 3 && item.s('description').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.s('description'), style: TextStyle(fontSize: 14, height: 1.4, color: t.textSoft)),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Icon(AppIcons.info, size: 16, color: t.textMuted),
              Expanded(
                child: Text(
                  'Tap an underlined word for its meaning and pronunciation. $speakingSampleNote',
                  style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
        ...body,
        if (keys.isNotEmpty) ...[
          const SizedBox(height: 4),
          SectionTitle(
            'Key vocabulary',
            subtitle: '${keys.length} words and phrases',
            action: 'Practise saying them',
            onAction: () => practiseSpeakingWords(context, keys, title: title),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in keys)
                ChipPill(
                  shrink: true,
                  label: speakingWord(k).s('headword').isNotEmpty ? speakingWord(k).s('headword') : k,
                  onTap: () => showSpeakingWord(context, k),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _cardBody(BuildContext context, Map<String, dynamic> card) {
    final t = context.tk;
    final sample = card.m('sample');
    final secs = sample.i('seconds');
    final links = card.ls('part3Topics');
    return <Widget>[
      HeroCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text('You should say:', style: TextStyle(fontSize: 13, color: t.heroMuted)),
            for (final b in card.ls('bullets'))
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 8), child: Dot(size: 5, color: t.heroText)),
                  Expanded(child: Text(b, style: TextStyle(fontSize: 15, color: t.heroText))),
                ],
              ),
          ],
        ),
      ),
      // Cards from sir's Speaking guide: his 1-minute note (4 + 1 keywords).
      if (card.ls('notes').isNotEmpty)
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              const Text('1-minute notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Text('What fits on the note paper in one minute', style: TextStyle(fontSize: 12, color: t.textMuted)),
              for (final n in card.ls('notes'))
                Text(n, style: TextStyle(fontSize: 13, height: 1.45, color: t.textSoft)),
            ],
          ),
        ),
      AppCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                const Text('Sample talk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Text(
                  '${sampleWordCount(sample.s('answer'))} words · about ${secs ~/ 60} min ${secs % 60} s',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
            MarkedText(sample.s('answer')),
            if (card.ls('phrases').isNotEmpty)
              Text(
                'Useful phrases: ${card.ls('phrases').join(' · ')}',
                style: TextStyle(fontSize: 13, height: 1.45, color: t.textSoft),
              ),
          ],
        ),
      ),
      if (card.l('followUps').isNotEmpty) ...[
        const SectionTitle('Rounding-off questions', subtitle: 'The examiner may ask one or two after your talk'),
        for (var i = 0; i < card.l('followUps').length; i++)
          SampleQuestionCard(
            number: i + 1,
            question: card.l('followUps')[i].s('q'),
            answer: card.l('followUps')[i].s('answer'),
          ),
      ],
      if (links.isNotEmpty) ...[
        const SectionTitle('Part 3 discussion', subtitle: 'Topics the examiner may move on to'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in links)
              if (Content.part3Topic(id).isNotEmpty)
                ChipPill(
                  shrink: true,
                  label: Content.part3Topic(id).s('topic'),
                  icon: AppIcons.chat,
                  onTap: () => context.push(Routes.speakingSamples, args: {'part': 3, 'topicId': id}),
                ),
          ],
        ),
      ],
    ];
  }
}
