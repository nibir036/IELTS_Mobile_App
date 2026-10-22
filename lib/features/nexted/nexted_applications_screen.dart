import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/nexted_api.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// The fixed steps an application moves through (25.4). Staff move it on the
/// web; the student follows it here. Side states (Rejected, Waiting List, On
/// Hold) sit outside this line and are shown as the status instead.
const List<String> kNextedStatusSteps = <String>[
  'Submitted',
  'Under Review',
  'Documents Requested',
  'Application Lodged with Institution',
  'Conditional Offer',
  'Unconditional Offer',
  'Deposit or Tuition Paid',
  'Admission Letter or CAS/CoE',
  'Visa Preparation',
  'Visa Lodged',
  'Visa Decision',
  'Enrolled',
];

const Set<String> kNextedSideStates = <String>{'Rejected', 'Waiting List', 'On Hold'};

int nextedStepIndex(String status) {
  final s = status.trim().toLowerCase();
  for (var i = 0; i < kNextedStatusSteps.length; i++) {
    if (kNextedStatusSteps[i].toLowerCase() == s) return i;
  }
  return -1;
}

/// nexted.app · my applications.
class NextedApplicationsScreen extends StatefulWidget {
  const NextedApplicationsScreen({super.key});

  @override
  State<NextedApplicationsScreen> createState() => _NextedApplicationsScreenState();
}

