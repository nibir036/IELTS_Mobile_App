import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../resources/widgets.dart' show resLiveCount;
import '../shell/main_shell.dart';
import '../writing/writing_data.dart' show WritingContent;
import 'widgets.dart';

/// B3 · Course & Module Hub (tab 1 of the shell).
class ModuleHubScreen extends StatefulWidget {
  const ModuleHubScreen({super.key});

  @override
  State<ModuleHubScreen> createState() => _ModuleHubScreenState();
}

class _ModuleHubScreenState extends State<ModuleHubScreen> {
  final Set<String> _expanded = <String>{};
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final acc = store.current;
    final modules = Demo.section('home').l('modules');
    final days = acc?.daysToExam;
    final headerSub = <String>[
      acc?.targetBand == null ? 'No target set' : 'Target ${Store.formatBand(acc!.targetBand)}',
      if (days != null && days >= 0) '$days days left',
    ].join(' · ');
    if (!_seeded) {
      _seeded = true;
      for (final m in modules) {
        if (m.b('expanded')) _expanded.add(m.s('id'));
      }
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, MainShell.navClearance),
      gap: 16,
      children: [
        Row(
          spacing: 12,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4B8CB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                acc?.initials ?? '?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: kInk,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    acc?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    headerSub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.search,
              tooltip: 'Search',
              bg: t.isNight ? t.surface : t.raised,
              onTap: () => context.push(Routes.search),
            ),
            IconBox(
              icon: AppIcons.bell,
              tooltip: 'Notifications',
              bg: t.isNight ? t.surface : t.raised,
              dot: store.unreadNotifications > 0,
              onTap: () => context.push(Routes.notifications),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            const Text(
              'Choose a task',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              'Pick a module to continue today',
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            for (final m in modules)
              if (m.l('items').isEmpty)
                _ModuleRow(module: m)
              else
                _ModuleGroup(
                  module: m,
                  expanded: _expanded.contains(m.s('id')),
                  onToggle: () => setState(() {
                    final id = m.s('id');
                    if (_expanded.contains(id)) {
                      _expanded.remove(id);
                    } else {
                      _expanded.add(id);
                    }
                  }),
                ),
          ],
        ),
      ],
    );
  }
}

/// Finished attempts that count toward a module / item (`skill` + optional
/// `kind` in home.json).
int _doneCount(Store store, Map<String, dynamic> m) {
  final skill = m.s('skill');
  if (skill.isEmpty) return 0;
  final kind = m.s('kind');
  return practiceAttempts(store, skill: skill, kind: kind.isEmpty ? null : kind)
      .length;
}

/// Live size of a content list named by `countOf` in home.json, so the
/// module rows show what is actually in the app (bank or demo).
int? contentCount(String key) => switch (key) {
      'readingTests' => Content.readingTests.length,
      'readingPracticeTests' => Content.readingPracticeTests.length,
      'readingBankSets' => Content.readingBankPassages.length,
      'listeningTests' => Content.listeningTests.length,
      'writingTests' => Content.writingTests.length,
      'speakingTests' => Content.speakingTests.length,
      'listeningSets' => Content.listeningSets.length,
      'writingTask1' => Content.writingTask1.length,
      'writingTask2' => Content.writingTask2.length,
      'part1Topics' => Content.part1Topics.length,
      'cueCards' => Content.cueCards.length,
      'part3Topics' => Content.part3Topics.length,
      // Every sample answer (Band 6 / 7 / 8 per bank question, or the one model answer).
      'writingSamples' => WritingContent.withModelAnswer().fold<int>(
          0, (n, p) => n + (p.l('samples').isNotEmpty ? p.l('samples').length : 1)),
      'writingTemplates' => WritingContent.all.m('templates').l('items').length,
      'writingIdeas' => WritingContent.ideaPrompts().length,
      _ => null,
    };

/// An item's goal: the live content count (`countOf`) when it tracks progress
/// (`skill`), else the fixed `goal`.
int _goal(Map<String, dynamic> it) {
  final n = contentCount(it.s('countOf'));
  if (n != null && n > 0 && it.s('skill').isNotEmpty) return n;
  return it.i('goal');
}

/// Module meta: "Done" when the goal is reached, otherwise a percentage.
String _moduleMeta(Store store, Map<String, dynamic> m) {
  final goal = m.i('goal');
  if (goal <= 0) return m.s('meta');
  final n = _doneCount(store, m);
  if (n >= goal) return 'Done';
  return '${(n * 100 / goal).round()}%';
}

/// Item meta: "n / goal" when the item tracks progress; "N unit" from a live
/// count (`countOf` + `unit`); else its static meta.
String _itemMeta(Store store, Map<String, dynamic> it) {
  final goal = _goal(it);
  if (goal > 0) return '${_doneCount(store, it)} / $goal';
  final n = contentCount(it.s('countOf'));
  if (n != null && n > 0 && it.s('unit').isNotEmpty) return '$n ${it.s('unit')}';
  final live = it.s('liveCount').isEmpty ? null : resLiveCount(it.s('liveCount'));
  return live ?? it.s('meta');
}

Color _tint(String key) => key == 'pink' ? kPastelPink : kPastelLavender;

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module});

  final Map<String, dynamic> module;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final meta = _moduleMeta(context.store, module);
    return AppCard(
      radius: 20,
      height: 60,
      padding: const EdgeInsets.fromLTRB(10, 0, 16, 0),
      onTap: () => openHomeTarget(context, module.s('target')),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _tint(module.s('tint')),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              meta == 'Done' ? AppIcons.check : homeIconFor(module.s('icon')),
              size: 20,
              color: kInk,
            ),
          ),
          Expanded(
            child: Text(
              module.s('title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            meta,
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          Icon(AppIcons.chevronDown, size: 20, color: t.text),
        ],
      ),
    );
  }
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({
    required this.module,
    required this.expanded,
    required this.onToggle,
  });

  final Map<String, dynamic> module;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final items = module.l('items');
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          width: 2,
                          color: t.isNight
                              ? const Color(0xFF5C2A20)
                              : const Color(0xFFB9BAF2),
                        ),
                      ),
                      child: Text(
                        _moduleMeta(context.store, module),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        module.s('title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(AppIcons.chevronDown, size: 20, color: t.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Opens / closes smoothly instead of jumping.
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: t.isNight ? t.surfaceAlt2 : null,
                        gradient: t.isNight
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFF0EEFC), Color(0xFFFBEAF0)],
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 4,
                        children: [
                          for (final it in items) _SubItem(item: it),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubItem extends StatelessWidget {
  const _SubItem({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final hi = item.b('highlight');
    final fg = hi ? t.onPrimary : t.text;
    final meta = _itemMeta(context.store, item);
    return Material(
      color: hi ? t.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(hi ? 16 : 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final args = item.m('args');
          final route = homeRouteFor(item.s('target'));
          if (args.isNotEmpty && route.isNotEmpty) {
            context.push(route, args: args);
          } else {
            openHomeTarget(context, item.s('target'));
          }
        },
        child: SizedBox(
          height: hi ? 50 : 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hi
                        ? t.onPrimary
                        : (t.isNight ? t.surfaceAlt : t.surface),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    homeIconFor(item.s('icon')),
                    size: 17,
                    color: hi
                        ? t.primary
                        : (t.isNight ? t.textMuted : t.text),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.s('title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hi ? FontWeight.w500 : FontWeight.w400,
                      color: fg,
                    ),
                  ),
                ),
                if (hi)
                  Icon(AppIcons.forward, size: 18, color: fg)
                else if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
