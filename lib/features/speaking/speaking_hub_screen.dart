import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// D1 · Speaking Hub & Mode Selection.
class SpeakingHubScreen extends StatefulWidget {
  const SpeakingHubScreen({super.key});

  @override
  State<SpeakingHubScreen> createState() => _SpeakingHubScreenState();
}

class _SpeakingHubScreenState extends State<SpeakingHubScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hub = speakingData().m('hub');
    final filters = hub.l('filters');
    final part1 = hub.m('part1');
    final modes = hub.l('modes');
    final mock = hub.m('mockInterview');
    final store = context.store;
    final questionCount = part1QuestionCount();
    final topics = Content.part1Topics;
    final nextTopic = nextPart1Topic();
    final chipTopics = <Map<String, dynamic>>[
      if (nextTopic.isNotEmpty) nextTopic,
      for (final tp in topics)
        if (tp.s('id') != nextTopic.s('id')) tp,
    ].take(3).toList();
    final cardCount = Content.cueCards.length;
    final part3Count = part3QuestionCount();
    final allCount = modes.length + 2;
    final answered = store.kv<num>(kPart1AnsweredKey)?.toInt() ?? 0;
    final completion = questionCount <= 0
        ? 0.0
        : (answered / questionCount).clamp(0.0, 1.0).toDouble();
    final filterId = _filter < filters.length ? filters[_filter].s('id') : 'all';

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      gap: 16,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              onTap: () => context.back(),
            ),
            const Spacer(),
            IconBox(
              icon: AppIcons.waveform,
              tooltip: 'My recordings',
              onTap: () => context.push(Routes.myRecordings),
            ),
          ],
        ),
        const Text(
          'Speaking\nPractice',
          style: TextStyle(
            fontSize: 50,
            fontWeight: FontWeight.w300,
            height: 1,
            letterSpacing: -1.5,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (var i = 0; i < filters.length; i++)
                _HubFilterChip(
                  label: filters[i].s('label'),
                  count: filters[i].s('id') == 'all' ? '$allCount' : null,
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
            ],
          ),
        ),
        if (filterId == 'due') const _DueToday(),
        if (filterId == 'saved') const _SavedCards(),
        if (filterId != 'due' && filterId != 'saved') HeroCard(
          radius: 34,
          padding: const EdgeInsets.all(20),
          // Part 1 topic list (like the cue card vault); the topic chips
          // below still start a session straight away.
          onTap: () => context.push(Routes.cueCardVault, args: {'part': 1}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        '${(completion * 100).round()}% completed',
                        style: TextStyle(fontSize: 13, color: t.heroMuted),
                      ),
                      SizedBox(
                        width: 96,
                        child: ProgressBar(
                          value: completion,
                          height: 3,
                          onHero: true,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(AppIcons.northEast, size: 22, color: t.heroText),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      part1.s('title'),
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.02,
                        letterSpacing: -0.5,
                        color: t.heroText,
                      ),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13, height: 1.5, color: t.heroMuted),
                      children: [
                        TextSpan(
                          text: part1.s('duration'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                          ),
                        ),
                        const TextSpan(text: ' min\n'),
                        TextSpan(
                          text: '$questionCount',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: t.heroText,
                          ),
                        ),
                        const TextSpan(text: ' questions'),
                      ],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final topic in chipTopics)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push(
                        Routes.speakingPart13,
                        args: {'part': 1, 'topicId': topic.s('id')},
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: t.heroChip,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          topic.s('topic'),
                          style: TextStyle(fontSize: 12, color: t.heroText),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (filterId != 'due' && filterId != 'saved') Row(
          spacing: 10,
          children: [
            for (final mode in modes)
              Expanded(
                child: _ModeCard(
                  mode: mode,
                  subtitle: mode.s('id') == 'part2'
                      ? '${mode.s('label')} · $cardCount'
                      : '${mode.s('label')} · $part3Count',
                  onTap: () {
                    if (mode.s('id') == 'part2') {
                      context.push(Routes.cueCardVault);
                    } else {
                      context.push(Routes.cueCardVault, args: {'part': 3});
                    }
                  },
                ),
              ),
          ],
        ),
        if (filterId != 'due' && filterId != 'saved') AppCard(
          radius: 28,
          color: t.raised,
          borderColor: t.border,
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          onTap: () => context.push(Routes.speakingPart13, args: {'mock': true}),
          child: Row(
            spacing: 14,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mock.s('title'), style: const TextStyle(fontSize: 18)),
                    Text(
                      mock.s('subtitle'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                child: Icon(AppIcons.play, size: 24, color: t.onPrimary),
              ),
            ],
          ),
        ),
        if (filterId != 'due' && filterId != 'saved' && hasSpeakingBank) AppCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          onTap: () => context.push(Routes.speakingLibrary),
          child: Row(
            spacing: 14,
            children: [
              IconCircle(AppIcons.library, size: 44, iconSize: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sample answers & vocabulary', style: TextStyle(fontSize: 18)),
                    Text(
                      'Model answers for every question · '
                      '${Content.speakingBankMeta.m('counts').i('headwords')} words to learn',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
            ],
          ),
        ),
        if (filterId != 'due' && filterId != 'saved' && Demo.guide('speaking').l('chapters').isNotEmpty) ...[
          _GuideRow(
            icon: AppIcons.school,
            title: 'Speaking Guide',
            subtitle: '${Demo.guide('speaking').l('chapters').length} chapters from the nextED Speaking book · English / বাংলা',
            onTap: () => context.push(Routes.speakingGuide),
          ),
          _GuideRow(
            icon: AppIcons.bulb,
            title: 'Speaking Tips',
            subtitle: 'Fluency, Part 1, Part 2 and Part 3 strategies',
            onTap: () => context.push(Routes.articleTips, args: <String, dynamic>{'series': 'speaking'}),
          ),
        ],
      ],
    );
  }
}

