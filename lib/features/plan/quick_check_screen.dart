import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/services/api_client.dart';
import '../../app/services/tts.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'plan_api.dart';
import 'plan_setup_screen.dart';
import 'quick_check_data.dart';

/// Optional quick check (about 8 minutes): grammar and vocabulary, plus
/// reading, listening and one paragraph for the modules in the plan. The
/// bands go to the server, which re-plans. Pops with `true` when saved.
/// Args: `{'modules': [...]}` (default: all four).
class QuickCheckScreen extends StatefulWidget {
  const QuickCheckScreen({super.key});

  @override
  State<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

enum _Stage { intro, questions, writing, result }

class _QuickCheckScreenState extends State<QuickCheckScreen> {
  _Stage _stage = _Stage.intro;
  List<Map<String, Object>> _asked = <Map<String, Object>>[];
  final Map<String, List<int>> _order = <String, List<int>>{};
  final Map<String, int> _chosen = <String, int>{};
  int _i = 0;
  bool _withWriting = false;
  bool _seeded = false;
  bool _busy = false;
  final TextEditingController _text = TextEditingController();
  Map<String, dynamic>? _writing;
  String? _writingError;
  Map<String, dynamic> _result = <String, dynamic>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final raw = context.routeArgs['modules'];
    final mods = raw is List ? raw.map((e) => '$e').toSet() : PlanApi.modules.toSet();
    _asked = QuickCheckData.items.where((it) {
      final sec = it['section']! as String;
      return sec == 'grammar' || sec == 'vocab' || mods.contains(sec);
    }).toList();
    _withWriting = mods.contains('writing');
    final rnd = math.Random(DateTime.now().millisecondsSinceEpoch);
    for (final it in _asked) {
      _order[it['id']! as String] = List<int>.generate((it['options']! as List).length, (k) => k)..shuffle(rnd);
    }
  }

  @override
  void dispose() {
    Tts.I.stop();
    _text.dispose();
    super.dispose();
  }

  int get _words => _text.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  void _pick(int option) {
    final id = _asked[_i]['id']! as String;
    setState(() => _chosen[id] = option);
  }

  void _next() {
    Tts.I.stop();
    if (_i + 1 < _asked.length) {
      setState(() => _i++);
    } else if (_withWriting) {
      setState(() => _stage = _Stage.writing);
    } else {
      _finish();
    }
  }