class _NextedApplicationsScreenState extends State<NextedApplicationsScreen> {
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!NextedApi.ready) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final r = await NextedApi.get(NextedConfig.applications);
      if (!mounted) return;
      setState(() {
        _items = r.l('applications').isNotEmpty ? r.l('applications') : r.l('items');
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;

    return AppScreen(
      gap: 13,
      children: [
        TopBar(
          title: 'My applications',
          subtitle: 'Your counsellor works these on the web',
          onBack: () => context.back(),
        ),

        if (!NextedConfig.hasApi) const NextedOfflineNotice(),

        if (_error != null)
          EmptyState(
            title: 'Couldn’t load your applications',
            message: _error,
            icon: AppIcons.cloudOff,
            actionLabel: 'Try again',
            onAction: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _load();
            },
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_items.isEmpty)
          const EmptyState(
            title: 'No applications yet',
            message: 'Apply from a matched course or scholarship and it appears here, '
                'with every step from submitted to enrolled.',
            icon: AppIcons.taskDone,
          )
        else
          for (final a in _items)
            _ApplicationCard(
              app: a,
              onTap: () async {
                await context.push(Routes.nextedApplication, args: <String, dynamic>{'id': a.s('id')});
                if (mounted) _load();
              },
            ),

        Text(
          'Every change your counsellor makes is timestamped and sent to your phone.',
          style: TextStyle(fontSize: 12, height: 1.45, color: t.textMuted),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.app, required this.onTap});

  final Map<String, dynamic> app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final status = app.s('status');
    final step = nextedStepIndex(status);
    final updated = DateTime.tryParse(app.s('updatedAt'))?.toLocal();
    final reference = app.s('reference').isEmpty ? app.s('id') : app.s('reference');

    return AppCard(
      radius: 24,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              IconCircle(
                app.s('type') == 'scholarship' ? AppIcons.medal : AppIcons.school,
                size: 42,
                iconSize: 20,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      app.s('title').isEmpty ? 'Application' : app.s('title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500),
                    ),
                    if (app.s('provider').isNotEmpty)
                      Text(
                        app.s('provider'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: t.textMuted),
                      ),
                  ],
                ),
              ),
              NextedStatusTag(status),
            ],
          ),
          if (step >= 0)
            ProgressBar(value: (step + 1) / kNextedStatusSteps.length, height: 5),
          Row(
            spacing: 8,
            children: [
              if (reference.isNotEmpty)
                Text(reference, style: TextStyle(fontSize: 12, color: t.textMuted)),
              const Spacer(),
              if (updated != null)
                Text('Updated ${Store.timeAgo(updated)}',
                    style: TextStyle(fontSize: 12, color: t.textMuted)),
              Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}

/// nexted.app · one application, with its status tracker.
class NextedApplicationScreen extends StatefulWidget {
  const NextedApplicationScreen({super.key});

  @override
  State<NextedApplicationScreen> createState() => _NextedApplicationScreenState();
}

class _NextedApplicationScreenState extends State<NextedApplicationScreen> {
  Map<String, dynamic> _app = <String, dynamic>{};
  bool _loading = true;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(context.routeArgs.s('id'));
  }

  Future<void> _load(String id) async {
    if (!NextedApi.ready || id.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final r = await NextedApi.get('${NextedConfig.applications}/$id');
      if (!mounted) return;
      setState(() {
        _app = r.m('application').isEmpty ? r : r.m('application');
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  /// When each step happened, from the application's history.
  Map<String, DateTime> get _history {
    final out = <String, DateTime>{};
    for (final h in _app.l('history')) {
      final at = DateTime.tryParse(h.s('at').isEmpty ? h.s('changedAt') : h.s('at'));
      final status = h.s('status');
      if (at != null && status.isNotEmpty) out[status.toLowerCase()] = at.toLocal();
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final status = _app.s('status');
    final step = nextedStepIndex(status);
    final side = kNextedSideStates.any((s) => s.toLowerCase() == status.trim().toLowerCase());
    final history = _history;
    final reference = _app.s('reference').isEmpty ? _app.s('id') : _app.s('reference');

    return AppScreen(
      gap: 13,
      children: [
        TopBar(
          title: _app.s('title').isEmpty ? 'Application' : _app.s('title'),
          subtitle: reference.isEmpty ? null : reference,
          onBack: () => context.back(),
        ),

        if (_error != null)
          EmptyState(
            title: 'Couldn’t load this application',
            message: _error,
            icon: AppIcons.cloudOff,
            actionLabel: 'Try again',
            onAction: () {
              setState(() {
                _error = null;
                _loading = true;
              });
              _load(context.routeArgs.s('id'));
            },
          )
        else if (_loading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          AppCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _app.s('provider').isEmpty ? 'Your application' : _app.s('provider'),
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                    ),
                    NextedStatusTag(status),
                  ],
                ),
                if (step >= 0)
                  Text(
                    'Step ${step + 1} of ${kNextedStatusSteps.length}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                if (side)
                  Text(
                    'Your counsellor will contact you about this.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: t.textSoft),
                  ),
              ],
            ),
          ),

          SectionTitle('Progress', fontSize: 15),
          AppCard(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < kNextedStatusSteps.length; i++)
                  _StepRow(
                    label: kNextedStatusSteps[i],
                    at: history[kNextedStatusSteps[i].toLowerCase()],
                    done: step >= 0 && i < step,
                    current: step == i,
                    last: i == kNextedStatusSteps.length - 1,
                  ),
              ],
            ),
          ),

          Text(
            'NextED staff move these steps from the web platform. You’ll get a '
            'notification each time something changes.',
            style: TextStyle(fontSize: 12, height: 1.45, color: t.textMuted),
          ),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.current,
    required this.last,
    this.at,
  });

  final String label;
  final bool done;
  final bool current;
  final bool last;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final active = done || current;
    final dot = current ? t.primary : (done ? t.primary.withValues(alpha: 0.45) : t.border);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: done
                    ? Icon(AppIcons.check, size: 9, color: t.onPrimary)
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done ? t.primary.withValues(alpha: 0.35) : t.border,
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                      color: active ? t.text : t.textMuted,
                    ),
                  ),
                  if (at != null)
                    Text(
                      '${Store.weekdayDate(at!)} · ${at!.hour.toString().padLeft(2, '0')}:${at!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11.5, color: t.textMuted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
