import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/nav.dart';
import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

/// D3 · Part 2 cue card with the 1-minute preparation countdown.
/// Route args: `{'cardId': '<cue card id>'}` (older `{'id'}` also works;
/// default: the first card of the bank).
/// Bookmarks and notes are per-user (Store kv).
class CueCardScreen extends StatefulWidget {
  const CueCardScreen({super.key});

  @override
  State<CueCardScreen> createState() => _CueCardScreenState();
}

class _CueCardScreenState extends State<CueCardScreen> {
  Timer? _timer;
  Map<String, dynamic>? _card;
  int _prepTotal = 60;
  int _left = 60;
  bool _leaving = false;
  final List<TextEditingController> _notes = <TextEditingController>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_card != null) return;
    final card = findCueCard(cueCardArg(context));
    _card = card;
    final prep = speakingData().m('recording').i('prepSeconds');
    _prepTotal = prep > 0 ? prep : 60;
    _left = _prepTotal;
    final notes = (Store.I.kv<List>(cueNotesKey(card.s('id'))) ?? const <Object>[])
        .map((e) => '$e')
        .toList();
    for (var i = 0; i < 3; i++) {
      _notes.add(TextEditingController(text: i < notes.length ? notes[i] : ''));
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 1) {
        setState(() => _left = 0);
        _start();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _notes) {
      c.dispose();
    }
    super.dispose();
  }

  void _start() {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    final id = (_card ?? <String, dynamic>{}).s('id');
    final notes = _notes.map((c) => c.text.trim()).toList();
    if (id.isNotEmpty) {
      Store.I.setKv(cueNotesKey(id), notes.any((n) => n.isNotEmpty) ? notes : null);
    }
    context.replace(
      Routes.speakingRecording,
      args: {'cardId': (_card ?? <String, dynamic>{}).s('id')},
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final card = _card ?? <String, dynamic>{};
    final total = Content.cueCards.length;
    final tag = card.s('category');
    final prompts = card.ls('prompts');
    final saved = context.store.kvSetHas(kSavedCardsKey, card.s('id'));

    return Scaffold(
      backgroundColor: t.bg,
      body: BackOnScrollUp(child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
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
                              const Text('Part 2 · Cue card', style: TextStyle(fontSize: 16)),
                              Text(
                                'Card ${card.i('number')} of $total',
                                style: TextStyle(fontSize: 12, color: t.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconBox(
                          icon: saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                          size: 56,
                          radius: 20,
                          iconSize: 22,
                          tooltip: 'Save card',
                          onTap: () {
                            Store.I.kvSetToggle(kSavedCardsKey, card.s('id'));
                            context.toast(saved ? 'Removed from saved' : 'Card saved');
                          },
                        ),
                      ],
                    ),
                    HeroCard(
                      radius: 34,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 14,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: t.peach,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnPeach),
                            ),
                          ),
                          Text(
                            card.s('title'),
                            style: TextStyle(
                              fontSize: 26,
                              height: 1.15,
                              letterSpacing: -0.4,
                              color: t.heroText,
                            ),
                          ),
                          Text(
                            'You should say:',
                            style: TextStyle(fontSize: 14, color: t.heroMuted),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: [
                              for (final p in prompts)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 10,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 9),
                                      child: Dot(size: 6, color: t.peach),
                                    ),
                                    Expanded(
                                      child: Text(
                                        p,
                                        style: TextStyle(fontSize: 16, color: t.heroText),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        spacing: 18,
                        children: [
                          RingProgress(
                            value: _left / _prepTotal,
                            size: 104,
                            stroke: 8,
                            track: t.isNight ? t.track : t.border,
                            child: Text(
                              clockShort(_left),
                              style: const TextStyle(
                                fontSize: 26,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 4,
                              children: [
                                const Text('Preparation', style: TextStyle(fontSize: 18)),
                                Text(
                                  'Then speak for up to 2 minutes. Recording starts on its own.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: t.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _NotesSheet(controllers: _notes, onStart: _start),
        ],
      )),
    );
  }
}

class _NotesSheet extends StatelessWidget {
  const _NotesSheet({required this.controllers, required this.onStart});

  final List<TextEditingController> controllers;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final lineColor = t.isNight ? t.divider : t.text;
    final noteColor = t.isNight ? const Color(0xFFE6E6E6) : t.text;
    // Outer box paints the 1px top hairline; inner box is the sheet.
    return Container(
      padding: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: t.divider,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: t.isNight ? const Color(0xFF333333) : t.surfaceAlt,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(child: Text('Notes', style: TextStyle(fontSize: 16))),
                  Text(
                    'Only you see these',
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                ],
              ),
              Column(
                children: [
                  for (final c in controllers)
                    Container(
                      height: 30,
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: lineColor)),
                      ),
                      child: TextField(
                        controller: c,
                        cursorColor: t.primary,
                        style: TextStyle(fontSize: 15, color: noteColor),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              PrimaryButton(
                label: 'Start speaking now',
                leading: AppIcons.mic,
                radius: 999,
                onTap: onStart,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
