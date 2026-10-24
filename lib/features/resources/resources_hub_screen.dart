import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/promo_cards.dart';
import '../../app/widgets/speak_button.dart';
import '../../app/widgets/vivid.dart';
import 'widgets.dart';

/// H1 · Resources Hub, in the same live style as Home: a banner carousel
/// (featured guide + any custom cards), colourful tiles with Nexi, swipeable
/// "recently added" cards, the word of the day and the word lists.
class ResourcesHubScreen extends StatefulWidget {
  const ResourcesHubScreen({super.key});

  @override
  State<ResourcesHubScreen> createState() => _ResourcesHubScreenState();
}

class _ResourcesHubScreenState extends State<ResourcesHubScreen> {
  int _filter = 0;

  Map<String, dynamic> get _hub => Demo.section('resources').m('hub');

  void _go(String target) {
    final route = resRoute(target);
    if (route == null) {
      context.toast('Not available in this version');
    } else {
      context.push(route);
    }
  }

  /// Colour and Nexi pose for a hub tile (by id; others take turns).
  static const List<VividTone> _tileTones = <VividTone>[Vivid.mock, Vivid.writing, Vivid.vocab, Vivid.listening];

  static NexiPose? _tilePose(String id) => switch (id) {
        // Four different Nexis (thumbs/point/wave are the same picture, and
        // reading is already on the featured banner above).
        'band_descriptors' => NexiPose.listening,
        'sample_answers' => NexiPose.writing,
        'tips' => NexiPose.point,
        'exam_day' => NexiPose.grad,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hub = _hub;
    final filters = hub.ls('filters');
    final featured = hub.m('featured');
    final tiles = hub.l('tiles');
    final wod = ResBank.wordOfTheDay(hub.m('wordOfTheDay'));
    final lists = hub.l('lists');
    final store = context.store;
    final wordSaved = isWordSaved(store, wod.s('id'));
    final selected =
        _filter < filters.length ? filters[_filter] : (filters.isEmpty ? 'All' : filters.first);
    final recent = hub
        .l('recent')
        .where((r) => _filter == 0 || r.s('skill') == selected)
        .toList();

    final banners = PromoCards.forPlace(context, PromoPlace.resources, <PromoItem>[
      if (featured.s('title').isNotEmpty)
        PromoItem(
          id: 'featured',
          title: featured.s('title'),
          subtitle: featured.s('readTime'),
          cta: 'Read guide',
          badge: featured.s('tag').toUpperCase(),
          tone: Vivid.forKey(featured.s('category').toLowerCase()),
          pose: NexiPose.reading,
          onTap: () => context.push(
            Routes.articleTips,
            args: <String, dynamic>{'articleId': featured.s('articleId')},
          ),
        ),
    ]);

    return AppScreen(
      gap: 16,
      children: [
        // Title + search
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Resources',
                    maxLines: 1,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.7),
                  ),
                  Text(
                    'Guides, word lists and tips – all in one place',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.search,
              tooltip: 'Search resources',
              onTap: () => context.push(Routes.search),
            ),
          ],
        ),
        ChipRow(
          labels: filters,
          selected: _filter,
          onChanged: (i) => setState(() => _filter = i),
        ),
        PromoCarousel(items: banners),

        const SectionHeader('Explore', emoji: '🧭', subtitle: 'Everything you need to study smarter'),
        for (var r = 0; r < tiles.length; r += 2)
          Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _tile(tiles, r)),
              Expanded(child: r + 1 < tiles.length ? _tile(tiles, r + 1) : const SizedBox.shrink()),
            ],
          ),

        SectionHeader(
          'Recently added',
          subtitle: _filter == 0 ? 'Fresh short reads' : 'Fresh in $selected',
        ),
        if (recent.isEmpty)
          AppCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Text(
                    'Nothing new in $selected yet – Nexi is writing it.',
                    style: TextStyle(fontSize: 13.5, height: 1.4, color: t.textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => PopIn(
                delayMs: 70 * i.clamp(0, 6),
                from: 0.85,
                child: _RecentCard(data: recent[i], onTap: () => context.push(Routes.articleTips)),
              ),
            ),
          ),

        _WordCard(word: wod, saved: wordSaved),

        SectionHeader(
          'Word lists & references',
          subtitle: '${lists.length} sections',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            for (var i = 0; i < lists.length; i++)
              _ListLink(
                data: lists[i],
                floatDelay: (i % 4) * 0.25,
                onTap: () => _go(lists[i].s('target')),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tile(List<Map<String, dynamic>> tiles, int i) {
    final d = tiles[i];
    return CategoryTile(
      title: d.s('title'),
      subtitle: d.s('subtitle'),
      tone: _tileTones[i % _tileTones.length],
      pose: _tilePose(d.s('id')),
      icon: resIcon(d.s('icon')),
      floatDelay: i * 0.21,
      onTap: () => _go(d.s('target')),
    );
  }
}

/// A "recently added" read: skill colour, title, minutes.
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final skill = data.s('skill');
    final v = Vivid.forKey(skill.toLowerCase());
    return AppCard(
      width: 170,
      radius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VividIcon(_skillIcon(skill), tone: v, size: 34, iconSize: 18, radius: 11),
              const Spacer(),
              Text(
                '${data.i('minutes')} min',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.s('title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, height: 1.2, fontWeight: FontWeight.w700, color: t.text),
          ),
          const SizedBox(height: 4),
          Text(
            skill,
            maxLines: 1,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ),
    );
  }

  static IconData _skillIcon(String skill) => switch (skill.toLowerCase()) {
        'listening' => AppIcons.listening,
        'reading' => AppIcons.reading,
        'writing' => AppIcons.writing,
        'speaking' => AppIcons.speaking,
        _ => AppIcons.article,
      };
}

/// Word of the day in the vocabulary colours, with listen and save.
class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.saved});

  final Map<String, dynamic> word;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final w = word;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  'Word of the day',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ),
              SpeakButton(
                text: w.s('word'),
                size: 38,
                radius: 13,
                iconSize: 18,
                bg: t.surfaceAlt,
              ),
              WiggleOnChange(
                trigger: saved,
                child: IconBox(
                  icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                  tooltip: 'Save word',
                  size: 38,
                  radius: 13,
                  iconSize: 18,
                  bg: t.surfaceAlt,
                  fg: t.iconAccent,
                  onTap: () {
                    final now = toggleSavedWord(w.s('id'));
                    context.toast(now ? 'Saved to your vault' : 'Removed from your vault');
                  },
                ),
              ),
            ],
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${w.s('word')} ',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: t.text),
                ),
                TextSpan(
                  text: w.s('partOfSpeechShort'),
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: t.textMuted),
                ),
              ],
            ),
          ),
          Text(
            w.s('definition'),
            style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textSoft),
          ),
        ],
      ),
    );
  }
}

/// One word list: a floating gradient icon, title, short line and a count.
class _ListLink extends StatelessWidget {
  const _ListLink({required this.data, required this.onTap, this.floatDelay = 0});

  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final double floatDelay;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final icon = resIcon(data.s('icon'));
    final v = Vivid.forIcon(icon);
    final count = resLiveCount(data.s('id')) ?? data.s('count');
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Row(
        spacing: 12,
        children: [
          VividIcon(icon, tone: v, size: 44, iconSize: 22, radius: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  data.s('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  data.s('subtitle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.3, color: t.textMuted),
                ),
                if (count.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      count,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSoft),
                    ),
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
