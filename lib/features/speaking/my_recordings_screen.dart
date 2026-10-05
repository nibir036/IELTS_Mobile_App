import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'speaking_audio.dart';
import 'widgets.dart';

/// D10 · My recordings - the student's speaking attempts (Part 1/2/3 and
/// mock interviews) with real playback of this device's recordings (or the
/// uploaded copy), simulated when no audio exists. Delete removes the attempt.
class MyRecordingsScreen extends StatefulWidget {
  const MyRecordingsScreen({super.key});

  @override
  State<MyRecordingsScreen> createState() => _MyRecordingsScreenState();
}

class _MyRecordingsScreenState extends State<MyRecordingsScreen> {
  late final Map<String, dynamic> _data = speakingData().m('recordings');
  String? _activeId;
  bool _activeSet = false;
  bool _oldestFirst = false;
  int _filter = 0;

  /// Player for the active row (real recording, or simulated playback).
  AnswerPlayer? _player;
  String? _playerFor;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  AnswerPlayer _playerOf(Map<String, dynamic> r) {
    final id = r.s('id');
    final existing = _player;
    if (existing != null && _playerFor == id) return existing;
    existing?.removeListener(_onPlayer);
    existing?.dispose();
    final seconds = r.i('durationSeconds') > 0 ? r.i('durationSeconds') : 60;
    final p = AnswerPlayer(r.l('audio'), fallbackSec: seconds)..addListener(_onPlayer);
    _player = p;
    _playerFor = id;
    return p;
  }

  void _toggle(Map<String, dynamic> r) {
    final p = _playerOf(r);
    setState(() => _activeId = r.s('id'));
    p.toggle();
  }

  void _seek(Map<String, dynamic> r, double fraction) {
    final p = _playerOf(r);
    setState(() => _activeId = r.s('id'));
    p.seekFraction(fraction);
  }

  void _delete(Map<String, dynamic> r) {
    final id = r.s('id');
    if (_activeId == id) {
      _player?.removeListener(_onPlayer);
      _player?.dispose();
      _player = null;
      _playerFor = null;
      _activeId = null;
    }
    Store.I.deleteAttempt(id);
    context.toast('Recording deleted');
  }

