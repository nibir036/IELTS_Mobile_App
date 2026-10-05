import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Question list shared by Writing (Task 1 / Task 2) and Speaking (Part 1 / 2 /
// 3): search, a type/category filter, a status filter (All · Not done · Done),
// "Random question" (a not-done one from the current filter) and the list -
// the same way Listening part practice and the Reading question bank work.
// ─────────────────────────────────────────────────────────────────────────────

/// One row of a [QuestionBrowser].
class QuestionItem {
  const QuestionItem({
    required this.id,
    required this.title,
    this.detail = '',
    this.group = '',
    this.done = false,
    this.status = '',
    this.search = '',
  });

  final String id;
  final String title;

  /// Second line before the status ("Line graph", "Education · Moderate" …).
  final String detail;

  /// Type / category label the filter chips use.
  final String group;
  final bool done;

  /// "Band 6.5 · 3 Oct" or "Not started".
  final String status;

  /// Extra text matched by the search box (question text, bullets …).
  final String search;
}

class QuestionBrowser extends StatefulWidget {
  const QuestionBrowser({
    super.key,
    required this.items,
    required this.onOpen,
    this.groups = const <String>[],
    this.groupAllLabel = 'All types',
    this.searchHint = 'Search',
    this.noun = 'question',
  });

  final List<QuestionItem> items;
  final ValueChanged<QuestionItem> onOpen;

  /// Filter chips after [groupAllLabel]; empty = no type filter.
  final List<String> groups;
  final String groupAllLabel;
  final String searchHint;

  /// "question", "topic", "cue card" (for counts and the empty state).
  final String noun;

  @override
  State<QuestionBrowser> createState() => _QuestionBrowserState();
}

class _QuestionBrowserState extends State<QuestionBrowser> {
  static const _pageSize = 25;
  final TextEditingController _search = TextEditingController();
  final Random _random = Random();
  String _query = '';
  int _group = 0;

  /// 0 all · 1 not done · 2 done
  int _status = 0;
  int _shown = _pageSize;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _plural(int n) => '$n ${widget.noun}${n == 1 ? '' : 's'}';

  List<QuestionItem> _filtered({bool withStatus = true}) {
    final q = _query.trim().toLowerCase();
    final group = _group > 0 && _group <= widget.groups.length ? widget.groups[_group - 1] : '';
    return widget.items.where((it) {
      if (group.isNotEmpty && it.group != group) return false;
      if (withStatus && _status == 1 && it.done) return false;
      if (withStatus && _status == 2 && !it.done) return false;
      if (q.isEmpty) return true;
      return it.title.toLowerCase().contains(q) ||
          it.detail.toLowerCase().contains(q) ||
          it.group.toLowerCase().contains(q) ||
          it.search.toLowerCase().contains(q);
    }).toList();
  }

  /// Opens a random question of the current filter, preferring ones not done yet.
  void _openRandom() {
    final pool = _filtered();
    final fresh = pool.where((it) => !it.done).toList();
    final from = fresh.isNotEmpty ? fresh : pool;
    if (from.isEmpty) {
      context.toast('No ${widget.noun}s match this filter');
      return;
    }
    widget.onOpen(from[_random.nextInt(from.length)]);
  }

  void _reset(VoidCallback change) => setState(() {
        change();
        _shown = _pageSize;
      });

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final base = _filtered(withStatus: false);
    final doneCount = base.where((it) => it.done).length;
    final list = _filtered();
    final visible = list.take(_shown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        PrimaryButton(
          label: 'Random ${widget.noun}',
          leading: AppIcons.shuffle,
          height: 52,
          onTap: _openRandom,
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            spacing: 10,
            children: [
              Icon(AppIcons.search, size: 20, color: t.textMuted),
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (v) => _reset(() => _query = v),
                  textInputAction: TextInputAction.search,
                  style: TextStyle(fontSize: 14, color: t.text),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.searchHint,
                    hintStyle: TextStyle(fontSize: 14, color: t.textFaint),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    _search.clear();
                    _reset(() => _query = '');
                  },
                  child: Icon(AppIcons.close, size: 18, color: t.textMuted),
                ),
            ],
          ),
        ),
        if (widget.groups.length > 1)
          ChipRow(
            labels: <String>[widget.groupAllLabel, ...widget.groups],
            selected: _group,
            onChanged: (i) => _reset(() => _group = i),
          ),
        ChipRow(
          labels: <String>[
            'All · ${base.length}',
            'Not done · ${base.length - doneCount}',
            'Done · $doneCount',
          ],
          selected: _status,
          onChanged: (i) => _reset(() => _status = i),
        ),
        Text(
          list.isEmpty ? 'No ${widget.noun}s found' : _plural(list.length),
          style: TextStyle(fontSize: 13, color: t.textMuted),
        ),
        for (final it in visible) _QuestionRow(item: it, onTap: () => widget.onOpen(it)),
        if (list.length > visible.length)
          SoftButton(
            label: 'Show more · ${list.length - visible.length} left',
            height: 48,
            expand: true,
            onTap: () => setState(() => _shown += _pageSize),
          ),
      ],
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.item, required this.onTap});

  final QuestionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final second = <String>[
      if (item.detail.isNotEmpty) item.detail,
      if (item.status.isNotEmpty) item.status,
    ].join(' · ');
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      onTap: onTap,
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3),
                ),
                if (second.isNotEmpty)
                  Text(
                    second,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
              ],
            ),
          ),
          if (item.done)
            Icon(AppIcons.checkCircle, size: 20, color: t.success)
          else
            Icon(AppIcons.chevronRight, size: 18, color: t.textMuted),
        ],
      ),
    );
  }
}
