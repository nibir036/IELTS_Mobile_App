import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/entitlements.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../home/upgrade_sheet.dart';
import '../home/widgets.dart';
import 'plan_api.dart';

/// Opens the exact lesson / set / test of a plan task.
void openPlanTask(BuildContext context, Map<String, dynamic> task) {
  final target = task.s('target');
  final args = task['args'];
  openStoredRoute(
    context,
    target.isNotEmpty ? target : skillLandingRoute(task.s('skill')),
    target.isNotEmpty && args is Map ? args.cast<String, dynamic>() : null,
  );
}

/// One plan task: tick circle (done / not done), title, minutes and why,
/// tap to start.
class PlanTaskRow extends StatelessWidget {
  const PlanTaskRow({super.key, required this.task, this.showReason = true, this.enabled = true});

  final Map<String, dynamic> task;
  final bool showReason;

  /// False for preview rows (nothing to open or tick yet).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final done = task.b('done');
    final checkpoint = task.s('kind') == 'checkpoint' || task.b('checkpoint');
    final (bg, fg) = done
        ? (t.peach, kOnPeach)
        : (t.isNight ? const Color(0xFF2A2F45) : t.surfaceAlt, checkpoint ? t.alert : t.textMuted);
    final min = task.i('durationMin');
    final reason = task.s('reason');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? () => openPlanTask(context, task) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Tooltip(
                message: done ? 'Mark as not done' : 'Mark as done',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? () => Store.I.toggleTask(task.s('id')) : null,
                  child: TintCircle(
                    icon: done ? AppIcons.check : (checkpoint ? AppIcons.flag : homeIconFor(task.s('skill'))),
                    bg: bg,
                    fg: fg,
                    size: 40,
                    iconSize: 19,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      task.s('title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: done ? t.textMuted : t.text,
                        decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationColor: t.textMuted,
                      ),
                    ),
                    Text(
                      <String>[
                        if (checkpoint) 'Checkpoint',
                        if (min > 0) '$min min',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: checkpoint ? t.alert : t.textMuted),
                    ),
                    if (showReason && reason.isNotEmpty)
                      Text(
                        reason,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.3, color: t.textMuted),
                      ),
                  ],
                ),
              ),
              if (enabled && !done)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(AppIcons.forward, size: 18, color: t.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home: today's plan tasks, or an invitation to make a plan.
class TodayPlanCard extends StatelessWidget {
  const TodayPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    if (!store.hasPlan) {
      if (!PlanApi.available) return const SizedBox.shrink();
      return AppCard(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        onTap: () => context.push(Routes.studyPlanSetup),
        child: Row(
          spacing: 14,
          children: [
            TintCircle(icon: AppIcons.calendar, bg: t.peach, fg: kOnPeach, size: 46),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  const Text('Get your study plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    'Daily tasks matched to your level, time and exam date.',
                    style: TextStyle(fontSize: 12.5, height: 1.3, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.forward, size: 20, color: t.textMuted),
          ],
        ),
      );
    }
    final today = PlanApi.tasksOn(store, DateTime.now());
    final done = today.where((x) => x.b('done')).length;
    final open = today.where((x) => !x.b('done')).toList();
    final shown = (open.isEmpty ? today : open).take(3).toList();
    return AppCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's plan", style: TextStyle(fontSize: 13, color: t.textMuted)),
                    Text(
                      today.isEmpty
                          ? 'Rest day'
                          : (open.isEmpty ? 'All done for today' : '$done of ${today.length} done'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SoftButton(label: 'See plan', onTap: () => context.push(Routes.studyPlan)),
            ],
          ),
          if (today.isNotEmpty) ProgressBar(value: done / today.length),
          if (today.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'No tasks today. Rest well, or get ahead from your plan.',
                style: TextStyle(fontSize: 12.5, color: t.textMuted),
              ),
            ),
          for (final task in shown) PlanTaskRow(task: task, showReason: false),
        ],
      ),
    );
  }
}

/// The week's note from the plan (AI-written when available).
class WeekNoteCard extends StatelessWidget {
  const WeekNoteCard({super.key, required this.note});

  final Map<String, dynamic> note;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final focus = note.ls('focus');
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(AppIcons.sparkle, size: 18, color: t.peach),
              Expanded(
                child: Text(
                  note.s('title'),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.25),
                ),
              ),
            ],
          ),
          Text(note.s('body'), style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textMuted)),
          if (focus.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final f in focus) Tag(_cap(f), tone: TagTone.accent, height: 24, fontSize: 11.5)],
            ),
        ],
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// "Get a sharper plan": opens the quick check; [onDone] runs after it saved.
class QuickCheckOffer extends StatelessWidget {
  const QuickCheckOffer({super.key, required this.modules, this.onDone});

  final List<String> modules;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    // The quick check is part of Pro.
    final pro = Entitlements.I.planExtras;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: () async {
        if (!pro) {
          await showUpgradeSheet(context, feature: 'quick_check');
          return;
        }
        final Object? ok = await context.push(Routes.studyPlanQuickCheck, args: <String, dynamic>{'modules': modules});
        if (ok == true) onDone?.call();
      },
      child: Row(
        spacing: 14,
        children: [
          TintCircle(icon: AppIcons.quiz, bg: t.peach, fg: kOnPeach, size: 44),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(pro ? 'Get a sharper plan' : 'Get a sharper plan · Pro',
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                Text(
                  pro
                      ? 'A quick check (about 8 minutes) so your plan starts from what you can do.'
                      : 'A quick check that starts your plan from what you can do. Part of Pro.',
                  style: TextStyle(fontSize: 12.5, height: 1.3, color: t.textMuted),
                ),
              ],
            ),
          ),
          Icon(pro ? AppIcons.forward : AppIcons.lock, size: 20, color: t.textMuted),
        ],
      ),
    );
  }
}

/// True once the student has done the quick check (synced state).
bool quickCheckDone(Store store) => store.kv<Map>('plan.quickcheck') != null;


/// Free plan notice on the study plan: the first 3 study days, then Pro.
class FreePlanBanner extends StatelessWidget {
  const FreePlanBanner({super.key, required this.access});

  /// The plan's `access` ({plan, freeUntil, ended}).
  final Map<String, dynamic> access;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final ended = access.b('ended');
    final until = DateTime.tryParse(access.s('freeUntil'));
    final untilLabel = until == null ? '' : Store.weekdayDate(until);
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 12,
            children: [
              TintCircle(icon: AppIcons.medal, bg: t.peach, fg: kOnPeach, size: 40),
              Expanded(
                child: Text(
                  ended ? 'Your 3-day free plan is over' : 'Free plan: your first 3 study days',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Text(
            ended
                ? 'Upgrade to Pro for a plan that runs all the way to your exam and adapts to your results every week.'
                : 'Tasks are planned up to ${untilLabel.isEmpty ? 'your third study day' : untilLabel}. '
                    'Pro plans run to your exam and adapt every week.',
            style: TextStyle(fontSize: 13, height: 1.4, color: t.textSoft),
          ),
          PrimaryButton(
            label: 'See Pro plans',
            height: 46,
            onTap: () => context.push(Routes.plans),
          ),
        ],
      ),
    );
  }
}