  /// One list row per speaking answer.
  Map<String, dynamic> _row(Attempt a, DateTime weekAgo) {
    final isTest = a.data['test'] == true;
    final part = isTest ? 'test' : a.kind;
    final answers = a.data['questions'] is List ? (a.data['questions'] as List).length : 0;
    final String detail;
    if (isTest) {
      detail = a.band != null ? 'Parts 1–3 · band ${Store.formatBand(a.band)}' : 'Parts 1–3';
    } else if (a.kind == 'part2' || answers == 0) {
      detail = 'band ${Store.formatBand(a.band)}';
    } else {
      detail = '$answers answer${answers == 1 ? '' : 's'}';
    }
    return <String, dynamic>{
      'id': a.id,
      'part': part,
      'group': a.createdAt.isAfter(weekAgo) ? 'This week' : 'Earlier',
      'title': a.title,
      'meta': '${Store.weekdayDate(a.createdAt)} · $detail',
      'durationSeconds': spokenSecOf(a),
      'audio': a.data['audio'] is List ? a.data['audio'] : <Object>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final store = context.store;
    final attempts = store
        .attemptsFor(skill: Skill.speaking)
        .where((a) => a.kind != 'pronunciation')
        .toList();
    final weekAgo = DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 6));
    final items = [for (final a in attempts) _row(a, weekAgo)];
    if (!_activeSet && items.isNotEmpty) {
      _activeSet = true;
      _activeId = items.first.s('id');
    }
    final totalSec = items.fold<int>(0, (sum, r) => sum + r.i('durationSeconds'));
    final summary = items.isEmpty
        ? 'No recordings yet'
        : '${items.length} recording${items.length == 1 ? '' : 's'} · ${(totalSec / 60).round()} min';
    final filters = _data.l('filters');
    final filterId = _filter < filters.length ? filters[_filter].s('id') : 'all';
    final groups = _data.ls('groups');
    final visible = items
        .where((r) => filterId == 'all' || r.s('part') == filterId)
        .toList();
    final ordered = _oldestFirst ? visible.reversed.toList() : visible;
    final groupOrder = _oldestFirst ? groups.reversed.toList() : groups;

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      gap: 12,
      children: [
        Row(
          children: [
            IconBox(
              icon: AppIcons.back,
              size: 56,
              radius: 20,
              iconSize: 20,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'My Recordings',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    summary,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
            ),
            IconBox(
              icon: AppIcons.sort,
              size: 56,
              radius: 20,
              iconSize: 22,
              tooltip: 'Sort',
              onTap: () {
                setState(() => _oldestFirst = !_oldestFirst);
                context.toast(_oldestFirst ? 'Oldest first' : 'Newest first');
              },
            ),
          ],
        ),
        if (items.isEmpty)
          EmptyState(
            icon: AppIcons.mic,
            title: 'No recordings yet',
            message: 'Your speaking answers are saved here so you can replay them.',
            actionLabel: 'Start speaking practice',
            onAction: () => openHub(context),
          ),
        if (items.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                for (var i = 0; i < filters.length; i++)
                  FlatChip(
                    label: filters[i].s('label'),
                    selected: i == _filter,
                    height: 36,
                    fontSize: 13,
                    bg: i == _filter ? t.text : Colors.transparent,
                    fg: i == _filter ? t.onPrimary : t.textMuted,
                    borderColor: i == _filter ? null : t.border,
                    onTap: () => setState(() => _filter = i),
                  ),
              ],
            ),
          ),
        if (items.isNotEmpty && ordered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No recordings here yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textMuted),
            ),
          ),
        for (final g in groupOrder)
          if (ordered.any((r) => r.s('group') == g))
            AppCard(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(g, style: TextStyle(fontSize: 12, color: t.textMuted)),
                  ),
                  for (final r in ordered.where((r) => r.s('group') == g))
                    _RecordingRow(
                      item: r,
                      active: r.s('id') == _activeId,
                      playing: r.s('id') == _playerFor && (_player?.playing ?? false),
                      progress: r.s('id') == _playerFor ? (_player?.progress ?? 0) : 0,
                      onToggle: () => _toggle(r),
                      onSeek: (f) => _seek(r, f),
                      onDelete: () => _delete(r),
                      onOpen: () => context.push(
                        Routes.speakingEvaluation,
                        args: {'attemptId': r.s('id')},
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({
    required this.item,
    required this.active,
    required this.playing,
    required this.progress,
    required this.onToggle,
    required this.onSeek,
    required this.onDelete,
    required this.onOpen,
  });

  final Map<String, dynamic> item;
  final bool active;
  final bool playing;
  final double progress;
  final VoidCallback onToggle;
  final ValueChanged<double> onSeek;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Row(
        spacing: 12,
        children: [
          IconBox(
            icon: playing ? AppIcons.pause : AppIcons.play,
            size: 44,
            radius: 15,
            iconSize: 18,
            bg: active ? t.primary : t.surfaceAlt2,
            fg: active ? t.onPrimary : t.text,
            tooltip: playing ? 'Pause' : 'Play',
            onTap: onToggle,
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.s('title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    item.s('meta'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                  if (active)
                    LayoutBuilder(
                      builder: (context, box) {
                        void seekAt(double dx) {
                          if (box.maxWidth <= 0) return;
                          onSeek((dx / box.maxWidth).clamp(0.0, 1.0).toDouble());
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => seekAt(d.localPosition.dx),
                          onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: ProgressBar(
                              value: progress,
                              height: 3,
                              track: t.isNight ? t.border : t.track,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Text(
            clockShort(item.i('durationSeconds')),
            style: TextStyle(
              fontSize: 13,
              color: t.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconBox(
            icon: AppIcons.delete,
            size: 36,
            radius: 12,
            iconSize: 18,
            bg: Colors.transparent,
            fg: t.textMuted,
            tooltip: 'Delete recording',
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}
