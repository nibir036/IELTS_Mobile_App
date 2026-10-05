import 'package:flutter/material.dart';

import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/services/notification_service.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// Profile › Notifications: which notifications to get and when.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool? _system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the phone's settings: check again.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final v = await NotificationService.I.systemEnabled();
    if (mounted) setState(() => _system = v);
  }

  Future<void> _allow() async {
    if (_system == true) return;
    await NotificationService.I.requestPermission();
    await _check();
    if (mounted && _system == false) {
      context.toast('Turn on notifications for IELTS AI in your phone settings');
    }
  }

  Future<void> _pickTime() async {
    final svc = NotificationService.I;
    final parts = svc.reminderTime().split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      helpText: 'Daily reminder time',
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    svc.setReminderTime(picked);
    if (mounted && (m < 8 * 60 || m > 22 * 60 + 30)) {
      context.toast('Reminders are sent between 8:00 AM and 10:30 PM');
    }
  }

  static String _fmt(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 20;
    final m = p.length > 1 ? p[1] : '00';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? 'AM' : 'PM'}';
  }

  static IconData _icon(String g) => switch (g) {
        NotifGroup.study => AppIcons.school,
        NotifGroup.exam => AppIcons.calendarMonth,
        NotifGroup.results => AppIcons.chart,
        NotifGroup.achievements => AppIcons.medal,
        _ => AppIcons.sparkle,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store; // rebuilds when a setting changes
    final svc = NotificationService.I;
    final studyOn = svc.enabled(NotifGroup.study, store);

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      gap: 14,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              bg: t.isNight ? t.surface : t.raised,
              onTap: () => context.back(),
            ),
          ],
        ),
        const Text(
          'Notifications',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.6),
        ),
        if (_system == false)
          AppCard(
            radius: 20,
            color: t.isNight ? t.surface : const Color(0xFFFFE2D8),
            child: Row(
              spacing: 12,
              children: [
                Icon(AppIcons.bell, color: t.text),
                Expanded(
                  child: Text(
                    'Notifications are turned off for IELTS AI on this phone.',
                    style: TextStyle(fontSize: 14, color: t.text),
                  ),
                ),
                LinkText('Allow', onTap: _allow),
              ],
            ),
          ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in NotifGroup.all)
                _GroupRow(
                  icon: _icon(g),
                  title: NotifGroup.label(g),
                  subtitle: NotifGroup.description(g),
                  value: svc.enabled(g, store),
                  onChanged: (v) => svc.setEnabled(g, v),
                ),
            ],
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: studyOn ? 1 : 0.45,
          child: AppCard(
            radius: 20,
            onTap: studyOn ? _pickTime : null,
            child: Row(
              spacing: 14,
              children: [
                Icon(AppIcons.clock, size: 22, color: t.textMuted),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily reminder', style: TextStyle(fontSize: 16, color: t.text)),
                      Text('When we remind you to study',
                          style: TextStyle(fontSize: 12, color: t.textMuted)),
                    ],
                  ),
                ),
                Text(_fmt(svc.reminderTime(store)),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: svc.planChanged,
          builder: (context, _, _) => _ComingUp(items: svc.upcoming.take(4).toList()),
        ),
        if (!svc.ready)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              svc.initError.isEmpty ? 'Phone notifications are not available.' : svc.initError,
              style: TextStyle(fontSize: 12.5, color: t.dangerText),
            ),
          )
        else
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: _TestButton(
                  label: 'Send a test',
                  onTap: () async {
                    await _allow();
                    final ok = await svc.sendTest();
                    if (context.mounted && !ok) context.toast('Could not show a notification');
                  },
                ),
              ),
              Expanded(
                child: _TestButton(
                  label: 'Test in 1 minute',
                  onTap: () async {
                    final ok = await svc.scheduleTest();
                    if (!context.mounted) return;
                    context.toast(ok
                        ? 'Scheduled. Close the app; it can arrive a few minutes late.'
                        : 'Could not schedule: ${svc.initError}');
                  },
                ),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'We never send study reminders between 10:30 PM and 8 AM, '
            'and at most one a day. Notifications use your explanation language.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textMuted),
          ),
        ),
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          spacing: 14,
          children: [
            Icon(icon, size: 22, color: t.isNight ? t.text : t.textMuted),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, color: t.text)),
                  Text(subtitle, style: TextStyle(fontSize: 12, height: 1.3, color: t.textMuted)),
                ],
              ),
            ),
            PillSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The next planned notifications, so the student can see when they come.
class _ComingUp extends StatelessWidget {
  const _ComingUp({required this.items});

  final List<(DateTime, String)> items;

  static String _when(DateTime d) {
    final now = DateTime.now();
    final day = DateUtils.dateOnly(d).difference(DateUtils.dateOnly(now)).inDays;
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final time = '$h12:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
    final label = switch (day) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => '${d.day} ${Store.monthShort(d.month)}',
    };
    return '$label · $time';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text('Coming up', style: TextStyle(fontSize: 13, color: t.textMuted)),
          if (items.isEmpty)
            Text('Nothing planned right now.', style: TextStyle(fontSize: 14, color: t.text))
          else
            for (final (at, title) in items)
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: t.text)),
                  ),
                  Text(_when(at), style: TextStyle(fontSize: 12.5, color: t.textMuted)),
                ],
              ),
          Text(
            "Once you've studied today, today's reminder is skipped.",
            style: TextStyle(fontSize: 11.5, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 16,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
      child: Center(
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.text)),
      ),
    );
  }
}
