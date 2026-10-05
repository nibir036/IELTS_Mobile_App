import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// kv key: best irregular-verb practice round {score, total, pct, at}.
const String kIrregularBestKey = 'resources.irregularBest';

/// Opens the practice round for [verbs] (rows with base / past / participle).
void openIrregularPractice(BuildContext context, List<Map<String, dynamic>> verbs) {
  if (verbs.isEmpty) {
    context.toast('No verbs to practise - change the letter or filter');
    return;
  }
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => IrregularVerbPracticeScreen(verbs: verbs),
    ),
  );
}

/// Accepted spellings for one form: the data value (which may list
/// alternatives as "learnt/learned" or "learnt, learned") plus common
/// British / American pairs.
List<String> acceptedForms(String value, {bool participle = false}) {
  const pairs = <String, String>{
    'learnt': 'learned',
    'burnt': 'burned',
    'dreamt': 'dreamed',
    'spelt': 'spelled',
    'spilt': 'spilled',
    'spoilt': 'spoiled',
    'smelt': 'smelled',
    'leapt': 'leaped',
    'leant': 'leaned',
    'knelt': 'kneeled',
    'dwelt': 'dwelled',
    'lit': 'lighted',
    'dived': 'dove',
  };
  final out = <String>{};
  for (final raw in value.toLowerCase().split(RegExp(r'\s*(?:/|,|\bor\b)\s*'))) {
    final v = raw.trim();
    if (v.isEmpty) continue;
    out.add(v);
    pairs.forEach((a, b) {
      if (v == a) out.add(b);
      if (v == b) out.add(a);
    });
  }
  if (participle && out.contains('got')) out.add('gotten');
  return out.toList();
}

bool _matches(String given, String value, {bool participle = false}) {
  final g = given.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (g.isEmpty) return false;
  return acceptedForms(value, participle: participle).contains(g);
}

/// Irregular verbs practice: type the past simple and past participle of each
/// base form, check, score at the end, retry the wrong ones. Best score is
/// kept in kv [kIrregularBestKey].
class IrregularVerbPracticeScreen extends StatefulWidget {
  const IrregularVerbPracticeScreen({super.key, required this.verbs});

  final List<Map<String, dynamic>> verbs;

  @override
  State<IrregularVerbPracticeScreen> createState() =>
      _IrregularVerbPracticeScreenState();
}

class _IrregularVerbPracticeScreenState extends State<IrregularVerbPracticeScreen> {
  final TextEditingController _past = TextEditingController();
  final TextEditingController _part = TextEditingController();

  late List<Map<String, dynamic>> _round;
  bool _retry = false;
  int _index = 0;
  bool _checked = false;
  bool _pastOk = false;
  bool _partOk = false;
  int _score = 0;
  final List<Map<String, dynamic>> _wrong = <Map<String, dynamic>>[];
  bool _finished = false;
  bool _newBest = false;

  @override
  void initState() {
    super.initState();
    _start(widget.verbs, retry: false);
  }

  @override
  void dispose() {
    _past.dispose();
    _part.dispose();
    super.dispose();
  }

  void _start(List<Map<String, dynamic>> verbs, {required bool retry}) {
    _round = List<Map<String, dynamic>>.of(verbs)..shuffle(math.Random());
    _retry = retry;
    _index = 0;
    _checked = false;
    _score = 0;
    _wrong.clear();
    _finished = false;
    _newBest = false;
    _past.clear();
    _part.clear();
  }

  void _check() {
    final v = _round[_index];
    if (_past.text.trim().isEmpty && _part.text.trim().isEmpty) {
      context.toast('Type both forms first');
      return;
    }
    final pastOk = _matches(_past.text, v.s('past'));
    final partOk = _matches(_part.text, v.s('participle'), participle: true);
    setState(() {
      _checked = true;
      _pastOk = pastOk;
      _partOk = partOk;
      if (pastOk && partOk) {
        _score++;
      } else {
        _wrong.add(v);
      }
    });
  }

  void _next() {
    if (_index + 1 < _round.length) {
      setState(() {
        _index++;
        _checked = false;
        _past.clear();
        _part.clear();
      });
      return;
    }
    _finish();
  }

