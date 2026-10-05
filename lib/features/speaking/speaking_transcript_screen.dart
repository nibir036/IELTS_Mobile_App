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

/// Pause chip / filler highlight colours (same in Day and Night on the canvas).
const Color _pauseBg = Color(0xFFDCE6FF);
const Color _fillerBg = Color(0xFFFFE2D8);
const Color _chipText = Color(0xFF151515);

/// D5 · Live transcription with highlighted fillers, pauses and
/// mispronounced words. Tap a highlight to see its note.
/// Reads the attempt from `{'attemptId'}` (or the newest speaking answer).
class SpeakingTranscriptScreen extends StatefulWidget {
  const SpeakingTranscriptScreen({super.key});

  @override
  State<SpeakingTranscriptScreen> createState() =>
      _SpeakingTranscriptScreenState();
}

class _SpeakingTranscriptScreenState extends State<SpeakingTranscriptScreen> {
  AnswerPlayer? _player;
  String? _playerFor;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  /// The player for attempt [a] (recreated if the attempt changes).
  AnswerPlayer _playerOf(Attempt a) {
    final existing = _player;
    if (existing != null && _playerFor == a.id) return existing;
    existing?.dispose();
    final spoken = spokenSecOf(a);
    final p = AnswerPlayer(a.data.l('audio'), fallbackSec: spoken > 0 ? spoken : 1);
    _player = p;
    _playerFor = a.id;
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final a = resolveSpeakingAnswer(context);
    if (a == null) {
      return AppScreen(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        gap: 14,
        children: [
          const _Header(onReRecord: null),
          EmptyState(
            icon: AppIcons.mic,
            title: 'No answers yet',
            message: 'Record a speaking answer to see your transcript here.',
            actionLabel: 'Start speaking practice',
            onAction: () => openHub(context),
          ),
        ],
      );
    }
    final player = _playerOf(a);
    final (fillers, pauses, wpm) = transcriptStats(a);
    final stats = <(String, String)>[
      ('$fillers', 'fillers'),
      ('$pauses', 'long pauses'),
      ('$wpm', 'words / min'),
    ];
    final tr = a.data['transcript'];
    final trMap = tr is Map ? tr.cast<String, dynamic>() : <String, dynamic>{};
    final paragraphs = trMap.l('paragraphs');
    final isDemo = trMap.b('demo');
    final offline = a.data.s('source') == 'demo';
    final trackColor = t.isNight ? const Color(0x26151515) : const Color(0xFF3A3A3A);
    final fillColor = t.isNight ? t.onPrimary : t.accentStrong;
    final timeColor = t.isNight ? t.onPrimary : const Color(0xFFD6D0D4);
    final underline = t.isNight ? t.text : t.danger;

    return AppScreen(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      gap: 14,
      footerPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      footer: PrimaryButton(
        label: 'See band evaluation',
        trailing: AppIcons.forward,
        height: 56,
        radius: 18,
        onTap: () => context.push(Routes.speakingEvaluation, args: {'attemptId': a.id}),
      ),
      children: [
        _Header(onReRecord: () => reRecordAttempt(context, a, replace: true)),
        ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final duration = player.durationSec;
            final pos = player.positionSec > duration ? duration : player.positionSec;
            return Container(
              height: 64,
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
              decoration: BoxDecoration(
                color: t.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                spacing: 12,
                children: [
                  IconBox(
                    icon: player.playing ? AppIcons.pause : AppIcons.play,
                    size: 48,
                    circle: true,
                    iconSize: 20,
                    bg: t.onPrimary,
                    fg: t.primary,
                    tooltip: player.playing ? 'Pause recording' : 'Play recording',
                    onTap: player.toggle,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        void seekAt(double dx) {
                          if (box.maxWidth <= 0) return;
                          player.seekFraction(dx / box.maxWidth);
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => seekAt(d.localPosition.dx),
                          onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
                          child: SizedBox(
                            height: 32,
                            child: Center(
                              child: ProgressBar(
                                value: player.progress,
                                height: 4,
                                track: trackColor,
                                fill: fillColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Text(
                    '${clockShort(pos.floor())} / ${clockShort(duration.round())}',
                    style: TextStyle(
                      fontSize: 13,
                      color: timeColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Row(
          spacing: 8,
          children: [
            for (final s in stats)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1, style: const TextStyle(fontSize: 22)),
                      Text(
                        s.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Legend(
                label: 'Pause',
                swatch: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: _pauseBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '‖',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _chipText,
                    ),
                  ),
                ),
              ),
              _Legend(
                label: 'Filler',
                swatch: Container(
                  width: 14,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _fillerBg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              _Legend(
                label: isDemo ? 'Mispronounced' : 'Error',
                swatch: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Container(width: 2.5, height: 2, color: underline),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isDemo || offline)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isDemo
                  ? (offline
                      ? 'Sample transcript - estimated offline.'
                      : 'Sample transcript - live speech-to-text turns on when the AI server is connected.')
                  : 'Estimated offline (AI unavailable)',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              for (final p in paragraphs)
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.85,
                      color: p.b('faded')
                          ? (t.isNight ? t.textMuted : t.textFaint)
                          : (t.isNight ? t.text : const Color(0xFF2A2629)),
                    ),
                    children: [
                      for (final tok in p.l('tokens')) _span(context, tok, underline),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  InlineSpan _span(BuildContext context, Map<String, dynamic> tok, Color underline) {
    final t = context.tk;
    final text = tok.s('text');
    final note = tok.s('note');
    switch (tok.s('type')) {
      case 'lead':
        return TextSpan(
          text: text,
          style: TextStyle(color: t.text, fontWeight: FontWeight.w500),
        );
      case 'filler':
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _TapNote(
            note: note,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _fillerBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 16, height: 1.3, color: _chipText),
              ),
            ),
          ),
        );
      case 'pause':
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _TapNote(
            note: note,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: _pauseBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: _chipText,
                ),
              ),
            ),
          ),
        );
      case 'error':
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _TapNote(
            note: note,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.3,
                color: t.isNight ? t.text : const Color(0xFF2A2629),
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.wavy,
                decorationColor: underline,
                decorationThickness: 1.5,
              ),
            ),
          ),
        );
      case 'mispronounced':
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _TapNote(
            note: note,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.3,
                color: t.isNight ? t.text : const Color(0xFF2A2629),
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
                decorationColor: underline,
                decorationThickness: 2,
              ),
            ),
          ),
        );
      default:
        return TextSpan(text: text);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onReRecord});

  final VoidCallback? onReRecord;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      children: [
        IconBox(
          icon: AppIcons.back,
          iconSize: 18,
          bg: t.surface,
          tooltip: 'Back',
          onTap: () => context.back(),
        ),
        const Expanded(
          child: Text(
            'Your answer',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        if (onReRecord != null)
          IconBox(
            icon: AppIcons.replay,
            bg: t.surface,
            tooltip: 'Re-record',
            onTap: onReRecord,
          )
        else
          const SizedBox(width: 44),
      ],
    );
  }
}

class _TapNote extends StatelessWidget {
  const _TapNote({required this.note, required this.child});

  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (note.isEmpty) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.toast(note),
      child: child,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.swatch});

  final String label;
  final Widget swatch;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        swatch,
        Text(label, style: TextStyle(fontSize: 12, color: context.tk.textMuted)),
      ],
    );
  }
}
