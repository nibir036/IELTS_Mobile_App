import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';
import 'writing_data.dart';

/// C7 · Sentence Builder Drill (Writing Booster).
///
/// Finishing the set records an Attempt (skill writing, kind 'drill',
/// score = drills right first time, band null). Opened with
/// `args['attemptId']` it shows that result.
class SentenceBuilderScreen extends StatefulWidget {
  const SentenceBuilderScreen({super.key});

  @override
  State<SentenceBuilderScreen> createState() => _SentenceBuilderScreenState();
}

class _SentenceBuilderScreenState extends State<SentenceBuilderScreen> {
  late final Map<String, dynamic> _data =
      WritingContent.all.m('sentenceBuilder');
  late final List<Map<String, dynamic>> _drills = _data.l('drills');
  int _drill = 0;
  List<String> _placed = <String>[];
  List<String> _bank = <String>[];
  final Map<String, bool> _firstTry = <String, bool>{};
  final DateTime _started = DateTime.now();
  Attempt? _result;
  bool _inited = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    final id = context.routeArgs['attemptId'];
    if (id is String) {
      final a = Store.I.attemptById(id);
      if (a != null && a.kind == 'drill') _result = a;
    }
  }

  Map<String, dynamic> get _current =>
      _drills.isEmpty ? <String, dynamic>{} : _drills[_drill];

  void _load() {
    final d = _current;
    final answer = d.ls('answer');
    final pre = d.i('prefilled').clamp(0, answer.length);
    _placed = answer.sublist(0, pre);
    _bank = List<String>.from(d.ls('bank'));
  }

  void _add(int i) {
    setState(() {
      _placed.add(_bank.removeAt(i));
    });
  }

  void _remove(int i) {
    final pre = _current.i('prefilled');
    if (i < pre) return;
    setState(() {
      _bank.add(_placed.removeAt(i));
    });
  }

  void _check() {
    final answer = _current.ls('answer');
    if (_placed.length < answer.length) {
      context.toast('Fill every slot first');
      return;
    }
    final id = _current.s('id');
    final ok = _placed.join(' ') == answer.join(' ');
    _firstTry.putIfAbsent(id, () => ok);
    if (!ok) {
      context.toast('Not quite — try a different order');
      return;
    }
    if (_drill + 1 < _drills.length) {
      context.toast('Correct!');
      setState(() {
        _drill++;
        _load();
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    final secs = DateTime.now().difference(_started).inSeconds;
    final correct = _firstTry.values.where((v) => v).length;
    final a = Attempt(
      id: Store.newId('att'),
      skill: Skill.writing,
      kind: 'drill',
      title: _data.s('category'),
      refId: _data.s('setId'),
      score: correct,
      total: _drills.length,
      durationSec: secs < 60 ? 60 : secs,
      createdAt: DateTime.now(),
      data: <String, dynamic>{
        'results': [
          for (final d in _drills)
            <String, dynamic>{
              'id': d.s('id'),
              'correct': _firstTry[d.s('id')] == true,
            },
        ],
      },
    );
    Store.I.addAttempt(a);
    setState(() => _result = a);
  }

  void _restart() {
    setState(() {
      _result = null;
      _drill = 0;
      _firstTry.clear();
      _load();
    });
  }

  Widget _resultView(Attempt a) {
    final t = context.tk;
    final score = a.score ?? 0;
    final total = a.total ?? _drills.length;
    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 16,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: WFlatButton(
              label: 'Writing home',
              bg: t.surface,
              fg: t.text,
              onTap: () => context.replace(Routes.writingSelector),
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: 'Practice again',
              height: 56,
              radius: 18,
              fontSize: 15,
              onTap: _restart,
            ),
          ),
        ],
      ),
      children: [
        WHeader(title: 'Writing Booster'),
        HeroCard(
          radius: 28,
          padding: const EdgeInsets.all(20),
          gradient: t.isNight ? null : wGradient(0xFFD6D8FA, 0xFFEEEFFD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                a.title,
                style: TextStyle(fontSize: 13, color: t.heroMuted),
              ),
              Text(
                '$score/$total',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w300,
                  height: 1,
                  color: t.heroText,
                ),
              ),
              Text(
                'sentences right first time · ${Store.relativeDay(a.createdAt)}',
                style: TextStyle(fontSize: 13, color: t.heroMuted),
              ),
              const SizedBox(height: 6),
              ProgressBar(value: total == 0 ? 0 : score / total, onHero: true),
            ],
          ),
        ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in a.data.l('results'))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    spacing: 10,
                    children: [
                      Icon(
                        r.b('correct') ? AppIcons.checkCircle : AppIcons.replay,
                        size: 18,
                        color: r.b('correct') ? t.text : t.textMuted,
                      ),
                      Expanded(
                        child: Text(
                          _labelFor(r.s('id')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        r.b('correct') ? 'First try' : 'Retried',
                        style: TextStyle(fontSize: 12, color: t.textMuted),
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

  String _labelFor(String id) {
    for (final d in _drills) {
      if (d.s('id') == id) {
        return 'Use “${d.s('connector')}” · ${d.s('function')}';
      }
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) return _resultView(result);
    final t = context.tk;
    final d = _current;
    final total = _drills.isEmpty ? 1 : _drills.length;
    final number = _drill + 1;
    final answer = d.ls('answer');
    final empty = (answer.length - _placed.length).clamp(0, 99);
    final sentences = d.ls('sentences');

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      gap: 16,
      footerPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      footer: Row(
        spacing: 8,
        children: [
          IconBox(
            icon: AppIcons.bulb,
            size: 56,
            radius: 18,
            iconSize: 22,
            bg: t.surface,
            tooltip: 'Hint',
            onTap: () => context.toast(d.s('hint')),
          ),
          Expanded(
            child: PrimaryButton(
              label: 'Check sentence',
              height: 56,
              radius: 18,
              onTap: _check,
            ),
          ),
        ],
      ),
      children: [
        Row(
          spacing: 12,
          children: [
            IconBox(
              icon: AppIcons.back,
              iconSize: 18,
              tooltip: 'Back',
              onTap: () => context.back(),
            ),
            Expanded(
              child: ProgressBar(
                value: number / total,
                height: 8,
                track: wc(t, 0xFFE6DAE1, 0xFF151515),
              ),
            ),
            Text(
              '$number/$total',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              _data.s('category'),
              style: TextStyle(fontSize: 13, color: t.textMuted),
            ),
            Text(
              d.s('instruction'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
          ],
        ),
        HeroCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          gradient: t.isNight ? null : wGradient(0xFFD6D8FA, 0xFFEEEFFD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  WPill(
                    'Use: ${d.s('connector')}',
                    bg: const Color(0xFF151515),
                    fg: const Color(0xFFFFFFFF),
                  ),
                  Text(
                    d.s('function'),
                    style: TextStyle(
                      fontSize: 12,
                      color: t.isNight
                          ? t.heroMuted
                          : const Color(0xFF4F4A6B),
                    ),
                  ),
                ],
              ),
              for (var i = 0; i < sentences.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        color: t.isNight
                            ? t.heroMuted
                            : const Color(0xFF4F4A6B),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        sentences[i],
                        style: TextStyle(fontSize: 16, color: t.heroText),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        DashedBox(
          color: wc(t, 0xFFE3D6DE, 0xFF2B2B2B),
          fill: t.surface,
          radius: 26,
          strokeWidth: 2,
          dash: 7,
          gap: 5,
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 114),
            child: Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _placed.length; i++)
                    _Word(
                      text: _placed[i],
                      height: 44,
                      radius: 14,
                      bg: t.primary,
                      fg: t.onPrimary,
                      onTap: () => _remove(i),
                    ),
                  for (var i = 0; i < empty; i++)
                    if (i == 0)
                      Container(
                        width: 96,
                        height: 44,
                        decoration: BoxDecoration(
                          color: wc(t, 0xFFFDF1F5, 0xFF1F1F1F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: wc(t, 0xFFF4B8CB, 0xFF5C2A20),
                            width: 2,
                          ),
                        ),
                      )
                    else
                      DashedBox(
                        width: 70,
                        height: 44,
                        radius: 14,
                        color: wc(t, 0xFFD8CCD3, 0xFF2B2B2B),
                      ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Tap words to add them',
            style: TextStyle(fontSize: 13, color: t.textMuted),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _bank.length; i++)
              _Word(
                text: _bank[i],
                height: 48,
                radius: 16,
                bg: t.surface,
                fg: t.text,
                border: t.border,
                padH: 16,
                onTap: () => _add(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.text,
    required this.height,
    required this.radius,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.border,
    this.padH = 14,
  });

  final String text;
  final double height;
  final double radius;
  final Color bg;
  final Color fg;
  final Color? border;
  final double padH;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: border == null ? BorderSide.none : BorderSide(color: border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padH),
            child: Center(
              widthFactor: 1,
              child: Text(text, style: TextStyle(fontSize: 15, color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}
