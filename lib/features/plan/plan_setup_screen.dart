import 'package:flutter/material.dart';

import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'plan_api.dart';

/// Study plan set-up: a few short steps, then the preview. With
/// `{'edit': true}` it changes the current plan's target and schedule
/// instead (modules and levels stay).
class PlanSetupScreen extends StatefulWidget {
  const PlanSetupScreen({super.key});

  @override
  State<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends State<PlanSetupScreen> {
  late Map<String, dynamic> _in;
  bool _edit = false;
  bool _seeded = false;
  int _step = 0;
  bool _busy = false;

  /// Steps shown: 0 modules · 1 levels · 2 target & exam · 3 schedule · 4 worry.
  List<int> get _steps => _edit ? const <int>[2, 3] : const <int>[0, 1, 2, 3, 4];

  static const List<double> _bands = <double>[5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5];
  static const List<int> _minutes = <int>[15, 20, 30, 45, 60, 90, 120];
  static const List<double> _previous = <double>[4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _edit = context.routeArgs['edit'] == true;
    _in = PlanApi.defaults(Store.I);
    _in['modules'] = List<String>.from((_in['modules'] as List?) ?? PlanApi.modules);
    _in['levels'] = Map<String, dynamic>.from((_in['levels'] as Map?) ?? <String, dynamic>{});
    _in['days'] = List<int>.from(((_in['days'] as List?) ?? const <int>[1, 2, 3, 4, 5]).map((e) => (e as num).toInt()));
  }

  List<String> get _mods => (_in['modules'] as List).cast<String>();
  List<int> get _days => (_in['days'] as List).cast<int>();
  Map<String, dynamic> get _levels => _in['levels'] as Map<String, dynamic>;

  bool get _canNext => switch (_steps[_step]) {
        0 => _mods.isNotEmpty,
        3 => _days.isNotEmpty,
        _ => true,
      };

  Future<void> _next() async {
    if (_step + 1 < _steps.length) {
      setState(() => _step++);
      return;
    }
    if (!_edit) {
      context.push(Routes.studyPlanPreview, args: <String, dynamic>{'inputs': Map<String, dynamic>.from(_in)});
      return;
    }
    setState(() => _busy = true);
    try {
      await PlanApi.change(<String, dynamic>{
        'action': 'update',
        'days': _days,
        'minutesPerDay': _in['minutesPerDay'],
        'studyTime': _in['studyTime'],
        'targetBand': _in['targetBand'],
        'examDate': _in['examDate'],
      });
      if (!mounted) return;
      context.toast('Plan updated');
      context.back();
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _prev() {
    if (_step == 0) {
      context.back();
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlanApi.available) return const PlanSignInNeeded();
    final last = _step + 1 == _steps.length;
    return AppScreen(
      gap: 16,
      footer: Row(
        spacing: 10,
        children: [
          if (_step > 0)
            Expanded(child: OutlineButtonX(label: 'Back', height: 56, radius: 999, onTap: _prev)),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _busy ? 'Saving…' : (last ? (_edit ? 'Save changes' : 'See my plan') : 'Next'),
              trailing: last ? null : AppIcons.forward,
              enabled: _canNext && !_busy,
              onTap: _canNext && !_busy ? _next : null,
            ),
          ),
        ],
      ),
      children: [
        TopBar(
          title: _edit ? 'Change my plan' : 'Your study plan',
          subtitle: 'Step ${_step + 1} of ${_steps.length}',
          onBack: () => context.back(),
        ),
        ProgressBar(value: (_step + 1) / _steps.length, height: 6),
        ..._stepBody(context, _steps[_step]),
      ],
    );
  }

  List<Widget> _stepBody(BuildContext context, int step) {
    final t = context.tk;
    Widget q(String title, [String? sub]) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.2)),
            if (sub != null) Text(sub, style: TextStyle(fontSize: 13.5, height: 1.35, color: t.textMuted)),
          ],
        );
    Widget chips(List<Widget> c) => Wrap(spacing: 8, runSpacing: 8, children: c);

    switch (step) {
      case 0:
        return <Widget>[
          q('What do you want to work on?', 'Pick every part of the test you want in your plan.'),
          for (final m in PlanApi.modules)
            OptionTile(
              label: PlanApi.moduleLabel(m),
              selected: _mods.contains(m),
              onTap: () => setState(() {
                if (!_mods.remove(m)) _mods.add(m);
              }),
            ),
        ];
      case 1:
        return <Widget>[
          q('Where are you now?', 'Your best guess is fine. The plan corrects itself as you practise.'),
          for (final m in PlanApi.modules.where(_mods.contains))
            AppCard(
              radius: 22,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Text(PlanApi.moduleLabel(m), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  chips(<Widget>[
                    for (final e in PlanApi.levelLabels.entries)
                      ChipPill(
                        label: e.value,
                        selected: (_levels[m] ?? 'intermediate') == e.key,
                        onTap: () => setState(() => _levels[m] = e.key),
                      ),
                  ]),
                ],
              ),
            ),
          Text('Taken IELTS before? Your overall band', style: TextStyle(fontSize: 13, color: t.textMuted)),
          chips(<Widget>[
            ChipPill(
              label: 'Not yet',
              selected: _in['previousScore'] == null,
              onTap: () => setState(() => _in['previousScore'] = null),
            ),
            for (final b in _previous)
              ChipPill(
                label: Store.formatBand(b),
                selected: _in['previousScore'] == b,
                onTap: () => setState(() => _in['previousScore'] = b),
              ),
          ]),
        ];
      case 2:
        final exam = DateTime.tryParse('${_in['examDate'] ?? ''}');
        return <Widget>[
          q('What band do you need?'),
          chips(<Widget>[
            for (final b in _bands)
              ChipPill(
                label: Store.formatBand(b),
                selected: (_in['targetBand'] as num?)?.toDouble() == b,
                onTap: () => setState(() => _in['targetBand'] = b),
              ),
          ]),
          const SizedBox(height: 4),
          q('When is your exam?', 'We fit the plan before it. No date yet is fine too.'),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: OutlineButtonX(
                  label: exam == null ? 'Pick a date' : '${Store.weekdayShort(exam.weekday)}, ${Store.shortDate(exam)} ${exam.year}',
                  leading: AppIcons.calendar,
                  height: 52,
                  radius: 999,
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: exam ?? now.add(const Duration(days: 60)),
                      firstDate: now.add(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 730)),
                    );
                    if (d != null) setState(() => _in['examDate'] = Store.dateKey(d));
                  },
                ),
              ),
              ChipPill(
                label: 'No date yet',
                selected: exam == null,
                onTap: () => setState(() => _in['examDate'] = null),
              ),
            ],
          ),
        ];
      case 3:
        final time = '${_in['studyTime'] ?? '20:00'}';
        return <Widget>[
          q('Which days can you study?'),
          chips(<Widget>[
            for (var d = 1; d <= 7; d++)
              ChipPill(
                label: Store.weekdayShort(d),
                selected: _days.contains(d),
                onTap: () => setState(() {
                  if (!_days.remove(d)) _days.add(d);
                  _days.sort();
                }),
              ),
          ]),
          q('How long each day?', 'Be realistic: a plan you can keep beats a big one you skip.'),
          chips(<Widget>[
            for (final m in _minutes)
              ChipPill(
                label: m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60}'),
                selected: (_in['minutesPerDay'] as num?)?.toInt() == m,
                onTap: () => setState(() => _in['minutesPerDay'] = m),
              ),
          ]),
          q('What time suits you?', 'Your reminder comes at this time.'),
          OutlineButtonX(
            label: time,
            leading: AppIcons.clock,
            height: 52,
            radius: 999,
            onTap: () async {
              final p = time.split(':');
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 20, minute: int.tryParse(p.last) ?? 0),
              );
              if (picked != null) {
                setState(() => _in['studyTime'] =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
              }
            },
          ),
        ];
      default:
        return <Widget>[
          q('Which part worries you most?', 'It gets a little more time.'),
          chips(<Widget>[
            ChipPill(
              label: 'Not sure',
              selected: _in['worry'] == null,
              onTap: () => setState(() => _in['worry'] = null),
            ),
            for (final m in PlanApi.modules.where(_mods.contains))
              ChipPill(
                label: PlanApi.moduleLabel(m),
                selected: _in['worry'] == m,
                onTap: () => setState(() => _in['worry'] = m),
              ),
          ]),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Row(
              spacing: 12,
              children: [
                Icon(AppIcons.bulb, color: t.peach),
                Expanded(
                  child: Text(
                    'Your plan uses your results in the app too, so it gets sharper the more you practise.',
                    style: TextStyle(fontSize: 13, height: 1.35, color: t.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }
}

/// Shown when there is no account on the server (offline demo).
class PlanSignInNeeded extends StatelessWidget {
  const PlanSignInNeeded({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      children: [
        TopBar(title: 'Study plan', onBack: () => context.back()),
        const EmptyState(
          icon: AppIcons.calendar,
          title: 'Sign in to get a study plan',
          message: 'Your plan is built from your results on your account, so it needs you to be signed in and online.',
        ),
      ],
    );
  }
}
