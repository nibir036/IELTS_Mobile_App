import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/data/res_bank.dart';
import '../../app/nav.dart';
import '../../app/services/tts.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import '../../app/widgets/lang_switch.dart';
import '../../app/widgets/speak_button.dart';
import '../reading/widgets.dart' show boldSpans;
import 'irregular_verbs_practice.dart';
import 'widgets.dart';

/// H8 · Irregular Verbs - searchable, letter-filtered verb table.
class IrregularVerbsScreen extends StatefulWidget {
  const IrregularVerbsScreen({super.key});

  @override
  State<IrregularVerbsScreen> createState() => _IrregularVerbsScreenState();
}

class _IrregularVerbsScreenState extends State<IrregularVerbsScreen> {
  /// The three forms read aloud: “go, went, gone”.
  static String _forms(Map<String, dynamic> v) => '${v.s('base')}, ${v.s('past')}, ${v.s('participle')}';

  late final Map<String, dynamic> _data =
      Demo.section('resources').m('irregularVerbs');

  /// The Resources bank's 175 verbs (with meaning and example), else the demo list.
  late final List<Map<String, dynamic>> _verbs =
      ResBank.irregularVerbs.isNotEmpty ? ResBank.irregularVerbs : _data.l('verbs');

  /// First letters that have verbs.
  late final List<String> _letters = ResBank.irregularVerbs.isNotEmpty
      ? (<String>{for (final v in _verbs) v.s('base')[0].toUpperCase()}.toList()..sort())
      : _data.ls('letters');
  late String _letter = _letters.contains(_data.s('defaultLetter')) ? _data.s('defaultLetter') : (_letters.isEmpty ? '' : _letters.first);
  String _query = '';

  /// 0 all · 1 same past & participle · 2 all three forms differ.
  int _pattern = 0;

  static const List<String> _patterns = <String>[
    'All verbs',
    'Same past & participle',
    'All three forms differ',
  ];

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _verbs.where((v) {
      final base = v.s('base');
      final past = v.s('past');
      final part = v.s('participle');
      if (q.isNotEmpty) {
        if (!(base.contains(q) || past.contains(q) || part.contains(q))) {
          return false;
        }
      } else if (_letter.isNotEmpty &&
          !base.toUpperCase().startsWith(_letter)) {
        return false;
      }
      if (_pattern == 1 && past != part) return false;
      if (_pattern == 2 && (base == past || past == part || base == part)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Meaning and example of a verb (bank verbs).
  void _showVerb(Map<String, dynamic> v) {
    showAppSheet<void>(
      context,
      Builder(
        builder: (ctx) {
          final t = ctx.tk;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              const SizedBox(height: 4),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      '${v.s('base')} – ${v.s('past')} – ${v.s('participle')}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                    ),
                  ),
                  SpeakButton(text: _forms(v), size: 40, radius: 14, bg: t.surfaceAlt2),
                ],
              ),
              Text(v.s('meaning'), style: TextStyle(fontSize: 16, height: 1.45, color: t.text)),
              TrMeaning('iv_${v.s('base').replaceAll(' ', '_')}', fontSize: 15),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                child: Text.rich(
                  TextSpan(children: boldSpans(v.s('example'))),
                  style: TextStyle(fontSize: 14, height: 1.45, color: t.text),
                ),
              ),
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openFilter() async {
    final picked = await showAppSheet<int>(
      context,
      Builder(
        builder: (ctx) {
          final t = ctx.tk;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  'Filter verbs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              for (var i = 0; i < _patterns.length; i++)
                OptionTile(
                  label: _patterns[i],
                  selected: i == _pattern,
                  onTap: () => Navigator.of(ctx).pop(i),
                ),
              Text(
                'Filters apply on top of the letter or search.',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _pattern = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final letters = _letters;
    final verbs = _visible;

    return AppScreen(
      gap: 12,
      footer: Row(
        spacing: 8,
        children: [
          Expanded(
            child: SoftButton(
              label: 'Listen',
              leading: AppIcons.volume,
              height: 56,
              radius: 18,
              fontSize: 15,
              expand: true,
              bg: t.isNight ? t.surface : t.raised,
              onTap: () => verbs.isEmpty ? context.toast('Nothing to play') : Tts.I.speak(_forms(verbs.first)),
            ),
          ),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: 'Practise these verbs',
              height: 56,
              radius: 18,
              fontSize: 15,
              // Practice over exactly the verbs shown (letter / search / filter).
              onTap: () => openIrregularPractice(context, verbs),
            ),
          ),
        ],
      ),
      children: [
        ResTopBar(
          title: 'Irregular Verbs',
          actions: [
            IconBox(
              icon: AppIcons.filter,
              tooltip: 'Filter',
              dot: _pattern != 0,
              onTap: _openFilter,
            ),
          ],
        ),
        if (ResBank.irregularVerbs.isNotEmpty) const ContentLangSwitch(module: 'resources'),
        ResSearchField(
          hint: 'Search ${_verbs.length} verbs',
          onChanged: (v) => setState(() => _query = v),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 2,
            children: [
              for (final l in letters)
                Material(
                  color: l == _letter ? t.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _letter = _letter == l ? '' : l),
                    child: SizedBox(
                      width: 26,
                      height: 30,
                      child: Center(
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 13,
                            color: l == _letter ? t.onPrimary : t.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    for (final h in const <String>['Base', 'Past simple', 'Past participle'])
                      Expanded(
                        child: Text(
                          h,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              if (verbs.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.divider)),
                  ),
                  child: Text(
                    'No verbs match.',
                    style: TextStyle(fontSize: 14, color: t.textMuted),
                  ),
                ),
              for (final v in verbs)
                InkWell(
                  onTap: v.s('meaning').isEmpty ? null : () => _showVerb(v),
                  child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          v.s('base'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          v.s('past'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          v.s('participle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      SpeakButton(
                        text: _forms(v),
                        tooltip: 'Play ${v.s('base')}',
                        size: 32,
                        radius: 10,
                        iconSize: 16,
                        bg: t.surfaceAlt2,
                      ),
                    ],
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
