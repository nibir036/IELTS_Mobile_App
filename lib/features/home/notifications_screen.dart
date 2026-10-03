import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// B6 · Notifications & Activity.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// Notification types each filter chip shows.
const Map<String, List<String>> _filterTypes = <String, List<String>>{
  'ai': <String>['score', 'ai'],
  'reminder': <String>['reminder', 'system'],
  'community': <String>['community'],
};

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _filter = 0;

  void _open(Map<String, dynamic> n) {
    Store.I.markNotificationRead(n.s('id'));
    final att = Store.I.attemptById(n.s('attemptId'));
    if (att != null) {
      openAttempt(context, att);
      return;
    }
    final target = n.s('target');
    if (target.isNotEmpty) {
      final args = n.m('args');
      openStoredRoute(context, target, args.isEmpty ? null : args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final data = Demo.section('home').m('notifications');
    final filters = data.l('filters');
    final items = store.notifications;
    final filterId =
        _filter < filters.length ? filters[_filter].s('id') : 'all';
    final types = _filterTypes[filterId];
    DateTime created(Map<String, dynamic> n) =>
        DateTime.tryParse(n.s('createdAt')) ?? DateTime.now();
    final visible = (filterId == 'all' || types == null
        ? List<Map<String, dynamic>>.of(items)
        : items.where((x) => types.contains(x.s('type'))).toList())
      ..sort((a, b) => created(b).compareTo(created(a)));

    // Group by day, newest first.
    final groups = <String>[];
    for (final it in visible) {
      final g = Store.relativeDay(created(it));
      if (!groups.contains(g)) groups.add(g);
    }

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
            const Spacer(),
            if (store.unreadNotifications > 0)
              LinkText(
                'Mark all read',
                color: t.textMuted,
                weight: FontWeight.w400,
                onTap: () => Store.I.markAllNotificationsRead(),
              ),
          ],
        ),
        const Text(
          'Activity',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 6,
            children: [
              for (var i = 0; i < filters.length; i++)
                _Filter(
                  label: filters[i].s('label'),
                  count: i == 0 ? '${items.length}' : null,
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
            ],
          ),
        ),
        const _StreakCard(),
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(g, style: TextStyle(fontSize: 13, color: t.textMuted)),
          ),
          AppCard(
            radius: 24,
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final it in visible)
                  if (Store.relativeDay(created(it)) == g)
                    _NotificationRow(
                      item: it,
                      time: Store.timeAgo(created(it)),
                      unread: it['read'] != true,
                      onTap: () => _open(it),
                    ),
              ],
            ),
          ),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'You’re all caught up',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ),
      ],
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: selected ? t.primary : t.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? t.onPrimary : t.text,
                ),
              ),
              if (count != null)
                Text(
                  count!,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? (t.isNight
                            ? const Color(0xFF5A5446)
                            : const Color(0xFFBDB6BB))
                        : t.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final streak = store.streakDays;
    final today = DateUtils.dateOnly(DateTime.now());
    final activeDays = store.attempts
        .map((a) => Store.dateKey(a.createdAt))
        .toSet();
    final week = <Map<String, dynamic>>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateUtils.addDaysToDate(today, -i);
      week.add(<String, dynamic>{
        'label': Store.weekdayShort(d.weekday).substring(0, 1),
        'done': activeDays.contains(Store.dateKey(d)),
        'today': i == 0,
      });
    }
    final todayMin = store.minutesOn(today);
    final studiedToday = week.last.b('done');
    final subtitle = studiedToday
        ? 'You studied $todayMin min today'
        : (streak > 0
            ? 'Study 20 min today to keep it'
            : 'Practise today to start a streak');
    return HeroCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      gradient: t.isNight
          ? null
          : const LinearGradient(
              begin: Alignment(-0.5, -0.87),
              end: Alignment(0.5, 0.87),
              colors: [Color(0xFFD6D8FA), Color(0xFFEEEFFD)],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      streak == 1 ? '1-day streak' : '$streak-day streak',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: t.heroText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: t.heroMuted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.isNight
                      ? const Color(0xFFFFF8E2)
                      : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  AppIcons.fire,
                  size: 22,
                  color: t.isNight
                      ? const Color(0xFFB63A26)
                      : const Color(0xFFD9612E),
                ),
              ),
            ],
          ),
          Row(
            spacing: 6,
            children: [
              for (final d in week)
                Expanded(
                  child: Column(
                    spacing: 4,
                    children: [
                      if (d.b('today') && !d.b('done'))
                        DashedRRect(color: t.heroText)
                      else
                        Container(
                          height: 34,
                          decoration: BoxDecoration(
                            color: d.b('done')
                                ? t.heroText
                                : t.heroText.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      Text(
                        d.s('label'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: d.b('today')
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: d.b('today') ? t.heroText : t.heroMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final type = item.s('type');
    final skill = item.s('skill');
    String tone;
    String iconKey;
    if (item.s('icon').isNotEmpty) {
      iconKey = item.s('icon');
      tone = item.s('tone');
    } else if (type == 'score' || type == 'ai') {
      iconKey = skill == Skill.speaking ? 'mic' : 'sparkle';
      tone = skill == Skill.speaking ? 'pink' : 'primary';
    } else if (type == 'reminder') {
      iconKey = 'clock';
      tone = 'lavender';
    } else if (type == 'community') {
      iconKey = 'chat';
      tone = 'neutral';
    } else {
      iconKey = 'bell';
      tone = 'neutral';
    }
    Color bg;
    Color fg;
    switch (tone) {
      case 'primary':
        bg = t.primary;
        fg = t.onPrimary;
      case 'pink':
        bg = kPastelPink;
        fg = t.isNight ? const Color(0xFF625C66) : kInk;
      case 'lavender':
        bg = kPastelLavender;
        fg = t.isNight ? const Color(0xFF625C66) : kInk;
      default:
        bg = t.surfaceAlt2;
        fg = t.isNight ? t.textMuted : t.text;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            TintCircle(
              icon: homeIconFor(iconKey),
              bg: bg,
              fg: fg,
              size: 42,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(
                    item.s('title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    item.s('body'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 6,
              children: [
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: t.textMuted),
                ),
                if (unread) Dot(size: 8, color: t.alert),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
