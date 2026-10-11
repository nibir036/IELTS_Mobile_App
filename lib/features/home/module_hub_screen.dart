import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/loop_video.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/user_avatar.dart';
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

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, MainShell.navClearance),
      gap: 16,
      children: [
        Row(
          spacing: 12,
          children: [
            // Same photo and action as the Profile tab in the nav bar.
            Semantics(
              button: true,
              label: 'Profile and settings',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => MainShell.of(context)?.select(4),
                child: const UserAvatar(size: 44),
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
        // Module cards, two per row: a short video (or Nexi until it is
        // ready); a tap opens the module's page with everything in it.
        // The first module (Resources) takes a whole row; the rest two per row.
        if (modules.isNotEmpty) _ModuleCard(module: modules.first, wide: true),
        for (var r = 1; r < modules.length; r += 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(child: _ModuleCard(module: modules[r])),
              Expanded(
                child: r + 1 < modules.length ? _ModuleCard(module: modules[r + 1]) : const SizedBox.shrink(),
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

/// Module meta: "Done" when the goal is reached, otherwise a percentage.
String _moduleMeta(Store store, Map<String, dynamic> m) {
  final goal = m.i('goal');
  if (goal <= 0) return m.s('meta');
  final n = _doneCount(store, m);
  if (n >= goal) return 'Done';
  return '${(n * 100 / goal).round()}%';
}

/// The page a module card opens (`hub` in home.json, else its `target`).
String moduleHubTarget(Map<String, dynamic> m) => m.s('hub').isNotEmpty ? m.s('hub') : m.s('target');

/// Nexi pose for a module card without its video yet.
NexiPose _poseFor(Map<String, dynamic> m) => switch (m.s('skill')) {
      'writing' => NexiPose.writing,
      'speaking' => NexiPose.speaking,
      'listening' => NexiPose.listening,
      'reading' => NexiPose.reading,
      _ => NexiPose.grad,
    };

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, this.wide = false});

  final Map<String, dynamic> module;

  /// Full-width card (landscape video).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final meta = _moduleMeta(context.store, module);
    final video = module.s('video');
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: t.isNight
              ? <Color>[t.surfaceAlt2, t.surfaceAlt]
              : const <Color>[Color(0xFFEEF3FF), Color(0xFFFFF1EB)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Nexi(_poseFor(module), height: 130),
        ),
      ),
    );
    void open() => openHomeTarget(context, moduleHubTarget(module));
    final card = AppCard(
        radius: 24,
        padding: EdgeInsets.zero,
        onTap: open,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: wide ? 1.38 : 0.9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.isEmpty) placeholder else LoopVideo(asset: video, placeholder: placeholder),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          meta,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.text),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
                child: Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: Text(
                        module.s('title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, height: 1.2, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(AppIcons.forward, size: 18, color: t.textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    return Semantics(
      button: true,
      label: '${module.s('title')}, $meta',
      child: Stack(
        children: [
          card,
          // The whole card is the tap target. On the web the video is a
          // browser element that would swallow taps, so a pointer
          // interceptor sits on top of it.
          Positioned.fill(
            child: PointerInterceptor(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(onTap: open),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
