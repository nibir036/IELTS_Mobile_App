import 'package:flutter/material.dart';

import '../../app/data/demo.dart';
import '../../app/theme/tokens.dart';
import '../../app/widgets/app_icons.dart';
import '../../app/widgets/kit.dart';
import 'widgets.dart';

// Message bubbles and the partner-practice session card of the room chat (H4).

class ChatBubbleHeader extends StatelessWidget {
  const ChatBubbleHeader({
    super.key,
    required this.name,
    required this.time,
    required this.color,
  });

  final String name;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
        Text(time, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class MyTextBubble extends StatelessWidget {
  const MyTextBubble({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              ChatBubbleHeader(
                name: 'You',
                time: data.s('time'),
                color: t.isNight ? t.heroMuted : const Color(0xFFBDB6BB),
              ),
              Text(
                data.s('text'),
                style: TextStyle(fontSize: 15, height: 1.4, color: t.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtherBubble extends StatelessWidget {
  const OtherBubble({
    super.key,
    required this.data,
    required this.playing,
    required this.progress,
    required this.onPlay,
  });

  final Map<String, dynamic> data;
  final bool playing;
  final double progress;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final voice = data.s('type') == 'voice';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: toneBg(t, data.s('tone')),
            shape: BoxShape.circle,
          ),
          child: Text(
            data.s('initials'),
            style: TextStyle(fontSize: 12, color: toneFg(t, data.s('tone'))),
          ),
        ),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: voice ? 12 : 14, vertical: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: voice ? 6 : 2,
                children: [
                  ChatBubbleHeader(
                    name: data.s('authorName'),
                    time: data.s('time'),
                    color: t.textMuted,
                  ),
                  if (voice)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 10,
                      children: [
                        IconBox(
                          icon: playing ? AppIcons.pause : AppIcons.play,
                          tooltip: 'Play voice message',
                          circle: true,
                          size: 36,
                          bg: t.primary,
                          fg: t.onPrimary,
                          onTap: onPlay,
                        ),
                        SizedBox(
                          width: 110,
                          child: WaveformBars(
                            count: 18,
                            height: 24,
                            progress: progress,
                            seed: 4,
                          ),
                        ),
                        Text(
                          data.s('duration'),
                          style: TextStyle(fontSize: 12, color: t.textMuted),
                        ),
                      ],
                    )
                  else
                    Text(
                      data.s('text'),
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.data,
    required this.joined,
    required this.onJoin,
  });

  final Map<String, dynamic> data;
  final bool joined;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final count = data.i('joined') + (joined ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: HeroCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        gradient: t.isNight
            ? null
            : const LinearGradient(
                begin: Alignment(-0.5, -0.87),
                end: Alignment(0.5, 0.87),
                colors: [Color(0xFFF7C6D6), Color(0xFFFBE7EE)],
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.s('label'),
                        style: TextStyle(fontSize: 12, color: t.heroMuted),
                      ),
                      Text(
                        data.s('title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: t.heroText,
                        ),
                      ),
                      Text(
                        'Starts ${data.s('startsAt')} · $count joined',
                        style: TextStyle(fontSize: 12, color: t.heroMuted),
                      ),
                    ],
                  ),
                ),
                AvatarStack(
                  people: data.l('avatars'),
                  size: 28,
                  overlap: 8,
                  fontSize: 10,
                  borderColor: t.isNight
                      ? ResPalette.creamBorder
                      : const Color(0xFFFBE7EE),
                ),
              ],
            ),
            PrimaryButton(
              label: joined ? 'Joined' : 'Join room',
              height: 44,
              radius: 14,
              fontSize: 14,
              bg: ResPalette.ink,
              fg: ResPalette.white,
              trailing: joined ? AppIcons.check : AppIcons.forward,
              onTap: onJoin,
            ),
          ],
        ),
      ),
    );
  }
}
