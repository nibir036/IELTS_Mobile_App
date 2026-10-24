import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/loop_video.dart';
import '../../app/widgets/mascot.dart';
import '../../app/widgets/motion.dart';
import '../../app/widgets/user_avatar.dart';
import '../../app/widgets/vivid.dart';
import '../shell/main_shell.dart';
import '../writing/writing_data.dart' show WritingContent;
import 'widgets.dart';
import '../../app/widgets/app_tour.dart';

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
              icon: AppIcons.bell,
              tooltip: 'Notifications',
              size: 46,
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
            const Text.rich(
              TextSpan(children: <InlineSpan>[
                TextSpan(text: 'Choose a task'),
              ]),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
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
          TourTarget(
            id: r == 1 ? 'practice.modules' : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(child: _ModuleCard(module: modules[r])),
                Expanded(
                  child: r + 1 < modules.length ? _ModuleCard(module: modules[r + 1]) : const SizedBox.shrink(),
                ),
              ],
            ),
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

/// Module card: the module's looping video ("live photo") with a pastel
/// footer in the module's colour, a gradient icon that pops over the edge,
/// a pulsing "live" badge and a progress line. The whole card squishes on press.
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, this.wide = false});

  final Map<String, dynamic> module;

  /// Full-width card (landscape video).
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final meta = _moduleMeta(store, module);
    final video = module.s('video');
    final skill = module.s('skill');
    final tone = Vivid.forKey(skill);
    final goal = module.i('goal');
    final progress = goal <= 0 ? null : (_doneCount(store, module) / goal).clamp(0.0, 1.0);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[tone.tile(t), tone.light.withValues(alpha: t.isNight ? 0.35 : 0.55)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FloatY(child: Nexi(_poseFor(module), height: 130)),
        ),
      ),
    );
    void open() => openHomeTarget(context, moduleHubTarget(module));
    const r = 26.0;
    // Plain footer under the video: the moving picture is the colour.
    final footer = t.isNight ? t.surface : Colors.white;
    final card = Container(
      decoration: BoxDecoration(
        color: footer,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: t.isNight ? t.border : const Color(0xFFF0E8E5)),
        boxShadow: t.isNight
            ? null
            : <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: wide ? 1.6 : 0.95,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.isEmpty) placeholder else LoopVideo(asset: video, placeholder: placeholder),
                  // Fade the video into the footer colour.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 46,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[footer.withValues(alpha: 0), footer],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PulseDot(color: meta == 'Done' ? const Color(0xFF4FE0A8) : Colors.white, size: 6),
                          Text(
                            meta,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      VividIcon(homeIconFor(module.s('icon')), tone: tone, size: wide ? 42 : 36, radius: 12),
                      Expanded(
                        child: Text(
                          module.s('title'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: wide ? 18 : 15,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: t.text,
                          ),
                        ),
                      ),
                      if (wide)
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
                          child: Icon(AppIcons.forward, size: 18, color: t.onPrimary),
                        ),
                    ],
                  ),
                  if (progress != null)
                    ProgressBar(
                      value: progress,
                      height: 4,
                      fill: tone.ink(t),
                    ),
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
      child: Pressable(
        scale: 0.96,
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
                  borderRadius: BorderRadius.circular(r),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: open, splashColor: tone.light.withValues(alpha: 0.25)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
