import 'dart:math';

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

/// One row of the vault: a cue card (Part 2) or a Part 1 / Part 3 topic.
class _VaultEntry {
  const _VaultEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.meta,
    required this.search,
    this.sampleArgs,
  });

  final String id;
  final String title;
  final String category;

  /// "Card 3 · 6 Part 3 Qs" / "Topic 2 · 5 questions".
  final String meta;
  final String search;

  /// Args for the sample-answer screen; null = no sample.
  final Map<String, dynamic>? sampleArgs;
}

/// D8 · Speaking practice vault, one look for every part. Args
/// `{'part': 1 | 2 | 3}` (default 2):
///   Part 1 → the bank's Part 1 topics → D2 {'part': 1, 'topicId'}
///   Part 2 → cue cards                → D3 {'cardId'}
///   Part 3 → the bank's discussion topics → D2 {'part': 3, 'part3TopicId'}
/// Bookmarks live in kv ([kSavedCardsKey] for cue cards, `speaking.savedPart1`
/// / `speaking.savedPart3` for topics); "You: 6.5" badges come from the
/// student's attempts of that part. The shuffle button opens a random entry
/// of the current filter, preferring ones not tried yet.
class CueCardVaultScreen extends StatefulWidget {
  const CueCardVaultScreen({super.key});

  @override
  State<CueCardVaultScreen> createState() => _CueCardVaultScreenState();
}

class _CueCardVaultScreenState extends State<CueCardVaultScreen> {
  late final Map<String, dynamic> _vault = speakingData().m('vault');
  int? _part;
  int _category = 0;
  String _query = '';
  final Random _random = Random();

  String get _savedKey => switch (_part) {
        1 => 'speaking.savedPart1',
        3 => 'speaking.savedPart3',
        _ => kSavedCardsKey,
      };

  List<_VaultEntry> _entries(int part) {
    switch (part) {
      case 1:
        final topics = Content.part1Topics;
        return <_VaultEntry>[
          for (var i = 0; i < topics.length; i++)
            _VaultEntry(
              id: topics[i].s('id'),
              title: topics[i].s('topic'),
              category: topics[i].s('categoryLabel'),
              meta: 'Topic ${i + 1} · ${topics[i].ls('questions').length} questions',
              search: topics[i].ls('questions').join(' '),
              sampleArgs: topics[i].l('samples').isEmpty
                  ? null
                  : <String, dynamic>{'part': 1, 'topicId': topics[i].s('id')},
            ),
        ];
      case 3:
        final topics = Content.part3Topics;
        return <_VaultEntry>[
          for (var i = 0; i < topics.length; i++)
            _VaultEntry(
              id: topics[i].s('id'),
              title: topics[i].s('topic'),
              category: topics[i].s('categoryLabel'),
              meta: 'Topic ${i + 1} · ${topics[i].l('questions').length} questions',
              search: '${topics[i].s('description')} '
                  '${topics[i].l('questions').map((q) => q.s('q')).join(' ')}',
              sampleArgs: topics[i].l('questions').any((q) => q.s('answer').isNotEmpty)
                  ? <String, dynamic>{'part': 3, 'topicId': topics[i].s('id')}
                  : null,
            ),
        ];
      default:
        return <_VaultEntry>[
          for (final c in allCueCards())
            _VaultEntry(
              id: c.s('id'),
              title: c.s('title'),
              category: c.s('category'),
              meta: 'Card ${c.i('number')} · ${c.ls('part3').length} Part 3 Qs',
              search: '${c.s('category')} ${c.ls('bullets').join(' ')}',
              sampleArgs: c.m('sample').isEmpty ? null : <String, dynamic>{'part': 2, 'cardId': c.s('id')},
            ),
        ];
    }
  }

  /// Filter chips after "All · Saved": the bank's categories for the part.
  List<String> _categories(int part, List<_VaultEntry> all) {
    if (part == 2) return cueTopics();
    final out = <String>[];
    for (final e in all) {
      if (e.category.isNotEmpty && !out.contains(e.category)) out.add(e.category);
    }
    return out;
  }