  Future<void> _scoreWriting() async {
    setState(() {
      _busy = true;
      _writingError = null;
    });
    try {
      _writing = await PlanApi.scoreParagraph(QuickCheckData.writingQuestion, _text.text.trim());
      await _finish();
    } on ApiException catch (e) {
      setState(() => _writingError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final bands = <String, dynamic>{};
    for (final sec in <String>['grammar', 'vocab', 'reading', 'listening']) {
      final asked = _asked.where((it) => it['section'] == sec).toList();
      if (asked.isNotEmpty) bands[sec] = QuickCheckData.band(asked, _chosen);
    }
    if (_writing != null) {
      bands['writing'] = <String, dynamic>{'band': _writing!['band'], 'criteria': _writing!['criteria']};
    }
    setState(() {
      _busy = true;
      _result = bands;
    });
    try {
      await PlanApi.saveQuickCheck(bands);
      if (mounted) setState(() => _stage = _Stage.result);
    } on ApiException catch (e) {
      if (mounted) context.toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlanApi.available) return const PlanSignInNeeded();
    return switch (_stage) {
      _Stage.intro => _intro(context),
      _Stage.questions => _question(context),
      _Stage.writing => _writingStep(context),
      _Stage.result => _resultStep(context),
    };
  }

  Widget _intro(BuildContext context) {
    final t = context.tk;
    final sections = <String>{for (final it in _asked) it['section']! as String, if (_withWriting) 'writing'};
    return AppScreen(
      gap: 16,
      footer: PrimaryButton(label: 'Start', trailing: AppIcons.forward, onTap: () => setState(() => _stage = _Stage.questions)),
      children: [
        TopBar(title: 'Quick check', subtitle: 'About ${_withWriting ? 10 : 6} minutes', onBack: () => context.back()),
        const Text('Get a sharper plan', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.2)),
        Text(
          '${_asked.length} short questions${_withWriting ? ' and one paragraph' : ''}. '
          'Your plan then starts from what you can do, not just your own guess.',
          style: TextStyle(fontSize: 14, height: 1.4, color: t.textMuted),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in sections) Tag(QuickCheckData.sectionLabels[s] ?? s, tone: TagTone.soft)],
        ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: Row(
            spacing: 12,
            children: [
              Icon(AppIcons.info, color: t.peach),
              Expanded(
                child: Text(
                  'No score is saved to your history. Do not look anything up; a guess is fine. '
                  'Listening questions are read aloud, so turn your sound on.',
                  style: TextStyle(fontSize: 13, height: 1.35, color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _question(BuildContext context) {
    final t = context.tk;
    final it = _asked[_i];
    final id = it['id']! as String;
    final options = (it['options']! as List).cast<String>();
    final order = _order[id]!;
    final sec = it['section']! as String;
    final text = it['text'] as String?;
    final say = it['say'] as String?;
    return AppScreen(
      gap: 14,
      footer: PrimaryButton(
        label: _busy ? 'Saving…' : (_i + 1 < _asked.length || _withWriting ? 'Next' : 'Finish'),
        enabled: _chosen.containsKey(id) && !_busy,
        onTap: _chosen.containsKey(id) && !_busy ? _next : null,
      ),
      children: [
        TopBar(
          title: 'Quick check',
          subtitle: 'Question ${_i + 1} of ${_asked.length}',
          onBack: () => setState(() {
            if (_i == 0) {
              _stage = _Stage.intro;
            } else {
              _i--;
            }
          }),
        ),
        ProgressBar(value: (_i + 1) / (_asked.length + (_withWriting ? 1 : 0)), height: 6),
        Align(alignment: Alignment.centerLeft, child: Tag(QuickCheckData.sectionLabels[sec] ?? sec)),
        if (text != null)
          AppCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.5)),
          ),
        if (say != null)
          ValueListenableBuilder<String?>(
            valueListenable: Tts.I.speaking,
            builder: (context, now, _) => OutlineButtonX(
              label: now == say ? 'Playing…' : 'Play the recording',
              leading: now == say ? AppIcons.volume : AppIcons.play,
              radius: 999,
              height: 52,
              onTap: () => Tts.I.speak(say),
            ),
          ),
        Text(it['q']! as String, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35)),
        for (final k in order)
          OptionTile(
            label: options[k],
            selected: _chosen[id] == k,
            onTap: () => _pick(k),
          ),
        if (say != null)
          Text('You can play it again if you need to.', style: TextStyle(fontSize: 12, color: t.textMuted)),
      ],
    );
  }

  Widget _writingStep(BuildContext context) {
    final t = context.tk;
    final n = _words;
    return AppScreen(
      gap: 14,
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: OutlineButtonX(label: 'Skip', radius: 999, height: 56, onTap: _busy ? null : () => _finish()),
          ),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _busy ? 'Scoring…' : 'Score my paragraph',
              enabled: n >= 30 && !_busy,
              onTap: n >= 30 && !_busy ? _scoreWriting : null,
            ),
          ),
        ],
      ),
      children: [
        TopBar(title: 'Quick check', subtitle: 'Last step: one paragraph', onBack: () => setState(() => _stage = _Stage.questions)),
        ProgressBar(value: 1, height: 6),
        const Align(alignment: Alignment.centerLeft, child: Tag('Writing')),
        Text(QuickCheckData.writingQuestion, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
        TextField(
          controller: _text,
          minLines: 7,
          maxLines: 12,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Write your paragraph here…',
            filled: true,
            fillColor: t.surfaceAlt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        Text(
          '$n words${n < 30 ? ' · at least 30' : ''}',
          style: TextStyle(fontSize: 12.5, color: n < 30 ? t.textMuted : t.text),
        ),
        if (_writingError != null)
          Text(
            '$_writingError You can skip this step; your plan still uses the other answers.',
            style: TextStyle(fontSize: 13, color: t.alert),
          ),
      ],
    );
  }

  /// Back to where the check was opened from; when the check is the only
  /// screen (web reload / hot restart on its address), open the plan instead.
  void _done() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(true);
    } else {
      nav.pushReplacementNamed(Routes.studyPlan);
    }
  }

  bool _showAnswers = false;

  String _band(double b, {bool capped = false}) => capped && b >= 8 ? '8.0+' : Store.formatBand(b);

  double? get _target {
    final p = PlanApi.current.value;
    final v = p == null ? null : (p['inputs'] as Map?)?['targetBand'];
    if (v is num) return v.toDouble();
    return Store.I.current?.targetBand;
  }

  Widget _resultStep(BuildContext context) {
    final t = context.tk;
    final sections = <String>['grammar', 'vocab', 'reading', 'listening'].where((k) => _result[k] is num).toList();
    final w = _writing;
    final bands = <String, double>{
      for (final k in sections) k: (_result[k] as num).toDouble(),
      if (w != null && w['band'] is num) 'writing': (w['band'] as num).toDouble(),
    };
    final overall = bands.isEmpty ? 0.0 : Store.roundBand(bands.values.reduce((a, b) => a + b) / bands.length);
    final target = _target;
    final weakest = (bands.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
        .take(2)
        .where((e) => bands.length > 1 && e.value < (target ?? 9))
        .map((e) => QuickCheckData.sectionLabels[e.key] ?? e.key)
        .toList();
    final gap = target == null ? null : target - overall;

    return AppScreen(
      gap: 14,
      footer: PrimaryButton(label: 'Done', onTap: _done),
      children: [
        TopBar(title: 'Quick check results', subtitle: 'Saved to your plan', showBack: false),
        HeroCard(
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text('YOUR STARTING POINT', style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: t.peach, fontWeight: FontWeight.w600)),
              Text(
                'About band ${_band(overall, capped: true)} overall',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: t.heroText),
              ),
              if (gap != null)
                Text(
                  gap <= 0
                      ? 'At or above your target of ${Store.formatBand(target)}. The plan keeps you sharp and works on exam technique.'
                      : 'Your target is ${Store.formatBand(target)}: about ${gap.toStringAsFixed(1)} band to go.',
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: t.heroText),
                ),
              Text(
                'Rough estimates from a short check (the average of the sections below). They get more accurate as you practise.',
                style: TextStyle(fontSize: 12, height: 1.4, color: t.heroMuted),
              ),
            ],
          ),
        ),
        for (final k in sections) _sectionCard(context, k, bands[k]!, target),
        if (w != null && w['band'] is num) _writingCard(context, w, target),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                spacing: 10,
                children: [
                  Icon(AppIcons.calendar, color: t.peach, size: 20),
                  const Expanded(child: Text('What happens next', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600))),
                ],
              ),
              Text(
                weakest.isEmpty
                    ? 'Your study plan has been rebuilt from these results: courses start at your level and the time split follows your scores.'
                    : 'Your study plan has been rebuilt from these results. It puts extra time on ${weakest.join(' and ')}, and courses start at your level.',
                style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textMuted),
              ),
            ],
          ),
        ),
        AppCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          onTap: () => setState(() => _showAnswers = !_showAnswers),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_showAnswers ? 'Hide' : 'Review'} your answers (${_asked.where((it) => _chosen[it['id']] == it['answer']).length} of ${_asked.length} correct)',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(_showAnswers ? AppIcons.chevronUp : AppIcons.chevronDown, color: t.textMuted),
            ],
          ),
        ),
        if (_showAnswers)
          for (final it in _asked) _answerRow(context, it),
      ],
    );
  }

  Widget _sectionCard(BuildContext context, String key, double band, double? target) {
    final t = context.tk;
    final asked = _asked.where((it) => it['section'] == key).toList();
    final right = asked.where((it) => _chosen[it['id']] == it['answer']).length;
    final missed = asked.where((it) => _chosen[it['id']] != it['answer']).map((it) => it['focus']! as String).toList();
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(QuickCheckData.sectionLabels[key] ?? key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('$right of ${asked.length} correct', style: TextStyle(fontSize: 12.5, color: t.textMuted)),
                  ],
                ),
              ),
              Text('about ${_band(band, capped: true)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          _bandBar(context, band, target),
          Text(QuickCheckData.meaning(band), style: TextStyle(fontSize: 13, height: 1.4, color: t.textMuted)),
          if (missed.isEmpty)
            Text('Nothing missed in this section.', style: TextStyle(fontSize: 12.5, color: t.success, fontWeight: FontWeight.w600))
          else ...[
            Text('To work on', style: TextStyle(fontSize: 12, color: t.textMuted, fontWeight: FontWeight.w600)),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final m in missed) Tag(m, tone: TagTone.accent, height: 24, fontSize: 11.5)]),
          ],
        ],
      ),
    );
  }

  Widget _writingCard(BuildContext context, Map<String, dynamic> w, double? target) {
    final t = context.tk;
    final band = (w['band'] as num).toDouble();
    final crit = (w['criteria'] as Map?) ?? const <String, dynamic>{};
    final feedback = w['feedback'];
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Writing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('Your paragraph, scored on the four IELTS criteria', style: TextStyle(fontSize: 12.5, color: t.textMuted)),
                  ],
                ),
              ),
              Text('about ${_band(band)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          _bandBar(context, band, target),
          for (final e in QuickCheckData.criteriaNames.entries)
            if (crit[e.key] is num)
              Row(
                spacing: 10,
                children: [
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13.5))),
                  SizedBox(width: 90, child: ProgressBar(value: ((crit[e.key] as num) / 9).clamp(0, 1).toDouble(), height: 6)),
                  SizedBox(
                    width: 34,
                    child: Text(Store.formatBand((crit[e.key] as num).toDouble()),
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
          if (feedback is String && feedback.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.peach.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Icon(AppIcons.bulb, color: t.peach, size: 20),
                  Expanded(child: Text(feedback, style: const TextStyle(fontSize: 13.5, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Band on a 4-9 scale with the target marked.
  Widget _bandBar(BuildContext context, double band, double? target) {
    final t = context.tk;
    double pos(double b) => ((b - 4) / 5).clamp(0, 1).toDouble();
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        height: 22,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, right: 0, top: 6, child: ProgressBar(value: pos(band), height: 8)),
            if (target != null)
              Positioned(
                left: (c.maxWidth * pos(target) - 1).clamp(0, c.maxWidth - 2).toDouble(),
                top: 0,
                child: Container(width: 2, height: 20, color: t.text),
              ),
          ],
        ),
      ),
    );
  }

  Widget _answerRow(BuildContext context, Map<String, Object> it) {
    final t = context.tk;
    final options = (it['options']! as List).cast<String>();
    final picked = _chosen[it['id']];
    final answer = it['answer']! as int;
    final ok = picked == answer;
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(ok ? AppIcons.checkCircle : AppIcons.cancel, size: 18, color: ok ? t.success : t.alert),
              Expanded(
                child: Text(
                  '${QuickCheckData.sectionLabels[it['section']] ?? ''} · ${it['focus']}',
                  style: TextStyle(fontSize: 12, color: t.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Text(it['q']! as String, style: const TextStyle(fontSize: 14, height: 1.35)),
          if (!ok && picked != null)
            Text('Your answer: ${options[picked]}', style: TextStyle(fontSize: 13, color: t.alert)),
          Text('Correct answer: ${options[answer]}', style: TextStyle(fontSize: 13, color: t.success, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
