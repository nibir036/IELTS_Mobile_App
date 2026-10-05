import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/services/audio_clip.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';

/// "4:59" from seconds.
String diagClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Two-button confirm dialog in the app style. Returns true for [confirm].
Future<bool> showDiagConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  IconData icon = AppIcons.info,
}) async {
  final r = await showAppDialog<bool>(
    context,
    Builder(
      builder: (ctx) {
        final t = ctx.tk;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Center(child: IconCircle(icon, size: 56)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: t.textMuted),
            ),
            const SizedBox(height: 4),
            PrimaryButton(
              label: confirm,
              height: 52,
              radius: 18,
              fontSize: 15,
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            OutlineButtonX(
              label: cancel,
              height: 52,
              radius: 18,
              fontSize: 15,
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        );
      },
    ),
  );
  return r == true;
}

/// Countdown pill in the header (turns alert-coloured in the last minute).
class DiagTimerPill extends StatelessWidget {
  const DiagTimerPill({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final low = seconds <= 60;
    final fg = low ? t.onAlert : t.text;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: low ? t.alert : t.raised,
        borderRadius: BorderRadius.circular(999),
        border: low ? null : Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(AppIcons.timer, size: 16, color: fg),
          Text(
            diagClock(seconds),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The listening recording: one play, no seeking or replay.
class DiagAudioCard extends StatelessWidget {
  const DiagAudioCard({
    super.key,
    required this.clip,
    required this.title,
    required this.started,
    required this.failed,
    required this.onPlay,
  });

  final AudioClip clip;
  final String title;
  final bool started;
  final bool failed;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clip,
      builder: (context, _) {
        final t = context.tk;
        final done = clip.completed;
        final String status;
        if (failed) {
          status = 'Audio couldn’t load - answer from what you know.';
        } else if (done) {
          status = 'Recording finished';
        } else if (!clip.loaded) {
          status = 'Loading audio…';
        } else if (!started) {
          status = 'Plays once - no replay';
        } else {
          status = clip.playing ? 'Playing · plays once' : 'Paused';
        }
        final canTap = !failed && !done && clip.loaded;
        return AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            spacing: 12,
            children: [
              IconBox(
                icon: done
                    ? AppIcons.check
                    : (clip.playing ? AppIcons.pause : AppIcons.play),
                tooltip: clip.playing ? 'Pause' : 'Play',
                size: 52,
                radius: 18,
                iconSize: 24,
                bg: canTap ? t.peach : t.surfaceAlt,
                fg: canTap ? kOnPeach : t.textMuted,
                onTap: canTap ? onPlay : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    ProgressBar(value: done ? 1 : clip.progress, height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: t.textMuted),
                          ),
                        ),
                        if (clip.durationSec > 0)
                          Text(
                            '${diagClock(clip.positionSec.round())} / ${diagClock(clip.durationSec.round())}',
                            style: TextStyle(fontSize: 12, color: t.textMuted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Live input level bars for the speaking recorder (newest on the right).
class DiagLevelBars extends StatelessWidget {
  const DiagLevelBars({super.key, required this.levels, this.height = 44});

  final List<double> levels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 3,
        children: [
          for (final l in levels)
            Expanded(
              child: Container(
                height: height * (0.12 + 0.88 * l.clamp(0.0, 1.0)),
                decoration: BoxDecoration(
                  color: l > 0.02 ? t.fill : (t.isNight ? t.surfaceAlt : t.border),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Section intro: icon, "Step 2 of 4 · Reading", part line and instructions.
class DiagIntroCard extends StatelessWidget {
  const DiagIntroCard({
    super.key,
    required this.icon,
    required this.title,
    required this.part,
    required this.intro,
  });

  final IconData icon;
  final String title;
  final String part;
  final String intro;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          IconCircle(icon, size: 44),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (part.isNotEmpty)
                  Text(part, style: TextStyle(fontSize: 13, color: t.textMuted)),
                if (intro.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      intro,
                      style: TextStyle(fontSize: 13, height: 1.45, color: t.textSoft),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen "Scoring…" overlay shown while the diagnostic is saved.
class DiagSavingOverlay extends StatelessWidget {
  const DiagSavingOverlay({super.key, required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: t.bg.withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: t.text),
              ),
              Text(
                stage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'This takes a few seconds.',
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A reading passage: title + lettered paragraphs.
class DiagPassageCard extends StatelessWidget {
  const DiagPassageCard({super.key, required this.passage});

  final Map<String, dynamic> passage;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            passage.s('title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, height: 1.25),
          ),
          for (final p in passage.l('paragraphs'))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                LetterBadge(p.s('letter'), size: 26, radius: 8, fontSize: 12),
                Expanded(
                  child: Text(
                    p.s('text'),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: t.isNight ? t.text : t.textSoft,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Writing step: the Task 2 prompt, the answer box and a live word count.
class DiagWritingPanel extends StatelessWidget {
  const DiagWritingPanel({
    super.key,
    required this.prompt,
    required this.controller,
    required this.minWords,
    required this.onChanged,
  });

  final Map<String, dynamic> prompt;
  final TextEditingController controller;
  final int minWords;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final words = RegExp(r"[A-Za-z0-9']+").allMatches(controller.text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  const Tag('Task 2'),
                  if (prompt.s('topic').isNotEmpty) Tag(prompt.s('topic'), tone: TagTone.outline),
                ],
              ),
              Text(
                prompt.s('prompt'),
                style: TextStyle(fontSize: 15, height: 1.5, color: t.isNight ? t.text : t.textSoft),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: t.isNight ? t.surface : t.raised,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.border),
          ),
          child: TextField(
            controller: controller,
            minLines: 10,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onChanged(),
            style: TextStyle(fontSize: 15, height: 1.5, color: t.text),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Write your paragraph here…',
              hintStyle: TextStyle(fontSize: 15, color: t.textFaint),
            ),
          ),
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(child: ProgressBar(value: minWords <= 0 ? 0.0 : words / minWords, height: 5)),
            Text(
              '$words / $minWords+ words',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: words >= minWords ? t.text : t.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
