import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/data/content.dart';
import '../../app/data/demo.dart';
import '../../app/data/store.dart';
import '../../app/services/audio_clip.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Voice notes, image messages, system lines and the AI speaking partner used
// by the room chat (H4).
// ═════════════════════════════════════════════════════════════════════════════

/// Recording paths made in this app session. On web a recording is a blob URL
/// that dies with the page, so an older blob path is shown as expired.
final Set<String> kSessionVoicePaths = <String>{};

/// True when a saved voice note can no longer be played.
bool voiceNoteExpired(Map<String, dynamic> m) {
  final path = m.s('path');
  if (path.isEmpty) return true;
  return path.startsWith('blob:') && !kSessionVoicePaths.contains(path);
}

/// "0:07" from milliseconds.
String clockFromMs(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

final Map<String, Uint8List> _imageCache = <String, Uint8List>{};

/// Decoded bytes of an image message (cached by message id), or null.
Uint8List? imageBytesOf(Map<String, dynamic> m) {
  final id = m.s('id');
  final cached = _imageCache[id];
  if (cached != null) return cached;
  final b64 = m.s('imageBase64');
  if (b64.isEmpty) return null;
  try {
    final bytes = base64Decode(b64);
    _imageCache[id] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

/// Full-screen image viewer (pinch to zoom).
Future<void> showImageViewer(BuildContext context, Uint8List bytes) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: ResPalette.ink,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconBox(
                icon: AppIcons.close,
                tooltip: 'Close',
                bg: ResPalette.white,
                fg: ResPalette.ink,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared shape of the user's own bubbles.
BoxDecoration _myBubbleDecoration(AppTokens t) => BoxDecoration(
      color: t.primary,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(6),
      ),
    );

/// The user's voice note: play/pause, waveform progress, duration. Shows
/// "Voice note (expired)" when the recording can no longer be loaded.
class MyVoiceBubble extends StatelessWidget {
  const MyVoiceBubble({
    super.key,
    required this.data,
    required this.clip,
    required this.expired,
    required this.onTap,
  });

  final Map<String, dynamic> data;

  /// The shared player when it holds this message, else null.
  final AudioClip? clip;
  final bool expired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final muted = t.isNight ? t.onPrimary.withValues(alpha: 0.6) : const Color(0xFFBDB6BB);
    final durationMs = data.i('durationMs');
    Widget row(bool playing, double progress) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            IconBox(
              icon: expired ? AppIcons.micOff : (playing ? AppIcons.pause : AppIcons.play),
              tooltip: expired ? 'Voice note expired' : 'Play voice note',
              circle: true,
              size: 36,
              bg: t.onPrimary,
              fg: t.primary,
              onTap: onTap,
            ),
            if (expired)
              Flexible(
                child: Text(
                  'Voice note (expired)',
                  style: TextStyle(fontSize: 14, color: t.onPrimary),
                ),
              )
            else
              SizedBox(
                width: 100,
                child: WaveformBars(
                  count: 16,
                  height: 24,
                  progress: progress,
                  seed: 9,
                  color: t.onPrimary.withValues(alpha: 0.35),
                  playedColor: t.onPrimary,
                ),
              ),
            Text(
              durationMs > 0 ? clockFromMs(durationMs) : data.s('duration'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        );
    final c = clip;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: _myBubbleDecoration(t),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'You · ${data.s('time')}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            if (c == null || expired)
              row(false, 0)
            else
              ListenableBuilder(
                listenable: c,
                builder: (context, _) => row(c.playing, c.progress),
              ),
          ],
        ),
      ),
    );
  }
}

