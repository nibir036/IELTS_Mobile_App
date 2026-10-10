import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/entitlements.dart';
import '../../app/services/notification_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/mascot.dart';
import '../home/widgets.dart';
import 'plan_api.dart';
import 'plan_setup_screen.dart';
import 'plan_widgets.dart';

/// The plan before it starts: how long, how the time is split, the phases
/// and the first week. "Start my plan" saves it.
class PlanPreviewScreen extends StatefulWidget {
  const PlanPreviewScreen({super.key});

  @override
  State<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends State<PlanPreviewScreen> {
  Map<String, dynamic> _inputs = <String, dynamic>{};
  Future<Map<String, dynamic>>? _future;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future != null || !PlanApi.available) return;
    final a = context.routeArgs['inputs'];
    _inputs = a is Map ? Map<String, dynamic>.from(a) : PlanApi.defaults(Store.I);
    _future = PlanApi.preview(_inputs);
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      await PlanApi.create(_inputs);
      // Reminders at the chosen study time.
      final p = '${_inputs['studyTime'] ?? ''}'.split(':');
      if (p.length == 2) {
        NotificationService.I.setReminderTime(TimeOfDay(hour: int.tryParse(p[0]) ?? 20, minute: int.tryParse(p[1]) ?? 0));
      }
      if (!mounted) return;
      const flow = <String>{Routes.studyPlanSetup, Routes.studyPlanPreview, Routes.studyPlan};
      Navigator.of(context).popUntil((r) => r.isFirst || !flow.contains(r.settings.name));
      context.push(Routes.studyPlan);
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlanApi.available) return const PlanSignInNeeded();
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppScreen(
            children: [
              TopBar(title: 'Your plan', onBack: () => context.back()),
              EmptyState(
                icon: AppIcons.wifiOff,
                title: 'Could not make the plan',
                message: '${snap.error}',
                actionLabel: 'Try again',
                onAction: () => setState(() => _future = PlanApi.preview(_inputs)),
              ),
            ],
          );
        }
        if (!snap.hasData) {
          return AppScreen(
            children: [
              TopBar(title: 'Your plan', onBack: () => context.back()),
              const SizedBox(height: 80),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Center(child: Text('Building your plan…', style: TextStyle(color: context.tk.textMuted))),
            ],
          );
        }
        return _body(context, snap.data!);
      },
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> r) {
    final t = context.tk;
    final est = r.m('estimate');
    final weeks = est.i('weeks');
    final onTrack = est.b('onTrack');
    final split = est.m('split');
    final focus = est.ls('focusLabels');
    final week = r.l('week');
    // The server only previews the days the plan will get (3 study days on Free).
    final access = r.m('access');
    final free = access.isNotEmpty ? access.s('plan') == 'free' : !Entitlements.I.planExtras;
    final freeEnded = free && access.b('ended');
    final days = <String, List<Map<String, dynamic>>>{};
    for (final w in week) {
      (days[w.s('date')] ??= <Map<String, dynamic>>[]).add(w);
    }
    final weeksLabel = !onTrack || est.i('weeksMin') == est.i('weeksMax')
        ? '$weeks weeks'
        : '${est.i('weeksMin')}-${est.i('weeksMax')} weeks';

    return AppScreen(
      gap: 14,
      footer: PrimaryButton(
        label: _saving ? 'Saving…' : 'Start my plan',
        enabled: !_saving,
        onTap: _saving ? null : _start,
      ),
      children: [
        TopBar(title: 'Your plan', subtitle: 'Check it before you start', onBack: () => context.back()),
        HeroCard(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(
                      onTrack ? 'TARGET BAND ${Store.formatBand(est.d('targetBand'))}' : 'YOUR BEST PLAN',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: t.peach, fontWeight: FontWeight.w600),
                    ),
                    Text(weeksLabel, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: t.heroText)),
                    Text(
                      r.s('summary'),
                      style: TextStyle(fontSize: 13, height: 1.4, color: t.heroMuted),
                    ),
                  ],
                ),
              ),
              const Nexi(NexiPose.writing, height: 100),
            ],
          ),
        ),
        if (free)
          Text(
            freeEnded
                ? 'Your 3 free study days are used. Pro runs this plan all the way to your exam and adapts it every week.'
                : 'On the free plan you get the first 3 study days of this plan. Pro runs it all the way and adapts it every week.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
          ),
        if (!quickCheckDone(context.store))
          QuickCheckOffer(
            modules: (_inputs['modules'] as List? ?? PlanApi.modules).map((e) => '$e').toList(),
            onDone: () => setState(() => _future = PlanApi.preview(_inputs)),
          ),
        if (est.l('phases').isNotEmpty)
          AppCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                const Text('How it goes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                for (final p in est.l('phases'))
                  Row(
                    spacing: 10,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: t.peach, shape: BoxShape.circle),
                      ),
                      Expanded(child: Text(p.s('label'), style: const TextStyle(fontSize: 14))),
                      Text(
                        p.i('fromWeek') == p.i('toWeek') ? 'Week ${p.i('fromWeek')}' : 'Weeks ${p.i('fromWeek')}-${p.i('toWeek')}',
                        style: TextStyle(fontSize: 12.5, color: t.textMuted),
                      ),
                    ],
                  ),
                if (est.ls('checkpointWeeks').isNotEmpty)
                  Text(
                    'Checkpoint tests in weeks ${est.ls('checkpointWeeks').join(', ')}.',
                    style: TextStyle(fontSize: 12.5, color: t.textMuted),
                  ),
              ],
            ),
          ),
        if (split.length > 1)
          AppCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                const Text('Where your time goes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                for (final e in split.entries)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 4,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(PlanApi.moduleLabel(e.key), style: const TextStyle(fontSize: 13.5))),
                          Text('${((e.value as num) * 100).round()}%', style: TextStyle(fontSize: 12.5, color: t.textMuted)),
                        ],
                      ),
                      ProgressBar(value: (e.value as num).toDouble(), height: 6),
                    ],
                  ),
              ],
            ),
          ),
        if (focus.isNotEmpty)
          AppCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                const Text('From your results so far', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final f in focus) Tag(f, tone: TagTone.accent)]),
              ],
            ),
          ),
        if (week.isNotEmpty)
          SectionTitle(
            free ? 'Your free days' : 'Your first week',
            subtitle: '${days.length} ${days.length == 1 ? 'day' : 'days'} · ${week.length} tasks',
          ),
        for (final e in days.entries)
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(_dayLabel(e.key), style: TextStyle(fontSize: 12.5, color: t.textMuted, fontWeight: FontWeight.w600)),
                ),
                for (final task in e.value) PlanTaskRow(task: task, enabled: false),
              ],
            ),
          ),
        if (free) const _ProDaysCard(),
      ],
    );
  }
}

/// Free plan: the rest of the plan is Pro.
class _ProDaysCard extends StatelessWidget {
  const _ProDaysCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 22,
      onTap: () => context.push(Routes.plans),
      child: Row(
        spacing: 12,
        children: [
          TintCircle(icon: AppIcons.lock, bg: t.surfaceAlt2, fg: t.textMuted, size: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                const Text('The rest of your plan · Pro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  'Every day up to your exam, adapted each week to your results.',
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: t.textMuted),
                ),
              ],
            ),
          ),
          Icon(AppIcons.forward, size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}

String _dayLabel(String key) => planDayLabel(key);

/// "Today", "Tomorrow" or "Wed, 14 Oct".
String planDayLabel(String key) {
  final d = DateTime.tryParse(key);
  if (d == null) return key;
  final today = DateUtils.dateOnly(DateTime.now());
  final diff = DateUtils.dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${Store.weekdayShort(d.weekday)}, ${Store.shortDate(d)}';
}