  void _finish() {
    final total = _round.length;
    var newBest = false;
    if (!_retry && total > 0) {
      final best = Store.I.kv<Map>(kIrregularBestKey)?.cast<String, dynamic>();
      final pct = (_score * 100 / total).round();
      final bestPct = best == null ? -1 : best.i('pct');
      if (pct > bestPct || (pct == bestPct && total > (best?.i('total') ?? 0))) {
        Store.I.setKv(kIrregularBestKey, <String, dynamic>{
          'score': _score,
          'total': total,
          'pct': pct,
          'at': DateTime.now().toIso8601String(),
        });
        newBest = true;
      }
    }
    setState(() {
      _finished = true;
      _newBest = newBest;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _finished ? _buildResult(context) : _buildQuestion(context);
  }

  Widget _buildQuestion(BuildContext context) {
    final t = context.tk;
    final v = _round[_index];
    return AppScreen(
      gap: 14,
      footer: PrimaryButton(
        label: !_checked
            ? 'Check'
            : (_index + 1 < _round.length ? 'Next verb' : 'See score'),
        trailing: _checked ? AppIcons.forward : null,
        onTap: _checked ? _next : _check,
      ),
      children: [
        Row(
          spacing: 10,
          children: [
            IconBox(
              icon: AppIcons.close,
              tooltip: 'Stop practice',
              iconSize: 18,
              onTap: () => context.back(),
            ),
            Expanded(
              child: Text(
                _retry ? 'Retry wrong verbs' : 'Practise irregular verbs',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
            Tag('${_index + 1}/${_round.length}'),
          ],
        ),
        ProgressBar(value: (_index + (_checked ? 1 : 0)) / _round.length),
        HeroCard(
          radius: 26,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text('Base form'.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: t.peach)),
              Text(
                v.s('base'),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                  color: t.heroText,
                ),
              ),
              Text(
                'Type the past simple and the past participle.',
                style: TextStyle(fontSize: 13, color: t.heroMuted),
              ),
            ],
          ),
        ),
        AppTextField(
          key: ValueKey<String>('past_${_index}_${v.s('base')}'),
          controller: _past,
          label: 'Past simple',
          hint: 'e.g. went',
          keyboardType: TextInputType.text,
        ),
        AppTextField(
          key: ValueKey<String>('part_${_index}_${v.s('base')}'),
          controller: _part,
          label: 'Past participle',
          hint: 'e.g. gone',
          keyboardType: TextInputType.text,
        ),
        if (_checked)
          AppCard(
            radius: 22,
            color: _pastOk && _partOk ? t.successSoft : t.dangerSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  _pastOk && _partOk ? 'Both correct' : 'Not quite',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _pastOk && _partOk ? t.text : t.dangerText,
                  ),
                ),
                _FormResult(label: 'Past simple', ok: _pastOk, answer: v.s('past')),
                _FormResult(
                  label: 'Past participle',
                  ok: _partOk,
                  answer: v.s('participle'),
                ),
                Text(
                  '${v.s('base')} – ${v.s('past')} – ${v.s('participle')}',
                  style: TextStyle(fontSize: 13, color: t.textMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final t = context.tk;
    final total = _round.length;
    final best = context.store.kv<Map>(kIrregularBestKey)?.cast<String, dynamic>();
    final wrong = List<Map<String, dynamic>>.of(_wrong);
    return AppScreen(
      gap: 14,
      footer: Row(
        spacing: 10,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Done',
              height: 56,
              fontSize: 15,
              expand: true,
              bg: t.isNight ? t.surface : t.raised,
              onTap: () => context.back(),
            ),
          ),
          Expanded(
            child: PrimaryButton(
              label: wrong.isEmpty ? 'Practise again' : 'Retry ${wrong.length} wrong',
              height: 56,
              fontSize: 15,
              onTap: () => setState(() {
                if (wrong.isEmpty) {
                  _start(widget.verbs, retry: false);
                } else {
                  _start(wrong, retry: true);
                }
              }),
            ),
          ),
        ],
      ),
      children: [
        ResTopBar(title: 'Irregular verbs practice', overline: 'Your score'),
        HeroCard(
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                (_retry ? 'Retry round' : 'Score').toUpperCase(),
                style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: t.peach),
              ),
              BigNumber('$_score/$total', color: t.heroText),
              Text(
                _newBest
                    ? 'New best score!'
                    : (best == null
                        ? 'Finish a full round to set your best score.'
                        : 'Best: ${best.i('score')}/${best.i('total')} (${best.i('pct')}%)'),
                style: TextStyle(fontSize: 14, color: t.heroText),
              ),
              const SizedBox(height: 4),
              ProgressBar(value: total == 0 ? 0 : _score / total, onHero: true),
            ],
          ),
        ),
        if (wrong.isNotEmpty) ...[
          const SectionTitle('To review'),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              children: [
                for (var i = 0; i < wrong.length; i++)
                  ListRow(
                    divider: i > 0,
                    title: wrong[i].s('base'),
                    subtitle: '${wrong[i].s('past')} · ${wrong[i].s('participle')}',
                    trailing: Icon(AppIcons.close, size: 18, color: t.danger),
                  ),
              ],
            ),
          ),
        ] else
          EmptyState(
            title: 'Every verb correct',
            message: 'Try another letter or the “All three forms differ” filter for a harder set.',
            icon: AppIcons.trophy,
          ),
      ],
    );
  }
}

class _FormResult extends StatelessWidget {
  const _FormResult({required this.label, required this.ok, required this.answer});

  final String label;
  final bool ok;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 8,
      children: [
        Icon(
          ok ? AppIcons.checkCircle : AppIcons.error,
          size: 18,
          color: ok ? t.success : t.danger,
        ),
        Expanded(
          child: Text(
            ok ? '$label: correct' : '$label: $answer',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: t.text),
          ),
        ),
      ],
    );
  }
}