/// The user's image message (rounded); tap opens the full-screen viewer.
class MyImageBubble extends StatelessWidget {
  const MyImageBubble({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final bytes = imageBytesOf(data);
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          GestureDetector(
            onTap: bytes == null ? null : () => showImageViewer(context, bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230, maxHeight: 280),
                child: bytes == null
                    ? const SizedBox(
                        width: 200,
                        child: ImagePlaceholder(
                          height: 140,
                          label: 'Image unavailable',
                          icon: AppIcons.attach,
                        ),
                      )
                    : Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (ctx, e, s) => const SizedBox(
                          width: 200,
                          child: ImagePlaceholder(
                            height: 140,
                            label: 'Image unavailable',
                            icon: AppIcons.attach,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Text(
            'You · ${data.s('time')}',
            style: TextStyle(fontSize: 12, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Centred muted line (room created, AI partner on/off…).
class ChatSystemLine extends StatelessWidget {
  const ChatSystemLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, height: 1.4, color: t.textMuted),
      ),
    );
  }
}

/// "AI partner is typing…" placeholder.
class PartnerTyping extends StatelessWidget {
  const PartnerTyping({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: toneBg(t, 'lilac'),
            shape: BoxShape.circle,
          ),
          child: const Icon(AppIcons.sparkle, size: 16, color: ResPalette.ink),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'AI partner is typing…',
            style: TextStyle(fontSize: 14, color: t.textMuted),
          ),
        ),
      ],
    );
  }
}

/// Composer replacement while a voice note is recording: cancel, live level
/// bars, elapsed time, stop & send.
class VoiceRecordingBar extends StatelessWidget {
  const VoiceRecordingBar({
    super.key,
    required this.elapsed,
    required this.level,
    required this.onCancel,
    required this.onSend,
  });

