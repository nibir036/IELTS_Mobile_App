import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// B5 · Schedule & Deadlines.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

const List<String> _weekdayNames = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const List<String> _monthNames = <String>[
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
];

/// '19:30' → '7:30 PM'.
String _fmtTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// 160 → '2 h 40 min', 20 → '20 min'.
String _fmtDuration(int min) {
  if (min <= 0) return '';
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String _taskSubtitle(Map<String, dynamic> task) {
  final kind = switch (task.s('kind')) {
    'goal' => 'Daily goal',
    'deadline' => 'Deadline',
    'reminder' => 'Reminder',
    _ => '',
  };
  return <String>[
    if (kind.isNotEmpty) kind,
    Skill.label(task.s('skill')),
    if (task.s('time').isNotEmpty) _fmtTime(task.s('time')),
    _fmtDuration(task.i('durationMin')),
  ].where((x) => x.isNotEmpty).join(' · ');
}

void _openTask(BuildContext context, Map<String, dynamic> task) {
  final target = task.s('target');
  openStoredRoute(
    context,
    target.isNotEmpty ? target : skillLandingRoute(task.s('skill')),
  );
}

Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> task) async {
  final ok = await showAppDialog<bool>(
    context,
    Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          const Text(
            'Delete task?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          Text(
            task.s('title'),
            style: TextStyle(fontSize: 14, color: ctx.tk.textMuted),
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: OutlineButtonX(
                  label: 'Cancel',
                  height: 48,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              Expanded(
                child: PrimaryButton(
                  label: 'Delete',
                  height: 48,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (ok == true) Store.I.removeTask(task.s('id'));
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _filter = 0;
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final data = Demo.section('home').m('schedule');
    final filters = data.l('filters');
    final today = DateUtils.dateOnly(DateTime.now());
    final strip = <DateTime>[
      for (var i = -3; i <= 3; i++) DateUtils.addDaysToDate(_day, i),
    ];
    final tasks = store.tasksOn(_day);
    final filterId =
        _filter < filters.length ? filters[_filter].s('id') : 'all';
    final visible = filterId == 'all'
        ? tasks
        : tasks.where((x) => x.s('skill') == filterId).toList();
    final doneCount = tasks.where((x) => x.b('done')).length;
    final offset = (_day.difference(today).inHours / 24).round();
    final dayWord = switch (offset) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => offset > 0 ? 'In $offset days' : '${-offset} days ago',
    };

    // Next unfinished mock on the schedule.
    Map<String, dynamic>? mock;
    DateTime? mockDate;
    for (final x in store.tasks) {
      if (x.s('skill') != Skill.mock || x.b('done')) continue;
      final d = DateTime.tryParse(x.s('date'));
      if (d == null || d.isBefore(today)) continue;
      if (mockDate == null ||
          d.isBefore(mockDate) ||
          (d == mockDate && x.s('time').compareTo(mock!.s('time')) < 0)) {
        mock = x;
        mockDate = d;
      }
    }

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      gap: 16,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              size: 56,
              radius: 20,
              onTap: () => context.back(),
            ),
            const Spacer(),
            IconBox(
              icon: AppIcons.add,
              tooltip: 'Add task',
              size: 56,
              radius: 20,
              iconSize: 24,
              onTap: () => showAppSheet<void>(context, _AddTaskSheet(day: _day)),
            ),
          ],
        ),
        const Text(
          'Schedule',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.6,
          ),
        ),

        // Day strip (tap a day to centre it)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < strip.length; i++)
                Flexible(
                  flex: switch ((i - 3).abs()) { 0 => 4, 1 => 3, _ => 2 },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _day = strip[i]),
                      child: _DayCell(
                        weekday: Store.weekdayShort(strip[i].weekday),
                        day: strip[i].day,
                        distance: (i - 3).abs(),
                        hasTasks: store.tasksOn(strip[i]).isNotEmpty,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (var i = 0; i < filters.length; i++)
                _FilterChip(
                  label: filters[i].s('label'),
                  count: i == 0 ? tasks.length : null,
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
            ],
          ),
        ),

        // Day card
        AppCard(
          radius: 30,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: [
                          Text(
                            '${_weekdayNames[_day.weekday - 1]}, ${_day.day} ${_monthNames[_day.month - 1]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 19),
                          ),
                          Text(
                            dayWord,
                            style: TextStyle(
                              fontSize: 13,
                              color: offset == 0 ? t.alert : t.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tasks.isNotEmpty)
                      Text(
                        '$doneCount of ${tasks.length} done',
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                  ],
                ),
              ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    spacing: 12,
                    children: [
                      Text(
                        tasks.isEmpty
                            ? 'Nothing scheduled for this day'
                            : 'Nothing in this category',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: t.textMuted),
                      ),
                      if (tasks.isEmpty)
                        SoftButton(
                          label: 'Add a task',
                          leading: AppIcons.add,
                          height: 44,
                          fontSize: 14,
                          bg: t.surfaceAlt2,
                          onTap: () => showAppSheet<void>(
                            context,
                            _AddTaskSheet(day: _day),
                          ),
                        ),
                    ],
                  ),
                ),
              for (final task in visible)
                Dismissible(
                  key: ValueKey<String>(task.s('id')),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => Store.I.removeTask(task.s('id')),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: t.dangerSoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(AppIcons.delete, size: 22, color: t.dangerText),
                  ),
                  child: _TaskRow(task: task),
                ),
            ],
          ),
        ),

        // Upcoming mock
        if (mock != null && mockDate != null)
          HeroCard(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
            onTap: () => context.push(Routes.mockSystemCheck),
            child: Row(
              spacing: 14,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      Text(
                        'Upcoming mock test',
                        style: TextStyle(fontSize: 13, color: t.heroMuted),
                      ),
                      Text(
                        mock.s('title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: t.heroText,
                        ),
                      ),
                      Text(
                        <String>[
                          '${Store.weekdayShort(mockDate.weekday)}, ${Store.shortDate(mockDate)}',
                          if (mock.s('time').isNotEmpty) _fmtTime(mock.s('time')),
                          _fmtDuration(mock.i('durationMin')),
                        ].where((x) => x.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.heroMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kInk,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(mockDate.difference(today).inHours / 24).round()}',
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1,
                          color: Color(0xFFF6ECC8),
                        ),
                      ),
                      Text(
                        (mockDate.difference(today).inHours / 24).round() == 1
                            ? 'day'
                            : 'days',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFF6ECC8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.weekday,
    required this.day,
    required this.distance,
    required this.hasTasks,
  });

  final String weekday;
  final int day;
  final int distance;
  final bool hasTasks;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    if (distance == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(weekday, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            '$day',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Dot(size: 6, color: hasTasks ? t.alert : Colors.transparent),
        ],
      );
    }
    final near = distance == 1;
    final color = near
        ? t.textMuted
        : (t.isNight ? const Color(0xFF6F6F6F) : t.textMuted);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          weekday,
          style: TextStyle(fontSize: near ? 15 : 13, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          '$day',
          style: TextStyle(fontSize: near ? 22 : 18, color: color),
        ),
        const SizedBox(height: 6),
        Dot(size: 4, color: hasTasks ? color : Colors.transparent),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? t.text : t.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(label, style: const TextStyle(fontSize: 15)),
              if (count != null)
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.isNight ? t.border : t.raised,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final done = task.b('done');
    final kind = task.s('kind');
    final dayTint = t.alert.withValues(alpha: 0.12);

    IconData icon;
    Color bg;
    Color fg;
    if (done) {
      icon = AppIcons.check;
      bg = t.isNight ? const Color(0xFF203A2E) : dayTint;
      fg = t.isNight ? const Color(0xFF7FD1A6) : t.alert;
    } else if (kind == 'deadline') {
      icon = AppIcons.error;
      bg = t.isNight ? const Color(0xFF3A1D1A) : dayTint;
      fg = t.isNight ? const Color(0xFFFF7A5C) : t.alert;
    } else {
      icon = homeIconFor(task.s('skill'));
      bg = t.isNight ? const Color(0xFF3A2A18) : dayTint;
      fg = t.isNight ? const Color(0xFFF2A14A) : t.textMuted;
    }

    return Material(
      color: t.isNight ? const Color(0xFF1C1C1C) : t.surfaceAlt,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTask(context, task),
        onLongPress: () => _confirmDelete(context, task),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            spacing: 12,
            children: [
              Tooltip(
                message: done ? 'Mark as not done' : 'Mark as done',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Store.I.toggleTask(task.s('id')),
                  child: TintCircle(icon: icon, bg: bg, fg: fg),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.s('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: done ? t.textMuted : t.text,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: t.textMuted,
                      ),
                    ),
                    Text(
                      _taskSubtitle(task),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: done && t.isNight
                            ? const Color(0xFF6F6F6F)
                            : t.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (!done)
                IconBox(
                  icon: AppIcons.play,
                  tooltip: 'Start',
                  bg: Colors.transparent,
                  iconSize: 22,
                  onTap: () => _openTask(context, task),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+" sheet: title, skill, time and duration → [Store.addTask].
class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.day});

  final DateTime day;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  static const List<String> _skills = <String>[
    Skill.listening,
    Skill.reading,
    Skill.writing,
    Skill.speaking,
    Skill.mock,
    Skill.vocab,
  ];
  static const List<int> _durations = <int>[15, 20, 30, 45, 60, 160];

  final TextEditingController _title = TextEditingController();
  String _skill = Skill.writing;
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  int _duration = 30;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _timeKey =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (!mounted) return;
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Store.I.addTask(<String, dynamic>{
      'title': title,
      'skill': _skill,
      'date': Store.dateKey(widget.day),
      'time': _timeKey,
      'durationMin': _duration,
      'target': skillLandingRoute(_skill),
    });
    context.toast('Task added');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const SizedBox(height: 4),
          Text(
            'New task · ${Store.weekdayDate(widget.day)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          AppTextField(
            label: 'Title',
            hint: 'e.g. Task 2 essay: technology',
            controller: _title,
            onChanged: (_) => setState(() {}),
          ),
          Text('Skill', style: TextStyle(fontSize: 13, color: t.textMuted)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in _skills)
                ChipPill(
                  label: Skill.label(k),
                  selected: _skill == k,
                  onTap: () => setState(() => _skill = k),
                ),
            ],
          ),
          Text('Time', style: TextStyle(fontSize: 13, color: t.textMuted)),
          AppCard(
            radius: 18,
            color: t.surfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: _pickTime,
            child: Row(
              spacing: 12,
              children: [
                Icon(AppIcons.clock, size: 20, color: t.text),
                Expanded(
                  child: Text(
                    _fmtTime(_timeKey),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Icon(AppIcons.chevronRight, size: 20, color: t.textMuted),
              ],
            ),
          ),
          Text('Duration', style: TextStyle(fontSize: 13, color: t.textMuted)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _durations)
                ChipPill(
                  label: _fmtDuration(d),
                  selected: _duration == d,
                  onTap: () => setState(() => _duration = d),
                ),
            ],
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Add task',
            enabled: _title.text.trim().isNotEmpty,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}
