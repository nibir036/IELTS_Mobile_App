import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// F3 · Listening Interactive Answer Sheet.
///
/// `{'testId': 'lt_01'}` → full test: the 4 parts' recordings play once, one
/// after another; questions 1–40 page by part. `{'setId': 'lb_p1_fn'}` → one
/// set on its own (question-bank sets: 20 questions, 8 formats).
/// Pink of a flagged question (same as the mock test's flags).
const Color kSheetFlag = Color(0xFFFFB8A3);

class ListeningAnswerSheetScreen extends StatefulWidget {
  const ListeningAnswerSheetScreen({super.key});

  @override
  State<ListeningAnswerSheetScreen> createState() =>
      _ListeningAnswerSheetScreenState();
}

class _ListeningAnswerSheetScreenState extends State<ListeningAnswerSheetScreen> {
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};
  Timer? _timer;
  SimAudio? _audio;
  int _audioIndex = -1;
  bool _switching = false;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    // Refreshes the countdown; audio progress comes from [_onAudioTick].
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    final args = context.routeArgs;
    final testId = args['testId'];
    final setId = args['setId'];
    ListeningSession.openSheet(
      testId: testId is String ? testId : null,
      setId: setId is String ? setId : null,
      fresh: args['fresh'] == true,
    );
    // The recording plays once, straight through: no seeking, no replay.
    if (!ListeningSession.sheetAudioDone && ListeningSession.sheetSets.isNotEmpty) {
      _startAudio(ListeningSession.sheetAudioPart, ListeningSession.sheetAudioSeconds);
    }
  }

  void _startAudio(int index, double start) {
    if (!mounted || index < 0 || index >= ListeningSession.sheetSets.length) return;
    _audio?.dispose();
    final set = ListeningSession.sheetSets[index].$1;
    _audioIndex = index;
    _switching = false;
    final audio = SimAudio(
      duration: set.d('durationSeconds'),
      start: start,
      asset: Content.setAudio(set),
      onTick: _onAudioTick,
    );
    _audio = audio;
    audio.play(notify: false);
  }

  void _onAudioTick() {
    final audio = _audio;
    if (!mounted || audio == null || !audio.loaded || _switching) return;
    if (ListeningSession.sheetAudioDone) return;
    if (audio.completed) {
      final next = _audioIndex + 1;
      if (next < ListeningSession.sheetSets.length) {
        _switching = true;
        final ended = _audioIndex;
        setState(() {
          ListeningSession.sheetAudioPart = next;
          ListeningSession.sheetAudioSeconds = 0;
          // Follow the recording to the next part if the student was on the
          // part that just ended.
          if (ListeningSession.sheetPart == ended) _showPart(next);
        });
        ListeningSession.saveSheet();
        // Swap the clip outside its own listener callback.
        Future<void>.microtask(() => _startAudio(next, 0));
        return;
      }
      setState(() {
        ListeningSession.sheetAudioDone = true;
        ListeningSession.sheetAudioSeconds = audio.duration;
      });
      return;
    }
    setState(() => ListeningSession.sheetAudioSeconds = audio.position);
  }

  @override
  void dispose() {
    _timer?.cancel();
    final audio = _audio;
    if (audio != null) {
      if (audio.loaded && !_switching && !ListeningSession.sheetAudioDone) {
        ListeningSession.sheetAudioSeconds = audio.position;
      }
      audio.dispose();
    }
    ListeningSession.saveSheet();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<ListeningItem> get _items => ListeningSession.sheetItems(ListeningSession.sheetPart);

  Map<String, dynamic> get _set {
    final i = ListeningSession.sheetPart;
    final sets = ListeningSession.sheetSets;
    return i >= 0 && i < sets.length ? sets[i].$1 : <String, dynamic>{};
  }

  List<int> get _partNumbers => <int>[
        for (final it in _items) ...it.numbers,
      ];

  bool get _lastPart => ListeningSession.sheetPart >= ListeningSession.sheetSets.length - 1;

  void _showPart(int index) {
    ListeningSession.sheetPart = index;
    final items = ListeningSession.sheetItems(index);
    if (items.isNotEmpty) ListeningSession.sheetCurrent = items.first.number;
  }

  TextEditingController _controllerFor(int n) => _controllers.putIfAbsent(
        n,
        () => TextEditingController(text: ListeningSession.sheetAnswers[n] ?? ''),
      );

  void _select(int n) => setState(() => ListeningSession.sheetCurrent = n);

  /// The item (question, or a pick-2 pair) the student is on.
  ListeningItem? get _currentItem {
    for (final it in _items) {
      if (it.contains(ListeningSession.sheetCurrent)) return it;
    }
    return _items.isEmpty ? null : _items.first;
  }

  bool _isFlagged(ListeningItem it) => it.numbers.any(ListeningSession.sheetFlags.contains);

  /// Flags / unflags the current question.
  void _toggleFlag() {
    final it = _currentItem;
    if (it == null) return;
    setState(() {
      if (_isFlagged(it)) {
        ListeningSession.sheetFlags.removeAll(it.numbers);
      } else {
        ListeningSession.sheetFlags.add(it.number);
      }
    });
    ListeningSession.saveSheet();
  }

  /// Next text gap on this page after [n] (else closes the keyboard).
  void _advance(int n) {
    final text = <int>[
      for (final it in _items)
        if (!it.isChoice) it.number,
    ];
    for (final x in text) {
      if (x > n) {
        _select(x);
        return;
      }
    }
    FocusScope.of(context).unfocus();
  }

  void _nextPart() {
    if (!_lastPart) {
      FocusScope.of(context).unfocus();
      setState(() => _showPart(ListeningSession.sheetPart + 1));
      ListeningSession.saveSheet();
      return;
    }
    _submit();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _audio?.pause();
    final a = ListeningSession.submitSheet();
    context.replace(Routes.listeningResults, args: <String, dynamic>{'attemptId': a.id});
  }

  void _review() {
    final t = context.tk;
    final answers = ListeningSession.sheetAnswers;
    final flagged = <int>[
      for (final it in ListeningSession.sheetAllItems)
        if (_isFlagged(it)) it.number,
    ];
    showAppSheet<void>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          const SizedBox(height: 4),
          const Text('Review answers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Text(
            flagged.isEmpty ? 'No questions flagged' : 'Flagged: ${flagged.map((n) => 'Q$n').join(', ')}',
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
          const SizedBox(height: 6),
          for (final it in _items)
            KeyValueRow(
              '${it.label}  ${itemPrompt(it)}${_isFlagged(it) ? '  (flagged)' : ''}',
              it.type == 'multi'
                  ? (multiChosen(it, answers).isEmpty ? '-' : (multiChosen(it, answers).toList()..sort()).join(', '))
                  : ((answers[it.number] ?? '').trim().isEmpty ? '-' : answers[it.number]!.trim()),
              labelColor: t.textMuted,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final sets = ListeningSession.sheetSets;
    if (sets.isEmpty) {
      return AppScreen(
        gap: 16,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        children: [
          ListeningHeader(title: 'Listening', onLeading: () => context.back()),
          EmptyState(
            title: 'Test not found',
            message: 'This listening test is not available any more.',
            icon: AppIcons.listening,
            actionLabel: 'Open library',
            onAction: () => context.replace(Routes.listeningLibrary),
          ),
        ],
      );
    }
    final set = _set;
    final items = _items;
    final nums = _partNumbers;
    final audio = _audio;
    final done = ListeningSession.sheetAudioDone;
    final audioLoading = !done && (audio == null || audio.loading);

    // Progress across the whole recording (content durations).
    final total = ListeningSession.sheetAudioTotal;
    var before = 0.0;
    for (var i = 0; i < ListeningSession.sheetAudioPart && i < sets.length; i++) {
      before += sets[i].$1.d('durationSeconds');
    }
    var playingIndex = ListeningSession.sheetAudioPart;
    if (playingIndex < 0) playingIndex = 0;
    if (playingIndex > sets.length - 1) playingIndex = sets.length - 1;
    final playingSet = sets[playingIndex].$1;
    final curDur = playingSet.d('durationSeconds');
    final pos = ListeningSession.sheetAudioSeconds.clamp(0.0, curDur > 0 ? curDur : 1.0).toDouble();
    final audioProgress = done ? 1.0 : (total <= 0 ? 0.0 : ((before + pos) / total).clamp(0.0, 1.0).toDouble());
    final audioLabel = done
        ? 'Played once'
        : (audioLoading
            ? 'Loading…'
            : (ListeningSession.sheetIsTest
                ? 'Part ${playingSet.i('part')} playing · once'
                : 'Plays once'));

    final first = nums.isEmpty ? 0 : nums.first;
    final last = nums.isEmpty ? 0 : nums.last;

    // Consecutive items of the same group.
    final groups = <List<ListeningItem>>[];
    for (final it in items) {
      if (groups.isEmpty || groups.last.first.group.s('id') != it.group.s('id')) {
        groups.add(<ListeningItem>[it]);
      } else {
        groups.last.add(it);
      }
    }

    return AppScreen(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Review',
              leading: AppIcons.checklist,
              height: 56,
              radius: 18,
              fontSize: 15,
              expand: true,
              bg: t.surface,
              onTap: _review,
            ),
          ),
          Builder(builder: (context) {
            final it = _currentItem;
            final on = it != null && _isFlagged(it);
            return IconBox(
              icon: AppIcons.flag,
              tooltip: it == null ? 'Flag' : (on ? 'Unflag Q${it.number}' : 'Flag Q${it.number}'),
              size: 56,
              radius: 18,
              iconSize: 22,
              bg: on ? kSheetFlag : t.surface,
              fg: on ? kInk : t.text,
              onTap: it == null ? null : _toggleFlag,
            );
          }),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _lastPart ? 'Submit' : 'Next part',
              trailing: AppIcons.forward,
              height: 56,
              radius: 18,
              fontSize: 15,
              onTap: _nextPart,
            ),
          ),
        ],
      ),
      children: [
        Row(
          spacing: 8,
          children: [
            IconBox(
              icon: AppIcons.back,
              tooltip: 'Back',
              iconSize: 18,
              bg: t.surface,
              onTap: () => context.back(),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showListeningSetInfo(context, set),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Part ${set.i('part')} · Questions $first–$last',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      ListeningSession.sheetIsTest
                          ? '${ListeningSession.sheetTitle} · ${set.s('title')}'
                          : ListeningSession.sheetTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(AppIcons.timer, size: 16, color: t.text),
                  Text(
                    timeLabel(ListeningSession.sheetRemaining.toDouble()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          height: 52,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          decoration: BoxDecoration(
            color: t.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            spacing: 12,
            children: [
              Icon(
                AppIcons.listening,
                size: 20,
                color: t.isNight ? kInk : const Color(0xFFFFD2C4),
              ),
              Expanded(
                child: ProgressBar(
                  value: audioProgress,
                  track: t.isNight ? kInk.withValues(alpha: 0.15) : const Color(0xFF3A3A3A),
                  fill: t.isNight ? kInk : const Color(0xFFFFD2C4),
                ),
              ),
              Text(
                audioLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: t.isNight ? t.heroMuted : const Color(0xFFB5B5B5),
                ),
              ),
            ],
          ),
        ),
        for (final g in groups) _groupCard(g, t),
        // Question chips, ten per row (bank sets have 20 questions).
        Column(
          spacing: 4,
          children: [
            for (var r = 0; r < nums.length; r += 10)
              Row(
                spacing: 4,
                children: [
                  for (var k = r; k < r + 10; k++)
                    Expanded(child: k < nums.length ? _navChip(nums[k], t) : const SizedBox.shrink()),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _groupCard(List<ListeningItem> items, AppTokens t) {
    final g = items.first.group;
    final type = g.s('type');
    final title = g.s('title');
    final instruction = g.s('instruction');
    final range = items.first.number == items.last.last
        ? 'Question ${items.first.number}'
        : 'Questions ${items.first.number}–${items.last.last}';
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            range,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: t.text),
                ),
                if (instruction.isNotEmpty) TextSpan(text: '. $instruction'),
              ],
            ),
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
          if (type == 'form' && g.s('formTitle').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    g.s('formTitle'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (g.s('formSubtitle').isNotEmpty)
                    Text(
                      g.s('formSubtitle'),
                      style: TextStyle(fontSize: 14, color: t.textMuted),
                    ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
          if (type == 'matching') _matchingBox(g, t),
          if (type == 'map' || type == 'table' || type == 'summary')
            ListeningGroupContext(
              group: g,
              answers: ListeningSession.sheetAnswers,
              current: ListeningSession.sheetCurrent,
            ),
          for (final it in items)
            if (it.isChoice) _choice(it, t) else _gapRow(it, t),
        ],
      ),
    );
  }

  Widget _matchingBox(Map<String, dynamic> g, AppTokens t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surfaceAlt2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          for (final o in g.l('options'))
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${o.s('key')}  ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: o.s('text')),
                ],
              ),
              style: TextStyle(fontSize: 13, color: t.isNight ? t.textSoft : t.text),
            ),
        ],
      ),
    );
  }

  Widget _gapRow(ListeningItem it, AppTokens t) {
    final n = it.number;
    final value = (ListeningSession.sheetAnswers[n] ?? '').trim();
    final active = ListeningSession.sheetCurrent == n;
    final state = active
        ? GapState.active
        : (value.isEmpty ? GapState.empty : GapState.filled);
    // form / table rows: label column + before/after; short answers: the
    // question above the box; notes, sentences, summaries: text with a gap.
    final labelled = it.type == 'form' || it.type == 'table';
    final short = it.type == 'short';
    final (before, after) = labelled
        ? (it.q.s('before'), it.q.s('after'))
        : (short ? ('', '') : splitGap(it.q.s('text')));
    return GapLine(
      label: labelled && it.q.s('label').isNotEmpty ? it.q.s('label') : null,
      prompt: short ? it.q.s('text') : null,
      before: before,
      after: after,
      gap: GapBox(
        number: n,
        value: value,
        state: state,
        filledColor: t.isNight ? t.surfaceAlt2 : t.successSoft,
        activeBorder: t.text,
        dashColor: t.isNight ? t.border : const Color(0xFFE0CDC7),
        onTap: active ? null : () => _select(n),
        editor: GapEditor(
          key: ValueKey<int>(n),
          controller: _controllerFor(n),
          onChanged: (v) => ListeningSession.sheetAnswers[n] = v,
          onSubmitted: (_) => _advance(n),
        ),
      ),
    );
  }

  Widget _choice(ListeningItem it, AppTokens t) {
    final answers = ListeningSession.sheetAnswers;
    final n = it.number;
    final multi = it.type == 'multi';
    // Matching and plan labelling: letter chips (the box / plan is above).
    final matching = it.type == 'matching' || it.type == 'map';
    final chosen = multi
        ? multiChosen(it, answers)
        : <String>{(answers[n] ?? '').trim().toUpperCase()};
    void pick(String key) {
      FocusScope.of(context).unfocus();
      setState(() {
        ListeningSession.sheetCurrent = n;
        if (multi) {
          toggleMultiLetter(it, answers, key);
        } else if (chosen.contains(key.toUpperCase())) {
          answers.remove(n);
        } else {
          answers[n] = key;
        }
      });
    }

    final numberStyle = TextStyle(fontSize: 12, color: t.textMuted);
    if (matching) {
      return _tapToSelect(n, Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                _number(it, '$n', numberStyle, t),
                Expanded(child: Text(it.q.s('text'), style: const TextStyle(fontSize: 14))),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in it.options)
                  LetterChip(
                    letter: o.s('key'),
                    selected: chosen.contains(o.s('key').toUpperCase()),
                    onTap: () => pick(o.s('key')),
                  ),
              ],
            ),
          ],
        ),
      ));
    }
    return _tapToSelect(n, Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              _number(it, it.label, numberStyle, t),
              Expanded(child: Text(it.q.s('text'), style: const TextStyle(fontSize: 14, height: 1.35))),
            ],
          ),
          for (final o in it.options)
            ListeningOption(
              letter: o.s('key'),
              text: o.s('text'),
              selected: chosen.contains(o.s('key').toUpperCase()),
              onTap: () => pick(o.s('key')),
            ),
        ],
      ),
    ));
  }

  /// Tapping anywhere on a question makes it the current one (for flagging).
  Widget _tapToSelect(int n, Widget child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (ListeningSession.sheetCurrent != n) _select(n);
        },
        child: child,
      );

  /// Question number: bold when current, with a flag when flagged.
  Widget _number(ListeningItem it, String label, TextStyle style, AppTokens t) {
    final current = it.contains(ListeningSession.sheetCurrent);
    final flagged = _isFlagged(it);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        if (flagged) Icon(AppIcons.flag, size: 12, color: t.isNight ? kSheetFlag : const Color(0xFFD9503A)),
        Text(
          label,
          style: current ? style.copyWith(color: t.text, fontWeight: FontWeight.w700) : style,
        ),
      ],
    );
  }

  Widget _navChip(int n, AppTokens t) {
    final answered = (ListeningSession.sheetAnswers[n] ?? '').trim().isNotEmpty;
    ListeningItem? owner;
    for (final it in _items) {
      if (it.contains(n)) owner = it;
    }
    final current = owner != null && owner.contains(ListeningSession.sheetCurrent);
    final flagged = owner != null && _isFlagged(owner);
    final target = owner == null ? n : owner.number;
    Color bg = t.surface;
    Color fg = t.textMuted;
    BorderSide side = BorderSide.none;
    var weight = FontWeight.w400;
    if (flagged) {
      bg = kSheetFlag;
      fg = kInk;
    } else if (answered) {
      bg = t.primary;
      fg = t.onPrimary;
    }
    if (current) {
      if (!flagged && !answered) fg = t.text;
      side = BorderSide(color: t.text, width: 1.5);
      weight = FontWeight.w600;
    }
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _select(target),
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              '$n',
              maxLines: 1,
              style: TextStyle(fontSize: 13, fontWeight: weight, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
