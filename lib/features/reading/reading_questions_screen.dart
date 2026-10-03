import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'exhibits.dart';
import 'widgets.dart';

/// E3 · Reading Question Panel (questions of the passage on screen).
class ReadingQuestionsScreen extends StatefulWidget {
  const ReadingQuestionsScreen({super.key});

  @override
  State<ReadingQuestionsScreen> createState() => _ReadingQuestionsScreenState();
}

class _ReadingQuestionsScreenState extends State<ReadingQuestionsScreen> {
  Timer? _ticker;
  bool _finished = false;
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};

  /// Heading question whose dropdown list is open.
  int? _openHeading;

  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    // Normally opened from the passage view (no args: keeps that session);
    // {'testId'} / {'passageId'} opens that test or set directly.
    ReadingSession.open(context.routeArgs);
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (ReadingSession.active && ReadingSession.remainingSeconds <= 0) {
        _submitNow(timeUp: true);
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    ReadingSession.save();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int n) => _controllers.putIfAbsent(
        n,
        () => TextEditingController(text: ReadingSession.answers[n] ?? ''),
      );

  void _answer(int n, String value) {
    setState(() {
      ReadingSession.answers[n] = value;
      ReadingSession.current = n;
    });
    ReadingSession.save();
  }

  void _submitNow({bool timeUp = false}) {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
    FocusScope.of(context).unfocus();
    final a = ReadingSession.submit();
    if (timeUp) context.toast('Time is up · answers submitted');
    context.replace(Routes.readingSolution, args: <String, dynamic>{'attemptId': a.id});
  }

  Future<void> _confirmSubmit() async {
    FocusScope.of(context).unfocus();
    final total = ReadingSession.numbers.length;
    final left = total - ReadingSession.answeredCount;
    if (left <= 0) {
      _submitNow();
      return;
    }
    final ok = await showAppDialog<bool>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Text(
              'Submit your answers?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text(
              '$left of $total questions are unanswered. Unanswered questions are marked wrong.',
              style: TextStyle(fontSize: 14, height: 1.4, color: ctx.tk.textMuted),
            ),
            PrimaryButton(
              label: 'Submit',
              height: 50,
              radius: 16,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            SoftButton(
              label: 'Keep working',
              expand: true,
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (!mounted || ok != true) return;
    _submitNow();
  }

  bool get _lastPart => ReadingSession.part >= ReadingSession.partCount - 1;

  void _next() {
    if (_lastPart) {
      _confirmSubmit();
      return;
    }
    FocusScope.of(context).unfocus();
    ReadingSession.showPart(ReadingSession.part + 1);
    ReadingSession.save();
    context.replace(Routes.readingPassage);
  }

  void _showPart(int i) {
    FocusScope.of(context).unfocus();
    setState(() {
      ReadingSession.showPart(i);
      _openHeading = null;
    });
    ReadingSession.save();
  }

  void _toggleFlag() {
    final n = ReadingSession.current;
    setState(() {
      if (ReadingSession.flagged.contains(n)) {
        ReadingSession.flagged.remove(n);
      } else {
        ReadingSession.flagged.add(n);
      }
    });
    ReadingSession.save();
    context.toast(ReadingSession.flagged.contains(n)
        ? 'Question $n flagged for review'
        : 'Flag removed');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final isTest = ReadingSession.isTest;
    final count = ReadingSession.partCount;
    final current = ReadingSession.current;
    final flagged = ReadingSession.flagged.contains(current);
    final part = ReadingSession.part;
    final items = ReadingSession.items;

    return AppScreen(
      key: ValueKey<int>(part),
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: SoftButton(
              label: flagged ? 'Flagged $current' : 'Flag $current',
              leading: flagged ? AppIcons.bookmarkFilled : AppIcons.flag,
              height: 54,
              radius: 18,
              fontSize: 15,
              expand: true,
              bg: t.surface,
              onTap: _toggleFlag,
            ),
          ),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _lastPart ? 'Submit' : 'Next passage',
              trailing: _lastPart ? null : AppIcons.forward,
              height: 54,
              radius: 18,
              fontSize: 15,
              onTap: _next,
            ),
          ),
        ],
      ),
      children: [
        ReadingHeader(
          title: isTest ? 'Passage ${part + 1} of $count' : ReadingRefs.modeLabel(ReadingSession.refId),
          subtitle: isTest ? ReadingSession.title : ReadingSession.passage.s('title'),
          onBack: () => context.back(),
          trailing: TimerPill(seconds: ReadingSession.remainingSeconds),
        ),
        if (isTest && count > 1)
          PassageSwitcher(
            count: count,
            index: part,
            onChanged: _showPart,
            sublabels: <String>[
              for (var i = 0; i < count; i++)
                '${items.where((it) => it.part == i && ReadingSession.isAnswered(it.number)).length}'
                    '/${items.where((it) => it.part == i).length}',
            ],
          ),
        ReadingTabs(
          labels: ['Passage', 'Questions ${ReadingSession.partRange}'],
          index: 1,
          onChanged: (i) {
            if (i == 0) context.replace(Routes.readingPassage);
          },
        ),
        for (final g in ReadingSession.groups) _groupCard(g, t),
      ],
    );
  }

  Widget _groupCard(Map<String, dynamic> g, AppTokens t) {
    final part = ReadingSession.part;
    final gid = g.s('id');
    final qs = <ReadingItem>[
      for (final it in ReadingSession.items)
        if (it.part == part && it.group.s('id') == gid) it,
    ];
    final type = g.s('type');
    final offset = qs.isEmpty ? 0 : qs.first.number - qs.first.local;
    final exhibitKind = type == 'summary' && g.s('text').isEmpty ? '' : type;
    final options = type == 'multi' ? <Map<String, dynamic>>[] : ReadingRefs.optionObjects(g);
    // What a gap shows: the typed words, or "D rodents" for a word-box letter.
    String shown(int n) {
      final v = (ReadingSession.answers[n] ?? '').trim();
      for (final o in options) {
        if (o.s('key') == v) return '$v ${o.s('text')}';
      }
      return v;
    }

    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(
                ReadingRefs.groupRange(ReadingSession.items, part, gid),
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
              Text(
                g.s('title'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              if (g.s('instruction').isNotEmpty)
                Text(
                  g.s('instruction'),
                  style: TextStyle(fontSize: 12, height: 1.35, color: t.textMuted),
                ),
            ],
          ),
          if (type == 'heading') _headingList(g, t),
          if (g.m('example').isNotEmpty)
            Text(
              'Example: ${g.m('example').s('text')} → ${g.m('example').s('answer')}',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: t.textMuted),
            ),
          if (kExhibitKinds.contains(exhibitKind))
            ReadingExhibit(
              kind: exhibitKind,
              data: g,
              offset: offset,
              filled: <int, String>{
                for (final it in qs) it.number: shown(it.number),
              },
              current: ReadingSession.current,
              image: ReadingSession.passage.s('diagram'),
              showTitle: false,
            ),
          if (options.isNotEmpty)
            OptionBox(title: ReadingRefs.optionsTitle(g), options: options),
          for (final it in qs)
            if (it.type != 'multi' || it.slot == 0) _question(it, g, t),
        ],
      ),
    );
  }

  Widget _question(ReadingItem it, Map<String, dynamic> g, AppTokens t) {
    switch (it.type) {
      case 'tfng':
      case 'ynng':
        return _choiceRow(it, g.ls('options'), t);
      case 'heading':
        return _heading(it, g, t);
      case 'mcq':
        return _mcq(it, t);
      case 'multi':
        return _multi(it, t);
      default:
        // Plain letters (matching info), lettered lists (features, endings,
        // word boxes) or a typed answer.
        final letters = ReadingRefs.letters(it);
        if (letters.isNotEmpty) return _matching(it, letters, t);
        return _gap(it, t);
    }
  }

  Widget _prompt(ReadingItem it) {
    final n = it.number;
    final nums = it.siblingNumbers;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: nums.length > 1 ? '${nums.first}–${nums.last}' : '$n',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (ReadingSession.flagged.contains(n))
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(AppIcons.bookmarkFilled, size: 14),
              ),
            ),
          TextSpan(text: '  ${ReadingRefs.questionText(it)}'),
        ],
      ),
      style: const TextStyle(fontSize: 14, height: 1.4),
    );
  }

  /// "Choose TWO letters": tick up to as many options as the question has
  /// numbers; the chosen letters fill those numbers in A→Z order.
  Widget _multi(ReadingItem it, AppTokens t) {
    final nums = it.siblingNumbers;
    final chosen = <String>{
      for (final n in nums)
        if ((ReadingSession.answers[n] ?? '').trim().isNotEmpty) ReadingSession.answers[n]!.trim(),
    };
    void toggle(String key) {
      final next = <String>{...chosen};
      if (next.contains(key)) {
        next.remove(key);
      } else if (next.length < nums.length) {
        next.add(key);
      } else {
        context.toast('Choose ${nums.length} letters · untick one first');
        return;
      }
      final sorted = next.toList()..sort();
      setState(() {
        for (var i = 0; i < nums.length; i++) {
          ReadingSession.answers[nums[i]] = i < sorted.length ? sorted[i] : '';
        }
        ReadingSession.current = nums.first;
      });
      ReadingSession.save();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _prompt(it),
        Text(
          '${chosen.length} of ${nums.length} chosen',
          style: TextStyle(fontSize: 12, color: t.textMuted),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (final o in it.q.l('options'))
              InkWell(
                onTap: () => toggle(o.s('key')),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: chosen.contains(o.s('key')) ? t.text : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: chosen.contains(o.s('key'))
                                ? t.text
                                : (t.isNight ? t.border : const Color(0xFFD8CCD3)),
                            width: 2,
                          ),
                        ),
                        child: chosen.contains(o.s('key'))
                            ? Icon(AppIcons.check, size: 14, color: t.surface)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          '${o.s('key')}  ${o.s('text')}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _choiceRow(ReadingItem it, List<String> options, AppTokens t) {
    final n = it.number;
    final chosen = ReadingSession.answers[n] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _prompt(it),
        Row(
          spacing: 6,
          children: [
            for (final o in options)
              Expanded(
                child: Material(
                  color: o == chosen
                      ? t.primary
                      : (t.isNight ? t.surfaceAlt2 : t.surface),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: o == chosen ? BorderSide.none : BorderSide(color: t.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _answer(n, o),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          o,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: o == chosen ? FontWeight.w500 : FontWeight.w400,
                            color: o == chosen ? t.onPrimary : t.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _matching(ReadingItem it, List<String> letters, AppTokens t) {
    final n = it.number;
    final chosen = ReadingSession.answers[n] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _prompt(it),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in letters)
              Material(
                color: o == chosen
                    ? t.primary
                    : (t.isNight ? t.surfaceAlt2 : t.surface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: o == chosen ? BorderSide.none : BorderSide(color: t.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _answer(n, o),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Text(
                        o,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: o == chosen ? FontWeight.w600 : FontWeight.w400,
                          color: o == chosen ? t.onPrimary : t.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// The list of headings shown once above the heading questions.
  Widget _headingList(Map<String, dynamic> g, AppTokens t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.isNight ? t.surfaceAlt2 : const Color(0xFFF8F3F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text('List of headings', style: TextStyle(fontSize: 12, color: t.textMuted)),
          for (final h in g.l('headings'))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    h.s('key'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    h.s('text'),
                    style: TextStyle(fontSize: 13, height: 1.35, color: t.textSoft),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _heading(ReadingItem it, Map<String, dynamic> g, AppTokens t) {
    final n = it.number;
    final chosen = ReadingSession.answers[n] ?? '';
    final headings = g.l('headings');
    var chosenText = 'Choose a heading';
    for (final h in headings) {
      if (h.s('key') == chosen) chosenText = '${h.s('key')}  ${h.s('text')}';
    }
    final open = _openHeading == n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 10,
          children: [
            SizedBox(
              width: 104,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$n', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: '  ${it.q.s('text')}'),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: open ? t.text : t.border,
                    width: open ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() {
                    _openHeading = open ? null : n;
                    ReadingSession.current = n;
                  }),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      spacing: 6,
                      children: [
                        Expanded(
                          child: Text(
                            chosenText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: chosen.isEmpty ? t.textMuted : t.text,
                            ),
                          ),
                        ),
                        Icon(
                          open ? AppIcons.chevronUp : AppIcons.chevronDown,
                          size: 18,
                          color: t.text,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (open)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: t.isNight ? t.surfaceAlt2 : const Color(0xFFF8F3F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final h in headings)
                  Material(
                    color: h.s('key') == chosen ? kLavender : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        _answer(n, h.s('key'));
                        setState(() => _openHeading = null);
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 38),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          spacing: 10,
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                h.s('key'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: h.s('key') == chosen ? kInk : t.text,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                h.s('text'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: h.s('key') == chosen ? kInk : t.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mcq(ReadingItem it, AppTokens t) {
    final n = it.number;
    final chosen = ReadingSession.answers[n] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _prompt(it),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (final o in it.q.l('options'))
              InkWell(
                onTap: () => _answer(n, o.s('key')),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    spacing: 10,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: o.s('key') == chosen
                                ? t.text
                                : (t.isNight ? t.border : const Color(0xFFD8CCD3)),
                            width: o.s('key') == chosen ? 6 : 2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${o.s('key')}  ${o.s('text')}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _gap(ReadingItem it, AppTokens t) {
    final n = it.number;
    final active = ReadingSession.current == n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        _prompt(it),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.isNight ? t.surfaceAlt2 : t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? t.text : t.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controllerFor(n),
                  onTap: () => setState(() => ReadingSession.current = n),
                  onChanged: (v) {
                    ReadingSession.answers[n] = v;
                    ReadingSession.current = n;
                  },
                  onEditingComplete: () {
                    ReadingSession.save();
                    FocusScope.of(context).nextFocus();
                  },
                  textInputAction: TextInputAction.next,
                  style: TextStyle(fontSize: 14, color: t.text),
                  cursorColor: t.alert,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Type your answer',
                    hintStyle: TextStyle(fontSize: 14, color: t.textFaint),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
