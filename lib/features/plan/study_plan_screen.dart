import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'plan_api.dart';
import 'plan_preview_screen.dart' show planDayLabel;
import 'plan_setup_screen.dart';
import 'plan_widgets.dart';

/// My study plan: where the student is (week, phase, progress), the next
/// two weeks of tasks, and pause / re-plan / change / end.
class StudyPlanScreen extends StatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  bool _loading = true;
  String? _error;
  bool _busy = false;
  bool _refetched = false;

  @override
  void initState() {
    super.initState();
    if (PlanApi.available) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = PlanApi.current.value == null;
      _error = null;
    });
    try {
      final p = await PlanApi.load();
      // The AI writes the week's note a few seconds after the plan changes;
      // fetch once more to show it.
      final note = p?['weekNote'];
      if (!_refetched && note is Map && note['by'] == 'rules') {
        _refetched = true;
        Future<void>.delayed(const Duration(seconds: 12), () {
          if (mounted) PlanApi.load().catchError((Object _) => null);
        });
      }
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) context.toast(done);
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actions(Map<String, dynamic> plan) async {
    final paused = plan.s('status') == 'paused';
    final choice = await showAppSheet<String>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Plan options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            if (paused)
              ListRow(
                leading: _optIcon(ctx, AppIcons.play),
                title: 'Resume now',
                subtitle: 'Pick up where you stopped',
                onTap: () => Navigator.pop(ctx, 'resume'),
              )
            else
              ListRow(
                leading: _optIcon(ctx, AppIcons.pause),
                title: 'Take a break',
                subtitle: 'Pause for a few days; the plan moves later',
                onTap: () => Navigator.pop(ctx, 'pause'),
              ),
            ListRow(
              leading: _optIcon(ctx, AppIcons.refresh),
              title: 'Re-plan from my results',
              subtitle: 'Rebuild the coming days from your latest scores',
              onTap: () => Navigator.pop(ctx, 'rebalance'),
            ),
            ListRow(
              leading: _optIcon(ctx, AppIcons.calendar),
              title: 'Change target or schedule',
              subtitle: 'Band, exam date, days, minutes, time',
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListRow(
              leading: _optIcon(ctx, AppIcons.delete),
              title: 'End this plan',
              subtitle: 'Finished tasks stay in your history',
              onTap: () => Navigator.pop(ctx, 'end'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'resume':
        await _run(() => PlanApi.change(<String, dynamic>{'action': 'resume'}), 'Welcome back. Your plan is on again.');
      case 'pause':
        final days = await _pauseDays();
        if (days != null) {
          await _run(() => PlanApi.change(<String, dynamic>{'action': 'pause', 'days': days}),
              'Paused for $days days. Your plan moves $days days later.');
        }
      case 'rebalance':
        await _run(() => PlanApi.change(<String, dynamic>{'action': 'rebalance'}), 'Plan rebuilt from your latest results.');
      case 'edit':
        await context.push(Routes.studyPlanSetup, args: <String, dynamic>{'edit': true});
        if (mounted) setState(() {});
      case 'end':
        final ok = await _confirmEnd();
        if (ok == true) await _run(PlanApi.end, 'Plan ended');
    }
  }

  Future<int?> _pauseDays() => showAppSheet<int>(
        context,
        Builder(
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              const Text('Pause for how long?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              for (final d in const <int>[3, 7, 14])
                OptionTile(label: '$d days', onTap: () => Navigator.pop(ctx, d)),
            ],
          ),
        ),
      );

  Future<bool?> _confirmEnd() => showAppDialog<bool>(
        context,
        Builder(
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              const Text('End your study plan?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text(
                'Open tasks are removed from your schedule. You can make a new plan any time.',
                style: TextStyle(fontSize: 14, color: ctx.tk.textMuted),
              ),
              PrimaryButton(label: 'End plan', onTap: () => Navigator.pop(ctx, true)),
              OutlineButtonX(label: 'Keep it', radius: 999, onTap: () => Navigator.pop(ctx, false)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!PlanApi.available) return const PlanSignInNeeded();
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: PlanApi.current,
      builder: (context, plan, _) {
        if (_loading) {
          return AppScreen(
            children: [
              TopBar(title: 'My study plan', onBack: () => context.back()),
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }
        if (plan == null) {
          return AppScreen(
            children: [
              TopBar(title: 'My study plan', onBack: () => context.back()),
              if (_error != null)
                EmptyState(
                  icon: AppIcons.wifiOff,
                  title: 'Could not load your plan',
                  message: _error,
                  actionLabel: 'Try again',
                  onAction: _load,
                )
              else
                EmptyState(
                  icon: AppIcons.calendar,
                  title: 'No study plan yet',
                  message: 'Answer a few questions and get daily tasks matched to your level, time and exam date.',
                  actionLabel: 'Make my plan',
                  onAction: () => context.push(Routes.studyPlanSetup),
                ),
            ],
          );
        }
        return _body(context, plan);
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> plan) {
    final t = context.tk;
    final store = context.store;
    final id = plan.s('id');
    final paused = plan.s('status') == 'paused';
    final progress = plan.m('progress');
    final weekTotal = progress.i('weekTotal');
    final weekDone = progress.i('weekDone');

    // Tasks from the local store (ticks show at once), today and after.
    final today = Store.dateKey(DateTime.now());
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final task in store.tasks) {
      if (task['planId'] != id || task.s('date').compareTo(today) < 0) continue;
      (byDay[task.s('date')] ??= <Map<String, dynamic>>[]).add(task);
    }
    final days = byDay.keys.toList()..sort();

    return AppScreen(
      gap: 14,
      children: [
        TopBar(
          title: 'My study plan',
          subtitle: 'Week ${plan.i('week')} of ${plan.i('weeks')}',
          onBack: () => context.back(),
          actions: [
            IconBox(icon: AppIcons.more, tooltip: 'Plan options', onTap: _busy ? null : () => _actions(plan)),
          ],
        ),
        HeroCard(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Row(
            spacing: 14,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      (paused ? 'PAUSED' : plan.m('phase').s('label')).toUpperCase(),
                      style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: t.peach, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      paused
                          ? 'Back on ${planDayLabel(_dayAfter(plan.s('pausedUntil')))}'
                          : 'Target band ${Store.formatBand(plan.m('estimate').d('targetBand'))}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: t.heroText),
                    ),
                    Text(
                      plan.s('summary'),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: t.heroMuted),
                    ),
                    if (plan.b('checkpointThisWeek'))
                      const Tag('Checkpoint this week', tone: TagTone.hero, icon: AppIcons.flag),
                  ],
                ),
              ),
              RingProgress(
                value: weekTotal == 0 ? 0 : weekDone / weekTotal,
                size: 92,
                stroke: 8,
                onHero: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$weekDone/$weekTotal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: t.heroText)),
                    Text('this week', style: TextStyle(fontSize: 10.5, color: t.heroMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (plan.m('access').s('plan') == 'free') FreePlanBanner(access: plan.m('access')),
        if (plan['weekNote'] is Map) WeekNoteCard(note: plan.m('weekNote')),
        if (!plan.m('quickCheck').b('done') && !quickCheckDone(store) && plan.i('week') <= 2)
          QuickCheckOffer(modules: plan.m('inputs').ls('modules'), onDone: _load),
        if (days.isEmpty && !plan.m('access').b('ended'))
          EmptyState(
            icon: paused ? AppIcons.pause : AppIcons.calendar,
            title: paused ? 'Enjoy your break' : 'Nothing planned yet',
            message: paused ? 'Your tasks come back when the pause ends.' : 'Open the options (top right) and choose re-plan.',
          ),
        for (final d in days)
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          planDayLabel(d),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: d == today ? t.text : t.textMuted),
                        ),
                      ),
                      Text(
                        '${byDay[d]!.fold<int>(0, (m, x) => m + x.i('durationMin'))} min',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
                for (final task in byDay[d]!) PlanTaskRow(task: task),
              ],
            ),
          ),
        Text(
          'Tasks tick themselves off when you finish them anywhere in the app. Missed ones move to your next study day.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
        ),
      ],
    );
  }

  static Widget _optIcon(BuildContext context, IconData icon) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(icon, size: 22, color: context.tk.textMuted),
      );

  static String _dayAfter(String key) {
    final d = DateTime.tryParse(key);
    return d == null ? key : Store.dateKey(d.add(const Duration(days: 1)));
  }
}