  final Duration elapsed;
  final ValueNotifier<double> level;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Row(
      spacing: 8,
      children: [
        IconBox(
          icon: AppIcons.delete,
          tooltip: 'Cancel voice note',
          size: 54,
          radius: 20,
          bg: t.isNight ? t.surface : t.raised,
          onTap: onCancel,
        ),
        Expanded(
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: t.isNight ? t.surface : t.raised,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              spacing: 10,
              children: [
                Dot(size: 9, color: t.alert),
                Text(
                  clockFromMs(elapsed.inMilliseconds),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: level,
                    builder: (context, v, _) => ClipRect(
                      child: WaveformBars(
                        count: 22,
                        height: 22 + 10 * v,
                        progress: 1,
                        seed: 3 + (v * 10).round(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconBox(
          icon: AppIcons.send,
          tooltip: 'Stop and send',
          size: 54,
          radius: 20,
          bg: t.peach,
          fg: kOnPeach,
          onTap: onSend,
        ),
      ],
    );
  }
}

// ── own-room dialogs ────────────────────────────────────────────────────────

/// Details of one of the user's rooms (name, topic, description, date).
Future<void> showRoomDetails(BuildContext context, Map<String, dynamic> room) {
  final desc = room.s('description');
  final created = DateTime.tryParse(room.s('createdAt'));
  return showAppDialog<void>(
    context,
    Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            room.s('name'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          Tag(room.s('topic')),
          Text(
            desc.isEmpty ? 'No description.' : desc,
            style: TextStyle(fontSize: 14, height: 1.4, color: ctx.tk.textSoft),
          ),
          if (created != null)
            Text(
              'Created by you · ${Store.shortDate(created)}',
              style: TextStyle(fontSize: 12, color: ctx.tk.textMuted),
            ),
          PrimaryButton(
            label: 'Close',
            height: 48,
            radius: 16,
            fontSize: 14,
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
}

/// Asks before deleting one of the user's rooms. → true to delete.
Future<bool?> confirmDeleteRoom(BuildContext context, Map<String, dynamic> room) {
  return showAppDialog<bool>(
    context,
    Builder(
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text(
            'Delete this room?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          Text(
            '“${room.s('name')}” and all its messages will be removed. This can’t be undone.',
            style: TextStyle(fontSize: 14, height: 1.4, color: ctx.tk.textMuted),
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: OutlineButtonX(
                  label: 'Keep',
                  height: 48,
                  radius: 16,
                  fontSize: 14,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
              ),
              Expanded(
                child: PrimaryButton(
                  label: 'Delete',
                  height: 48,
                  radius: 16,
                  fontSize: 14,
                  bg: ctx.tk.danger,
                  fg: ctx.tk.onAlert,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── AI speaking partner ─────────────────────────────────────────────────────

/// Part 3 questions for a room: cue cards whose title / questions mention the
/// room's keyword (e.g. "Environment" from "Part 3 · Environment"), else a
/// cue card picked from the room id. → (topic label, questions).
(String, List<String>) partnerQuestionsFor(String roomId, String keyword) {
  final cards = Content.cueCards.where((c) => c.ls('part3').isNotEmpty).toList();
  if (cards.isEmpty) {
    return (
      keyword.isEmpty ? 'General' : keyword,
      const <String>[
        'Do you think people today have enough free time? Why?',
        'How has technology changed the way people learn?',
        'Should governments spend more on public transport or on roads?',
      ],
    );
  }
  final k = keyword.trim().toLowerCase();
  if (k.isNotEmpty) {
    final matches = <String>[];
    for (final c in cards) {
      for (final q in c.ls('part3')) {
        if (q.toLowerCase().contains(k) && !matches.contains(q)) matches.add(q);
      }
    }
    if (matches.length >= 2) return (keyword, matches);
    for (final c in cards) {
      if (c.s('topic').toLowerCase() == k || c.s('title').toLowerCase().contains(k)) {
        return (c.s('topic'), c.ls('part3'));
      }
    }
  }
  final card = cards[roomId.hashCode.abs() % cards.length];
  final day = DateTime.now().day;
  final pick = cards[(roomId.hashCode.abs() + day) % cards.length];
  final c = pick.ls('part3').isNotEmpty ? pick : card;
  return (c.s('topic'), c.ls('part3'));
}

const List<String> _linkers = <String>[
  'because',
  'however',
  'although',
  'therefore',
  'moreover',
  'whereas',
  'for example',
  'for instance',
  'on the other hand',
  'in addition',
  'as a result',
  'which means',
  'while',
  'since',
  'unless',
  'so that',
];

const Map<String, String> _upgrades = <String, String>{
  'very important': 'crucial',
  'a lot of': 'a great deal of',
  'lots of': 'numerous',
  'very big': 'enormous',
  'good': 'beneficial',
  'bad': 'harmful',
  'big': 'significant',
  'important': 'essential',
  'things': 'aspects',
  'problem': 'issue',
  'people': 'individuals',
  'think': 'would argue',
  'nowadays': 'these days',
  'show': 'demonstrate',
  'help': 'support',
  'get': 'obtain',
};

bool _hasPhrase(String text, String phrase) =>
    RegExp('\\b${RegExp.escape(phrase)}\\b').hasMatch(text);

/// Offline heuristic partner: word count, linking words, one vocabulary
/// upgrade, then [nextQuestion].
String offlinePartnerReply(String answer, String nextQuestion) {
  final lower = answer.toLowerCase();
  final words = RegExp(r"[A-Za-z']+").allMatches(answer).length;
  final parts = <String>[];
  if (words < 12) {
    parts.add('That’s quite short ($words words). In Part 3, aim for 3–5 sentences: '
        'your view, a reason and an example.');
  } else if (words <= 40) {
    parts.add('Good answer - $words words. Add one more supporting detail or an example to develop it.');
  } else {
    parts.add('Nicely developed answer ($words words).');
  }
  final used = _linkers.where((l) => _hasPhrase(lower, l)).take(2).toList();
  if (used.isNotEmpty) {
    parts.add('You linked ideas with ${used.map((l) => '“$l”').join(' and ')}.');
  } else {
    parts.add('Try linking ideas with “because”, “however” or “for instance”.');
  }
  String? vocab;
  for (final e in _upgrades.entries) {
    if (_hasPhrase(lower, e.key)) {
      vocab = 'Vocabulary: instead of “${e.key}”, try “${e.value}”.';
      break;
    }
  }
  final extra = const <String>['considerable', 'widespread', 'a growing number of', 'long-term'];
  vocab ??= 'Vocabulary: try a less common expression such as '
      '“${extra[math.min(words, 1000) % extra.length]}”.';
  return '${parts.join(' ')}\n$vocab\n\nNext question: $nextQuestion';
}
