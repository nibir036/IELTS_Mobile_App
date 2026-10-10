import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/speak_button.dart';
import 'widgets.dart';

/// H1 · Resources Hub.
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

    return AppScreen(
      gap: 12,
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
            const Expanded(
              child: Text(
                'Resources',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.8,
                ),
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
        _FeaturedCard(
          data: featured,
          onTap: () => context.push(
            Routes.articleTips,
            args: <String, dynamic>{'articleId': featured.s('articleId')},
          ),
        ),
        // 2 × 2 tiles
        for (var r = 0; r < tiles.length; r += 2)
          Row(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HubTile(
                  data: tiles[r],
                  onTap: () => _go(tiles[r].s('target')),
                ),
              ),
              Expanded(
                child: r + 1 < tiles.length
                    ? _HubTile(
                        data: tiles[r + 1],
                        onTap: () => _go(tiles[r + 1].s('target')),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        // Recently added
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Recently added',
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ),
              if (recent.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.divider)),
                  ),
                  child: Text(
                    'Nothing new in $selected yet',
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ),
              for (final r in recent)
                ListRow(
                  divider: true,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  onTap: () => context.push(Routes.articleTips),
                  leading: LetterBadge(
                    r.s('letter'),
                    size: 42,
                    radius: 14,
                    fontSize: 14,
                    fg: t.text,
                  ),
                  title: r.s('title'),
                  subtitle: '${r.s('skill')} · ${r.i('minutes')} min',
                ),
            ],
          ),
        ),
        // Word of the day
        HeroCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Word of the day'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                        color: t.peach,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${wod.s('word')} '),
                          TextSpan(
                            text: wod.s('partOfSpeechShort'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: t.heroMuted,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                        color: t.heroText,
                      ),
                    ),
                    Text(
                      wod.s('definition'),
                      style: TextStyle(
                        fontSize: 12,
                        color: t.heroMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SpeakButton(
                text: wod.s('word'),
                size: 40,
                radius: 14,
                iconSize: 18,
                bg: t.heroChip,
                fg: t.heroText,
              ),
              IconBox(
                icon: wordSaved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                tooltip: 'Save word',
                size: 40,
                radius: 14,
                iconSize: 18,
                bg: wordSaved ? t.peach : t.heroChip,
                fg: wordSaved ? kOnPeach : t.heroText,
                onTap: () {
                  final now = toggleSavedWord(wod.s('id'));
                  context.toast(now ? 'Saved to your vault' : 'Removed from your vault');
                },
              ),
            ],
          ),
        ),
        // Word lists
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Word lists & references',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${lists.length} sections',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            for (final item in lists)
              _ListLink(
                data: item,
                onTap: () => _go(item.s('target')),
              ),
          ],
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return HeroCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      onTap: onTap,
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text(
                  data.s('tag').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: t.peach,
                  ),
                ),
                Text(
                  data.s('title'),
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: t.heroText,
                  ),
                ),
                Text(
                  data.s('readTime'),
                  style: TextStyle(fontSize: 12.5, color: t.heroMuted),
                ),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: kPeachGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                        'Read guide',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kOnPeach,
                        ),
                      ),
                      ),
                      Icon(AppIcons.forward, size: 16, color: kOnPeach),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Nexi(NexiPose.reading, height: 110),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tone = data.s('tone');
    final accent = tone != 'plain';
    final bg = accent ? (t.isNight ? t.primary : toneBg(t, tone)) : t.surface;
    final fg = accent ? ResPalette.ink : t.text;
    final muted = accent ? const Color(0xFF625C66) : t.textMuted;
    final boxBg = accent
        ? (t.isNight ? ResPalette.creamChip : ResPalette.white)
        : t.surfaceAlt2;
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      color: bg,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(resIcon(data.s('icon')), size: 20, color: fg),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.s('title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
              Text(
                data.s('subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListLink extends StatelessWidget {
  const _ListLink({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final tone = data.s('tone');
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      onTap: onTap,
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: toneBg(t, tone),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              resIcon(data.s('icon')),
              size: 20,
              color: toneFg(t, tone),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.s('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  data.s('subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
              ],
            ),
          ),
          Text(
            resLiveCount(data.s('id')) ?? data.s('count'),
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}