  void _open(int part, String id) {
    switch (part) {
      case 1:
        context.push(Routes.speakingPart13, args: <String, dynamic>{'part': 1, 'topicId': id});
      case 3:
        context.push(Routes.speakingPart13, args: <String, dynamic>{'part': 3, 'part3TopicId': id});
      default:
        context.push(Routes.cueCard, args: <String, dynamic>{'cardId': id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final part = _part ??= () {
      final a = context.routeArgs['part'];
      return a is int && a >= 1 && a <= 3 ? a : 2;
    }();
    final all = _entries(part);
    // All · Saved · the bank's categories.
    final categories = <String>['All', 'Saved', ..._categories(part, all)];
    final selectedCategory =
        _category < categories.length ? categories[_category] : 'All';
    final store = context.store;
    final saved = store.kvSet(_savedKey);
    final youBands = <String, double?>{};
    final practised = <String>{};
    for (final a in store.attemptsFor(skill: Skill.speaking, kind: 'part$part')) {
      if (practised.add(a.refId)) youBands[a.refId] = a.band;
    }
    final q = _query.trim().toLowerCase();
    final cards = all.where((c) {
      final bool catOk;
      if (selectedCategory == 'All') {
        catOk = true;
      } else if (selectedCategory == 'Saved') {
        catOk = saved.contains(c.id);
      } else {
        catOk = c.category == selectedCategory;
      }
      final qOk = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q) ||
          c.search.toLowerCase().contains(q);
      return catOk && qOk;
    }).toList();
    // "Up next": the first entry not practised yet, shown first as the
    // featured card when browsing everything.
    String featuredId = '';
    if (selectedCategory == 'All' && q.isEmpty) {
      for (final c in all) {
        if (!practised.contains(c.id)) {
          featuredId = c.id;
          break;
        }
      }
      if (featuredId.isNotEmpty) {
        final i = cards.indexWhere((c) => c.id == featuredId);
        if (i > 0) cards.insert(0, cards.removeAt(i));
      }
    }
    final done = all.where((c) => practised.contains(c.id)).length;
    final title = switch (part) {
      1 => 'Part 1 topics',
      3 => 'Part 3 topics',
      _ => 'Cue card vault',
    };
    final subtitle = switch (part) {
      1 => '${all.length} interview topics with sample answers · $done practised',
      3 => '${all.length} discussion topics with sample answers · $done practised',
      _ => _vault
          .s('subtitle')
          .replaceAll('{n}', '${all.length}')
          .replaceAll('{practised}', '$done'),
    };
    final noun = part == 2 ? 'cue card' : 'topic';

    void openRandom() {
      final fresh = cards.where((c) => !practised.contains(c.id)).toList();
      final pool = fresh.isNotEmpty ? fresh : cards;
      if (pool.isEmpty) {
        context.toast('No ${noun}s match this filter');
        return;
      }
      _open(part, pool[_random.nextInt(pool.length)].id);
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      gap: 14,
      children: [
        Row(
          spacing: 8,
          children: [
            IconBox(
              icon: AppIcons.back,
              iconSize: 20,
              bg: t.surface,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: part == 2
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _vault.s('setLabel'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            IconBox(
              icon: AppIcons.shuffle,
              iconSize: 20,
              bg: t.surface,
              tooltip: 'Random $noun',
              onTap: openRandom,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            spacing: 10,
            children: [
              Icon(AppIcons.search, size: 18, color: t.textMuted),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  cursorColor: t.primary,
                  style: TextStyle(fontSize: 15, color: t.text),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: part == 2 ? 'Search a topic' : 'Search a topic or question',
                    hintStyle: TextStyle(fontSize: 15, color: t.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (var i = 0; i < categories.length; i++)
                FlatChip(
                  label: categories[i],
                  selected: i == _category,
                  bg: i == _category ? t.primary : t.surface,
                  fg: i == _category ? t.onPrimary : t.text,
                  onTap: () => setState(() => _category = i),
                ),
            ],
          ),
        ),
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              selectedCategory == 'Saved' && q.isEmpty
                  ? 'No saved ${noun}s yet. Tap the bookmark on a card to keep it here.'
                  : 'No ${noun}s match your search.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ),
        Column(
          spacing: 10,
          children: [
            for (final c in cards)
              _VaultCard(
                entry: c,
                featured: c.id == featuredId,
                saved: saved.contains(c.id),
                practised: practised.contains(c.id),
                youBand: youBands[c.id],
                onToggleSave: () => Store.I.kvSetToggle(_savedKey, c.id),
                onTap: () => _open(part, c.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _VaultCard extends StatelessWidget {
  const _VaultCard({
    required this.entry,
    required this.featured,
    required this.saved,
    required this.practised,
    required this.youBand,
    required this.onToggleSave,
    required this.onTap,
  });

  final _VaultEntry entry;
  final bool featured;
  final bool saved;
  final bool practised;
  final double? youBand;
  final VoidCallback onToggleSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final category = entry.category;
    final tag = featured
        ? (category.isEmpty ? 'Up next' : '$category · Up next')
        : category;
    final you = youBand;
    final youText = you != null
        ? 'You: ${bandText(you)}'
        : (practised ? 'Practised' : 'Not tried');

    final Color titleColor = featured ? t.heroText : t.text;
    final Color metaColor = featured ? t.heroMuted : t.textMuted;
    final Color tagBg = featured
        ? (t.isNight ? const Color(0x14151515) : const Color(0xCCFFFFFF))
        : cueCategoryTint(category);
    final Color tagFg = featured
        ? (t.isNight ? t.heroMuted : t.heroText)
        : (t.isNight ? const Color(0xFF625C66) : t.text);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tagFg),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleSave,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                    size: 20,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          Text(
            entry.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.25,
              color: titleColor,
            ),
          ),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(
                entry.meta,
                style: TextStyle(fontSize: 12, color: metaColor),
              ),
              Text(youText, style: TextStyle(fontSize: 12, color: metaColor)),
              if (entry.sampleArgs != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(Routes.speakingSamples, args: entry.sampleArgs),
                  child: Text(
                    'Sample answer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (featured) {
      return HeroCard(
        radius: 24,
        padding: EdgeInsets.zero,
        onTap: onTap,
        gradient: t.isNight
            ? null
            : const LinearGradient(
                begin: Alignment(-0.5, -0.87),
                end: Alignment(0.5, 0.87),
                colors: [Color(0xFFF7C6D6), Color(0xFFFCEBF1)],
              ),
        child: content,
      );
    }
    return AppCard(
      radius: 24,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: content,
    );
  }
}