/// "Due today" filter: speaking tasks scheduled for today.
class _DueToday extends StatelessWidget {
  const _DueToday();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final due = store
        .tasksOn(DateTime.now())
        .where((task) => task.s('skill') == Skill.speaking && !task.b('done'))
        .toList();
    if (due.isEmpty) {
      return EmptyState(
        icon: AppIcons.calendar,
        title: 'Nothing due today',
        message: 'Speaking tasks you schedule for today show up here.',
        actionLabel: 'Start Part 1',
        onAction: () => context.push(Routes.speakingPart13, args: {'part': 1}),
      );
    }
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < due.length; i++)
            ListRow(
              divider: i > 0,
              title: due[i].s('title'),
              subtitle: [
                if (due[i].s('time').isNotEmpty) due[i].s('time'),
                if (due[i].i('durationMin') > 0) '${due[i].i('durationMin')} min',
              ].join(' · '),
              leading: IconCircle(AppIcons.mic, size: 40, iconSize: 16),
              trailing: Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
              onTap: () {
                final target = due[i].s('target');
                context.push(
                  target.isNotEmpty ? target : Routes.speakingPart13,
                  args: target.isNotEmpty ? null : {'part': 1},
                );
              },
            ),
        ],
      ),
    );
  }
}

/// "Saved" filter: bookmarked cue cards.
class _SavedCards extends StatelessWidget {
  const _SavedCards();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final saved = context.store.kvSet(kSavedCardsKey);
    final cards = allCueCards().where((c) => saved.contains(c.s('id'))).toList();
    if (cards.isEmpty) {
      return EmptyState(
        icon: AppIcons.bookmark,
        title: 'No saved cue cards',
        message: 'Tap the bookmark on a cue card to keep it here.',
        actionLabel: 'Browse cue cards',
        onAction: () => context.push(Routes.cueCardVault),
      );
    }
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++)
            ListRow(
              divider: i > 0,
              title: cards[i].s('title'),
              subtitle: 'Part 2 · ${cards[i].s('category')}',
              leading: IconCircle(AppIcons.bookmarkFilled, size: 40, iconSize: 16),
              trailing: Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
              onTap: () => context.push(Routes.cueCard, args: {'cardId': cards[i].s('id')}),
            ),
        ],
      ),
    );
  }
}

class _HubFilterChip extends StatelessWidget {
  const _HubFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: 48,
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(
          side: selected
              ? BorderSide(color: t.text, width: 1.5)
              : BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: count != null ? 16 : 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(label, style: TextStyle(fontSize: 15, color: t.text)),
                if (count != null)
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.isNight ? t.border : t.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count!,
                      style: TextStyle(fontSize: 12, color: t.text),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.subtitle, required this.onTap});

  final Map<String, dynamic> mode;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isCue = mode.s('id') == 'part2';
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 22,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconCircle(
                isCue ? AppIcons.article : AppIcons.chat,
                size: 44,
                iconSize: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mode.s('duration'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode.s('title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Guide / tips row under the speaking tools.
class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      onTap: onTap,
      child: Row(
        spacing: 14,
        children: [
          IconCircle(icon, size: 44, iconSize: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18)),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
        ],
      ),
    );
  }
}
